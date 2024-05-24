#!/bin/bash
#
# Removes other offline runners after a short delay.
#
# We have this logic in ci-storage container and not in each ci-runner to save
# on GitHub rate limiting: if every runner pulls the list of runners all the
# time, then all runners in total will exhaust the rate limit pretty quickly.
#
set -u -e

runner_ids() {
  local repo="$1"
  gh api \
    "repos/$repo/actions/runners" \
    -q '.runners[] | {id,name,status,busy} | select((.name | startswith("ci-storage-")) and (.busy == false) and (.status == "offline")) | {id} | .[]' \
    --paginate
}

remove_offline_loop() {
  local repo="$1"

  # Make sure we don't delete newly created (but still offline) runners, after
  # they are registered, but before they become online. I.e. we delete only
  # runners from ids1 that remain offline for at least N seconds (ids2).
  local ENSURE_OFFLINE_SEC=60

  while :; do
    ids1=$(runner_ids "$repo" | sort || true)
    sleep $ENSURE_OFFLINE_SEC
    ids2=$(runner_ids "$repo" | sort || true)
    ids1_intersect_ids2=$(comm -12 <(echo "$ids1") <(echo "$ids2"))

    if [[ "$ids1_intersect_ids2" == "" ]]; then
      continue
    fi

    echo "$repo: Offline runners to be removed: $(echo "$ids1_intersect_ids2" | wc -w)"
    for id in $ids1_intersect_ids2; do
      echo "$repo: Removing offline runner $id..."
      gh api -X DELETE "/repos/$repo/actions/runners/$id" || true
    done
  done
}

if [[ "$GH_REPOSITORIES" != "" ]]; then
  for repo in $GH_REPOSITORIES; do
    remove_offline_loop "$repo" &
  done
fi
