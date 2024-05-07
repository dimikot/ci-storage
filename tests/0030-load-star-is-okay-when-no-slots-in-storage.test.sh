#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id="*" \
  load || error=$?

test "$error" == 0
grep -qF 'Checking slot-id="*"... storage has no slots, so exiting with a no-op' "$OUT"
