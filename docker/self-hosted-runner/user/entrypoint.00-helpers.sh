#!/bin/bash
#
# Holds reusable functions and tools.
#
set -u -e

# We don't use ec2metadata CLI tool, because it does not allow to configure
# timeout. In case the container is run outside of AWS infra (e.g. during local
# development), the absense of timeout causes problems.
aws_metadata_curl() {
  local timeout_sec token path
  timeout_sec=5
  token=$(
    curl -s -m $timeout_sec --fail -X PUT \
      "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
      || true
  )
  if [[ "$token" != "" ]]; then
    path="$1"
    shift
    curl -s -m $timeout_sec -H "X-aws-ec2-metadata-token: $token" "$@" "http://169.254.169.254/$path" || true
  fi
}
