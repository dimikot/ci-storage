#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=absent \
  load || error=$?

test "$error" == 1
grep -qF 'Checking slot-id="absent"... not found in the storage' "$OUT"
grep -qF 'Error: none of the provided slot id(s) were found in the storage, aborting' "$OUT"
