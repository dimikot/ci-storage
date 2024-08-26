#!/bin/bash
set -e

echo "Building & booting containters on the local laptop for debugging purposes..."

# This is for debugging/illustration purposes only.
btime=1719410000
if [[ "$OSTYPE" == darwin* ]]; then
  btime=$(sysctl -n kern.boottime | awk '{print $4}' | tr -d ',')
elif [[ "$OSTYPE" == linux* ]]; then
  btime=$(grep btime /proc/stat | awk '{print $2}')
fi

GH_TOKEN=$(gh auth token) \
GH_REPOSITORY=$(gh repo view --json owner,name -q '.owner.login + "/" + .name') \
GH_LABELS=ci-storage-dev \
FORWARD_HOST=host.docker.internal \
TZ=America/Los_Angeles \
BTIME="$btime" \
ASGS=$(gh repo view --json owner,name -q '.owner.login + "/" + .name'):ci-storage-dev:myasg \
DOMAIN=${DOMAIN:-example.com} \
docker compose up --pull=always --build "$@"
