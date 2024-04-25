#!/bin/bash
set -e

echo "Building & booting containters on the local laptop for debugging purposes..."

GH_TOKEN=$(gh auth token) \
GH_REPOSITORY=$(gh repo view --json owner,name -q '.owner.login + "/" + .name') \
GH_LABELS=ci-storage-dev \
CI_STORAGE_HOST=ci-storage:22 \
docker compose up --build "$@"
