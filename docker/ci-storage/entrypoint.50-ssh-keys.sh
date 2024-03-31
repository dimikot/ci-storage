#!/bin/bash
#
# Puts SSH keys into the guest's home directory.
#
set -u -e

secret_file=/run/secrets/CI_STORAGE_PUBLIC_KEY

if [[ ! -r "$secret_file" || -d "$secret_file" ]]; then
  echo "You must pass secret $(basename "$secret_file") or mount $secret_file file when using this image."
  exit 1
fi

cat "$secret_file" > ~guest/.ssh/authorized_keys
chown -R guest:guest ~guest/.ssh
chmod 600 ~guest/.ssh/*
