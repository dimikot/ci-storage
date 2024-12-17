#!/bin/bash
source ./common.sh

test -e "$LOCAL_DIR/file-1"
test -e "$LOCAL_DIR/dir-a"

echo "hints=old" > "$LOCAL_META_FILE"

ci-storage \
  --slot-id="*" \
  load

grep -qF 'Checking slot-id="*"... storage has no slots, so cleaning' "$OUT"
grep -qE "hints=$" "$LOCAL_META_FILE"
test ! -e "$LOCAL_DIR/file-1"
test ! -e "$LOCAL_DIR/dir-a"
