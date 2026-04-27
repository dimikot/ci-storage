#!/bin/bash
#
# Sets up port forwarding to the storage host.
#
# Format for each entry in FORWARD_PORTS:
# - 1234 (implies tcp)
# - 1234/udp
# - 1234/tcp
# - 1234/tcp-backup (flips primary server with backup in FORWARD_HOST list)
#
set -u -e

if [[ "$FORWARD_HOST" != "" && "$FORWARD_PORTS" != "" ]]; then
  # Remove port numbers from the FORWARD_HOST list, in case the client passed
  # them. Sometimes, it's easier to erase the port numbers here than on the
  # client's side, where FORWARD_HOST is passed as host:ignored_port from some
  # other data source.
  FORWARD_HOST=$(echo "$FORWARD_HOST" | sed -E 's/:[0-9]+//g')

  tcp_lines=()
  udp_lines=()
  for spec in $FORWARD_PORTS; do
    hosts=$(echo "$FORWARD_HOST" | xargs)
    port=${spec%%/*}
    proto=${spec##*/}
    if [[ "$proto" == "$port" ]]; then
      proto=tcp
    fi
    if [[ "$proto" == "tcp-backup" ]]; then
      proto="tcp"
      hosts=$(echo "$FORWARD_HOST" | awk '{for(i=NF;i>0;i--) printf "%s ", $i; print ""}' | xargs)
    fi
    if [[ "$proto" == udp ]]; then
      # UDP forwarding doesn't support backup servers, so use the first host.
      udp_lines+=("127.0.0.1 $port/$proto ${hosts%% *} $port/$proto")
    else
      tcp_lines+=("listen ${proto}_${port}")
      tcp_lines+=("  bind 127.0.0.1:$port")
      i=0
      for host in $hosts; do
        # ipv4 is needed for e.g. host.docker.internal
        tcp_line="  server server$i $host:$port resolvers res resolve-prefer ipv4 check inter 10s fall 6 rise 6"
        if [[ $i == 0 ]]; then
          tcp_lines+=("$tcp_line")
        else
          tcp_lines+=("$tcp_line backup")
        fi
        i=$((i+1))
      done
      tcp_lines+=("  mode $proto")
    fi
  done

  say "Forwarding ports:"

  # For TCP, we use fast haproxy.
  if [[ ${#tcp_lines[@]} != 0 ]]; then
    config=/etc/haproxy/haproxy.cfg
    section="# forward"
    (
      sed -E \
        -e "/^$section/,\$d" \
        -e '/httplog/d' \
        -e 's/^([[:space:]]+timeout[[:space:]]+(client|server))[[:space:]]+[0-9]+/\1 3600000/g' \
        $config
      echo "$section"
      echo "resolvers res"
      echo "  parse-resolv-conf"
      echo "  hold valid 10s"
      printf '%s\n' "${tcp_lines[@]}"
    ) > $config.new
    mv -f $config.new $config
    echo "haproxy tcp:"
    sed -e "1,/^$section/d" -e "s/^/  /" $config
  fi

  # Rinetd is super-slow, so we use it only for UDP.
  if [[ ${#udp_lines[@]} != 0 ]]; then
    config=/etc/rinetd.conf
    printf '%s\n' "${udp_lines[@]}" > $config
    echo "rinetd udp:"
    sed -e "s/^/  /" $config
  fi

  if [[ ${#udp_lines[@]} != 0 ]]; then
    say "Starting rinetd..."
    systemctl start rinetd &
  fi

  if [[ ${#tcp_lines[@]} != 0 ]]; then
    # We must wait for it (not run it in background), otherwise "ci-storage
    # load" step will likely fail.
    say "Starting haproxy..."
    /etc/init.d/haproxy start
  fi
fi
