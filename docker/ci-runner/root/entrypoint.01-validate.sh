#!/bin/bash
#
# Validates environment variables.
#
set -u -e

if [[ "${GH_TOKEN:=}" == "" ]]; then
  echo "GH_TOKEN must be set."
  exit 1
fi

if [[ "${GH_REPOSITORY:=}" != */* ]]; then
  echo "GH_REPOSITORY must be set, and the format should be {owner}/{repo}."
  exit 1
fi

if [[ "${GH_LABELS:=}" == "" ]]; then
  echo "GH_LABELS must be set."
  exit 1
fi

if [[ "${TZ:=}" != "" && ! "$TZ" =~ ^[-+_/a-zA-Z0-9]+$ ]]; then
  echo "If TZ is passed, it must be a valid TZ Idenfitier from https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
  exit 1
fi

if [[ "${FORWARD_HOST:=}" != "" && ! "$FORWARD_HOST" =~ ^[-.[:alnum:]]+(:[0-9]+)?$ ]]; then
  echo "If FORWARD_HOST is passed, it must be a hostname."
  exit 1
fi

if [[ "${FORWARD_PORTS:=}" != "" && ! "$FORWARD_PORTS" =~ ^([[:space:]]*[0-9]+(/tcp|/udp)?[[:space:]]*)+$ ]]; then
  echo 'If FORWARD_PORTS is passed, it must be in the form of (example): "123 456/udp 789/tcp".';
  exit 1
fi

if [[ "${CI_STORAGE_HOST:=}" != "" && ! "$CI_STORAGE_HOST" =~ ^([-.[:alnum:]]+@)?[-.[:alnum:]]+(:[0-9]+)?$ ]]; then
  echo "If CI_STORAGE_HOST is passed, it must be in the form of [user@]host[:port]."
  exit 1
fi

if [[ "${BTIME:=}" != "" && ! "$BTIME" =~ ^[0-9]+$ ]]; then
  echo "If BTIME is passed, it must be a number (boot timestamp)."
  exit 1
fi

if [[ "${DEBUG_SHUTDOWN_DELAY_SEC:=}" != "" && ! "$DEBUG_SHUTDOWN_DELAY_SEC" =~ ^[0-9]+$ ]]; then
  echo "If DEBUG_SHUTDOWN_DELAY_SEC is passed, it must be a number."
  exit 1
fi

secret_file=/run/secrets/CI_STORAGE_PRIVATE_KEY
if [[ "$CI_STORAGE_HOST" != "" && ! -f $secret_file ]]; then
  echo "To access CI_STORAGE_HOST=$CI_STORAGE_HOST, a secret $(basename "$secret_file") or a mounted file $secret_file should exist. The container will start, but ci-storage tool won't be usable, which may be fine in dev environment."
fi

echo
