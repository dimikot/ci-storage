#!/bin/bash
#
# Upgrades-over the runner manually on each start and use --disableupdate in
# config.sh. If we rely on the automatic upgrade during run.sh is running, then
# it could kill jobs picked up and then abandoned due to the upgrade process.
#
set -u -e

cd ~/actions-runner

arch=$(dpkg --print-architecture)
case "$arch" in
  x86_64|amd64) arch=linux-x64 ;;
  aarch64|arm64) arch=linux-arm64 ;;
  *) echo >&2 "unsupported architecture: $arch"; exit 1 ;;
esac
runner_version=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | jq -r ".tag_name[1:]")
curl --no-progress-meter -L "https://github.com/actions/runner/releases/download/v$runner_version/actions-runner-$arch-$runner_version.tar.gz" | tar xz

echo "Updated runner to $runner_version"
