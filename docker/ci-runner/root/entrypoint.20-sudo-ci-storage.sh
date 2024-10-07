#!/bin/bash
#
# Allows to run /usr/bin/ci-storage with sudo.
#
set -u -e

echo "guest ALL=(ALL) NOPASSWD: /usr/bin/ci-storage" > /etc/sudoers.d/ci-storage
chmod 440 /etc/sudoers.d/ci-storage
