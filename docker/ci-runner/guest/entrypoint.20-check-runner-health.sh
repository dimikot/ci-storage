#!/bin/bash
#
# GitHub Runners have some bugs. They sometimes don't die, and instead get stuck
# in a desperate restart loop. Here we work it around.
#
# Related GitHub issue: https://github.com/actions/runner/issues/2507
#
set -u -e

rm -f ~/actions-runner/_diag/*.log

check_runner_health_loop() {
  pid="$1"
  unhealthy_re="Registration was not found or is not medium trust"

  while :; do
    log=$(find ~/actions-runner/_diag -name "*.log" | tail -n1)
    if [[ "$log" != "" ]]; then
      # Find the very last line matching the regexp.
      error=$(tail -n 500 "$log" | tac | grep -m1 -E -B15 -A15 "$unhealthy_re" | tac)
      if [[ "$error" != "" ]]; then
        say "Deadly message found in $log, terminating self. Last log lines:"
        say "---------------------"
        echo "$error"
        say "---------------------"
        kill -SIGINT "$pid"
        return
      fi
    fi
    sleep 5
  done
}

check_runner_health_loop $$ &
