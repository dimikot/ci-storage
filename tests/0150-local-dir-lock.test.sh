#!/bin/bash
source ./common.sh

# Holds a flock() of the given kind (ex or sh) on $LOCAL_DIR in background for
# the given number of seconds, and returns once the lock is acquired.
hold-lock() {
  { set +o xtrace; } 2>/dev/null
  rm -f "$LOCAL_DIR.locked"
  python3 -c '
import fcntl, os, sys, time
fd = os.open(sys.argv[1], os.O_RDONLY)
fcntl.flock(fd, fcntl.LOCK_EX if sys.argv[2] == "ex" else fcntl.LOCK_SH)
open(sys.argv[1] + ".locked", "w").close()
time.sleep(float(sys.argv[3]))
' "$LOCAL_DIR" "$1" "$2" &
  while [[ ! -e "$LOCAL_DIR.locked" ]]; do sleep 0.1; done
  { set -o xtrace; } 2>/dev/null
}

ci-storage \
  --slot-id=myslot \
  store

# Load waits for an exclusive lock held by someone else.
hold-lock ex 2
start=$SECONDS
ci-storage \
  --slot-id=myslot \
  load
grep -qF "Waiting for an exclusive lock on directory $LOCAL_DIR..." "$OUT"
test $((SECONDS - start)) -ge 1
test -f "$LOCAL_DIR/file-1"
wait

# Load also waits for a shared lock (e.g. a concurrent store).
hold-lock sh 2
ci-storage \
  --slot-id=myslot \
  load
grep -qF "Waiting for an exclusive lock on directory $LOCAL_DIR..." "$OUT"
wait

# Store waits for an exclusive lock (e.g. a concurrent load).
hold-lock ex 2
ci-storage \
  --slot-id=myslot2 \
  store
grep -qF "Waiting for a shared lock on directory $LOCAL_DIR..." "$OUT"
test -f "$STORAGE_DIR/myslot2/file-1"
wait

# Stores don't block each other.
hold-lock sh 2
ci-storage \
  --slot-id=myslot3 \
  store
test "$(grep -cF "Waiting for" "$OUT")" == 0
test -f "$STORAGE_DIR/myslot3/file-1"
wait

# Without contention, there is no waiting.
ci-storage \
  --slot-id=myslot \
  load
test "$(grep -cF "Waiting for" "$OUT")" == 0
