#!/bin/bash
#
# Keeps ~user directory in cache to lower the chances of the directory entries
# to be evicted.
#
set -u -e

prewarm_loop() {
  sleep 30
  while :; do
    tmp=/tmp/time_took
    export TIMEFORMAT="%R sec"
    du=$({ time du -sh ~user | sed -E 's/\s+/ /g'; } 2>$tmp)
    echo "$(nice_date): Prewarm (took $(cat $tmp)): $du: $(uptime | sed -E -e 's/^\s*[0-9:]+\s+//' -e 's/\s+/ /g')"
    sleep 60
  done
}

prewarm_loop &
