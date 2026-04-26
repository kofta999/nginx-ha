import { Hono } from "hono";
import { upgradeWebSocket, websocket } from "hono/bun";
import {
  Registry,
  collectDefaultMetrics,
  Counter,
  Histogram,
} from "prom-client";

type Product = {
  id: string;
  name: string;
  price: number;
  currency: "USD";
};

const app = new Hono();

/**
 * Prometheus metrics setup
 */
const register = new Registry();
collectDefaultMetrics({ register, prefix: "products_" });

const httpRequestsTotal = new Counter({
  name: "products_http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status"] as const,
  registers: [register],
});

const httpRequestDurationSeconds = new Histogram({
  name: "products_http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status"] as const,
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5],
  registers: [register],
});

const productsCreatedTotal = new Counter({
  name: "products_created_total",
  help: "Total products created",
  registers: [register],
});

const wsConnectionsTotal = new Counter({
  name: "products_ws_connections_total",
  help: "Total WebSocket connections opened",
  registers: [register],
});

const wsPriceUpdatesTotal = new Counter({
  name: "products_ws_price_updates_total",
  help: "Total fake price updates sent over WebSocket",
  registers: [register],
});

// Global HTTP metrics middleware (simple and reliable)
app.use("*", async (c, next) => {
  const start = performance.now();
  await next();

  const durationSeconds = (performance.now() - start) / 1000;
  const route = c.req.path;
  const method = c.req.method;
  const status = String(c.res.status);

  httpRequestsTotal.inc({ method, route, status });
  httpRequestDurationSeconds.observe(
    { method, route, status },
    durationSeconds,
  );
});

const products: Product[] = [
  { id: "p1", name: "Keyboard", price: 49.99, currency: "USD" },
  { id: "p2", name: "Mouse", price: 24.99, currency: "USD" },
  { id: "p3", name: "Monitor", price: 199.99, currency: "USD" },
];

const findProduct = (id: string) => products.find((p) => p.id === id);

const randomPrice = (base: number) => {
  const delta = (Math.random() - 0.5) * 4;
  const next = Math.max(1, base + delta);
  return Number(next.toFixed(2));
};

app.get("/info", (c) => {
  return c.json({
    service: "products",
    ok: true,
    endpoints: {
      health: "GET /health",
      metrics: "GET /metrics",
      list: "GET /",
      getOne: "GET /:id",
      create: "POST /",
      updatesWs: "GET /ws/prices",
    },
  });
});

app.get("/health", (c) => c.json({ ok: true }));

app.get("/metrics", async (c) => {
  c.header("Content-Type", register.contentType);
  return c.text(await register.metrics());
});

// REST: list
app.get("/", (c) => c.json(products));

// REST: get by id
app.get("/:id", (c) => {
  const product = findProduct(c.req.param("id"));
  if (!product) return c.json({ error: "Product not found" }, 404);
  return c.json(product);
});

// REST: create
app.post("/", async (c) => {
  const body = await c.req.json().catch(() => null);
  if (!body?.name || typeof body?.price !== "number") {
    return c.json(
      { error: "name (string) and price (number) are required" },
      400,
    );
  }

  const product: Product = {
    id: `p${products.length + 1}`,
    name: String(body.name),
    price: Number(body.price),
    currency: "USD",
  };

  products.push(product);
  productsCreatedTotal.inc();

  return c.json(product, 201);
});

// WS: stream fake price updates every 3s
app.get(
  "/ws/prices",
  upgradeWebSocket(() => {
    let timer: ReturnType<typeof setInterval> | null = null;

    return {
      onOpen(_event, ws) {
        wsConnectionsTotal.inc();
        ws.send(
          JSON.stringify({
            type: "welcome",
            message: "Connected to price stream",
          }),
        );

        timer = setInterval(() => {
          const picked = products[Math.floor(Math.random() * products.length)];
          if (!picked) return;

          const updated = {
            ...picked,
            price: randomPrice(picked.price),
            ts: new Date().toISOString(),
          };

          wsPriceUpdatesTotal.inc();
          ws.send(
            JSON.stringify({
              type: "price_update",
              data: updated,
            }),
          );
        }, 3000);
      },

      onClose() {
        if (timer) clearInterval(timer);
      },
    };
  }),
);

export default {
  port: 4000,
  fetch: app.fetch,
  websocket,
};
