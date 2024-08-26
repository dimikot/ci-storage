import time
import datetime
from api_aws import (
    DRY_RUN_MSG,
    aws_autoscaling_describe_auto_scaling_group,
    aws_autoscaling_terminate_instance,
    aws_region,
)
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
            with logged_result(
                swallow=True,
                doing=f"terminating old idle instance {runner.name} in {self.asg_spec}"
                + (f" {DRY_RUN_MSG}" if not aws_region() else ""),
            ):
                aws_autoscaling_terminate_instance(instance_id=runner.instance_id())
                self.terminated_instance_ids[runner.id] = True
