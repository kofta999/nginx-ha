import { Hono } from "hono";
import { sign, verify } from "hono/jwt";

const app = new Hono();

const JWT_SECRET = process.env.JWT_SECRET || "change-me-in-production";
const JWT_ISSUER = "auth-service";
const JWT_AUDIENCE = "nginx-ha-clients";

app.get("/", (c) => {
  return c.json({
    service: "auth",
    ok: true,
    endpoints: {
      issue: "POST /token",
      verify: "POST /verify",
    },
  });
});

app.get("/health", (c) => c.json({ ok: true }));

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
    return c.json({ valid: false, error: "Token is required" }, 400);
  }

  try {
    const payload = await verify(token, JWT_SECRET, { alg: "HS256" });
    return c.json({ valid: true, payload });
  } catch (e) {
    console.log(e);
    return c.json({ valid: false, error: "Invalid or expired token" }, 401);
  }
});

export default {
  port: 3000,
  fetch: app.fetch,
};
