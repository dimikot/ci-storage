#!/bin/bash
#
# In the very end, runs the self-hosted runner and waits for its termination. In
# case a SIGINT or SIGHUP are received, they will be processed by the cleanup()
# function defined in the config script above.
#
set -u -e

if [[ "${CI_STORAGE_PID:=}" != "" ]]; then
  say "Waiting for the initial \"ci-storage load\" to finish (pid=$CI_STORAGE_PID)..."
  wait "$CI_STORAGE_PID"
fi

say "Starting the self-hosted runner..."
cd ~/actions-runner && ./run.sh & wait $!
