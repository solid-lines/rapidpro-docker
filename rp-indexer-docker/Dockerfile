FROM debian:bullseye-slim

ARG RPINDEXER_REPO
ENV RPINDEXER_REPO=${RPINDEXER_REPO:-nyaruka/rp-indexer}
ARG RPINDEXER_VERSION
ENV RPINDEXER_VERSION=${RPINDEXER_VERSION:-7.4.0}

RUN set -ex; \
    addgroup --system rp_indexer; \
    adduser --system --ingroup rp_indexer rp_indexer

# Install ca-certificates so HTTPS works in general
RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates && \
  rm -rf /var/lib/apt/lists/*

RUN set -ex; \
  apt-get update; \
  apt-get install -y --no-install-recommends wget; \
  rm -rf /var/lib/apt/lists/*; \
  \
  wget -O rp-indexer.tar.gz "https://github.com/${RPINDEXER_REPO}/releases/download/v${RPINDEXER_VERSION}/rp-indexer_${RPINDEXER_VERSION}_linux_amd64.tar.gz"; \
  mkdir /usr/local/src/rp-indexer; \
  tar -xzC /usr/local/src/rp-indexer -f rp-indexer.tar.gz; \
  \
# Just grab the binary and ignore the other packaged files
  mv /usr/local/src/rp-indexer/rp-indexer /usr/local/bin/; \
  rm -rf /usr/local/src/rp-indexer rp-indexer.tar.gz; \
  \
  apt-get purge -y --auto-remove wget

EXPOSE 8080

RUN mkdir -p /var/log/rp-indexer
RUN chown -R rp_indexer:rp_indexer /var/log/rp-indexer
# forward request and error logs to docker log collector
#RUN ln -sf /dev/stdout /var/log/rp-indexer/rp-indexer.log \
#    && ln -sf /dev/stderr /var/log/rp-indexer/rp-indexer.error

USER rp_indexer
ENTRYPOINT []

ARG RPINDEXER_LOG_LEVEL
ENV RPINDEXER_LOG_LEVEL ${RPINDEXER_LOG_LEVEL:-warning}

CMD rp-indexer --debug-conf -log-level $RPINDEXER_LOG_LEVEL > /var/log/rp-indexer/rp-indexer.log
