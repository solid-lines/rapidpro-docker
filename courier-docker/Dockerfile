FROM debian:bullseye-slim as build

ARG COURIER_REPO
ENV COURIER_REPO=${COURIER_REPO:-nyaruka/courier}
ARG COURIER_VERSION
ENV COURIER_VERSION=${COURIER_VERSION:-7.4.0}

RUN apt update && apt install -y wget
RUN echo "wget -q -O courier.tar.gz https://github.com/$COURIER_REPO/releases/download/v${COURIER_VERSION}/courier_${COURIER_VERSION}_linux_amd64.tar.gz"
RUN wget -q -O courier.tar.gz "https://github.com/$COURIER_REPO/releases/download/v${COURIER_VERSION}/courier_${COURIER_VERSION}_linux_amd64.tar.gz"
RUN mkdir courier
RUN tar -xzC courier -f courier.tar.gz


FROM debian:bullseye-slim

RUN set -ex; \
    addgroup --system courier; \
    adduser --system --ingroup courier courier

# Install ca-certificates so HTTPS works in general
RUN apt-get update && \
  apt-get install -y --no-install-recommends vim nano net-tools iputils-ping procps ca-certificates && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build courier/courier /usr/local/bin

EXPOSE 8080

RUN mkdir _storage && chown courier _storage
RUN mkdir /var/spool/courier && chown courier /var/spool/courier

RUN mkdir -p /var/log/courier
# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/courier/courier.log \
    && ln -sf /dev/stderr /var/log/courier/courier.error

USER courier

ENTRYPOINT []
CMD ["courier"]
