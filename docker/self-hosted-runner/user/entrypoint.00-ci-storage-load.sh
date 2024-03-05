#!/bin/bash
set -u -e

if [[ "$CI_STORAGE_HOST_PRIVATE_KEY_EVAL" != "" ]]; then
  eval "$CI_STORAGE_HOST_PRIVATE_KEY_EVAL" > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
fi

echo "$CI_STORAGE_HOST" > ci-storage-host

if [[ "$CI_STORAGE_HOST" != "" && "$CI_STORAGE_HOST_PRIVATE_KEY_EVAL" != "" ]]; then
  local_dir=~/actions-runner/_work/${GH_REPOSITORY##*/}/${GH_REPOSITORY##*/}
  mkdir -p "$local_dir"
  ci-storage load \
    --storage-host="$CI_STORAGE_HOST" \
    --storage-dir="~/ci-storage/$GH_REPOSITORY" \
    --slot-id="?" \
    --local-dir="$local_dir"
fi
