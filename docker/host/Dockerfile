ARG BASE_IMAGE="ubuntu:22.04"

FROM $BASE_IMAGE

# SECRET: CI_STORAGE_PUBLIC_KEY

ENV DEBIAN_FRONTEND=noninteractive
RUN true \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
      openssh-server \
      jq gh rsync python3 rinetd rsyslog systemctl gosu less mc git curl wget pv psmisc unzip vim nano telnet net-tools apt-transport-https ca-certificates locales gnupg \
    && sed -i -e "s|#PermitRootLogin.*|PermitRootLogin no|" /etc/ssh/sshd_config \
    && useradd -m user \
    && mkdir -p ~user/.ssh ~user/ci-storage \
    && chown -R user:user ~user \
    && chmod 700 ~user/.ssh

COPY --chmod=755 entrypoint.sh /

WORKDIR /
EXPOSE 22/tcp
ENTRYPOINT ["/entrypoint.sh"]
