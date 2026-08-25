# pgvectorscale on Railway

[![CI](https://github.com/joeychilson/railway-pgvectorscale/actions/workflows/build-docker.yml/badge.svg)](https://github.com/joeychilson/railway-pgvectorscale/actions/workflows/build-docker.yml)
[![Release](https://img.shields.io/github/v/release/joeychilson/railway-pgvectorscale)](https://github.com/joeychilson/railway-pgvectorscale/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Railway template for running PostgreSQL 18 with
[pgvector](https://github.com/pgvector/pgvector) and
[pgvectorscale](https://github.com/timescale/pgvectorscale).

The image extends Railway's
[`postgres-ssl`](https://github.com/railwayapp-templates/postgres-ssl) image
with scalable vector search while preserving SSL, pgBackRest WAL archiving,
point-in-time recovery, and Railway's volume conventions.

## Deployment

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/postgresql-with-pgvectorscale?referralCode=NhCCIt&utm_medium=integration&utm_source=template&utm_campaign=generic)

The template creates both extensions automatically:

| Extension | Purpose |
|---|---|
| `vector` | Vector values, similarity search, and HNSW and IVFFlat indexes |
| `vectorscale` | StreamingDiskANN indexes and statistical binary quantization |

For a manual Railway deployment:

1. Use `ghcr.io/joeychilson/railway-pgvectorscale:<version>`.
2. Attach a volume at `/var/lib/postgresql/data`.
3. Configure the PostgreSQL variables below.
4. Add a TCP proxy on port `5432` only when external access is required.

The base image refuses to start on Railway without the volume to protect the
database from accidental data loss.

## Configuration

| Variable | Value | Purpose |
|---|---|---|
| `PGDATA` | `/var/lib/postgresql/data/pgdata` | PostgreSQL data directory |
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PASSWORD` | Secret | Required database password |
| `POSTGRES_DB` | `railway` | Default database |
| `DATABASE_URL` | Template-generated | Private Railway connection string |
| `POSTGRES_ENSURE_EXTENSIONS` | `on` | Set to `off` to disable automatic extension creation and updates |
| `SSL_CERT_DAYS` | `820` | Self-signed certificate validity |
| `WAL_ARCHIVE_*` | Optional | pgBackRest WAL archiving settings |
| `WAL_RECOVER_FROM_*` | Optional | pgBackRest recovery settings |

The template uses this private connection string:

```text
postgresql://${{POSTGRES_USER}}:${{POSTGRES_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:5432/${{POSTGRES_DB}}
```

## Example

Create and query a StreamingDiskANN index:

```sql
CREATE TABLE items (
    id BIGSERIAL PRIMARY KEY,
    embedding VECTOR(1536)
);

CREATE INDEX ON items USING diskann (embedding vector_cosine_ops);

SELECT id
FROM items
ORDER BY embedding <=> '[...]'
LIMIT 10;
```

## Updates

Images are published only from GitHub releases. Exact `X.Y.Z` and
`sha-<commit>` tags are immutable, while `X.Y` tracks the latest patch release
in that minor line. There is no `latest` tag. Use the `X.Y` channel with
Railway image auto-updates to receive reviewed patch releases.

On each boot, a background task creates missing extensions and runs
`ALTER EXTENSION ... UPDATE` when the image contains newer extension SQL. This
keeps existing databases aligned with the libraries shipped in the image.

PostgreSQL minor upgrades can use the existing volume. A PostgreSQL major
upgrade requires a dump and restore or logical replication; never switch an
existing volume directly between major versions.

A weekly workflow checks for new pgvectorscale releases and opens a pull
request. Each update is smoke-tested and reviewed before a GitHub release
publishes the image.

## Migrating from PostgreSQL 16

Older template deployments use
`ghcr.io/joeychilson/railway-pgvectorscale:sha-252c4c3`, which contains
PostgreSQL 16, pgvector 0.8.1, and pgvectorscale 0.8.0. That image remains
available but does not receive updates.

To migrate:

1. Deploy a new service from the current template.
2. Copy the database:

   ```text
   pg_dump -Fc "$OLD_DATABASE_URL" | \
     pg_restore -d "$NEW_DATABASE_URL" --no-owner
   ```

3. Update the application to use the new `DATABASE_URL`.
4. Remove the old service after verifying the migration.

## Development

```text
docker compose up -d --build
./test/smoke-test.sh $(docker compose images -q postgres)
```

The smoke test verifies SSL, both extensions, extension-version alignment,
StreamingDiskANN indexing and queries, and data persistence after a restart.

## License

[MIT](LICENSE)
