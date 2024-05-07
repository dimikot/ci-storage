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
grep -qF 'Checking slot-id="absent1"... not found in the storage' "$OUT"
grep -qF 'Checking slot-id="absent2"... not found in the storage' "$OUT"
grep -qF 'Checking slot-id="*"... using the most recent slot-id="myslot" for the full (non-layer) load' "$OUT"
