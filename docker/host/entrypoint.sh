#!/bin/bash
#
# A container which holds ci-storage saved slots. Its ~user/ci-storage should be
# persistent across container restarts (e.g. point to an AWS EBS volume).
#
set -u -e

if [[ "${CI_STORAGE_HOST_PUBLIC_KEY_EVAL:=}" == "" ]]; then
  echo "CI_STORAGE_HOST_PUBLIC_KEY_EVAL must be contain a bash script which prints a valid SSH public key (e.g. fetched from AWS Secrets Manager or so)."
  exit 1
fi

authorized_keys_file=~user/.ssh/authorized_keys
public_key=$(eval "$CI_STORAGE_HOST_PUBLIC_KEY_EVAL")
if [[ "$public_key" == "" ]]; then
  echo "CI_STORAGE_HOST_PUBLIC_KEY_EVAL evaluated to an empty string."
  exit 1
fi

if [[ ! -f $authorized_keys_file ]] || ! grep -qF "$public_key" $authorized_keys_file; then
  echo "$public_key" >> $authorized_keys_file
  chown user:user $authorized_keys_file
fi

mkdir -p /var/run/sshd
exec /usr/sbin/sshd -D -o ListenAddress=0.0.0.0
