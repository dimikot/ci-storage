#!/bin/bash
#
# Fixes permissions for the potentially mounted volume.
#
set -u -e

chown guest:guest "$STORAGE_DIR"
chmod 700 "$STORAGE_DIR"
