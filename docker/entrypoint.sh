#!/bin/bash
#
# Here we make an opinionated decision to NOT use ephemeral or jit acton
# runners. Reasons:
# - We WANT to reuse the work directory across job runs, that's the whole point
#   of ci-storage architecture and its speedup benefits. So once the runner
#   finishes some job, we do NOT want it to terminate (as it does in ephemeral
#   or jit mode), we want it to CONTINUE listening for more jobs to run.
# - GitHub doesn't allow to remove busy runners via API, which is very good for
#   us: in case the container shuts down externaly due to downscaling, we just
#   enter the graceful retry loop to delete the corresponding runner via API.
# - One downside happens when a runner container dies unexpectedly (rare). In
#   this case, regular "offline" long-living runners are auto-removed by GitHub
#   itself once in 2 weeks, whilst ephemeral (or jit) "offline" runners are
#   auto-removed in 1 day. But we anyways need to implement some manual removal
#   cycle exernally, since even 1 day is way too much for garbage accumulation.
#
set -u -e -o xtrace

: $GH_REPOSITORY # {owner}/{repo}
: $GH_LABELS
: $GH_TOKEN # used by gh cli

cd ./actions-runner

name="ci-storage-$(hostname)"

token=$(gh api -X POST --jq .token "repos/$GH_REPOSITORY/actions/runners/registration-token")
./config.sh \
  --unattended \
  --url https://github.com/$GH_REPOSITORY \
  --token "$token" \
  --name "$name" \
  --labels "$GH_LABELS"

cleanup() {
  # Retry deleting the runner until it succeeds.
  # - Busy runner fails in deletion, so we can retry safely until it becomes
  #   idle and is successfully deleted.
  # - The extrnal orchestrator will eventually kill the container after a large
  #   timeout (say, 15 minutes or so) needed for a running job to finish.
  while :; do
    token=$(gh api -X POST --jq .token "repos/$GH_REPOSITORY/actions/runners/remove-token")
    ./config.sh remove --token "$token" && break
    sleep 5
    : "Retrying deletion till the runner becomes idle and succeeds..."
  done
}

trap "cleanup; exit 130" INT
trap "cleanup; exit 143" TERM

echo $$ > runner.pid

eval "$@"

./run.sh & wait $!
