#!/bin/bash
#
# Fixes permissions for the potentially mounted volume.
#
set -u -e

chown guest:guest "$WORK_DIR"
chmod 700 "$WORK_DIR"
