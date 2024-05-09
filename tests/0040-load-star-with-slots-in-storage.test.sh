#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot \
  store
  
ci-storage \
  --slot-id="*" \
  load || error=$?

test "$error" == 0
grep -qF 'Checking slot-id="*"... using the most recent slot-id="myslot" for the full (non-layer) load' "$OUT"
