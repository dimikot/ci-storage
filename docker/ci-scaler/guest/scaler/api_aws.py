import dataclasses
import functools
import json
import os
import re
import subprocess
import urllib.error
import urllib.request
from helpers import check_output
from typing import Any, Literal


NAMESPACE = "ci-storage/metrics"
METADATA_TIMEOUT_SEC = 3
DRY_RUN_MSG = "(DRY-RUN: no AWS metadata service)"


@dataclasses.dataclass
class AsgDescription:
    desired_capacity: int
    min_size: int
    max_size: int


@functools.lru_cache(maxsize=None)
def aws_metadata_curl(path: str) -> str | None:
    try:
        with urllib.request.urlopen(
            urllib.request.Request(
                url="http://169.254.169.254/latest/api/token",
                method="PUT",
                headers={"x-aws-ec2-metadata-token-ttl-seconds": "21600"},
            ),
            timeout=METADATA_TIMEOUT_SEC,
        ) as response:
            token = response.read().decode("utf-8")
        if token:
            with urllib.request.urlopen(
                urllib.request.Request(
                    url=f"http://169.254.169.254/{path}",
                    headers={"x-aws-ec2-metadata-token": token},
                ),
                timeout=METADATA_TIMEOUT_SEC,
            ) as response:
                return response.read().decode("utf-8")
    except urllib.error.URLError:
        return None


@functools.lru_cache(maxsize=None)
def aws_region() -> str | None:
    region = os.environ.get("AWS_REGION")
    if region:
        return region
    az = aws_metadata_curl("latest/meta-data/placement/availability-zone")
    return re.sub(r"[a-z]$", "", az) if az else None


def aws(
    *args: str,
    input: str | None = None,
) -> str | None:
    region = aws_region()
    if not region:
        return None
    return check_output(["aws", f"--region={region}", *args], input=input)


def aws_json(
    *args: str,
    input: str | None = None,
) -> dict[str, Any] | None:
    res = aws(*args, "--output=json", input=input)
    return json.loads(res.strip()) if res else None


def aws_cloudwatch_put_metric_data(
    *,
    metrics: dict[str, int],
    dimensions: dict[str, str],
) -> Literal[True] | None:
    res = aws(
        "cloudwatch",
        "put-metric-data",
        f"--namespace={NAMESPACE}",
        "--metric-data",
        *(
            f"MetricName={name},Value={value},Unit=None,StorageResolution=1,Dimensions=["
            + ",".join(
                f"{{Name={name},Value={value}}}" for name, value in dimensions.items()
            )
            + "]"
            for name, value in metrics.items()
        ),
    )
    return None if res is None else True


def aws_autoscaling_describe_auto_scaling_group(
    *,
    asg_name: str,
) -> AsgDescription | None:
    res = aws_json(
        "autoscaling",
        "describe-auto-scaling-groups",
        f"--auto-scaling-group-names={asg_name}",
    )
    if res is None:
        return None
    asgs = res.get("AutoScalingGroups")
    if not asgs:
        raise ValueError(f"AutoScalingGroup {asg_name} not found")
    asg = asgs[0]
    return AsgDescription(
        desired_capacity=asg["DesiredCapacity"],
        min_size=asg["MinSize"],
        max_size=asg["MaxSize"],
    )


def aws_autoscaling_increment_desired_capacity(
    *,
    asg_name: str,
    inc: int,
) -> Literal[True] | None:
    desc = aws_autoscaling_describe_auto_scaling_group(asg_name=asg_name)
    if desc is None:
        return None
    try:
        aws(
            "autoscaling",
            "set-desired-capacity",
            f"--auto-scaling-group-name={asg_name}",
            f"--desired-capacity={min(max(desc.desired_capacity + inc, desc.min_size), desc.max_size)}",
        )
        return True
    except subprocess.CalledProcessError as e:
        if "above" in e.stderr:
            # "An error occurred (ValidationError) when calling the
            # SetDesiredCapacity operation: New SetDesiredCapacity value N is
            # above max value N for the AutoScalingGroup" - do one retry in case
            # there is a race condition (better than nothing).
            desc = aws_autoscaling_describe_auto_scaling_group(asg_name=asg_name)
            assert desc is not None
            aws(
                "autoscaling",
                "set-desired-capacity",
                f"--auto-scaling-group-name={asg_name}",
                f"--desired-capacity={desc.max_size}",
            )
            return True
        else:
            raise


def aws_autoscaling_terminate_instance(
    *,
    instance_id: str,
) -> Literal[True] | None:
    try:
        res = aws(
            "autoscaling",
            "terminate-instance-in-auto-scaling-group",
            f"--instance-id={instance_id}",
            "--should-decrement-desired-capacity",
        )
        return None if res is None else True
    except subprocess.CalledProcessError as e:
        if "shouldDecrementDesiredCapacity" in e.stderr:
            # E.g. this error message: "Currently, desiredSize equals minSize
            # (3). Terminating instance without replacement will violate group's
            # min size constraint. Either set shouldDecrementDesiredCapacity
            # flag to false or lower group's min size." - do a retry without
            # decrementing desired capacity.
            res = aws(
                "autoscaling",
                "terminate-instance-in-auto-scaling-group",
                f"--instance-id={instance_id}",
                "--no-should-decrement-desired-capacity",
            )
            return None if res is None else True
        elif "not found" in e.stderr:
            return True
        else:
            raise
