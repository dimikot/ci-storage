#!/bin/bash
#
# Configures self-hosted runner.
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
#   auto-removed in 1 day. But we anyways implement the manual removal cycle in
#   ci-scaler, since even 1 day is way too much for garbage accumulation.
#
set -u -e

cd ~/actions-runner

name_prefix="ci-storage"
instance_id=$(aws_instance_id)
if [[ "$instance_id" != "" ]]; then
  hash="${instance_id##i-}"
  name="$name_prefix-$hash-$(date '+%m%d-%H%M')"
else
  name="$name_prefix-$(date '+%Y%m%d-%H%M%S')-$((RANDOM+10000))"
fi

rm -f .runner
token=$(gh api -X POST --jq .token "repos/$GH_REPOSITORY/actions/runners/registration-token")
./config.sh \
  --unattended \
  --url "https://github.com/$GH_REPOSITORY" \
  --token "$token" \
  --name "$name" \
  --labels "$GH_LABELS" \
  --work "$WORK_DIR" \
  --disableupdate \
  --replace

