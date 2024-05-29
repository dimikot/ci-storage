#!/bin/bash
#
# Puts SSH keys into the guest's home directory.
#
set -u -e

secret_file=/run/secrets/CI_STORAGE_PUBLIC_KEY
if [[ -f "$secret_file" ]]; then
  cat "$secret_file" > ~guest/.ssh/authorized_keys
  chmod 600 ~guest/.ssh/*
fi

chown -R guest:guest ~guest/.ssh
