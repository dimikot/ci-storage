#!/bin/bash
#
# Optionally run Docker-in-Docker service.
# Requires sysbox installed on the host.
#
set -u -e

# We use the init script and not systemd, because containerd's systemctl script
# tries to modprobe, fails and shows a nasty warning.
/etc/init.d/docker start
echo

dind_loop() {
  for _n in {0..9}; do
    if ! pgrep dockerd >/dev/null; then
      log=/var/log/docker.log
      echo
      echo "Warning: Docker-in-Docker died; we still continue though."
      echo "- Maybe sysbox is not installed on the host system?"
      echo "- Or maybe you run this container on a Docker Desktop host?"
      echo "Logs from $log:"
      tail -n 5 $log | sed -E "s/^ +//" | grep . || true
      echo
      break
    fi
    sleep 1
  done
}

dind_loop &
