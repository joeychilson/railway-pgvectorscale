# Deploy and Host PostgreSQL with pgvectorscale with Railway

PostgreSQL 18 with pgvector and pgvectorscale for vector search. pgvector adds
vector types and HNSW and IVFFlat indexes; pgvectorscale adds StreamingDiskANN
indexes and statistical binary quantization for larger embedding tables. Both
extensions are created for you in the default database.

## About Hosting PostgreSQL with pgvectorscale

The template runs one PostgreSQL service from a tested image for amd64 and
arm64, with a volume at `/var/lib/postgresql/data` and a generated password.
The image builds on Railway's own `postgres-ssl` image, so it keeps SSL,
pgBackRest WAL archiving, point-in-time recovery, and Railway's volume checks.
On every boot it creates missing extensions and updates their SQL to match the
image, so an image update never leaves a database on an old extension version.
Patch releases install automatically during Railway's nightly update window.

## Common Use Cases

- Retrieval-augmented generation (RAG) over your own documents
- Semantic search and recommendations
- Storing embeddings next to the relational data they describe
- Vector search over tables too large for an in-memory index

## Dependencies for PostgreSQL with pgvectorscale Hosting

- None. Applications connect with `DATABASE_URL`.

### Deployment Dependencies

- [pgvector](https://github.com/pgvector/pgvector)
- [pgvectorscale](https://github.com/timescale/pgvectorscale)
- [Template source and full README](https://github.com/joeychilson/railway-pgvectorscale)

### Implementation Details

Connect other services with the `DATABASE_URL` reference variable. It uses
private networking, and `DATABASE_PUBLIC_URL` goes through the TCP proxy.

```sql
CREATE TABLE items (
    id BIGSERIAL PRIMARY KEY,
    embedding VECTOR(1536)
);

CREATE INDEX ON items USING diskann (embedding vector_cosine_ops);

SELECT id FROM items ORDER BY embedding <=> '[...]' LIMIT 10;
```

### Why Deploy PostgreSQL with pgvectorscale on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will
host your infrastructure so you don't have to deal with configuration, while
allowing you to vertically and horizontally scale it.

By deploying PostgreSQL with pgvectorscale on Railway, you are one step closer
to supporting a complete full-stack application with minimal burden. Host your
servers, databases, AI agents, and more on Railway.
