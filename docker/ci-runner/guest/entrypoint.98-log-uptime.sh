#!/bin/bash
#
# Logs uptime of the runner (since instance boot timestamp if passed) in the
# beginning and then time to time.
#
set -u -e

# shellcheck disable=SC2034
log_uptime_loop() {
  label=${GH_LABELS##*,}
  dimensions="GH_REPOSITORY=$GH_REPOSITORY,GH_LABEL=$label"
  while :; do
    out=()
    InstanceUptimeSec=$(($(date '+%s') - BTIME))
    RunnerUptimeSec=$(awk '{print int($1)}' /proc/uptime)
    for metric in InstanceUptimeSec RunnerUptimeSec; do
      if aws_cloudwatch_put_metric_data "$metric" "${!metric}" "$dimensions"; then
        suffix="publishing to CloudWatch"
      else
        suffix="AWS metadata service is not available, so not publishing"
      fi
      out+=("$metric=${!metric}")
    done
    echo "$(nice_date): $GH_REPOSITORY: ${out[*]} ($suffix)"
    sleep 60
  done
}

if [[ "$BTIME" != "" ]]; then
  log_uptime_loop &
fi
