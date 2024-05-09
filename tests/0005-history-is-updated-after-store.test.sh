#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot \
  store

test -f "$STORAGE_DIR/myslot/file-1"
grep -qE 'full_snapshot_history=myslot$' "$STORAGE_DIR/myslot/.ci-storage.meta"
