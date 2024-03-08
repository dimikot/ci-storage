#!/bin/bash
set -u -e

if [[ "$FORWARD_HOST" == "" ]]; then
  FORWARD_HOST="$CI_STORAGE_HOST"
fi

if [[ "$FORWARD_HOST" != "" && "$FORWARD_PORTS" != "" ]]; then
  FORWARD_HOST="${FORWARD_HOST%%:*}"
  for port in $FORWARD_PORTS; do
    echo "127.0.0.1 $port $FORWARD_HOST $port";
  done > /etc/rinetd.conf

  service rinetd start

  echo "Forwarding ports:"
  cat /etc/rinetd.conf
  echo
fi
