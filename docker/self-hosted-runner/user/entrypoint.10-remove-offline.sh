#!/bin/bash
set -u -e

runner_ids() {
  gh api \
    "repos/$GH_REPOSITORY/actions/runners" \
    -q '.runners[] | {id,status,busy} | select((.busy == false) and (.status == "offline")) | {id} | .[]' \
    --paginate
}

remove_offline() {
  # Make sure we don't delete newly created runners, after they are registered,
  # but before they become online. I.e. we delete only runners which remain
  # offline for at least some time.
  ids1=$(runner_ids | sort)
  sleep 30
  ids2=$(runner_ids | sort)
  ids=$(comm -12 <(echo "$ids1") <(echo "$ids2"))

  for id in $ids; do
    echo "Removing offline runner $id..."
    gh api -X DELETE "/repos/$GH_REPOSITORY/actions/runners/$id" || true
  done
}

remove_offline &
