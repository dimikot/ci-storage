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
)
from api_aws import DRY_RUN_MSG, aws_autoscaling_increment_desired_capacity
from helpers import ExpiringDict, PostJsonHttpRequestHandler, AsgSpec, log
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


class HandlerWebhooks:
    def __init__(self, *, domain: str, asg_specs: list[AsgSpec]):
        self.domain = domain
        self.asg_specs = asg_specs
        self.webhooks: dict[str, str] = {}
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
            url = f"https://{self.domain}/ci-storage"
            log(f"Registering webhook for {repository}: {url}")
            gh_webhook_ensure_exists(
                repository=repository,
                url=url,
                secret=self.secret,
                events=[WORKFLOW_RUN_EVENT],
            )
            self.webhooks[repository] = url
        return self

    def __exit__(self, *_: Any):
        for repository, url in self.webhooks.items():
            log(f"Deleting webhook {url} for {repository}")
            gh_webhook_ensure_absent(repository=repository, url=url)

    def handle(
        self,
        handler: PostJsonHttpRequestHandler,
        data: dict[str, Any],
        data_bytes: bytes,
    ):
        action = data.get("action")
        event_payload = data.get(WORKFLOW_RUN_EVENT)
        name = event_payload.get("name") if event_payload else None

        keys = [k for k in data.keys() if k not in IGNORE_KEYS]
        if keys:
            handler.log_suffix = (
                f"{{{','.join(keys)}}}"
                + (f" action={action}" if action else "")
                + (f' name="{name}"' if name else "")
            )

        if "hook" in data:
            return handler.send_json(202, message='ignoring service "hook" event')

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
            if action != "in_progress":
                return handler.send_json(202, message="ignoring non-in_progress event")

            repository = str(data["repository"]["full_name"])
            head_sha = str(event_payload["head_sha"])
            path = str(event_payload["path"])
            key = (int(event_payload["id"]), int(event_payload["run_attempt"]))

            processed_at = self.duplicated_events.get(key)
            if processed_at:
                return handler.send_json(
                    202,
                    message=f"this event has already been processed at {time.ctime(processed_at)}",
                )
            self.duplicated_events[key] = time.time()

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

            return self._handle_workflow_run_in_progress(
                handler=handler,
                repository=repository,
                labels=labels,
            )

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
            return handler.send_error(
                404,
                f"No matching auto-scaling group(s) found for repository {repository} and labels {[*labels.keys()]}",
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
