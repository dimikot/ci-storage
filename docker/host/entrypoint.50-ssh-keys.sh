#!/bin/bash
#
# Puts SSH keys into the user's home directory.
#
set -u -e

secret_file=/run/secrets/CI_STORAGE_PUBLIC_KEY
if [[ ! -f "$secret_file" ]]; then
  echo "You must pass secret CI_STORAGE_PUBLIC_KEY when using this image."
  exit 1
fi

cat "$secret_file" > ~user/.ssh/authorized_keys
chown -R user:user ~user/.ssh
chmod 600 ~user/.ssh/*
