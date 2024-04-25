#!/bin/bash
#
# Puts SSH keys into the guest's home directory.
#
set -u -e

secret_file=/run/secrets/CI_STORAGE_PRIVATE_KEY
if [[ -f "$secret_file" ]]; then
  cat "$secret_file" > ~guest/.ssh/id_rsa
  chmod 600 ~guest/.ssh/*
fi

chown -R guest:guest ~guest/.ssh
