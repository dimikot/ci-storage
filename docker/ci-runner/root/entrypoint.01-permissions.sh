#!/bin/bash
#
# Fixes permissions for the potentially mounted volume.
#
set -u -e

chown guest:guest /mnt
chmod 700 /mnt
