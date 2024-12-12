#!/bin/bash
source ./common.sh

echo "a" > "$LOCAL_DIR/file-new-a"
echo "b" > "$LOCAL_DIR/file-new-b"
echo "c" > "$LOCAL_DIR/file-c"
ci-storage \
  --slot-id=myslot1 \
  --hint="aaa bbb" \
  --hint="@$LOCAL_DIR/file-new-* $LOCAL_DIR/file-c $LOCAL_DIR/file-absent?" \
  --hint=" ccc " \
  store

grep -qF "hints=aaa bbb @f3bba3f02fb45a2a ccc" "$STORAGE_DIR/myslot1/.ci-storage.meta"
