ARG BASE_IMAGE="ubuntu:22.04"

FROM $BASE_IMAGE

ENV TZ=""
# SECRET: CI_STORAGE_PUBLIC_KEY

ENV DEBIAN_FRONTEND=noninteractive
RUN true \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
      openssh-server \
      jq gh rsync python3 rsyslog systemctl tzdata gosu less mc git curl wget pv psmisc unzip vim nano telnet net-tools apt-transport-https ca-certificates locales gnupg \
    && sed -i -e "s|#PermitRootLogin.*|PermitRootLogin no|" /etc/ssh/sshd_config \
    && useradd -m user \
    && mkdir -p ~user/.ssh ~user/ci-storage \
    && chown -R user:user ~user \
    && chmod 700 ~user/.ssh

# We want the default user to be root, to allow people extend the image with no
# boilerplate. But when someone runs e.g. "docker compose exec bash -l", we want
# the user to be "user".
RUN echo "cd ~user && gosu user:user bash -l" > ~/.bash_profile

COPY --chmod=755 --chown=root:root entrypoint*.sh /root

WORKDIR /root
EXPOSE 22/tcp
ENTRYPOINT ["/root/entrypoint.sh"]
