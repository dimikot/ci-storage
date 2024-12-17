#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot0 \
  store

ci-storage \
  --slot-id="*" \
  --hint="aaa" \
  load

grep -qF "hints=aaa" "$LOCAL_META_FILE"

ci-storage \
  --slot-id=myslot1 \
  --hint="" \
  store

grep -qF "hints=aaa" "$STORAGE_DIR/myslot1/.ci-storage.meta"
