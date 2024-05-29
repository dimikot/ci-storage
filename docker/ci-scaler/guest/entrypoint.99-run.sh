#!/bin/bash
#
# Runs webhooks listener and runner maintainer.
#
set -u -e

if [[ "$ASGS" != "" ]]; then
  exec python3 ./scaler/main.py \
    --asgs="$ASGS" \
    --domain="$DOMAIN"
else
  exec sleep 1000000000
fi
