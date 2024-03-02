ARG BASE_IMAGE="ubuntu:22.04"

FROM $BASE_IMAGE

ENV CI_STORAGE_HOST_PUBLIC_KEY=""

ENV DEBIAN_FRONTEND=noninteractive
RUN true \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
      openssh-server \
      jq gh rsync python3 mc git curl wget pv psmisc unzip vim nano telnet net-tools apt-transport-https ca-certificates locales \
    && sed -i -e "s|#PermitRootLogin.*|PermitRootLogin no|" /etc/ssh/sshd_config \
    && useradd -m user \
    && mkdir -p ~user/.ssh ~user/ci-storage \
    && chown -R user:user ~user \
    && chmod 700 ~user/.ssh

COPY --chmod=755 entrypoint.sh /

WORKDIR /
EXPOSE 22/tcp
ENTRYPOINT ["/entrypoint.sh"]
