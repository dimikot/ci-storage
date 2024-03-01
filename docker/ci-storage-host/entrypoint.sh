#!/bin/bash
#
# A container which holds ci-storage saved slots. Its ~ubuntu/ci-storage should
# be persistent across container restarts.
#
set -u -e

if [ "${CI_STORAGE_HOST_SSH_KEY:-}" = "" ]; then
  echo "CI_STORAGE_HOST_SSH_KEY is not set, exiting..."
  exit 1
fi

cd /home/ubuntu

echo "$CI_STORAGE_HOST_SSH_KEY" > .ssh/id_ed25519
chmod 600 .ssh/id_ed25519
ssh-keygen -f .ssh/id_ed25519 -y > .ssh/authorized_keys
chown -R ubuntu:ubuntu .ssh

# This code is for simplifying the CI tests and allow self-hosted-runner to boot
# in docker-compose. In real world, the 1st slot created should contain the real
# files (e.g. a cloned git repo).
if [ ! -e ci-storage -a "${GH_REPOSITORY:-}" != "" ]; then
  mkdir -p ci-storage/$GH_REPOSITORY/initial
  chown -R ubuntu:ubuntu ci-storage
fi

mkdir -p /var/run/sshd
exec /usr/sbin/sshd -D -o ListenAddress=0.0.0.0
