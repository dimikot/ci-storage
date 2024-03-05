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

if [[ "${CI_STORAGE_HOST:=}" != "" && ! "$CI_STORAGE_HOST" =~ ^([-.[:alnum:]]+@)?[-.[:alnum:]]+(:[0-9]+)?$ ]]; then
  echo "If CI_STORAGE_HOST is passed, it must be in form of [user@]host[:port].";
  exit 1;
fi

if [[ "${CI_STORAGE_HOST_PRIVATE_KEY_EVAL:=}" != "" && "$CI_STORAGE_HOST_PRIVATE_KEY_EVAL" != *\ * ]]; then
  echo "If CI_STORAGE_HOST_PRIVATE_KEY_EVAL is passed, it must contain a shell command which prints an SSH private key (e.g. fetched from AWS Secrets Manager or so).";
  exit 1;
fi
