# PostgreSQL with pgvectorscale on Railway

[![Release](https://img.shields.io/github/v/release/joeychilson/railway-pgvectorscale)](https://github.com/joeychilson/railway-pgvectorscale/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Railway template for PostgreSQL 18 with
[pgvector](https://github.com/pgvector/pgvector) and
[pgvectorscale](https://github.com/timescale/pgvectorscale). The image builds on
Railway's [`postgres-ssl`](https://github.com/railwayapp-templates/postgres-ssl)
image, so it keeps SSL, pgBackRest WAL archiving, point-in-time recovery, and
Railway's volume checks.

## Deploy

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/postgresql-with-pgvectorscale?referralCode=NhCCIt&utm_medium=integration&utm_source=template&utm_campaign=generic)

The template creates one `Postgres` service with:

- The `ghcr.io/joeychilson/railway-pgvectorscale` image for amd64 and arm64.
- A volume at `/var/lib/postgresql/data`.
- A generated `POSTGRES_PASSWORD`.
- `DATABASE_URL` for private networking and `DATABASE_PUBLIC_URL` through a TCP
  proxy on port `5432`.
- The `vector` and `vectorscale` extensions, created in the default database.

| Extension | Adds |
|---|---|
| `vector` | Vector types, similarity search, and HNSW and IVFFlat indexes |
| `vectorscale` | StreamingDiskANN indexes and statistical binary quantization |

To deploy the image without the template, use
`ghcr.io/joeychilson/railway-pgvectorscale:<version>`, attach a volume at
`/var/lib/postgresql/data`, and set the variables below. The base image refuses
to start on Railway without that volume, so a missing volume can't lose data.

## Usage

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

## Configuration

| Variable | Value | Purpose |
|---|---|---|
| `PGDATA` | `/var/lib/postgresql/data/pgdata` | Data directory |
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PASSWORD` | Generated | Database password |
| `POSTGRES_DB` | `railway` | Default database |
| `DATABASE_URL` | Generated | Connection string over private networking |
| `DATABASE_PUBLIC_URL` | Generated | Connection string through the TCP proxy |
| `POSTGRES_ENSURE_EXTENSIONS` | `on` | Set to `off` to stop creating and updating extensions on boot |
| `SSL_CERT_DAYS` | `820` | Lifetime of the self-signed certificate |
| `WAL_ARCHIVE_*`, `WAL_RECOVER_FROM_*` | Optional | pgBackRest archiving and recovery settings from `postgres-ssl` |

Other services in the project connect with:

```text
postgresql://${{POSTGRES_USER}}:${{POSTGRES_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:5432/${{POSTGRES_DB}}
```

## Updates

Each release is published as `ghcr.io/joeychilson/railway-pgvectorscale:X.Y.Z`
and moves the `X.Y` tag to it. The Railway template deploys `X.Y` with patch
auto-updates on, so a deployment that keeps that setting picks up patch releases
in Railway's nightly update window. A minor or major release starts a new `X.Y`
tag, and its release notes say what to change before you move to it.

On every boot, a background job creates missing extensions and runs
`ALTER EXTENSION ... UPDATE` when the image ships newer extension SQL, so
existing databases stay in step with the libraries in the image. PostgreSQL
minor versions upgrade in place. A PostgreSQL major upgrade needs a dump and
restore or logical replication; never point an existing volume at a new major
version.

[Renovate](https://docs.renovatebot.com) bumps PostgreSQL minor versions,
pgvector, and pgvectorscale. The bump merges after the smoke test passes on
amd64 and arm64, and the merge publishes a patch release. pgvectorscale minor
updates wait for review while it is on 0.x. The release policy for all of these
templates is in
[railway-templates](https://github.com/joeychilson/railway-templates#releases).

### Migrating from PostgreSQL 16

Early deployments of this template use
`ghcr.io/joeychilson/railway-pgvectorscale:sha-252c4c3`, which has PostgreSQL
16, pgvector 0.8.1, and pgvectorscale 0.8.0. That image stays available but
gets no updates. To move to PostgreSQL 18:

1. Deploy a new service from the current template.
2. Copy the database:

   ```text
   pg_dump -Fc "$OLD_DATABASE_URL" | pg_restore -d "$NEW_DATABASE_URL" --no-owner
   ```

3. Point the application at the new `DATABASE_URL`.
4. Remove the old service once the new one checks out.

## Development

```text
docker build -t railway-pgvectorscale:test .
./test/smoke-test.sh railway-pgvectorscale:test
```

The smoke test checks SSL, both extensions and their versions, a
StreamingDiskANN index and query, data after a restart, and a clean shutdown on
SIGTERM.

## License

[MIT](LICENSE)
