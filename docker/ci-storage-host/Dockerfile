ARG BASE_IMAGE="ubuntu:22.04"

FROM $BASE_IMAGE

ENV GH_REPOSITORY=""
ENV CI_STORAGE_HOST_SSH_KEY=""

ENV DEBIAN_FRONTEND=noninteractive
RUN true \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
      awscli rsync openssh-server \
      mc gcc git curl wget pv psmisc unzip vim nano telnet net-tools bash-completion \
      libssl-dev apt-transport-https build-essential ca-certificates locales pkg-config \
    && sed -i -e "s|#PermitRootLogin.*|PermitRootLogin no|" /etc/ssh/sshd_config \
    && useradd -m ubuntu \
    && mkdir -p /home/ubuntu/.ssh \
    && chown -R ubuntu:ubuntu /home/ubuntu/.ssh \
    && chmod 700 /home/ubuntu/.ssh

COPY --chmod=755 entrypoint.sh /

WORKDIR /
EXPOSE 22/tcp
ENTRYPOINT ["/entrypoint.sh"]
