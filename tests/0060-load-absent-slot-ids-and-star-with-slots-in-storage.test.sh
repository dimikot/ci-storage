#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot \
  store
  
ci-storage \
  --slot-id=absent1 \
  --slot-id=absent2 \
  --slot-id="*" \
  load || error=$?

test "$error" == 0
grep -qF 'Checking slot-id="absent1"... not found' "$OUT"
grep -qF 'Checking slot-id="absent2"... not found' "$OUT"
grep -qF 'Checking slot-id="*"... loading the most recent full (non-layer) slot-id="myslot"' "$OUT"
