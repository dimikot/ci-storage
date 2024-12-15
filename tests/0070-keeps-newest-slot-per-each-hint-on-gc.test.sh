#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id=myslot-a1 \
  --hint="a" \
  store
ci-storage \
  --slot-id=myslot-a2 \
  --hint="a" \
  store

ci-storage \
  --slot-id=myslot-b1 \
  --hint="b" \
  store
ci-storage \
  --slot-id=myslot-b2 \
  --hint="b" \
  store

ci-storage \
  --slot-id=myslot-c1 \
  --hint="c" \
  store
ci-storage \
  --slot-id=myslot-c2 \
  --hint="c" \
  store

ci-storage \
  --slot-id=myslot-d1 \
  --hint="d" \
  store
ci-storage \
  --slot-id=myslot-d2 \
  --hint="d" \
  store

ci-storage \
  --slot-id=myslot-x \
  --hint="x" \
  --storage-keep-hint-slots=2 \
  store

grep -qF 'myslot-x, the newest slot overall' "$OUT"
grep -qF 'myslot-d2, the newest slot with this hint (hint=d' "$OUT"
grep -qF 'myslot-c2, the newest slot with this hint (hint=c' "$OUT"
grep -qF 'myslot-b2, new enough' "$OUT"
grep -qF 'myslot-a2, new enough' "$OUT"

