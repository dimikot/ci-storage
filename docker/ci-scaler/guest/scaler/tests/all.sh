#!/bin/bash
set -e -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
export PYTHONPATH=..
python3 -B -m unittest discover -v -s . -p 'test_*.py' -- "$@"
