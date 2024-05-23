#!/bin/bash
#
# Publishes CloudWatch metrics for auto-scaling.
#
set -u -e

cloudwatch_loop() {
  NAMESPACE="ci-storage/metrics"
  INTERVAL_SEC=30
  REGION=$(aws_metadata_curl latest/meta-data/placement/availability-zone | sed "s/[a-z]$//")

  # For faster debugging output.
  if [[ "$GH_REPOSITORY" == */ci-storage ]]; then
    INTERVAL_SEC=4
  fi

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
    first_online_runner_name=$(
        echo "$runners" | jq -r 'select((.status != "offline")) | {name} | .[]' | head -n1
    )

    # Start with fresh unset metric variables on each iteration.
    # shellcheck disable=SC2034
    (
      IdleRunnersCount=$(($(echo "$idle_runner_ids" | wc -w)))
      ActiveRunnersCount=$(($(echo "$active_runner_ids" | wc -w)))
      OfflineRunnersCount=$(($(echo "$offline_runner_ids" | wc -w)))
      AllRunnersCount=$(($(echo "$all_runner_ids" | wc -w)))
      ActiveRunnersPercent=$((("$IdleRunnersCount" + "$ActiveRunnersCount") == 0 ? 100 : 100 * "$ActiveRunnersCount" / ("$IdleRunnersCount" + "$ActiveRunnersCount")))

      if [[ "$(cat ~/actions-runner/.name)" == "$first_online_runner_name" ]]; then
        # Fetch current Docker Hub rate limits.
        docker_hub_token=$(
          curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" \
          | jq -r .token || true
        )
        lines=$(
          curl -s --head \
            -H "Authorization: Bearer $docker_hub_token" \
            https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest \
          | tr "[:upper:]" "[:lower:]" \
          | grep -Ei "^ratelimit-limit:|^ratelimit-remaining:" \
          | sed -E 's/;.*|:|\r//g' || true
        )
        while read -r key value; do
          case "$key" in
            ratelimit-limit) DockerHubLimit=$(("$value")) ;;
            ratelimit-remaining) DockerHubRemaining=$(("$value")) ;;
          esac
        done <<<"$lines"

        # Fetch current GitHub rate limits.
        lines=$(
          gh api -i -X HEAD /rate_limit \
          | tr "[:upper:]" "[:lower:]" \
          | grep -Ei "^x-ratelimit-limit:|^x-ratelimit-remaining:" \
          | sed -E 's/;.*|:|\r//g' || true
        )
        while read -r key value; do
          case "$key" in
            x-ratelimit-limit) GitHubLimit=$(("$value")) ;;
            x-ratelimit-remaining) GitHubRemaining=$(("$value")) ;;
          esac
        done <<<"$lines"
      fi

      # Send data to CloudWatch.
      out=()
      for metric in \
        IdleRunnersCount \
        ActiveRunnersCount \
        OfflineRunnersCount \
        AllRunnersCount \
        ActiveRunnersPercent \
        DockerHubLimit \
        DockerHubRemaining \
        GitHubLimit \
        GitHubRemaining \
      ; do
        [[ "${!metric:-}" == "" ]] && continue
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
    )
  done
}

cloudwatch_loop &
