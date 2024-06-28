#!/bin/bash
#
# Sends a graceful shutdown request to self it the instance interruption notice
# is received.
#
# To test interruption manually:
# https://github.com/aws/amazon-ec2-spot-interrupter
#
set -u -e

instance_interruption_loop() {
  pid="$1"

  sleep 5

  res=$(aws_metadata_curl latest/meta-data/spot/instance-action --head)
  if [[ "$res" == "" ]]; then
    say "AWS metadata service is not available, skipping interruption checks."
    return
  fi

  say "Checking for instance interruption in background every few seconds."
  while :; do
    response_http_200=$(
      aws_metadata_curl latest/meta-data/spot/instance-action --head \
      | head -1 | grep 200 || true
    )
    if [[ "$response_http_200" != "" ]]; then
      say "Instance interruption detected, sending SIGINT to PID $pid."
      kill -SIGINT "$pid"
      return
    else
      sleep 2
    fi
  done
}

instance_interruption_loop $$ &
