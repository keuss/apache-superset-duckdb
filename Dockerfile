FROM apache/superset:latest

USER root

# Installation des drivers pour que SQLAlchemy (Superset) parle à DuckDB
RUN apt-get update && apt-get install -y build-essential libpq-dev \
    && . /app/.venv/bin/activate \
    && uv pip install --no-cache-dir duckdb duckdb-engine psycopg2-binary \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER superset