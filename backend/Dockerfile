FROM oven/bun:1 AS base

WORKDIR /app

# Instalacja zależności (korzysta z bun.lockb)
COPY bun.lockb package.json ./
RUN bun install --ci

# Kopiowanie źródeł
COPY . .

EXPOSE 3333

CMD ["bun", "run", "start"]
