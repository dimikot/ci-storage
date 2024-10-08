#!/bin/bash
#
# Validates environment variables.
#
set -u -e

export TZ
if [[ "${TZ:=}" != "" && ! "$TZ" =~ ^[-+_/a-zA-Z0-9]+$ ]]; then
  say "If TZ is passed, it must be a valid TZ Idenfitier from https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
  exit 1
fi

secret_file=/run/secrets/CI_STORAGE_PUBLIC_KEY
if [[ ! -f $secret_file ]]; then
  say "To access this container over SSH, a secret $(basename "$secret_file") or a mounted file $secret_file should exist. The container will start, but it's not accessible, which may be fine in dev environment."
fi
