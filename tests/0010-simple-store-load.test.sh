#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot \
  --hint="aaa" \
  --hint="bbb ccc" \
  store

test -f "$STORAGE_DIR/myslot/file-1"
grep -qE 'full_snapshot_history=myslot$' "$STORAGE_DIR/myslot/.ci-storage.meta"
grep -qE 'hints=aaa bbb ccc$' "$STORAGE_DIR/myslot/.ci-storage.meta"

ci-storage \
  --slot-id=myslot \
  load

grep -qF 'Checking slot-id="myslot"... found in the storage, using it' "$OUT"
grep -qE 'full_snapshot_history=myslot$' "$META_FILE"
grep -qE 'hints=aaa bbb ccc$' "$META_FILE"
