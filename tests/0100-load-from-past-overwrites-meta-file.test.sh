#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot1 \
  store

grep -qE "full_snapshot_history=myslot1\$" "$LOCAL_META_FILE"

ci-storage \
  --slot-id=myslot2 \
  store

grep -qE "full_snapshot_history=myslot2 myslot1\$" "$LOCAL_META_FILE"

ci-storage \
  --slot-id=myslot1 \
  load

grep -qE "full_snapshot_history=myslot1\$" "$LOCAL_META_FILE"

ci-storage \
  --slot-id=myslot1 \
  load

grep -qE "full_snapshot_history=myslot1\$" "$LOCAL_META_FILE" # no duplicates

ci-storage \
  --slot-id=myslot2 \
  load

grep -qE "full_snapshot_history=myslot2 myslot1\$" "$LOCAL_META_FILE"
