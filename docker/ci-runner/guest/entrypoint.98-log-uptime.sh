#!/bin/bash
#
# Logs uptime of the runner in the beginning and then time to time.
#
set -u -e

log_uptime_loop() {
  label=${GH_LABELS##*,}
  dimensions="GH_REPOSITORY=$GH_REPOSITORY,GH_LABEL=$label"
  while :; do
    out=()
    metric="RunnerUptimeSec"
    value=$(awk '{print int($1)}' /proc/uptime)
    if aws_cloudwatch_put_metric_data "$metric" "$value" "$dimensions"; then
      suffix="publishing to CloudWatch"
    else
      suffix="AWS metadata service is not available, so not publishing"
    fi
    out+=("$metric=$value")
    echo "$(nice_date): $GH_REPOSITORY: ${out[*]} ($suffix)"
    sleep 60
  done
}

log_uptime_loop &
