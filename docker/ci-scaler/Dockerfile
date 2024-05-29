ARG BASE_IMAGE="ubuntu:22.04"
FROM $BASE_IMAGE

ENV GH_TOKEN=""
ENV ASGS=""
ENV DOMAIN=""
ENV TZ=""

ENV DEBIAN_FRONTEND=noninteractive

RUN true \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
      awscli jq gh rsync python3 python3-yaml rsyslog systemctl tzdata gosu less mc git curl wget pv psmisc unzip vim nano telnet net-tools apt-transport-https ca-certificates locales gnupg lsb-release \
    && useradd -m guest -s /bin/bash \
    && mkdir ~guest/.ssh && chmod 700 ~guest/.ssh \
    && chown -R guest:guest ~guest

# We want the default user to be root, to allow people extend the image with no
# boilerplate. But when someone runs e.g. "docker compose exec bash -l", we want
# the user to be "guest".
RUN echo "cd ~guest && gosu guest bash -l" > ~/.bash_profile

COPY --chmod=755 --chown=root:root root/entrypoint*.sh /root
COPY --chmod=755 --chown=guest:guest guest/entrypoint*.sh /home/guest
COPY --chown=guest:guest guest/scaler/ /home/guest/scaler/

WORKDIR /root
EXPOSE 8088/tcp
ENTRYPOINT ["/root/entrypoint.sh"]
