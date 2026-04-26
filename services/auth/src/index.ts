import { Hono } from "hono";
import { sign, verify } from "hono/jwt";
import {
  Counter,
  Histogram,
  Registry,
  collectDefaultMetrics,
} from "prom-client";

const app = new Hono();

const JWT_SECRET = process.env.JWT_SECRET || "change-me-in-production";
const JWT_ISSUER = "auth-service";
const JWT_AUDIENCE = "nginx-ha-clients";

// Prometheus registry + default process metrics
const register = new Registry();
collectDefaultMetrics({ register });

// HTTP metrics
const httpRequestsTotal = new Counter({
  name: "auth_http_requests_total",
  help: "Total number of HTTP requests for auth service",
  labelNames: ["method", "route", "status_code"] as const,
  registers: [register],
});

const httpRequestDurationSeconds = new Histogram({
  name: "auth_http_request_duration_seconds",
  help: "HTTP request duration in seconds for auth service",
  labelNames: ["method", "route", "status_code"] as const,
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5],
  registers: [register],
});

// Auth-specific metrics
const tokensIssuedTotal = new Counter({
  name: "auth_tokens_issued_total",
  help: "Total number of JWT tokens issued",
  registers: [register],
});

const tokenVerifyTotal = new Counter({
  name: "auth_token_verify_total",
  help: "Total number of JWT verification attempts",
  labelNames: ["result"] as const, // success | failure
  registers: [register],
});

// Middleware for HTTP metrics
app.use("*", async (c, next) => {
  const start = performance.now();
  await next();

  const durationSeconds = (performance.now() - start) / 1000;
  const route = c.req.path; // simple/low-complexity label
  const method = c.req.method;
  const status = String(c.res.status);

  httpRequestsTotal.inc({ method, route, status_code: status });
  httpRequestDurationSeconds.observe(
    { method, route, status_code: status },
    durationSeconds,
  );
});

app.get("/info", (c) => {
  return c.json({
    service: "auth",
    ok: true,
    endpoints: {
      issue: "POST /token",
      verify: "POST /verify",
      metrics: "GET /metrics",
    },
  });
});

app.get("/health", (c) => c.json({ ok: true }));

app.get("/metrics", async (c) => {
  c.header("Content-Type", register.contentType);
  return c.text(await register.metrics());
});

app.post("/token", async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const sub = body?.sub || "anonymous";
  const role = body?.role || "user";
  const expiresIn = Number(body?.expiresIn ?? 60 * 60); // default 1h

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub,
    role,
    iss: JWT_ISSUER,
    aud: JWT_AUDIENCE,
    iat: now,
    exp: now + expiresIn,
  };

  const token = await sign(payload, JWT_SECRET);
  tokensIssuedTotal.inc();

  return c.json({
    token,
    tokenType: "Bearer",
    expiresIn,
    payload,
  });
});

app.post("/verify", async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const authHeader = c.req.header("authorization");
  const bearer = authHeader?.startsWith("Bearer ")
    ? authHeader.slice(7)
    : undefined;
  const token = body?.token || bearer;

  if (!token) {
    tokenVerifyTotal.inc({ result: "failure" });
    return c.json({ valid: false, error: "Token is required" }, 400);
  }

  try {
    const payload = await verify(token, JWT_SECRET, { alg: "HS256" });
    tokenVerifyTotal.inc({ result: "success" });
    return c.json({ valid: true, payload });
  } catch (_e) {
    tokenVerifyTotal.inc({ result: "failure" });
    return c.json({ valid: false, error: "Invalid or expired token" }, 401);
  }
});

export default {
  port: 3000,
  fetch: app.fetch,
};
