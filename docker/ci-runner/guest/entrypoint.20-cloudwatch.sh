#!/bin/bash
#
# Publishes CloudWatch metrics for auto-scaling.
#
set -u -e

cloudwatch_loop() {
  NAMESPACE="ci-storage/metrics"
  INTERVAL_SEC=30
  REGION=$(aws_metadata_curl latest/meta-data/placement/availability-zone | sed "s/[a-z]$//")

  while :; do
    duration=$(("$INTERVAL_SEC" + ("$RANDOM" * "$INTERVAL_SEC" / 4 / 32768)))
    sleep "$duration"

    res=$(gh api "repos/$GH_REPOSITORY/actions/runners" --paginate || true)
    if ! grep -qF '"runners":' <<<"$res"; then
      echo "$(nice_date): gh api returned result with no \"runners\" key:"
      echo "$res"
      continue
    fi

    runners=$(echo "$res" | jq '.runners[] | {id,name,status,busy} | select(.name | startswith("ci-storage-"))')

    idle_runner_ids=$(
        echo "$runners" | jq -r 'select((.busy == false) and (.status == "online")) | {id} | .[]'
    )
    active_runner_ids=$(
        echo "$runners" | jq -r 'select((.busy == true) and (.status == "online")) | {id} | .[]'
    )
    offline_runner_ids=$(
        echo "$runners" | jq -r 'select((.status == "offline")) | {id} | .[]'
    )
    all_runner_ids=$(
        echo "$runners" | jq -r 'select(true) | {id} | .[]'
    )

    # shellcheck disable=SC2034
    IdleRunnersCount=$(($(echo "$idle_runner_ids" | wc -w)))
    ActiveRunnersCount=$(($(echo "$active_runner_ids" | wc -w)))
    # shellcheck disable=SC2034
    OfflineRunnersCount=$(($(echo "$offline_runner_ids" | wc -w)))
    # shellcheck disable=SC2034
    AllRunnersCount=$(($(echo "$all_runner_ids" | wc -w)))
    # shellcheck disable=SC2034
    ActiveRunnersPercent=$((("$IdleRunnersCount" + "$ActiveRunnersCount") == 0 ? 100 : 100 * "$ActiveRunnersCount" / ("$IdleRunnersCount" + "$ActiveRunnersCount")))

    out=()
    for metric in IdleRunnersCount ActiveRunnersCount OfflineRunnersCount AllRunnersCount ActiveRunnersPercent; do
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

    echo "$(nice_date): ${out[*]} ($suffix)"
  done
}

cloudwatch_loop &
