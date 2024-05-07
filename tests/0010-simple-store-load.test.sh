#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot \
  store

ci-storage \
  --slot-id=myslot \
  load

grep -qF 'Checking slot-id="myslot"... found in the storage, using it' "$OUT"
grep -qE 'full_snapshot_history=myslot$' "$META_FILE"
