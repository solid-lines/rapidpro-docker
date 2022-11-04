FROM debian:bullseye-slim as builder

ENV PIP_RETRIES=120 \
    PIP_TIMEOUT=400 \
    PIP_DEFAULT_TIMEOUT=400 \
    C_FORCE_ROOT=1

RUN addgroup --system rapidpro; \
    adduser --system --ingroup rapidpro rapidpro


# Install `psql` for `manage.py dbshell`
# `magic` is needed since rapidpro v3.0.64
# `pcre` is needed for uwsgi
# `geos`, `gdal`, and `proj` are needed for `manage.py download_geojson` and `manage.py import_geojson`
# `npm` for static file generation
RUN apt update && apt install postgresql-client libmagic-dev libpcre3 libgeos-c1v5 libgdal28 libproj19 bzip2 npm wget tar git nano software-properties-common bash-completion python3-virtualenv python3-dev python3-distutils python3-apt vim net-tools iputils-ping procps -y

WORKDIR /

ARG RAPIDPRO_VERSION
ARG RAPIDPRO_REPO
ENV RAPIDPRO_VERSION=${RAPIDPRO_VERSION:-7.4.2}
ENV RAPIDPRO_REPO=${RAPIDPRO_REPO:-rapidpro/rapidpro}
RUN echo "Downloading RapidPro v${RAPIDPRO_VERSION} from https://github.com/rapidpro/rapidpro.git" && \
    git clone --depth 1 --branch v${RAPIDPRO_VERSION} https://github.com/rapidpro/rapidpro.git

WORKDIR /rapidpro

#RUN ln -s /rapidpro/temba/settings.py.dev /rapidpro/temba/settings.py
RUN pip install -U pip && pip install -U poetry
RUN npm install -g coffeescript less && npm install

# Build Python virtualenv
RUN virtualenv -p python3 /rapidpro/env
ENV PATH="/rapidpro/env/bin:$PATH"
ENV VIRTUAL_ENV="/rapidpro/env"

# Install configuration related dependencies
RUN pip install getenv django uwsgi
RUN pip install poetry 
RUN poetry install

ENV UWSGI_VIRTUALENV=/rapidpro/env UWSGI_WSGI_FILE=temba/wsgi.py UWSGI_HTTP=:8000 UWSGI_MASTER=1 UWSGI_WORKERS=8 UWSGI_HARAKIRI=20
# Enable HTTP 1.1 Keep Alive options for uWSGI (http-auto-chunked needed when ConditionalGetMiddleware not installed)
# These options don't appear to be configurable via environment variables, so pass them in here instead
ENV STARTUP_CMD="/rapidpro/env/bin/uwsgi --http-auto-chunked --http-keepalive --logto /var/log/rapidpro/rapidpro.log"

COPY settings.py /rapidpro/temba/
COPY settings_common.py /rapidpro/temba/
# 500.html needed to keep the missing template from causing an exception during error handling
COPY stack/500.html /rapidpro/templates/
COPY stack/init_db.sql /rapidpro/
COPY stack/clear-compressor-cache.py /rapidpro/

EXPOSE 8000
COPY stack/startup.sh /

LABEL org.label-schema.name="RapidPro" \
      org.label-schema.description="RapidPro allows organizations to visually build scalable interactive messaging applications." \
      org.label-schema.url="https://www.rapidpro.io/" \
      org.label-schema.vcs-url="https://github.com/$RAPIDPRO_REPO" \
      org.label-schema.vendor="Nyaruka, UNICEF, and individual contributors." \
      org.label-schema.version=$RAPIDPRO_VERSION \
      org.label-schema.schema-version="1.0"


# forward request and error logs to docker log collector
RUN mkdir -p /var/log/rapidpro
RUN ln -sf /dev/stdout /var/log/rapidpro/rapidpro.log \
    && ln -sf /dev/stderr /var/log/rapidpro/rapidpro.error

#RUN chown -R rapidpro:rapidpro /rapidpro
#USER rapidpro
CMD ["/startup.sh"]

