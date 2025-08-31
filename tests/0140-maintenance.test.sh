#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot1 \
  store

sleep 1

ci-storage \
  --slot-id=myslot2 \
  store

test -f "$STORAGE_DIR/myslot1/file-1"

sleep 2

ci-storage \
  --slot-id=myslot3 \
  --storage-max-age-sec=1 \
  store

grep -qE 'will rename .*myslot1 to myslot1.bak.rm.* and remove' "$OUT"
test ! -e "$STORAGE_DIR/myslot"
