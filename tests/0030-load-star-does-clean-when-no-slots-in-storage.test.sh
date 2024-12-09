#!/bin/bash
source ./common.sh

test -e "$LOCAL_DIR/file-1"
test -e "$LOCAL_DIR/dir-a"

ci-storage \
  --slot-id="*" \
  load

grep -qF 'Checking slot-id="*"... storage has no slots, so cleaning' "$OUT"

test ! -e "$LOCAL_DIR/file-1"
test ! -e "$LOCAL_DIR/dir-a"
