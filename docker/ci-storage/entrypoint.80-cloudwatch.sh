#!/bin/bash
#
# Publishes CloudWatch metrics for auto-scaling.
#
# We have this logic in ci-storage container and not in each ci-runner to save
# on GitHub rate limiting: if every runner pulls the list of runners all the
# time, then all runners in total will exhaust the rate limit pretty quickly.
#
set -u -e

cloudwatch_loop() {
  local repo="$1"
  local INTERVAL_SEC=20

  while :; do
    duration=$(("$INTERVAL_SEC" + ("$RANDOM" * "$INTERVAL_SEC" / 4 / 32768)))
    sleep "$duration"

    res=$(gh api "repos/$repo/actions/runners" --paginate || true)
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

    # Start with fresh unset metric variables on each iteration.
    # shellcheck disable=SC2034
    (
      IdleRunnersCount=$(($(echo "$idle_runner_ids" | wc -w)))
      ActiveRunnersCount=$(($(echo "$active_runner_ids" | wc -w)))
      OfflineRunnersCount=$(($(echo "$offline_runner_ids" | wc -w)))
      AllRunnersCount=$(($(echo "$all_runner_ids" | wc -w)))
      OnlineRunnersCount=$(("$IdleRunnersCount" + "$ActiveRunnersCount"))
      ActiveRunnersPercent=$(("$OnlineRunnersCount" == 0 ? 0 : 100 * "$ActiveRunnersCount" / "$OnlineRunnersCount"))

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

      # Send data to CloudWatch.
      out=()
      for metric in \
        IdleRunnersCount \
        ActiveRunnersCount \
        OfflineRunnersCount \
        AllRunnersCount \
        OnlineRunnersCount \
        ActiveRunnersPercent \
        DockerHubLimit \
        DockerHubRemaining \
        GitHubLimit \
        GitHubRemaining \
      ; do
        if [[ "${!metric:-}" != "" ]]; then
          if aws_cloudwatch_put_metric_data "$metric" "${!metric}" "GH_REPOSITORY=$repo"; then
            suffix="publishing to CloudWatch"
          else
            suffix="AWS metadata service is not available, so not publishing"
          fi
          out+=("$metric=${!metric}")
        fi
      done

      echo "$(nice_date): $repo: ${out[*]} ($suffix)"
    )
  done
}

if [[ "$GH_REPOSITORIES" != "" ]]; then
  for repo in $GH_REPOSITORIES; do
    cloudwatch_loop "$repo" &
  done
fi
