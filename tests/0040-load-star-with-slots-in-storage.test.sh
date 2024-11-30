#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot \
  store
  
ci-storage \
  --slot-id="*" \
  load || error=$?

test "$error" == 0
grep -qF 'Checking slot-id="*"... loading the most recent full (non-layer) slot-id="myslot"' "$OUT"
