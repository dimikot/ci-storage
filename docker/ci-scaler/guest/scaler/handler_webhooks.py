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
from api_aws import (
    DRY_RUN_MSG,
    aws_autoscaling_increment_desired_capacity,
    aws_cloudwatch_put_metric_data,
)
from helpers import (
    ExpiringDict,
    PostJsonHttpRequestHandler,
    AsgSpec,
    log,
    logged_result,
)
from typing import Any, Literal, cast


DUPLICATED_EVENTS_TTL = 3600
JOB_TIMING_TTL = 3600 * 2
WORKFLOW_TTL = 3600
WORKFLOW_RUN_EVENT = "workflow_run"
WORKFLOW_JOB_EVENT = "workflow_job"
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


@dataclasses.dataclass
class JobTiming:
    job_id: int
    queued_at: float | None = None
    started_at: float | None = None
    completed_at: float | None = None
    bumped: set[str] = dataclasses.field(default_factory=set)


class HandlerWebhooks:
    def __init__(self, *, domain: str, asg_specs: list[AsgSpec]):
        self.domain = domain
        self.asg_specs = asg_specs
        self.webhooks: dict[str, Webhook] = {}
        self.service_action = ServiceAction(prev_at=int(time.time()))
        self.secret = gh_get_webhook_secret()
        self.duplicated_events = ExpiringDict[tuple[int, str], float](
            ttl=DUPLICATED_EVENTS_TTL
        )
        self.job_timings = ExpiringDict[int, JobTiming](ttl=JOB_TIMING_TTL)
        self.workflows = ExpiringDict[str, dict[str, Any]](ttl=WORKFLOW_TTL)
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
                    events=[WORKFLOW_RUN_EVENT, WORKFLOW_JOB_EVENT],
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
        run_payload = data.get(WORKFLOW_RUN_EVENT)
        job_payload = data.get(WORKFLOW_JOB_EVENT)

        # For local debugging only! Allows to simulate a webhook with just
        # querying an URL that includes the repo name and label:
        # - /workflow_run/owner/repo/label
        # - /workflow_job/owner/repo/label/{queued|in_progress|completed}/job_id
        if (
            handler.client_address[0] == "127.0.0.1"
            and not action
            and not run_payload
            and not job_payload
        ):
            if match := re.match(
                rf"^/{WORKFLOW_RUN_EVENT}/([^/]+/[^/]+)/([^/]+)/?$",
                handler.path,
            ):
                return self._handle_workflow_run_in_progress(
                    handler=handler,
                    repository=match.group(1),
                    labels={match.group(2): 1},
                )
            elif match := re.match(
                rf"^/{WORKFLOW_JOB_EVENT}/([^/]+/[^/]+)/([^/]+)/([^/]+)/([^/]+)/?$",
                handler.path,
            ):
                return self._handle_workflow_job_timing(
                    handler=handler,
                    repository=match.group(1),
                    labels={match.group(2): 1},
                    action=cast(Any, match.group(3)),
                    job_id=int(match.group(4)),
                    name=None,
                )
            else:
                return handler.send_error(
                    404,
                    f"When accessing from localhost for debugging, the path must look like: "
                    + f"/{WORKFLOW_RUN_EVENT}/owner/repo/label"
                    + f" or "
                    + f"/{WORKFLOW_JOB_EVENT}/owner/repo/label/{'{queued|in_progress|completed}'}/job_id"
                    + f", but got {handler.path}",
                )

        repository: str | None = data.get("repository", {}).get("full_name", None)
        if repository in self.webhooks:
            self.webhooks[repository].last_delivery_at = int(time.time())

        name = (
            str(run_payload.get("name"))
            if run_payload
            else str(job_payload.get("name")) if job_payload else None
        )
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

        assert self.secret
        error = verify_signature(
            secret=self.secret,
            headers=handler.headers,
            data_bytes=data_bytes,
        )
        if error:
            return handler.send_error(403, error)

        if run_payload:
            if action != "requested" and action != "in_progress":
                return handler.send_json(
                    202,
                    message='ignoring action != ["requested", "in_progress"]',
                )

            event_key = (int(run_payload["id"]), str(run_payload["run_attempt"]))
            processed_at = self.duplicated_events.get(event_key)
            if processed_at:
                return handler.send_json(
                    202,
                    message=f"ignoring event that has already been processed at {time.ctime(processed_at)}",
                )

            head_sha = str(run_payload["head_sha"])
            path = str(run_payload["path"])
            message = f"{repository}{event_key}: downloading {os.path.basename(path)} and parsing jobs list"
            try:
                cache_key = f"{repository}:{path}"
                workflow = self.workflows.get(cache_key, None)
                if not workflow:
                    workflow = gh_fetch_workflow(
                        repository=repository,
                        sha=head_sha,
                        path=path,
                    )
                    self.workflows[cache_key] = workflow
                else:
                    message += f" (cached)"
                labels = gh_predict_workflow_labels(workflow=workflow)
                log(
                    f"{message}... "
                    + " ".join([f"{k}:+{v}" for k, v in labels.items()])
                )
            except Exception as e:
                return handler.send_error(500, f"{message} failed: {e}")

            self.duplicated_events[event_key] = time.time()
            return self._handle_workflow_run_in_progress(
                handler=handler,
                repository=repository,
                labels=labels,
            )

        if job_payload:
            if action != "queued" and action != "in_progress" and action != "completed":
                return handler.send_json(
                    202,
                    message='ignoring action != ["queued", "in_progress", "completed"]',
                )

            event_key = (int(job_payload["id"]), action)
            processed_at = self.duplicated_events.get(event_key)
            if processed_at:
                return handler.send_json(
                    202,
                    message=f"ignoring event that has already been processed at {time.ctime(processed_at)}",
                )

            self.duplicated_events[event_key] = time.time()
            return self._handle_workflow_job_timing(
                handler=handler,
                repository=repository,
                labels={label: 1 for label in job_payload["labels"]},
                action=action,
                job_id=int(job_payload["id"]),
                name=name,
            )

        return handler.send_json(
            202,
            message=f"ignoring event with no {WORKFLOW_RUN_EVENT} and {WORKFLOW_JOB_EVENT}",
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
                messages.append(f"{asg_spec}:+{inc}")

        if not messages:
            # Most likely, it's a GitHub-hosted action runner's label.
            return handler.send_json(
                202,
                message=f"ignoring event, since no matching auto-scaling group(s) found for repository {repository} and labels {[*labels.keys()]}",
            )

        return handler.send_json(
            200,
            message=f"updated desired capacity: {', '.join(messages)}"
            + (f" {DRY_RUN_MSG}" if not has_aws else ""),
        )

    def _handle_workflow_job_timing(
        self,
        *,
        handler: PostJsonHttpRequestHandler,
        repository: str,
        labels: dict[str, int],
        action: Literal["queued", "in_progress", "completed"],
        job_id: int,
        name: str | None,
    ):
        asg_spec: AsgSpec | None = None
        for asg in self.asg_specs:
            if asg.repository == repository and asg.label in labels:
                asg_spec = asg
                break
        if not asg_spec:
            return handler.send_json(
                202,
                message=f"ignoring event, since no matching auto-scaling group(s) found for repository {repository} and labels {[*labels.keys()]}",
            )

        timing = self.job_timings.get(job_id) or JobTiming(job_id=job_id)
        self.job_timings[job_id] = timing

        now = time.time()
        if action == "queued":
            timing.queued_at = now
        elif action == "in_progress":
            timing.started_at = now
        elif action == "completed":
            timing.completed_at = now

        metrics: dict[str, int] = {}
        if timing.started_at and timing.queued_at:
            metrics["JobPickUpTimeSec"] = int(timing.started_at - timing.queued_at)
        if timing.completed_at and timing.started_at:
            metrics["JobExecutionTimeSec"] = int(
                timing.completed_at - timing.started_at
            )
        if timing.completed_at and timing.queued_at:
            metrics["JobCompleteTimeSec"] = int(timing.completed_at - timing.queued_at)

        for metric in timing.bumped:
            metrics.pop(metric, None)
        timing.bumped.update(metrics.keys())

        if metrics:
            job_name = (
                re.sub(
                    r"^_+|_+$",  # e.g. "_some_text_" -> "some_text"
                    "",
                    re.sub(
                        r"[^-_a-zA-Z0-9]+",  # e.g. "run lint" -> "run_lint"
                        "_",
                        re.sub(
                            r"\s+\d+$",  # e.g. "test 6" -> "test x"
                            " x",
                            name.lower(),  # e.g. "Abc" -> "abc"
                        ),
                    ),
                )
                if name
                else None
            )
            has_aws = aws_cloudwatch_put_metric_data(
                metrics=metrics,
                dimensions={
                    "GH_REPOSITORY": asg_spec.repository,
                    "GH_LABEL": asg_spec.label,
                    **({"GH_JOB_NAME": job_name} if job_name else {}),
                },
            )
            log(
                f"{asg_spec}: job_id={job_id} job_name={job_name}: "
                + " ".join(f"{k}={v}" for k, v in metrics.items())
                + (f" {DRY_RUN_MSG}" if not has_aws else "")
            )

        return handler.send_json(
            200,
            message=f"processed event for job_id={job_id}: {asg_spec}",
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
