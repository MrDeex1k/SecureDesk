# PostgreSQL 18 Dockerfile
FROM postgres:18

# Set environment labels
LABEL maintainer="SecureDesk"
LABEL description="PostgreSQL 18 database for SecureDesk application"

# Install gettext for envsubst
RUN apt-get update && apt-get install -y gettext-base && rm -rf /var/lib/apt/lists/*

# Copy and process initialization scripts
COPY ./init-sql/ /tmp/init-sql/
RUN for file in /tmp/init-sql/*.sql; do \
        envsubst < "$file" > "/docker-entrypoint-initdb.d/$(basename "$file")"; \
    done

# Expose PostgreSQL port
EXPOSE 54328