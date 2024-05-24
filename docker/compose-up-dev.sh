#!/bin/bash
set -e

echo "Building & booting containters on the local laptop for debugging purposes..."

GH_TOKEN=$(gh auth token) \
GH_REPOSITORY=$(gh repo view --json owner,name -q '.owner.login + "/" + .name') \
GH_REPOSITORIES=$(gh repo view --json owner,name -q '.owner.login + "/" + .name') \
GH_LABELS=ci-storage-dev \
TZ=America/Los_Angeles \
FORWARD_HOST=host.docker.internal \
docker compose up --pull=always --build "$@"
