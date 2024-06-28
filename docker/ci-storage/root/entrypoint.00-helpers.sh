#!/bin/bash
#
# Holds reusable functions and tools.
#
set -u -e

# Storage directory where ci-storage tool saves the data.
export STORAGE_DIR="/mnt"

# Prints the current date and the message after it.
say() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S %Z")] $*"
}

export -f say

exec 42>&1 > >(grep --line-buffered -v '^$' >&42) 2>&1
echo "==================================="
say "Starting."

