#!/bin/bash
#
# Upgrades-over the runner manually on each start and use --disableupdate in
# config.sh. If we relied on the auto-upgrade during run.sh is running, then it
# could kill jobs picked up and then abandoned due to the upgrade process.
#
set -u -e

cd ~/actions-runner

updated_at_file=.updated_at

if [[ "$(find . -name "$updated_at_file" -mtime +21)" != "" ]]; then
  arch=$(dpkg --print-architecture)
  case "$arch" in
    x86_64|amd64) arch=linux-x64 ;;
    aarch64|arm64) arch=linux-arm64 ;;
    *) echo >&2 "unsupported architecture: $arch"; exit 1 ;;
  esac
  say "Fetching the latest runner version..."
  runner_version=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | jq -r ".tag_name[1:]")
  say "Updating runner to \"$runner_version\" (previously updated on $(cat $updated_at_file))..."
  curl --no-progress-meter -L "https://github.com/actions/runner/releases/download/v$runner_version/actions-runner-$arch-$runner_version.tar.gz" | tar xz
  say "Updated runner to $runner_version (previously updated on $(cat $updated_at_file))."
  date > $updated_at_file
else
  say "Runner is new enough (last updated on $(cat $updated_at_file)), skipping the update."
fi
