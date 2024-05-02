ARG BASE_IMAGE="ubuntu:22.04"
FROM $BASE_IMAGE

ENV GH_TOKEN=""
ENV GH_REPOSITORY=""
ENV GH_LABELS=""
ENV TZ=""
ENV FORWARD_HOST=""
ENV FORWARD_PORTS=""
ENV CI_STORAGE_HOST=""
ENV DEBUG_SHUTDOWN_DELAY_SEC=""
# SECRET: CI_STORAGE_PRIVATE_KEY

ENV DEBIAN_FRONTEND=noninteractive

# Register official Docker repo.
RUN true \
    && apt-get update -y \
    && apt-get install -y lsb-release ca-certificates curl \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

# Install all needed packages.
RUN true \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
      openssh-client \
      docker-ce-cli awscli build-essential haproxy rinetd \
      jq gh rsync python3 rsyslog systemctl tzdata gosu less mc git curl wget pv psmisc unzip vim nano telnet net-tools apt-transport-https ca-certificates locales gnupg

# Add user "guest".
RUN true \
    && useradd -m guest -s /bin/bash

# Do stuff as user "guest".
USER guest
RUN true \
    && mkdir ~guest/.ssh && chmod 700 ~guest/.ssh \
    && mkdir ~guest/actions-runner \
    && chown -R guest:guest ~guest \
    && cd ~guest/actions-runner \
    && arch=$(dpkg --print-architecture) \
    && case "$arch" in \
      x86_64|amd64) arch=linux-x64 ;; \
      aarch64|arm64) arch=linux-arm64 ;; \
      *) echo >&2 "unsupported architecture: $arch"; exit 1 ;; \
    esac \
    && runner_version=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | jq -r ".tag_name[1:]") \
    && curl --no-progress-meter -L https://github.com/actions/runner/releases/download/v$runner_version/actions-runner-$arch-$runner_version.tar.gz | tar xz

USER root
RUN true \
    && ~guest/actions-runner/bin/installdependencies.sh \
    && apt-get autoremove \
    && apt-get clean \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*

# We want the default user to be root, to allow people extend the image with no
# boilerplate. But when someone runs e.g. "docker compose exec bash -l", we want
# the user to be "guest".
RUN echo "cd ~guest && gosu guest:guest bash -l" > ~/.bash_profile

ADD --chmod=755 https://raw.githubusercontent.com/dimikot/ci-storage/main/ci-storage /usr/bin/ci-storage
ADD --chmod=755 https://raw.githubusercontent.com/dimikot/signal-fanout/main/signal-fanout /usr/bin/signal-fanout
ADD --chmod=755 https://raw.githubusercontent.com/dimikot/run-in-separate-pgrp/main/run-in-separate-pgrp /usr/bin/run-in-separate-pgrp

COPY --chmod=755 --chown=root:root root/entrypoint*.sh /root
COPY --chmod=755 --chown=guest:guest guest/entrypoint*.sh /home/guest

WORKDIR /root
ENTRYPOINT ["/root/entrypoint.sh"]
