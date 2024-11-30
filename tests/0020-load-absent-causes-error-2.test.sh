#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id="absent1 absent2" \
  load || error=$?

test "$error" == 1
grep -qF 'Checking slot-id="absent1"... not found' "$OUT"
grep -qF 'Checking slot-id="absent2"... not found' "$OUT"
grep -qF 'Error: none of the provided slot id(s) were found' "$OUT"
