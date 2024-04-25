#!/bin/bash
#
# Holds reusable functions and tools.
#
set -u -e

# Prints the current date in the same format as the GitHub Actions runner does.
nice_date() {
  date +"%Y-%m-%d %H:%M:%S %Z"
}

export -f nice_date

nice_date
