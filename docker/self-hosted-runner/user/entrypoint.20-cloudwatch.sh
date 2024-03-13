#!/bin/bash
#
# Publishes CloudWatch metrics for auto-scaling.
# - ActiveRunnersPercent: percentage of active runners
# - IdleRunnersCountInverse: 1000000 minus "count of idle runners"
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
    all_runner_ids=$(
        echo "$runners" | jq -r '{id} | .[]'
    )

    IdleRunnersCount=$(echo "$idle_runner_ids" | wc -w)
    ActiveRunnersCount=$(echo "$active_runner_ids" | wc -w)
    AllRunnersCount=$(echo "$all_runner_ids" | wc -w)
    # shellcheck disable=SC2034
    ActiveRunnersPercent=$(("$AllRunnersCount" == 0 ? 100 : 100 * "$ActiveRunnersCount" / "$AllRunnersCount"))
    # shellcheck disable=SC2034
    IdleRunnersCountInverse=$((1000000 - "$IdleRunnersCount"))

    out=()
    for metric in IdleRunnersCount ActiveRunnersCount AllRunnersCount ActiveRunnersPercent IdleRunnersCountInverse; do
      out+=("$metric=${!metric}")
      if [[ "$REGION" != "" ]]; then
        suffix="publishing to CloudWatch"
        aws cloudwatch put-metric-data \
          --metric-name="$metric" \
          --namespace="$NAMESPACE" \
          --value="${!metric}" \
          --storage-resolution="1" \
          --unit="None" \
          --dimensions="GH_REPOSITORY=$GH_REPOSITORY" \
          --region="$REGION" \
          || true
      else
        suffix="AWS metadata service is not available, so not publishing"
      fi
    done

    echo "${out[*]} ($suffix)"
  done
}

cloudwatch_loop &
