#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id="absent1 absent2" \
  load || error=$?

test "$error" == 1
grep -qF 'Checking slot-id="absent1"... not found in the storage' "$OUT"
grep -qF 'Checking slot-id="absent2"... not found in the storage' "$OUT"
grep -qF 'Error: none of the provided slot id(s) were found in the storage, aborting' "$OUT"
