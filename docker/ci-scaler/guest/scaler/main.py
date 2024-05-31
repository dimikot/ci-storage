#!/usr/bin/env python3
__import__("sys").dont_write_bytecode = True
import argparse
import re
import socketserver
import threading
import time
from api_gh import gh_fetch_runners
from handler_cloudwatch_rate_limits import HandlerCloudWatchRateLimits
from handler_cloudwatch_runners import HandlerCloudWatchRunners
from handler_idle_runners import HandlerIdleRunners
from handler_offline_runners import HandlerOfflineRunners
from handler_webhooks import HandlerWebhooks
from helpers import (
    AsgHandler,
    AsgSpec,
    logged_result,
    log,
    ParagraphFormatter,
    Runner,
    wrap_main,
)


def main():
    parser = argparse.ArgumentParser(
        description="""
            Adds a runner instance to an auto-scaling group upon receiving a
            workflow webhook event from GitHub. Removes runner instances from
            auto-scaling groups if they are idle for too long. De-registers
            offline runners. Publishes CloudWatch metrics about the runners and
            about rate limits.

            Each --asg spec "{owner}/{repo}:{label}:{asg_name}" means: "when
            receiving a webhook about a queued job in the repository
            {owner}/{repo} labelled with {label}, add an instance to the
            auto-scaling group {asg_name}". The list of specs also defines,
            which repositories are subject for maintenance.

            When a workflow starts running, and the tool gets a webhook event,
            it tries to predict, how many more runner instances does it need to
            launch in the corresponding auto-scaling groups. To do this, the
            tool downloads and parses the workflow yaml file and counts the
            number of jobs (taking care of matrix shards if any). The prediction
            algorithm can be made as flexible as needed in the future.
        """,
        formatter_class=ParagraphFormatter,
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8088,
        help="port to listen for GitHub webhook events",
    )
    parser.add_argument(
        "--domain",
        type=str,
        required=True,
        help="domain of API Gateway which listens for GitHub webhook requests via HTTPS and forwards all requests to this container's port",
    )
    parser.add_argument(
        "--asgs",
        type=str,
        action="append",
        default=[],
        required=True,
        help="space delimited list of auto-scaling specs; format of each item: {owner}/{repo}:{label}:{asg_name}",
    )
    parser.add_argument(
        "--poll-interval-sec",
        type=int,
        default=120,
        help="poll for the list of runners that often; it also determines the interval for publishing CloudWatch metrics",
    )
    parser.add_argument(
        "--max-idle-age-sec",
        type=int,
        default=300,
        help="idle runner instances will be removed from the auto-scaling group after this time if they are not needed for elasticity",
    )
    parser.add_argument(
        "--max-offline-age-sec",
        type=int,
        default=120,
        help="offline runners will be de-registered after this time",
    )
    args = parser.parse_args()

    port = int(args.port)
    domain = re.sub(r"^[^/]*//|/.*$", "", str(args.domain))
    asg_specs = [AsgSpec(s) for s in " ".join(args.asgs).split()]
    poll_interval_sec = int(args.poll_interval_sec)
    max_idle_age_sec = int(args.max_idle_age_sec)
    max_offline_age_sec = int(args.max_offline_age_sec)

    handler_cloudwatch_rate_limits = HandlerCloudWatchRateLimits()
    handlers_asg: dict[AsgSpec, list[AsgHandler]] = {}
    for asg_spec in asg_specs:
        handlers_asg.setdefault(asg_spec, []).extend(
            [
                HandlerCloudWatchRunners(asg_spec=asg_spec),
                HandlerIdleRunners(
                    asg_spec=asg_spec,
                    max_idle_age_sec=max_idle_age_sec,
                ),
                HandlerOfflineRunners(
                    asg_spec=asg_spec,
                    max_offline_age_sec=max_offline_age_sec,
                ),
            ]
        )

    def poll_thread():
        while True:
            runners: dict[str, list[Runner]] = {}
            for repository in set(asg_spec.repository for asg_spec in asg_specs):
                runners[repository] = gh_fetch_runners(repository=repository)
            for asg_spec in asg_specs:
                for handler in handlers_asg.get(asg_spec, []):
                    with logged_result(swallow=True, failure=f"Error in {handler}"):
                        handler.handle(
                            [
                                runner
                                for runner in runners[asg_spec.repository]
                                if asg_spec.label in runner.labels
                            ]
                        )
            with logged_result(
                swallow=True,
                failure=f"Error in {handler_cloudwatch_rate_limits}",
            ):
                handler_cloudwatch_rate_limits.handle()
            time.sleep(poll_interval_sec)

    with HandlerWebhooks(domain=domain, asg_specs=asg_specs) as webhooks:
        with socketserver.TCPServer(
            ("", port),
            webhooks.RequestHandler,
            bind_and_activate=False,
        ) as httpd:
            httpd.allow_reuse_port = True
            httpd.server_bind()
            httpd.server_activate()
            httpd.service_actions = webhooks.service_actions
            log(f"Listening for webhook events on port {port}")
            thread = threading.Thread(
                target=lambda: wrap_main(poll_thread),
                daemon=True,
            )
            thread.start()
            httpd.serve_forever()


if __name__ == "__main__":
    wrap_main(main)
