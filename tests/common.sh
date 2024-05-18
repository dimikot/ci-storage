#!/bin/bash
set -e -o pipefail

# shellcheck disable=SC2154
trap '
  exitcode=$?
  set +o xtrace
  if [[ "$exitcode" != 0 ]]; then
    echo
    echo "FAILED! Last output was:"
    echo "==================="
    cat $OUT
    exit 1
  fi
' EXIT

export STORAGE_DIR=/tmp/ci-storage/storage_dir
export LOCAL_DIR=/tmp/ci-storage/local_dir
export OUT=/tmp/ci-storage/out.txt
export META_FILE=/tmp/.ci-storage.meta._tmp_ci-storage_local_dir
export error=0

rm -rf $STORAGE_DIR* $LOCAL_DIR* $OUT /tmp/.ci-storage.meta*
mkdir -p $STORAGE_DIR $LOCAL_DIR
touch $OUT

touch $LOCAL_DIR/file-1
mkdir $LOCAL_DIR/dir-a
touch $LOCAL_DIR/dir-a/file-a-1

ci-storage() {
  ../ci-storage --local-dir="$LOCAL_DIR" --storage-dir="$STORAGE_DIR" "$@" &>$OUT
}

set -o xtrace
