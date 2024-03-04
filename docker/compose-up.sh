#!/bin/bash
set -e

echo "Building & booting containters on the local laptop for debugging purposes..."

GH_REPOSITORY=$(gh repo view --json owner,name -q '.owner.login + "/" + .name') \
  GH_TOKEN=$(gh auth token) \
  docker compose up --build "$@"
