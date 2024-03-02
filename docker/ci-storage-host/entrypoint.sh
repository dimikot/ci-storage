#!/bin/bash
#
# A container which holds ci-storage saved slots. Its ~user/ci-storage should be
# persistent across container restarts (e.g. point to an AWS EBS volume).
#
set -u -e

if [[ "${CI_STORAGE_HOST_PUBLIC_KEY:=''}" == "" ]]; then
  echo "CI_STORAGE_HOST_PUBLIC_KEY must be set to a valid SSH public key."
  exit 1
fi

authorized_keys=~user/.ssh/authorized_keys

if [[ ! -f $authorized_keys ]] || ! grep -qF "$CI_STORAGE_HOST_PUBLIC_KEY" $authorized_keys; then
  echo "$CI_STORAGE_HOST_PUBLIC_KEY" >> $authorized_keys
  chown user:user $authorized_keys
fi

mkdir -p /var/run/sshd
exec /usr/sbin/sshd -D -o ListenAddress=0.0.0.0
