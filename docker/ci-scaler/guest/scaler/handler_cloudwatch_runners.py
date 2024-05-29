import re
from api_aws import (
    DRY_RUN_MSG,
    aws_autoscaling_describe_auto_scaling_group,
    aws_cloudwatch_put_metric_data,
)
from helpers import AsgHandler, Runner, log


class HandlerCloudWatchRunners(AsgHandler):
    def handle(self, runners: list[Runner]) -> None:
        metrics: dict[str, int] = {}
        metrics["IdleRunnersCount"] = len(
            [r for r in runners if not r.busy and r.status == "online"]
        )
        metrics["ActiveRunnersCount"] = len(
            [r for r in runners if r.busy and r.status == "online"]
        )
        metrics["OfflineRunnersCount"] = len(
            [r for r in runners if r.status == "offline"]
        )
        metrics["OnlineRunnersCount"] = len(
            [r for r in runners if r.status == "online"]
        )
        metrics["AllRunnersCount"] = len(runners)
        metrics["ActiveRunnersPercent"] = (
            0
            if metrics["OnlineRunnersCount"] == 0
            else int(
                (metrics["ActiveRunnersCount"] / metrics["OnlineRunnersCount"]) * 100
            )
        )

        asg_description = aws_autoscaling_describe_auto_scaling_group(
            asg_name=self.asg_spec.asg_name
        )
        if asg_description:
            metrics["AsgDesiredCapacity"] = asg_description.desired_capacity
            metrics["AsgMinSize"] = asg_description.min_size
            metrics["AsgMaxSize"] = asg_description.max_size

        has_aws = aws_cloudwatch_put_metric_data(
            metrics=metrics,
            dimensions={
                "GH_REPOSITORY": self.asg_spec.repository,
                "GH_LABEL": self.asg_spec.label,
            },
        )
        log(
            f"{self.asg_spec}: "
            + " ".join(
                f"{re.sub(f'Runners|Count|Capacity', '', k)}={v}"
                for k, v in metrics.items()
            )
            + (f" {DRY_RUN_MSG}" if not has_aws else "")
        )
