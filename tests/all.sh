#!/bin/bash
set -e -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

for f in *.test.sh; do
  echo "== Running $f"
  cd "$(dirname "$f")"
  bash "$f" 2>&1 | sed -e '/^+ set +o xtrace/d' -e '/^+ exitcode=0/d'
  cd - &>/dev/null
  echo
done

echo "OK"
