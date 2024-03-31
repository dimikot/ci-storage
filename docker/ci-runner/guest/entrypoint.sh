#!/bin/bash
#
# Includes all entrypoint.*.sh scripts.
#
set -u -e

if [[ "$(whoami)" != guest ]]; then
  echo 'This script must be run as "guest" user.'
  exit 1
fi

cd ~guest

echo $$ > .entrypoint.pid

for entrypoint in ~/entrypoint.*.sh; do
  # shellcheck disable=SC1090
  [[ -f "$entrypoint" ]] && { pushd . >/dev/null; source "$entrypoint"; popd >/dev/null; }
done
