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

if [[ "${CI_STORAGE_HOST_PRIVATE_KEY:=}" != "" && "$CI_STORAGE_HOST_PRIVATE_KEY" != *OPENSSH\ PRIVATE\ KEY* ]]; then
  echo "If CI_STORAGE_HOST_PRIVATE_KEY is passed, it must be an SSH private key.";
  exit 1;
fi
