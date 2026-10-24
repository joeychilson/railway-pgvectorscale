# PostgreSQL with pgvector and pgvectorscale, built on Railway's postgres-ssl
# image: self-signed SSL, pgBackRest WAL archiving and point-in-time recovery,
# and Railway's volume checks.

# renovate: datasource=docker packageName=ghcr.io/railwayapp-templates/postgres-ssl depName=PostgreSQL
ARG POSTGRES_VERSION=18.6@sha256:4fc833b43d2aaf6ecc9b18615f5533602b723a32d0e2efe2dae8ca0f7217c863
# renovate: datasource=github-tags packageName=pgvector/pgvector depName=pgvector extractVersion=^v(?<version>.+)$
ARG PGVECTOR_VERSION=0.8.7
# renovate: datasource=github-releases packageName=timescale/pgvectorscale depName=pgvectorscale
ARG PGVECTORSCALE_VERSION=0.9.1

# Build against the same PostgreSQL the final image runs. PG_MAJOR comes from
# the base image.
FROM ghcr.io/railwayapp-templates/postgres-ssl:${POSTGRES_VERSION} AS builder
ARG PGVECTOR_VERSION
ARG PGVECTORSCALE_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      "postgresql-server-dev-${PG_MAJOR}" \
      unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# OPTFLAGS="" builds for any CPU instead of the build machine's.
RUN curl -fsSL "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" | tar xz \
    && make -C "pgvector-${PGVECTOR_VERSION}" OPTFLAGS="" -j"$(nproc)" \
    && make -C "pgvector-${PGVECTOR_VERSION}" OPTFLAGS="" install DESTDIR=/out

RUN curl -fsSL -o vectorscale.zip \
      "https://github.com/timescale/pgvectorscale/releases/download/${PGVECTORSCALE_VERSION}/pgvectorscale-${PGVECTORSCALE_VERSION}-pg${PG_MAJOR}-$(dpkg --print-architecture).zip" \
    && unzip -q vectorscale.zip -d vectorscale \
    && mv vectorscale/pgvectorscale-postgresql-"${PG_MAJOR}"_*.deb pgvectorscale.deb

FROM ghcr.io/railwayapp-templates/postgres-ssl:${POSTGRES_VERSION}
ARG PGVECTOR_VERSION

# The base image ships pgvector from apt. Replace it with the pinned build.
RUN dpkg --purge "postgresql-${PG_MAJOR}-pgvector"
COPY --from=builder /out/ /
COPY --from=builder /build/pgvectorscale.deb /tmp/
RUN dpkg -i /tmp/pgvectorscale.deb && rm /tmp/pgvectorscale.deb

RUN set -eux; \
    extensions="/usr/share/postgresql/${PG_MAJOR}/extension"; \
    grep -qx "default_version = '${PGVECTOR_VERSION}'" "$extensions/vector.control"; \
    test -f "$extensions/vectorscale.control"

COPY --chmod=755 ensure-extensions.sh /usr/local/bin/ensure-extensions.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/pgvectorscale-entrypoint.sh
COPY init-extensions.sql /docker-entrypoint-initdb.d/

# tini stays PID 1, as in the base image, so Postgres receives SIGTERM and
# shuts down cleanly on a redeploy.
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "pgvectorscale-entrypoint.sh"]
# Setting ENTRYPOINT resets the inherited CMD. Railway's TCP proxy expects
# port 5432.
CMD ["postgres", "-p", "5432", "-c", "listen_addresses=*"]
