FROM debian:stretch-slim

RUN set -ex; \
    addgroup --system mailroom; \
    adduser --system --ingroup mailroom mailroom

# Install ca-certificates so HTTPS works in general
RUN apt-get update && \
    apt-get install -y --no-install-recommends nano ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ARG MAILROOM_REPO
ENV MAILROOM_REPO ${MAILROOM_REPO:-nyaruka/mailroom}
ARG MAILROOM_VERSION
ENV MAILROOM_VERSION ${MAILROOM_VERSION:-6.2.3}

RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends vim net-tools iputils-ping procps wget; \
    rm -rf /var/lib/apt/lists/*; \
    \
    wget -O mailroom.tar.gz "https://github.com/$MAILROOM_REPO/releases/download/v${MAILROOM_VERSION}/mailroom_${MAILROOM_VERSION}_linux_amd64.tar.gz"; \
    mkdir /usr/local/src/mailroom; \
    tar -xzC /usr/local/src/mailroom -f mailroom.tar.gz; \
    \
    # move all packaged files. need static files for documentation.
    mv /usr/local/src/mailroom/mailroom /usr/local/bin/; \
    mv /usr/local/src/mailroom/docs /; \ 
    rm -rf /usr/local/src/mailroom mailroom.tar.gz; \
    \
    apt-get purge -y --auto-remove wget

EXPOSE 8090

RUN mkdir -p /var/log/mailroom
# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/mailroom/mailroom.log \
    && ln -sf /dev/stderr /var/log/mailroom/mailroom.error
USER mailroom

ENTRYPOINT []
CMD ["mailroom"]
