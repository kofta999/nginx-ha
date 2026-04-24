FROM oven/bun:1.3 AS builder
WORKDIR /app

COPY package.json bun.lock ./

RUN bun install

COPY . .

RUN bun run build

FROM oven/bun:1.3-alpine
WORKDIR /app

COPY --from=builder /app/dist/index.js .

CMD ["bun", "run", "index.js"]
