#!/bin/bash
#
# Validates environment variables.
#
set -u -e

if [[ "${GH_REPOSITORIES:=}" != "" && "${GH_TOKEN:=}" == "" ]]; then
  echo "When GH_REPOSITORIES is set, GH_TOKEN must also be set."
  exit 1
fi

if [[ "${GH_REPOSITORIES:=}" != "" && "$GH_REPOSITORIES" != */* ]]; then
  echo "If GH_REPOSITORIES is set, its format should be a space-delimited list of {owner}/{repo}."
  exit 1
fi

secret_file=/run/secrets/CI_STORAGE_PUBLIC_KEY
if [[ ! -f $secret_file ]]; then
  echo "To access this container over SSH, a secret $(basename "$secret_file") or a mounted file $secret_file should exist. The container will start, but it's not accessible, which may be fine in dev environment."
fi
