from api_docker_hub import docker_hub_fetch_rate_limits
from unittest import TestCase


class Test(TestCase):
    def test_docker_hub_fetch_rate_limits(self):
        rate_limits = docker_hub_fetch_rate_limits()
        # When run from inside of GitHub's runners, Docker Hub doesn't even
        # return the rate limit headers.
        self.assertGreaterEqual(rate_limits.limit, 0)
        self.assertGreaterEqual(rate_limits.remaining, 0)
