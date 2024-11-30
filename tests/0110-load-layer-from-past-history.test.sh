#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=slot_with_layer_1 \
  store

grep -qE "full_snapshot_history=slot_with_layer_1\$" "$META_FILE"

touch "$LOCAL_DIR/file-in-layer-1"
ci-storage \
  --slot-id=slot_with_layer_1 \
  --storage-dir="$STORAGE_DIR.layer" \
  --layer="file-in-layer-1" \
  store
rm "$LOCAL_DIR/file-in-layer-1"

touch "$LOCAL_DIR/file-new-2"
ci-storage \
  --slot-id=slot_without_layer_2 \
  store

touch "$LOCAL_DIR/file-in-layer-another"
ci-storage \
  --slot-id=slot_with_layer_without_full_3 \
  --storage-dir="$STORAGE_DIR.layer" \
  --layer="file-in-layer-another" \
  store
rm "$LOCAL_DIR/file-in-layer-another"

grep -qE "full_snapshot_history=slot_without_layer_2 slot_with_layer_1\$" "$META_FILE"

ci-storage \
  --slot-id=slot_without_layer_2 \
  load

grep -qE "full_snapshot_history=slot_without_layer_2 slot_with_layer_1\$" "$META_FILE"

ci-storage \
  --slot-id=slot_without_layer_2 \
  --slot-id="*" \
  --storage-dir="$STORAGE_DIR.layer" \
  --layer="*" \
  load

test -f "$LOCAL_DIR/file-in-layer-1"
grep -qF 'Checking slot-id="slot_without_layer_2"... not found' "$OUT"
grep -qF 'Checking slot-id="*"... prioritizing' "$OUT"
grep -qF 'Checking slot-id="slot_without_layer_2" from history... not found' "$OUT"
grep -qF 'Checking slot-id="slot_with_layer_1" from history... found' "$OUT"

ci-storage \
  --slot-id=slot_with_layer_1 \
  load

grep -qE "full_snapshot_history=slot_with_layer_1\$" "$META_FILE"
