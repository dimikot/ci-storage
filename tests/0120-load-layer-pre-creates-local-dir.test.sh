#!/bin/bash
source ./common.sh

ci-storage \
  --slot-id="*" \
  --local-dir="$LOCAL_DIR.new" \
  --layer="*" \
  load

test -d "$LOCAL_DIR.new"
