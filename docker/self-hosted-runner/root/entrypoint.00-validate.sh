#!/bin/bash
set -u -e

if [[ "${GH_REPOSITORY:=}" != */* ]]; then
  echo "GH_REPOSITORY must be set, and the format should be {owner}/{repo}.";
  exit 1;
fi

if [[ "${GH_LABELS:=}" == "" ]]; then
  echo "GH_LABELS must be set.";
  exit 1;
fi

if [[ "${GH_TOKEN:=}" == "" ]]; then
  echo "GH_TOKEN must be set.";
  exit 1;
fi

if [[ "${FORWARD_HOST:=}" != "" && ! "$FORWARD_HOST" =~ ^[-.[:alnum:]]+(:[0-9]+)?$ ]]; then
  echo "If FORWARD_HOST is passed, it must be a hostname.";
  exit 1;
fi

if [[ "${FORWARD_PORTS:=}" != "" && ! "$FORWARD_PORTS" =~ ^([[:space:]]*[0-9]+(/tcp|/udp)?[[:space:]]*)+$ ]]; then
  echo 'If FORWARD_PORTS is passed, it must be in form of (example): "123 456/udp 789/tcp".';
  exit 1;
fi

if [[ "${CI_STORAGE_HOST:=}" != "" && ! "$CI_STORAGE_HOST" =~ ^([-.[:alnum:]]+@)?[-.[:alnum:]]+(:[0-9]+)?$ ]]; then
  echo "If CI_STORAGE_HOST is passed, it must be in form of [user@]host[:port].";
  exit 1;
fi

if [[ "${CI_STORAGE_HOST:=}" != "" && ! -f /run/secrets/CI_STORAGE_PRIVATE_KEY ]]; then
  echo "You must pass secret CI_STORAGE_PRIVATE_KEY when using CI_STORAGE_HOST."
  exit 1
fi
