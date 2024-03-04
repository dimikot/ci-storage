#!/bin/bash
set -u -e

cd ~/actions-runner && ./run.sh & wait $!
