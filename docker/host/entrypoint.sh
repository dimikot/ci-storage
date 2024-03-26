#!/bin/bash
#
# A container which holds ci-storage saved slots. Its ~user/ci-storage should be
# persistent across container restarts (e.g. point to an AWS EBS volume).
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

systemctl start rsyslog || true

mkdir -p /var/run/sshd
exec /usr/sbin/sshd -D -o ListenAddress=0.0.0.0
