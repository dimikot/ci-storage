#!/bin/bash
set -u -e

if [[ "$(whoami)" != user ]]; then
  echo 'This script must be run as "user" user.';
  exit 1;
fi

cd ~user

echo $$ > .entrypoint.pid

for entrypoint in ~/entrypoint.*.sh; do
  # shellcheck disable=SC1090
  [[ -f "$entrypoint" ]] && { pushd . >/dev/null; source "$entrypoint"; popd >/dev/null; }
done
