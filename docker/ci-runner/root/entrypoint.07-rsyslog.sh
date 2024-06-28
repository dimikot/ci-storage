#!/bin/bash
#
# Configures and starts rsyslog.
#
set -u -e

say "Starting rsyslog..."
systemctl start rsyslog &
