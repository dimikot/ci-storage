import json
import re
import urllib.request
from helpers import RateLimits


def docker_hub_fetch_rate_limits() -> RateLimits:
    with urllib.request.urlopen(
        urllib.request.Request(
            "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull",
            method="GET",
        )
    ) as res:
        token = json.loads(res.read().decode()).get("token", "")

    with urllib.request.urlopen(
        urllib.request.Request(
            "https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest",
            method="HEAD",
            headers={"Authorization": f"Bearer {token}"},
        )
    ) as res:
        headers = res.headers

    return RateLimits(
        limit=int(re.sub(r";.*", "", headers.get("ratelimit-limit", "0")).strip()),
        remaining=int(
            re.sub(r";.*", "", headers.get("ratelimit-remaining", "0")).strip()
        ),
    )
