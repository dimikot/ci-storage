#!/bin/bash
#
# Fixes permissions for the potentially mounted volume.
#
set -u -e

chown guest:guest /mnt

chmod 700 /mnt

if [[ -e /var/run/docker.sock ]]; then
  chown root:guest /var/run/docker.sock
fi
