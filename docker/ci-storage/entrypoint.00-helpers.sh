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

# Publishes a metric to CloudWatch. Returns an error exit code in case we are
# running not in AWS infra (i.e. there is no CloudWatch available), otherwise
# always succeeds, independently on aws CLI exit code (for caller simplicity).
aws_cloudwatch_put_metric_data() {
  local metric="$1"
  local value="$2"
  local dimensions="$3"
  if [[ "${REGION-unset}" == "unset" ]]; then
    REGION=$(aws_metadata_curl latest/meta-data/placement/availability-zone | sed "s/[a-z]$//")
  fi
  if [[ "$REGION" == "" ]]; then
    return 1
  fi
  aws cloudwatch put-metric-data \
    --metric-name="$metric" \
    --namespace="ci-storage/metrics" \
    --value="$value" \
    --storage-resolution="1" \
    --unit="None" \
    --dimensions="$dimensions" \
    --region="$REGION" \
    || true
}

# Prints the current date in the same format as the GitHub Actions runner does.
nice_date() {
  date +"%Y-%m-%d %H:%M:%S %Z"
}

export -f aws_metadata_curl
export -f aws_cloudwatch_put_metric_data
export -f nice_date

nice_date
