FROM postgres:16 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    libssl-dev \
    pkg-config \
    postgresql-server-dev-16 \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN cd /tmp && \
    git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && \
    make install

RUN cd /tmp && \
    git clone --branch 0.8.0 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    cargo install --locked cargo-pgrx --version 0.12.9 && \
    cargo pgrx init --pg16 /usr/bin/pg_config && \
    cargo pgrx install --release

FROM postgres:16

COPY --from=builder /usr/share/postgresql/16/extension/vector--*.sql /usr/share/postgresql/16/extension/
COPY --from=builder /usr/share/postgresql/16/extension/vector.control /usr/share/postgresql/16/extension/
COPY --from=builder /usr/lib/postgresql/16/lib/vector.so /usr/lib/postgresql/16/lib/

COPY --from=builder /usr/share/postgresql/16/extension/vectorscale--*.sql /usr/share/postgresql/16/extension/
COPY --from=builder /usr/share/postgresql/16/extension/vectorscale.control /usr/share/postgresql/16/extension/
COPY --from=builder /usr/lib/postgresql/16/lib/vectorscale*.so /usr/lib/postgresql/16/lib/

COPY init-extensions.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
