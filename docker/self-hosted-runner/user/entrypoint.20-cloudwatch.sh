#!/bin/bash
#
# Publishes CloudWatch metrics for auto-scaling.
# - ActiveRunnersPercent: percentage of active runners
# - IdleRunnersCountNegative: count of idle runners multiplied by -1
#
set -u -e

cloudwatch_loop() {
  NAMESPACE="ci-storage/metrics"
  INTERVAL_SEC=10
  REGION=$(aws_metadata_curl latest/meta-data/placement/availability-zone | sed "s/[a-z]$//")

  while :; do
    sleep "$INTERVAL_SEC"

    runners=$(
      gh api \
        "repos/$GH_REPOSITORY/actions/runners" \
        -q '.runners[] | {id,name,status,busy} | select(.name | startswith("ci-storage-"))' \
        --paginate || true
    )

    if [[ "$runners" == "" ]]; then
      continue
    fi

    idle_runner_ids=$(
        echo "$runners" | jq -r 'select((.name | startswith("ci-storage-")) and (.busy == false) and (.status == "online")) | {id} | .[]'
    )
    active_runner_ids=$(
        echo "$runners" | jq -r 'select((.name | startswith("ci-storage-")) and (.busy == true) and (.status == "online")) | {id} | .[]'
    )
    all_runners_ids=$(
        echo "$runners" | jq -r '{id} | .[]'
    )

    idle_runner_count=$(echo "$idle_runner_ids" | wc -w)
    active_runner_count=$(echo "$active_runner_ids" | wc -w)
    all_runner_count=$(echo "$all_runners_ids" | wc -w)

    ActiveRunnersPercent=$(("$all_runner_count" == 0 ? 100 : 100 * "$active_runner_count" / "$all_runner_count"))
    IdleRunnersCountNegative=$((-1 * "$idle_runner_count"))

    if [[ "$REGION" != "" ]]; then
      suffix="publishing to CloudWatch"
      for metric in ActiveRunnersPercent IdleRunnersCountNegative; do
        aws cloudwatch put-metric-data \
          --metric-name="$metric" \
          --namespace="$NAMESPACE" \
          --value="${!metric}" \
          --storage-resolution="1" \
          --unit="None" \
          --dimensions="GH_REPOSITORY=$GH_REPOSITORY" \
          --region="$REGION" \
          || true
      done
    else
      suffix="AWS metadata service is not available, so not publishing"
    fi
    echo "ActiveRunnersPercent=$ActiveRunnersPercent, IdleRunnersCountNegative=$IdleRunnersCountNegative ($suffix)"
  done
}

cloudwatch_loop &
