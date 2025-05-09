#!/bin/bash
#
# Upgrades-over the runner manually on each start and use --disableupdate in
# config.sh. If we relied on the auto-upgrade during run.sh is running, then it
# could kill jobs picked up and then abandoned due to the upgrade process.
#
set -u -e

cd ~/actions-runner

updated_at_file=.updated_at

if [[ ! -f "$updated_at_file" || "$(find . -name "$updated_at_file" -mtime +21)" != "" ]]; then
  arch=$(dpkg --print-architecture)
  case "$arch" in
    x86_64|amd64) arch=linux-x64 ;;
    aarch64|arm64) arch=linux-arm64 ;;
    *) echo >&2 "unsupported architecture: $arch"; exit 1 ;;
  esac

  say "Getting the latest runner version (previously updated at $(cat $updated_at_file))..."
  runner_version=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | jq -r ".tag_name[1:]")

  file="actions-runner-$arch-$runner_version.tar.gz"
  path="$CACHE_DIR/$file"
  url="https://github.com/actions/runner/releases/download/v$runner_version/$file"

  say "Content of $CACHE_DIR:"
  ls -la "$CACHE_DIR"

  if [[ ! -r "$path" ]]; then
    say "Downloading $url to $CACHE_DIR..."
    curl --no-progress-meter -L "$url" > "$path.tmp"
    mv -f "$path.tmp" "$path"
  else
    say "Using previously downloaded $path"
  fi

  tar xzf "$path"
  date > "$updated_at_file"

  say "Updated runner to $runner_version from $path"
else
  say "Runner is new enough (previously updated at $(cat $updated_at_file)), skipping the update."
fi
