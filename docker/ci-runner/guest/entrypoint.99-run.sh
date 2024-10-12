#!/bin/bash
#
# In the very end, runs the self-hosted runner and waits for its termination. In
# case a SIGINT or SIGHUP are received, they will be processed by the
# terminate_on_signal() function defined in the config script above.
#
set -u -e

while :; do
  say 'Waiting for the initial "ci-storage load" to finish...'
  pgrep -xa ci-storage || break
  for _i in {1..6}; do
    sleep 0.5
    pgrep -xa ci-storage >/dev/null || break
  done
done

say "Starting the self-hosted runner..."

# Use "& wait $!" to let terminate_on_signal() properly handle signals for
# graceful termination (we can't use "exec" here).
cd ~/actions-runner && ./run.sh & wait $!
