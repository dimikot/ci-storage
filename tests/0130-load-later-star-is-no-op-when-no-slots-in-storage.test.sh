#!/bin/bash
source ./common.sh

test -e "$LOCAL_DIR/file-1"
test -e "$LOCAL_DIR/dir-a"

ci-storage \
  --slot-id="*" \
  --layer="*" \
  load

test -e "$LOCAL_DIR/file-1"
test -e "$LOCAL_DIR/dir-a"
