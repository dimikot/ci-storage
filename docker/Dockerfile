ARG BASE_IMAGE="ubuntu:22.04"

FROM $BASE_IMAGE

ARG RUNNER_VERSION="2.314.1"

ENV GH_REPOSITORY=""
ENV GH_LABELS=""
ENV GH_TOKEN=""

ENV DEBIAN_FRONTEND=noninteractive
RUN true \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
      awscli jq gh \
      mc gcc git curl wget pv psmisc unzip vim nano telnet net-tools bash-completion \
      libssl-dev apt-transport-https build-essential ca-certificates locales pkg-config

RUN true \
    && useradd -m ubuntu

USER ubuntu
RUN true \
    && mkdir /home/ubuntu/actions-runner \
    && cd /home/ubuntu/actions-runner \
    && arch=$(dpkg --print-architecture) \
    && case "$arch" in \
      x86_64|amd64) arch=linux-x64 ;; \
      aarch64|arm64) arch=linux-arm64 ;; \
      *) echo >&2 "unsupported architecture: $arch"; exit 1 ;; \
    esac \
    && curl --no-progress-meter -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-$arch-$RUNNER_VERSION.tar.gz | tar xz

USER root
RUN /home/ubuntu/actions-runner/bin/installdependencies.sh \
    apt-get autoremove \
    && apt-get clean \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*

USER ubuntu
COPY --chmod=755 --chown=ubuntu:ubuntu entrypoint.sh /home/ubuntu

WORKDIR /home/ubuntu
ENTRYPOINT ["./entrypoint.sh"]

# If overridden in the derived image, evals this as "ubuntu" user as a shell
# script after config.sh, but before run.sh.
CMD []

