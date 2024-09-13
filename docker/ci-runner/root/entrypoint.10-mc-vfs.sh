#!/bin/bash
#
# Configures MC VSF parameters.
#
set -u -e

for file in /etc/mc/mc.ext /root/.config/mc/mc.ext; do
  if [[ -f $file ]] && ! grep -q "/POSIX tar archive" /etc/mc/mc.ext; then
    sed -i $"1i type/POSIX tar archive\n  Open=%cd %p/utar://\n  View=%view{ascii} tar tf \"\${MC_EXT_FILENAME}\"\n" $file
  fi
done
