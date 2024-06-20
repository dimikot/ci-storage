#!/bin/bash
#
# Prints usage statistics and also, if work directory is not on tmpfs, keeps it
# in cache to lower the chances of the directory entries to be evicted.
#
set -u -e

prewarm_loop() {
  sleep 30
  while :; do
    time_took=/tmp/time_took
    export TIMEFORMAT="%R sec"
    info=$({ time df -h --output=fstype,target,used "$WORK_DIR" | tail -n1 | sed -E 's/[[:space:]]+/ /g'; } 2>$time_took)
    if [[ "$info" != *tmpfs* ]]; then
      info=$({ time du -sh "$WORK_DIR" | sed -E 's/\s+/ /g'; } 2>$time_took)
    fi
    uptime=$(uptime | sed -E -e 's/^\s*[0-9:]+\s+//' -e 's/\s+/ /g')
    echo "$(nice_date): Prewarm (took $(cat $time_took)): $info: $uptime"
    sleep 60
  done
}

# Print "prewarm" stats only when TZ is set. This prevents it from printing in
# debug dev environment of the client for instance.
if [[ "$TZ" != "" ]]; then
  prewarm_loop &
fi
