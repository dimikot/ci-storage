ARG BASE_IMAGE="ubuntu:22.04"
FROM $BASE_IMAGE

ARG RUNNER_VERSION="2.314.1"

ENV GH_REPOSITORY=""
ENV GH_LABELS=""
ENV GH_TOKEN=""
ENV CI_STORAGE_HOST=""
ENV CI_STORAGE_HOST_PRIVATE_KEY=""

ENV DEBIAN_FRONTEND=noninteractive
RUN true \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
      openssh-client \
      jq gh rsync python3 mc git curl wget pv psmisc unzip vim nano telnet net-tools apt-transport-https ca-certificates locales \
    && useradd -m user

USER user
RUN true \
    && mkdir -p ~user/.ssh \
    && chmod 700 ~user/.ssh \
    && mkdir ~user/actions-runner \
    && cd ~user/actions-runner \
    && arch=$(dpkg --print-architecture) \
    && case "$arch" in \
      x86_64|amd64) arch=linux-x64 ;; \
      aarch64|arm64) arch=linux-arm64 ;; \
      *) echo >&2 "unsupported architecture: $arch"; exit 1 ;; \
    esac \
    && curl --no-progress-meter -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-$arch-$RUNNER_VERSION.tar.gz | tar xz

USER root
RUN true \
    && ~user/actions-runner/bin/installdependencies.sh \
    && apt-get autoremove \
    && apt-get clean \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && curl https://raw.githubusercontent.com/dimikot/ci-storage/main/ci-storage > /usr/bin/ci-storage \
    && chmod 755 /usr/bin/ci-storage

COPY --chmod=755 --chown=user:user entrypoint.sh /home/user

USER user
WORKDIR /home/user
ENTRYPOINT ["./entrypoint.sh"]

# If overridden in the derived image, evals this as a shell script after
# config.sh, but before run.sh.
CMD []
