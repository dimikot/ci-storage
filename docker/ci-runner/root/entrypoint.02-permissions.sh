#!/bin/bash
#
# Fixes permissions for the potentially mounted volume.
#
set -u -e

mkdir -p "$WORK_DIR"
chown guest:guest "$WORK_DIR"
chmod 700 "$WORK_DIR"

mkdir -p "$CACHE_DIR"
chown guest:guest "$CACHE_DIR"
chmod 700 "$CACHE_DIR"
