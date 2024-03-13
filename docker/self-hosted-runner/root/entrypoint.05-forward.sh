#!/bin/bash
#
# Sets up port forwarding to the storage host.
#
set -u -e

if [[ "$FORWARD_HOST" == "" ]]; then
  FORWARD_HOST="$CI_STORAGE_HOST"
fi

if [[ "$FORWARD_HOST" != "" && "$FORWARD_PORTS" != "" ]]; then
  FORWARD_HOST="${FORWARD_HOST%%:*}"
  for port in $FORWARD_PORTS; do
    echo "127.0.0.1 $port $FORWARD_HOST $port";
  done > /etc/rinetd.conf

  systemctl start rinetd

  echo "Forwarding ports:"
  cat /etc/rinetd.conf
  echo
fi
