#!/bin/bash
#
# Includes all entrypoint.*.sh scripts and then runs the guest's entrypoint.sh.
#
set -u -e

if [[ "$(whoami)" != root ]]; then
  echo 'This script must be run as "root" user.'
  exit 1
fi

cd /

for entrypoint in ~/entrypoint.*.sh; do
  # shellcheck disable=SC1090
  [[ -f "$entrypoint" ]] && { pushd . >/dev/null; source "$entrypoint"; popd >/dev/null; }
done

"$@"

exec gosu guest ~guest/entrypoint.sh
