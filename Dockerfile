# syntax=docker/dockerfile:1

# PostgreSQL 18 with pgvector + pgvectorscale, built for Railway.
#
# Base: Railway's official postgres-ssl image (self-signed SSL, pgBackRest
# WAL archiving / PITR, volume-mount guards, stale-pid cleanup).
#
# Version pins — bump these to upgrade:
ARG PG_MAJOR=18
ARG BASE_IMAGE=ghcr.io/railwayapp-templates/postgres-ssl:18
ARG PGVECTORSCALE_VERSION=0.9.0

# -----------------------------------------------------------------------------
# Fetcher: pgvectorscale ships prebuilt .debs on its GitHub releases
# (Rust/pgrx — building from source is slow and needs a full toolchain).
# -----------------------------------------------------------------------------
FROM postgres:${PG_MAJOR} AS fetcher
ARG PG_MAJOR
ARG PGVECTORSCALE_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      unzip \
    && rm -rf /var/lib/apt/lists/*

RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL -o /tmp/vectorscale.zip \
       "https://github.com/timescale/pgvectorscale/releases/download/${PGVECTORSCALE_VERSION}/pgvectorscale-${PGVECTORSCALE_VERSION}-pg${PG_MAJOR}-${arch}.zip" \
    && mkdir -p /debs \
    && unzip /tmp/vectorscale.zip -d /debs \
    && ls /debs/*.deb

# -----------------------------------------------------------------------------
# Final image
# -----------------------------------------------------------------------------
FROM ${BASE_IMAGE}
ARG PG_MAJOR

COPY --from=fetcher /debs/ /tmp/debs/

# pgvector from PGDG (already configured in the official postgres base image),
# pgvectorscale from the fetched release .deb.
RUN apt-get update && apt-get install -y --no-install-recommends \
      postgresql-${PG_MAJOR}-pgvector \
      /tmp/debs/*.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/debs

# Build-time sanity check: both extensions must be installable.
RUN set -eux; \
    for ext in vector vectorscale; do \
      test -f "/usr/share/postgresql/${PG_MAJOR}/extension/${ext}.control"; \
    done; \
    ls "/usr/lib/postgresql/${PG_MAJOR}/lib/" | grep -q vectorscale

COPY --chmod=755 ensure-extensions.sh /usr/local/bin/ensure-extensions.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/pgvectorscale-entrypoint.sh
COPY init-extensions.sql /docker-entrypoint-initdb.d/

ENTRYPOINT ["pgvectorscale-entrypoint.sh"]
# Redeclared because setting ENTRYPOINT resets any inherited CMD. Port is
# pinned to 5432 (Railway's TCP proxy expects it), matching the base image.
CMD ["postgres", "-p", "5432", "-c", "listen_addresses=*"]
