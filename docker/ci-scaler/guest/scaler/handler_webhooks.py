import dataclasses
import email
import email.message
import hashlib
import hmac
import os.path
import re
import time
from api_gh import (
    gh_fetch_workflow,
    gh_get_webhook_secret,
    gh_predict_workflow_labels,
    gh_webhook_ensure_absent,
    gh_webhook_ensure_exists,
    gh_webhook_ping,
)
from api_aws import DRY_RUN_MSG, aws_autoscaling_increment_desired_capacity
from helpers import (
    ExpiringDict,
    PostJsonHttpRequestHandler,
    AsgSpec,
    log,
    logged_result,
)
from typing import Any


DUPLICATED_EVENTS_TTL = 3600
WORKFLOW_RUN_EVENT = "workflow_run"
IGNORE_KEYS = [
    "zen",
    "hook_id",
    "repository",
    "sender",
    "organization",
    "enterprise",
    "action",
]
URL_PATH = "/ci-storage"
SERVICE_ACTION_INTERVAL_SEC = 10


@dataclasses.dataclass
class Webhook:
    url: str
    last_delivery_at: int | None


@dataclasses.dataclass
class ServiceAction:
    prev_at: int
    iteration: int = 0


class HandlerWebhooks:
    def __init__(self, *, domain: str, asg_specs: list[AsgSpec]):
        self.domain = domain
        self.asg_specs = asg_specs
        self.webhooks: dict[str, Webhook] = {}
        self.service_action = ServiceAction(prev_at=int(time.time()))
        self.secret = gh_get_webhook_secret()
        self.duplicated_events = ExpiringDict[tuple[int, int], float](
            ttl=DUPLICATED_EVENTS_TTL
        )
        this = self

        class RequestHandler(PostJsonHttpRequestHandler):
            def handle_POST_json(self, data: dict[str, Any], data_bytes: bytes):
                this.handle(self, data, data_bytes)

        self.RequestHandler = RequestHandler

    def __enter__(self):
        if not self.secret:
            return self
        for repository in list(set(asg_spec.repository for asg_spec in self.asg_specs)):
            url = f"https://{self.domain}{URL_PATH}"
            with logged_result(doing=f"Registering webhook for {repository}: {url}"):
                gh_webhook_ensure_exists(
                    repository=repository,
                    url=url,
                    secret=self.secret,
                    events=[WORKFLOW_RUN_EVENT],
                )
                self.webhooks[repository] = Webhook(url=url, last_delivery_at=None)
        return self

    def __exit__(self, *_: Any):
        for repository, webhook in self.webhooks.items():
            with logged_result(
                swallow=True,
                doing=f"Deleting webhook for {repository}: {webhook.url}",
            ):
                gh_webhook_ensure_absent(repository=repository, url=webhook.url)

    def service_actions(self):
        now = int(time.time())
        if now > self.service_action.prev_at + SERVICE_ACTION_INTERVAL_SEC:
            i = self.service_action.iteration
            self.service_action.iteration += 1
            self.service_action.prev_at = now
            webhooks = [*self.webhooks.items()]
            if webhooks:
                repository, webhook = webhooks[i % len(webhooks)]
                if webhook.last_delivery_at is None:
                    with logged_result(
                        swallow=True,
                        doing=f"Sending additional PING to webhook for {repository}: {webhook.url}",
                    ):
                        gh_webhook_ping(repository=repository, url=webhook.url)

    def handle(
        self,
        handler: PostJsonHttpRequestHandler,
        data: dict[str, Any],
        data_bytes: bytes,
    ):
        action = data.get("action")
        event_payload = data.get(WORKFLOW_RUN_EVENT)
        name = event_payload.get("name") if event_payload else None
        repository: str | None = data.get("repository", {}).get("full_name", None)

        if repository in self.webhooks:
            self.webhooks[repository].last_delivery_at = int(time.time())

        keys = [k for k in data.keys() if k not in IGNORE_KEYS]
        if keys:
            handler.log_suffix = (
                f"{{{','.join(keys)}}}"
                + (f" action={action}" if action else "")
                + (f' name="{name}"' if name else "")
            )

        if "hook" in data:
            return handler.send_json(202, message='ignoring "hook" service event')

        if not repository:
            return handler.send_json(202, message="ignoring event with no repository")

        if handler.client_address[0] == "127.0.0.1" and not event_payload:
            match = re.match(
                rf"^/{WORKFLOW_RUN_EVENT}/([^/]+/[^/]+)/([^/]+)/?$",
                handler.path,
            )
            if match:
                return self._handle_workflow_run_in_progress(
                    handler=handler,
                    repository=match.group(1),
                    labels={match.group(2): 1},
                )
            else:
                return handler.send_error(
                    404,
                    f"When accessing from localhost for debugging, the path must "
                    + f"look like: /{WORKFLOW_RUN_EVENT}/{'{owner}/{repo}/{label}'}, but got {handler.path}",
                )

        assert self.secret
        error = verify_signature(
            secret=self.secret,
            headers=handler.headers,
            data_bytes=data_bytes,
        )
        if error:
            return handler.send_error(403, error)

        if event_payload:
            if action != "requested" and action != "in_progress":
                return handler.send_json(
                    202,
                    message='ignoring action != ["requested", "in_progress"]',
                )

            event_key = (int(event_payload["id"]), int(event_payload["run_attempt"]))
            processed_at = self.duplicated_events.get(event_key)
            if processed_at:
                return handler.send_json(
                    202,
                    message=f"this event has already been processed at {time.ctime(processed_at)}",
                )

            head_sha = str(event_payload["head_sha"])
            path = str(event_payload["path"])

            message = f"{repository}: downloading {os.path.basename(path)} and parsing jobs list..."
            try:
                workflow = gh_fetch_workflow(
                    repository=repository,
                    sha=head_sha,
                    path=path,
                )
                labels = gh_predict_workflow_labels(workflow=workflow)
                log(f"{message} " + " ".join([f"{k}:+{v}" for k, v in labels.items()]))
            except Exception as e:
                return handler.send_error(500, f"{message} failed: {e}")

            self._handle_workflow_run_in_progress(
                handler=handler,
                repository=repository,
                labels=labels,
            )
            self.duplicated_events[event_key] = time.time()

    def _handle_workflow_run_in_progress(
        self,
        *,
        handler: PostJsonHttpRequestHandler,
        repository: str,
        labels: dict[str, int] = {},
    ):
        messages: list[str] = []
        has_aws = False
        for asg_spec in self.asg_specs:
            if asg_spec.repository == repository and asg_spec.label in labels:
                inc = labels[asg_spec.label]
                res = aws_autoscaling_increment_desired_capacity(
                    asg_name=asg_spec.asg_name,
                    inc=inc,
                )
                has_aws = has_aws or res
                messages.append(f"{asg_spec.label}:+{inc}")
        if messages:
            return handler.send_json(
                200,
                message=f"{repository} desired capacity: {', '.join(messages)}"
                + (f" {DRY_RUN_MSG}" if not has_aws else ""),
            )
        else:
            # Most likely, it's a GitHub-hosted action runner's label.
            return handler.send_json(
                202,
                message=f"Ignored: no matching auto-scaling group(s) found for repository {repository} and labels {[*labels.keys()]}",
            )


def verify_signature(
    *,
    secret: str,
    headers: email.message.Message,
    data_bytes: bytes,
) -> str | None:
    header_name = "X-Hub-Signature-256"
    signature_header = headers.get(header_name)
    if not signature_header:
        return f"{header_name} header is missing"
    hash_object = hmac.new(
        secret.encode(),
        msg=data_bytes,
        digestmod=hashlib.sha256,
    )
    expected_signature = "sha256=" + hash_object.hexdigest()
    if not hmac.compare_digest(expected_signature, signature_header):
        return "Request signatures didn't match"
    return None
