#!/bin/bash
source ./common.sh

touch "$LOCAL_DIR/file"
ci-storage --slot-id="myslot1-early" store
sleep 1

touch "$LOCAL_DIR/file"
ci-storage --slot-id="myslot2-middle" store
sleep 1

# After loading from myslot1-early slot...
ci-storage --slot-id="myslot1-early" load
grep -qF 'Checking slot-id="myslot1-early"... found in the storage, using it' "$OUT"

# ...we should use the same myslot1-early as a value for --link-dest as well
# (NOT the most recent slot myslot2-middle).
ci-storage --slot-id="myslot3-late" store
grep -qF -- '--link-dest=../myslot1-early/' "$OUT"

# Check hard-link counts: we should dedup myslot1-early with myslot3-late.
test "$(hardlink-count "$STORAGE_DIR/myslot1-early/file")" == 2
test "$(hardlink-count "$STORAGE_DIR/myslot2-middle/file")" == 1
test "$(hardlink-count "$STORAGE_DIR/myslot3-late/file")" == 2

# Just in case, load from myslot3-late, and since it has been dedupped with
# myslot1-early, they should all dedup between each other.
ci-storage --slot-id="*" load
grep -qF 'Checking slot-id="*"... loading the most recent full (non-layer) slot-id="myslot3-late"' "$OUT"

ci-storage --slot-id="myslot4-end" store
grep -qF -- '--link-dest=../myslot3-late/' "$OUT"
test "$(hardlink-count "$STORAGE_DIR/myslot1-early/file")" == 3
test "$(hardlink-count "$STORAGE_DIR/myslot2-middle/file")" == 1
test "$(hardlink-count "$STORAGE_DIR/myslot3-late/file")" == 3
test "$(hardlink-count "$STORAGE_DIR/myslot4-end/file")" == 3
