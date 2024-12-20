#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id="absent1" \
  --slot-id="absent2" \
  --slot-id="*" \
  load

grep -qF 'Checking slot-id="*"... storage has no slots, so cleaning' "$OUT"
