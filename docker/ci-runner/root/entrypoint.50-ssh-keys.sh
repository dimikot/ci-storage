#!/bin/bash
#
# Puts SSH keys into the guest's and root's home directories.
#
set -u -e

mkdir -p ~guest/.ssh && chmod 700 ~guest/.ssh
mkdir -p ~root/.ssh && chmod 700 ~root/.ssh

secret_file=/run/secrets/CI_STORAGE_PRIVATE_KEY
if [[ -f "$secret_file" ]]; then
  cat "$secret_file" > ~guest/.ssh/id_rsa
  cat "$secret_file" > ~root/.ssh/id_rsa
fi

chmod 600 ~guest/.ssh/* || true
chown -R guest:guest ~guest/.ssh || true

chmod 600 ~root/.ssh/* || true
chown -R root:root ~root/.ssh || true
