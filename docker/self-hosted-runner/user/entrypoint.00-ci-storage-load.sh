#!/bin/bash
set -u -e

echo "$CI_STORAGE_HOST" > ci-storage-host

if [[ "$CI_STORAGE_HOST" != "" ]]; then
  local_dir=~/actions-runner/_work/${GH_REPOSITORY##*/}/${GH_REPOSITORY##*/}
  mkdir -p "$local_dir"
  ci-storage load \
    --storage-host="$CI_STORAGE_HOST" \
    --storage-dir="~/ci-storage/$GH_REPOSITORY" \
    --slot-id="?" \
    --local-dir="$local_dir"
fi
