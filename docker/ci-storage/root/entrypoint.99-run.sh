#!/bin/bash
#
# In the very end, run sshd server.
#
set -u -e

say "Starting SSH server..."

mkdir -p /var/run/sshd
exec /usr/sbin/sshd -D -o ListenAddress=0.0.0.0
