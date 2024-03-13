#!/bin/bash
#
# In the very end, runs the self-hosted runner and waits for its termination. In
# case a SIGINT or SIGHUP are received, they will be processed by the cleanup()
# function defined in the config script above.
#
set -u -e

cd ~/actions-runner && ./run.sh & wait $!
