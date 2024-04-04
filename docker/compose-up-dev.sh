#!/bin/bash
set -e

echo "Building & booting containters on the local laptop for debugging purposes..."

TZ="America/Los_Angeles" \
GH_TOKEN=$(gh auth token) \
GH_REPOSITORY=$(gh repo view --json owner,name -q '.owner.login + "/" + .name') \
  docker compose up --build "$@"
