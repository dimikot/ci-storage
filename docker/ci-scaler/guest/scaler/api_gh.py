import codecs
import hashlib
import json
import os
import subprocess
import time
import yaml
from helpers import Runner, RateLimits, check_output
from typing import Any, cast


def gh(
    *args: str,
    input: str | None = None,
) -> str:
    return check_output(["gh", *args], input=input)


def gh_api(
    *args: str,
    input: Any | None = None,
) -> Any:
    args = ("-H", "Accept: application/vnd.github.v3+json", *args)
    res = gh(
        "api",
        *(["--input=-"] if input else []),
        *args,
        input=json.dumps(input) if input is not None else None,
    )
    return json.loads(res.strip()) if res != "" else None


def gh_fetch_runners(
    *,
    repository: str,
) -> list[Runner]:
    res = gh_api(f"repos/{repository}/actions/runners", "--paginate")
    if not isinstance(res, dict):
        raise ValueError(f"gh api returned a non-object: {res}")
    runners = cast(dict[str, Any], res).get("runners")
    if not isinstance(runners, list):
        raise ValueError(f'gh api returned a response with no "runners" key: {res}')
    return [
        Runner(
            id=str(runner["id"]),
            name=str(runner["name"]),
            status=runner["status"],
            busy=bool(runner["busy"]),
            labels=[
                str(item["name"])
                for item in runner["labels"]
                if item["type"] == "custom"
            ],
            loaded_at=int(time.time()),
        )
        for runner in cast(list[dict[str, Any]], runners)
    ]


def gh_runner_ensure_absent(
    *,
    repository: str,
    runner_id: str,
):
    # It does not fail if id is not found: instead, always returns 204.
    gh_api("-XDELETE", f"/repos/{repository}/actions/runners/{runner_id}")


def gh_get_webhook_secret() -> str | None:
    # In Ubuntu, gh tool may be old, so it may not support "gh auth token". So
    # we try to use a well-known environment variable first.
    token = os.environ.get("GH_TOKEN", os.environ.get("GITHUB_TOKEN"))
    if not token:
        token = gh("auth", "token")
    return hashlib.sha256(token.encode()).digest().hex() if token else None


def gh_webhook_ensure_exists(
    *,
    repository: str,
    url: str,
    secret: str,
    events: list[str],
):
    gh_webhook_ensure_absent(repository=repository, url=url)
    try:
        gh_api(
            "-XPOST",
            f"/repos/{repository}/hooks",
            input={
                "config": {
                    "url": url,
                    "content_type": "json",
                    "secret": secret,
                },
                "events": events,
                "active": True,
            },
        )
    except subprocess.CalledProcessError as e:
        if e.stdout.find(b"Hook already exists") == -1:
            raise


def gh_webhook_ensure_absent(
    *,
    repository: str,
    url: str,
):
    ids = gh_api(
        f"/repos/{repository}/hooks",
        "--paginate",
        "--jq",
        f"[.[] | select(.config.url=={json.dumps(url)}) | .id]",
    )
    for id in ids:
        gh_api("-XDELETE", f"/repos/{repository}/hooks/{id}")


def gh_fetch_workflow(
    *,
    repository: str,
    sha: str,
    path: str,
) -> dict[str, Any]:
    res = gh_api(f"/repos/{repository}/contents/{path}?ref={sha}")
    workflow_content = cast(
        str | bytes,
        codecs.decode(str(res["content"]).encode(), res["encoding"]),
    )
    workflow_content = (
        workflow_content.decode()
        if isinstance(workflow_content, bytes)
        else str(workflow_content)
    )
    workflow = yaml.safe_load(workflow_content)
    if not isinstance(workflow, dict):
        raise ValueError("Invalid workflow file")
    return cast(dict[str, Any], workflow)


def gh_fetch_rate_limits() -> RateLimits:
    res = gh("api", "-i", "-XHEAD", "/rate_limit")
    rate_limit = RateLimits(limit=0, remaining=0)
    for line in res.splitlines():
        if ":" in line:
            name, value = [v.strip() for v in line.split(":", 1)]
            if name.lower() == "x-ratelimit-limit":
                rate_limit.limit = int(value)
            elif name.lower() == "x-ratelimit-remaining":
                rate_limit.remaining = int(value)
    return rate_limit


def gh_predict_workflow_labels(
    *,
    workflow: dict[str, Any],
) -> dict[str, int]:
    labels: dict[str, int] = {}
    for job in cast(dict[str, Any], workflow["jobs"]).values():
        inc = 1
        runs_on = (
            [str(k) for k in cast(list[Any], job["runs-on"])]
            if isinstance(job["runs-on"], list)
            else [str(job["runs-on"])]
        )
        strategy = job.get("strategy", {})
        max_parallel = strategy.get("max-parallel", None)
        matrix = strategy.get("matrix", None)
        if isinstance(matrix, dict):
            for shards in cast(dict[Any, Any], matrix).values():
                if isinstance(shards, list):
                    inc *= len(cast(list[Any], shards))
            if isinstance(max_parallel, int):
                inc = min(inc, max_parallel)
        for label in runs_on:
            if "$" not in label:
                labels[label] = labels.get(label, 0) + inc
    return labels
