#!/bin/bash
#
# Sets up port forwarding to the storage host.
#
set -u -e

if [[ "$FORWARD_HOST" != "" && "$FORWARD_PORTS" != "" ]]; then
  FORWARD_HOST="${FORWARD_HOST%%:*}"

  tcp_lines=()
  udp_lines=()
  for spec in $FORWARD_PORTS; do
    port=${spec%%/*}
    proto=${spec##*/}
    [[ "$proto" == "$port" ]] && proto=tcp
    if [[ "$proto" == udp ]]; then
      udp_lines+=("127.0.0.1 $port/$proto $FORWARD_HOST $port/$proto")
    else
      tcp_lines+=("listen ${proto}_${port}")
      tcp_lines+=("  bind 127.0.0.1:$port")
      tcp_lines+=("  server server1 $FORWARD_HOST:$port resolvers res")
      tcp_lines+=("  mode $proto")
    fi
  done

  echo "Forwarding ports:"

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
    echo "haproxy:"
    sed -e "1,/^$section/d" -e "s/^/  /" $config
  fi

  # Rinetd is super-slow, so we use it only for UDP.
  if [[ ${#udp_lines[@]} != 0 ]]; then
    config=/etc/rinetd.conf
    printf '%s\n' "${udp_lines[@]}" > $config
    echo "rinetd:"
    sed -e "s/^/  /" $config
  fi

  echo

  if [[ ${#tcp_lines[@]} != 0 ]]; then
    /etc/init.d/haproxy start || true
    echo
  fi
  if [[ ${#udp_lines[@]} != 0 ]]; then
    systemctl start rinetd || true
  fi
fi
