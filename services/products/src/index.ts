import { Hono } from "hono";
import { upgradeWebSocket, websocket } from "hono/bun";

type Product = {
  id: string;
  name: string;
  price: number;
  currency: "USD";
};

const app = new Hono();

const products: Product[] = [
  { id: "p1", name: "Keyboard", price: 49.99, currency: "USD" },
  { id: "p2", name: "Mouse", price: 24.99, currency: "USD" },
  { id: "p3", name: "Monitor", price: 199.99, currency: "USD" },
];

const findProduct = (id: string) => products.find((p) => p.id === id);

const randomPrice = (base: number) => {
  const delta = (Math.random() - 0.5) * 4; // -2..+2
  const next = Math.max(1, base + delta);
  return Number(next.toFixed(2));
};

app.get("/", (c) => {
  return c.json({
    service: "products",
    ok: true,
    endpoints: {
      list: "GET /products",
      getOne: "GET /products/:id",
      create: "POST /products",
      updatesWs: "GET /ws/prices",
    },
  });
});

app.get("/health", (c) => c.json({ ok: true }));

// REST: list
app.get("/products", (c) => c.json(products));

// REST: get by id
app.get("/products/:id", (c) => {
  const product = findProduct(c.req.param("id"));
  if (!product) return c.json({ error: "Product not found" }, 404);
  return c.json(product);
});

// REST: create
app.post("/products", async (c) => {
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
  return c.json(product, 201);
});

// WS: stream fake price updates every 3s
app.get(
  "/ws/prices",
  upgradeWebSocket(() => {
    let timer: ReturnType<typeof setInterval> | null = null;

    return {
      onOpen(_event, ws) {
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
