#!/bin/bash
#
# Validates environment variables.
#
set -u -e

secret_file=/run/secrets/CI_STORAGE_PUBLIC_KEY
if [[ ! -f $secret_file ]]; then
  echo "To access this container over SSH, a secret $(basename "$secret_file") or a mounted file $secret_file should exist. The container will start, but it's not accessible, which may be fine in dev environment."
fi

echo
