#!/bin/bash
set -u -e

secret_file=/run/secrets/CI_STORAGE_PRIVATE_KEY
if [[ -f "$secret_file" ]]; then
  cat "$secret_file" > ~user/.ssh/id_rsa
fi

chown -R user:user ~user/.ssh
chmod 600 ~user/.ssh/*
