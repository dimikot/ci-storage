#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot1 \
  --hint="aaa" \
  store

touch "$LOCAL_DIR/file-new-2"
ci-storage \
  --slot-id=myslot2 \
  --hint="bbb ccc" \
  store

rm "$LOCAL_DIR/file-new-2"
ci-storage \
  --slot-id="*" \
  --hint="000 111 222" \
  load

grep -qF 'No slots matching hints, so loading the most recent full (non-layer) slot-id="myslot2"' "$OUT"
test -e "$LOCAL_DIR/file-new-2"

touch "$LOCAL_DIR/file-new-3"
ci-storage \
  --slot-id=myslot3 \
  --hint="bbb" \
  store

rm "$LOCAL_DIR/file-new-2"
ci-storage \
  --slot-id="*" \
  --hint="000 bbb ccc" \
  load

grep -qF 'Checking slot-id="myslot3" from the storage... weight: 010, matched hints: bbb' "$OUT"
grep -qF 'Checking slot-id="myslot2" from the storage... weight: 011, matched hints: bbb, ccc' "$OUT"
grep -qF 'Winner: slot-id="myslot2"' "$OUT"

test -e "$LOCAL_DIR/file-new-2"
