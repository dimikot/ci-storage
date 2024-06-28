#!/bin/bash
#
# Logs uptime of the runner (since instance boot timestamp, if it's passed) in
# the beginning and then time to time. Also, tries to amend the instance Name
# tag by adding boot latency suffix to it: "docker_boot_sec+runner_boot_sec".
#
set -u -e

TAG_NAME="Name"
TAG_BTIME="ci-storage:BTIME"
TAG_DOCKER_BOOT_SEC="ci-storage:DockerBootSec"
TAG_RUNNER_BOOT_SEC="ci-storage:RunnerBootSec"

log_uptime_loop() {
  label=${GH_LABELS##*,}
  dimensions="GH_REPOSITORY=$GH_REPOSITORY,GH_LABEL=$label"
  instance_id=$(aws_instance_id)

  i=0
  while :; do
    if [[ "$i" == 0 ]]; then
      RunnerBootSec=$(awk '{print int($1)}' /proc/uptime)
      DockerBootSec=$(($(date '+%s') - BTIME - RunnerBootSec))
      suffix="$DockerBootSec+$RunnerBootSec sec"
      message="Appending boot latency ($suffix) suffix to the instance Name tag..."
      if [[ "$instance_id" != "" ]]; then
        say "$message"
        # Only append boot latency if we actually booted or rebooted (i.e.
        # $btime injected from the outside has changed). Don't do it if the
        # container has just been restarted (i.e. if $btime didn't change).
        name=$(aws_read_tag "$TAG_NAME" || true)
        if [[ "$name" != "" ]]; then
          prev_btime=$(aws_read_tag "$TAG_BTIME" || true)
          if [[ "$prev_btime" != "$BTIME" ]]; then
            aws_write_tag "$TAG_BTIME" "$BTIME" || true
            aws_write_tag "$TAG_RUNNER_BOOT_SEC" "$RunnerBootSec" || true
            aws_write_tag "$TAG_DOCKER_BOOT_SEC" "$DockerBootSec" || true
            aws_write_tag "$TAG_NAME" "$name ($suffix)" || true
          else
            say "It is the container who restarted, not the instance start/reboot, so skipping."
            DockerBootSec=$(aws_read_tag "$TAG_DOCKER_BOOT_SEC" || true)
          fi
        else
          say "Could not read Name tag of instance \"$instance_id\"."
        fi
      else
        say "$message (AWS metadata service is not available, so skipping)"
      fi
    fi

    # shellcheck disable=SC2034
    InstanceUptimeSec=$(($(date '+%s') - BTIME))
    # shellcheck disable=SC2034
    RunnerUptimeSec=$(awk '{print int($1)}' /proc/uptime)

    out=()
    for metric in DockerBootSec RunnerBootSec InstanceUptimeSec RunnerUptimeSec; do
      if [[ "${!metric}" == "" ]]; then
        continue
      fi
      if [[ "$instance_id" != "" ]]; then
        suffix="publishing to CloudWatch"
        namespace=""
        if [[ "$metric" == *Boot* ]]; then
          # By default, metrics in CWAgent namespace are shown right on the
          # instance's Monitoring tab.
          namespace="CWAgent"
        fi
        aws_cloudwatch_put_metric_data "$metric" "${!metric}" "$dimensions" "$namespace" || true
      else
        suffix="AWS metadata service is not available, so not publishing"
      fi
      out+=("$metric=${!metric}")
    done

    say "$GH_REPOSITORY: ${out[*]} ($suffix)"
    i=$((i + 1))
    sleep 60
  done
}

if [[ "$BTIME" != "" ]]; then
  log_uptime_loop &
fi
