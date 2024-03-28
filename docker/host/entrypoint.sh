#!/bin/bash
#
# A container which holds ci-storage saved slots. Its ~user/ci-storage directory
# should be persistent across container restarts (e.g. be on an AWS EBS volume).
#
set -u -e

if [[ "$(whoami)" != root ]]; then
  echo 'This script must be run as "root" user.'
  exit 1
fi

cd /

"$@"

for entrypoint in ~/entrypoint.*.sh; do
  # shellcheck disable=SC1090
  [[ -f "$entrypoint" ]] && { pushd . >/dev/null; source "$entrypoint"; popd >/dev/null; }
done
