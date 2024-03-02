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
set -u -e

if [[ "${GH_REPOSITORY:=''}" != */* ]]; then
  echo "GH_REPOSITORY must be set, and the format should be {owner}/{repo}.";
  exit 1;
fi
if [[ "${GH_LABELS:=''}" == "" ]]; then
  echo "GH_LABELS must be set.";
  exit 1;
fi
if [[ "${GH_TOKEN:=''}" == "" ]]; then
  echo "GH_TOKEN must be set.";
  exit 1;
fi
if [[ "${CI_STORAGE_HOST:=''}" != "" && ! "$CI_STORAGE_HOST" =~ ^([-.[:alnum:]]+@)?[-.[:alnum:]]+$ ]]; then
  echo "If CI_STORAGE_HOST is passed, it must be in form of {hostname} or {user}@{hostname}.";
  exit 1;
fi
if [[ "${CI_STORAGE_HOST_PRIVATE_KEY:=''}" != "" && "$CI_STORAGE_HOST_PRIVATE_KEY" != *OPENSSH\ PRIVATE\ KEY* ]]; then
  echo "If CI_STORAGE_HOST_PRIVATE_KEY is passed, it must be an SSH private key.";
  exit 1;
fi

if [[ "$(whoami)" != user || ! -d ./actions-runner ]]; then
  echo 'This script must be run as "user" user, and ./actions-runner/ should exist.';
  exit 1;
fi

if [[ "$CI_STORAGE_HOST_PRIVATE_KEY" != "" ]]; then
  echo "$CI_STORAGE_HOST_PRIVATE_KEY" > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
fi

echo $$ > entrypoint.pid
echo "$CI_STORAGE_HOST" > ci-storage-host

cd ./actions-runner

name="ci-storage-$(hostname)"
local_dir=_work/${GH_REPOSITORY##*/}/${GH_REPOSITORY##*/}

if [[ "$CI_STORAGE_HOST" != "" ]]; then
  ssh-keyscan -H "$CI_STORAGE_HOST" >> ~/.ssh/known_hosts
  chmod 600 ~/.ssh/known_hosts
  mkdir -p "$local_dir"
  ci-storage load \
    --storage-host="$CI_STORAGE_HOST" \
    --storage-dir="~/ci-storage/$GH_REPOSITORY" \
    --slot-id="?" \
    --local-dir="$local_dir"
fi

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
  # - In case we can't delete the runner for a long time still, the extrnal
  #   orchestrator will eventually kill the container after a large timeout
  #   (say, 15 minutes or so) needed for a running job to finish.
  echo "Received graceful shutdown signal, removing the runner..."
  while :; do
    token=$(gh api -X POST --jq .token "repos/$GH_REPOSITORY/actions/runners/remove-token")
    ./config.sh remove --token "$token" && break
    sleep 5
    echo "Retrying removal till the runner becomes idle and it succeeds..."
  done
}

trap "cleanup; exit 130" INT
trap "cleanup; exit 143" TERM

"$@"

./run.sh & wait $!
