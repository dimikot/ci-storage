#!/bin/bash
#
# Configures and starts rsyslog.
#
set -u -e

say "Starting rsyslog..."
mkdir -p /var/log/journal && chmod 755 /var/log/journal
systemctl start rsyslog &
