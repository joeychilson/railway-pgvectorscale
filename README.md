# railway-pgvectorscale

**PostgreSQL 18 with [pgvector](https://github.com/pgvector/pgvector) and
[pgvectorscale](https://github.com/timescale/pgvectorscale)**, built for
[Railway](https://railway.com). It extends Railway's official
[`postgres-ssl`](https://github.com/railwayapp-templates/postgres-ssl) image,
so you keep self-signed SSL, pgBackRest WAL archiving / point-in-time
recovery, and Railway's volume conventions — and adds vector search that
scales past what plain HNSW can hold in memory.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/postgresql-with-pgvectorscale?referralCode=NhCCIt&utm_medium=integration&utm_source=template&utm_campaign=generic)

## What's inside

| Extension | What it gives you |
|---|---|
| `vector` (pgvector, from PGDG) | Vector similarity search: `vector` type, HNSW + IVFFlat indexes |
| `vectorscale` (pgvectorscale, prebuilt release package) | StreamingDiskANN index + statistical binary quantization — pgvector at bigger scale, lower memory |

Both extensions are created automatically in your database on first boot, and
an on-boot updater keeps their SQL in sync with the version shipped in the
image (see below).

```sql
CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(1536));
CREATE INDEX ON items USING diskann (embedding vector_cosine_ops);
SELECT id FROM items ORDER BY embedding <=> '[...]' LIMIT 10;
```

## How updates are delivered (and why nothing breaks)

- Images are published **only** from GitHub releases, under **immutable
  version tags** (`X.Y.Z`, `X.Y`, `sha-<commit>`). There is no `latest` tag;
  a tag you deploy is never mutated underneath you.
- On every boot, a background task creates the default extensions if missing
  and runs `ALTER EXTENSION ... UPDATE` to bring installed extensions up to
  the version the image ships. pgvectorscale's shared library is
  version-named, so this step is what makes image upgrades safe for existing
  databases. Disable with `POSTGRES_ENSURE_EXTENSIONS=off`.
- Postgres **minor** upgrades ride along with new image releases and are safe
  for your data volume. **Major** upgrades (e.g. 16 → 18) require a
  dump/restore or logical replication, as with any Postgres — never just
  switch the image tag across a major version.
- Railway's [image auto-updates](https://docs.railway.com/deployments/image-auto-updates)
  work with the semver tags: enable them on your service to be offered
  patch/minor bumps during a maintenance window you choose.

## Deploying manually (outside the template)

1. Create a service from the image
   `ghcr.io/joeychilson/railway-pgvectorscale:<version>`.
2. **Attach a volume at `/var/lib/postgresql/data`** (the base image refuses
   to boot on Railway without it — this protects your data).
3. Set variables:

   | Variable | Value |
   |---|---|
   | `PGDATA` | `/var/lib/postgresql/data/pgdata` |
   | `POSTGRES_USER` | `postgres` |
   | `POSTGRES_PASSWORD` | a strong secret |
   | `POSTGRES_DB` | `railway` |
   | `DATABASE_URL` | `postgresql://${{POSTGRES_USER}}:${{POSTGRES_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:5432/${{POSTGRES_DB}}` |

4. Add a TCP proxy on port `5432` if you want external access.

## Migrating from the PostgreSQL 16 image

Deployments created from this template before the PostgreSQL 18 update run
`ghcr.io/joeychilson/railway-pgvectorscale:sha-252c4c3` (PostgreSQL 16,
pgvector 0.8.1, pgvectorscale 0.8.0). That image keeps working and will not
change — but it also won't receive updates. To move to 18:

1. Deploy a new service from the current template.
2. Copy the data: `pg_dump -Fc "$OLD_DATABASE_URL" | pg_restore -d "$NEW_DATABASE_URL" --no-owner`
3. Point your app at the new `DATABASE_URL`, then delete the old service.

## Local development

```bash
docker compose up -d --build
./test/smoke-test.sh $(docker compose images -q postgres)
```

The smoke test boots the image, verifies SSL and both extensions, builds a
`diskann` index, queries it, and restarts the container to prove data
survives. CI runs it before any image is published.

## Environment variables (image-specific)

| Variable | Default | Purpose |
|---|---|---|
| `POSTGRES_ENSURE_EXTENSIONS` | `on` | `off` disables the boot-time extension create/update task |
| `SSL_CERT_DAYS` | `820` | Self-signed cert validity (base image) |
| `WAL_ARCHIVE_*` / `WAL_RECOVER_FROM_*` | – | pgBackRest WAL archiving & PITR (base image; see its README) |

## Documentation

- [pgvectorscale Docs](https://github.com/timescale/pgvectorscale)
- [pgvector Docs](https://github.com/pgvector/pgvector)
- [Railway Docs](https://docs.railway.com/)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Please open an issue or submit a PR.
