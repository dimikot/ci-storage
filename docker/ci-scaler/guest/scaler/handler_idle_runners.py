import time
import datetime
from api_aws import (
    DRY_RUN_MSG,
    aws_autoscaling_describe_auto_scaling_group,
    aws_autoscaling_terminate_instance,
    aws_region,
)
from api_gh import gh_runner_ensure_absent
from helpers import (
    AsgHandler,
    AsgSpec,
    Runner,
    RunnersRegistry,
    ExpiringDict,
    logged_result,
)
from typing import Literal

REVISIT_TERMINATED_INSTANCE_SEC = datetime.timedelta(minutes=10).total_seconds()


class HandlerIdleRunners(AsgHandler):
    def __init__(
        self,
        *,
        asg_spec: AsgSpec,
        max_idle_age_sec: int,
    ):
        super().__init__(asg_spec=asg_spec)
        self.max_idle_age_sec = max_idle_age_sec
        self.idle_runners = RunnersRegistry()
        self.terminated_instance_ids = ExpiringDict[str, Literal[True]](
            ttl=REVISIT_TERMINATED_INSTANCE_SEC,
        )

    def handle(self, runners: list[Runner]) -> None:
        self.idle_runners.assign_if_not_exists(
            runner
            for runner in runners
            if not runner.busy and runner.status == "online"
        )
        old_idle_runners = sorted(
            [
                runner
                for runner in self.idle_runners.values()
                if runner.id not in self.terminated_instance_ids
                and time.time() > runner.loaded_at + self.max_idle_age_sec
            ],
            key=lambda runner: -runner.loaded_at,  # oldest runners last
        )

        asg_description = aws_autoscaling_describe_auto_scaling_group(
            asg_name=self.asg_spec.asg_name
        )
        min_size = asg_description.min_size if asg_description else 1

        for runner in old_idle_runners[min_size:]:
            if (
                asg_description
                and runner.instance_id() not in asg_description.instance_ids
            ):
                # This is a weird GitHub bug: sometimes the runner exists and is
                # idle, but the corresponding instance is NOT in ASG (and not in
                # AWS) anymore. How could it disappear, and the runner remains
                # idle for many days? Mystery. So in this case, instead of
                # trying to delete the disappeared instance from ASG and fail,
                # we try to remove that sick runner from GitHub.
                with logged_result(
                    swallow=True,
                    doing=f"instance {runner.instance_id()} for old idle runner {runner.name} "
                    + f"is not in ASG {self.asg_spec} (GitHub bug?), so just removing the runner from GitHub"
                    + (f" {DRY_RUN_MSG}" if not aws_region() else ""),
                ):
                    gh_runner_ensure_absent(
                        repository=self.asg_spec.repository,
                        runner_id=runner.id,
                    )
                    self.terminated_instance_ids[runner.id] = True
            else:
                with logged_result(
                    swallow=True,
                    doing=f"terminating instance {runner.instance_id()} for old idle runner {runner.name} "
                    + f"in {self.asg_spec}"
                    + (f" {DRY_RUN_MSG}" if not aws_region() else ""),
                ):
                    aws_autoscaling_terminate_instance(instance_id=runner.instance_id())
                    self.terminated_instance_ids[runner.id] = True
