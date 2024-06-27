#!/bin/bash
#
# Holds reusable functions and tools.
#
set -u -e

# GitHub Runner's work directory (encouraged to be mounted on tmpfs).
export WORK_DIR="/mnt"

# We don't use ec2metadata CLI tool, because it does not allow to configure
# timeout. In case the container is run outside of AWS infra (e.g. during local
# development), the absense of timeout causes problems. Prints an empty value
# and always succeeds if not in AWS infra.
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

# Prints the current AWS region name or nothing if not in AWS infra. Always
# succeeds.
aws_region() {
  if [[ "${REGION-unset}" == "unset" ]]; then
    REGION=$(aws_metadata_curl latest/meta-data/placement/availability-zone | sed "s/[a-z]$//")
  fi
  echo "$REGION"
}

# Prints the current AWS instance ID or nothing if not in AWS infra. Always
# succeeds.
aws_instance_id() {
  if [[ "${INSTANCE_ID-unset}" == "unset" ]]; then
    INSTANCE_ID=$(aws_metadata_curl latest/meta-data/instance-id)
  fi
  echo "$INSTANCE_ID"
}

# Publishes a metric to CloudWatch. Fails on error.
aws_cloudwatch_put_metric_data() {
  local metric="$1"
  local value="$2"
  local dimensions="$3"
  local namespace="${4:-ci-storage/metrics}"
  aws cloudwatch put-metric-data \
    --region="$(aws_region)" \
    --metric-name="$metric" \
    --namespace="$namespace" \
    --value="$value" \
    --storage-resolution="1" \
    --unit="None" \
    --dimensions="Region=$(aws_region),$dimensions,InstanceId=$(aws_instance_id)"
}

# Prints the value of the current instance's tag with the provided name. If
# there is no such tag, prints nothing and succeeds (default AWS behavior).
# Fails on error.
aws_read_tag() {
  local key="$1"
  local res; res=$(
    aws ec2 describe-tags \
    --region "$(aws_region)" \
    --query "Tags[0].Value" \
    --output text \
    --filters "Name=resource-id,Values=$(aws_instance_id)" "Name=key,Values=$key"
  )
  if [[ "$res" != "None" ]]; then
    echo "$res"
  fi
}

# Writes (or overwrites) a tag with the provided key and value to the current
# instance. Fails on error.
aws_write_tag() {
  local key="$1"
  local value="$2"
  aws ec2 create-tags \
    --region "$(aws_region)" \
    --resources "$(aws_instance_id)" \
    --tags "Key=$key,Value=$value"
}

# Prints the current date in the same format as the GitHub Actions runner does.
nice_date() {
  date +"%Y-%m-%d %H:%M:%S %Z"
}

export -f aws_metadata_curl
export -f aws_region
export -f aws_instance_id
export -f aws_cloudwatch_put_metric_data
export -f aws_read_tag
export -f aws_write_tag
export -f nice_date

nice_date
