#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot \
  store

ci-storage \
  --slot-id="*" \
  load

grep -qF 'Checking slot-id="*"... loading the most recent full (non-layer) slot-id="myslot"' "$OUT"
