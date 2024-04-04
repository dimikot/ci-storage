#!/bin/bash
set -e -o xtrace
cd "$(dirname "${BASH_SOURCE[0]}")"

../ci-storage \
  --slot-id=myslot \
  --storage-dir=/tmp/ci-storage-tests \
  --local-dir=.. \
  --storage-max-age-sec=2 \
  --verbose \
  --exclude=".git" \
  store

# To let background garbage collection finish.
sleep 0.5

ls -la /tmp/ci-storage-tests
