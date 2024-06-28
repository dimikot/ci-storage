#!/bin/bash
#
# Validates environment variables.
#
set -u -e

if [[ "${ASGS:=}" != "" && "${GH_TOKEN:=}" == "" ]]; then
  say "When ASGS is set, GH_TOKEN must also be set."
  exit 1
fi

if [[ "${ASGS:=}" != "" && "$ASGS" != */*:*:* ]]; then
  say "If ASGS is set, its format should be a space-delimited list of {owner}/{repo}:{label}:{asg_name}."
  exit 1
fi

if [[ "$ASGS" == "" ]]; then
  say "For this container to operate, ASGS environment variable should be passed. The container will start, but it'll do nothing, which may be fine in dev environment."
fi

if [[ "${DOMAIN:=}" != "" && "$DOMAIN" != *.*  ]]; then
  say "If DOMAIN is set, it should be a fully qualified domain name."
  exit 1
fi
