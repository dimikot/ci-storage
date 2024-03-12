#!/bin/bash
#
# To test interruption manually:
# https://github.com/aws/amazon-ec2-spot-interrupter
#
set -u -e

get_metadata_token() {
  curl -s -m5 -X PUT \
    "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
    || true
}

check_interruption() {
  pid="$1"

  sleep 5
  
  token=$(get_metadata_token)
  if [[ "$token" == "" ]]; then
    echo "AWS metadata service is not available, skipping interruption checks."
    return
  fi
  
  echo "Checking for instance interruption in background every few seconds."
  while :; do
    for _i in {1..300}; do
      response_http_200=$(
        curl -s -m5 --head \
          -H "X-aws-ec2-metadata-token: $token" \
          http://169.254.169.254/latest/meta-data/spot/instance-action \
          | head -1 | grep 200 \
          || true
      )
      if [[ "$response_http_200" != "" ]]; then
        echo "Instance interruption detected, sending SIGINT to PID $pid."
        kill -int "$pid"
        return
      else
        sleep 2
      fi
    done
    token=$(get_metadata_token)
  done
}

check_interruption $$ &
