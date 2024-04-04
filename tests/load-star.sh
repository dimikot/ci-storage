#!/bin/bash
set -e -o xtrace
cd "$(dirname "${BASH_SOURCE[0]}")"

../ci-storage \
  --slot-id="*" \
  --storage-dir=/tmp/ci-storage-tests \
  --local-dir=/tmp/ci-storage-loaded \
  --verbose \
  --exclude=".git" \
  load

sleep 0.5
ls -la /tmp/ci-storage-tests
