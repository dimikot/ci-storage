from api_gh import gh_fetch_rate_limits
from api_docker_hub import docker_hub_fetch_rate_limits
from api_aws import DRY_RUN_MSG, aws_cloudwatch_put_metric_data
from helpers import log


class HandlerCloudWatchRateLimits:
    def __init__(self):
        pass

    def __str__(self) -> str:
        return self.__class__.__name__

    def handle(self):
        gh = gh_fetch_rate_limits()
        docker_hub = docker_hub_fetch_rate_limits()
        metrics = {
            "GitHubLimit": gh.limit,
            "GitHubRemaining": gh.remaining,
            "DockerHubLimit": docker_hub.limit,
            "DockerHubRemaining": docker_hub.remaining,
        }
        has_aws = aws_cloudwatch_put_metric_data(
            metrics=metrics,
            dimensions={},
        )
        log(
            " ".join(f"{k}={v}" for k, v in metrics.items())
            + (f" {DRY_RUN_MSG}" if not has_aws else "")
        )
