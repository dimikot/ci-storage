#!/bin/bash
#
# Configures self-hosted runner and sets up graceful shutdown handling.
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
set -u -e

cd ~/actions-runner

name=$(cat .name 2>/dev/null || true)
if [[ "$name" == "" ]]; then
  name_prefix="ci-storage"
  instance_id=$(aws_metadata_curl latest/meta-data/instance-id)
  if [[ "$instance_id" != "" ]]; then
    hash="${instance_id##i-}"
    name="$name_prefix-${hash:0:8}-$(date '+%m%d-%H%M')"
  else
    name="$name_prefix-$(date '+%Y%m%d-%H%M%S')-$((RANDOM+10000))"
  fi
  echo "$name" > .name
fi

rm -f .runner
token=$(gh api -X POST --jq .token "repos/$GH_REPOSITORY/actions/runners/registration-token")
./config.sh \
  --unattended \
  --url "https://github.com/$GH_REPOSITORY" \
  --token "$token" \
  --name "$name" \
  --labels "$GH_LABELS" \
  --replace

cleanup() {
  echo "$(nice_date): Received graceful shutdown signal $1..."

  # A debug facility to test, how much time does the orchestrator give the
  # container to gracefully shutdown before killing it.
  if [[ "$DEBUG_SHUTDOWN_DELAY_SEC" != "" ]]; then
    echo "Artificially delaying shutdown for $DEBUG_SHUTDOWN_DELAY_SEC second(s)..."
    count=0
    while [[ $count -lt "$DEBUG_SHUTDOWN_DELAY_SEC" ]]; do
      sleep 1
      count=$((count + 1))
      echo "  ...$count seconds elapsed"
    done
  fi

  # Retry deleting the runner until it succeeds.
  # - Busy runner fails in deletion, so we can retry safely until it becomes
  #   idle and is successfully deleted.
  # - In case we can't delete the runner for a long time still, the extrnal
  #   orchestrator will eventually kill the container after a large timeout
  #   (say, 15 minutes or so) needed for a running job to finish.
  echo "Removing the runner..."
  while :; do
    token=$(gh api -X POST --jq .token "repos/$GH_REPOSITORY/actions/runners/remove-token")
    cd ~/actions-runner && ./config.sh remove --token "$token" && break
    sleep 5
    echo "$(nice_date): Retrying till the runner becomes idle and the removal succeeds..."
  done
}

trap "cleanup SIGINT; exit 130" INT
trap "cleanup SIGHUP; exit 143" TERM
