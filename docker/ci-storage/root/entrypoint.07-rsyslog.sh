#!/bin/bash
#
# Configures and starts rsyslog.
#
set -u -e

systemctl start rsyslog &
