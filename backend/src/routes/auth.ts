import { Hono } from "hono";
import { z } from "zod";
import { D1Service } from "../services/d1.service";
import { WakitService } from "../services/wakit.service";
import { JWTService } from "../services/jwt.service";

type Variables = {
  userId: string;
};

const app = new Hono<{ Variables: Variables }>();

const d1 = new D1Service(
  process.env.D1_ACCOUNT_ID ?? "",
  process.env.D1_DATABASE_ID ?? "",
  process.env.D1_API_TOKEN ?? ""
);

const wakit = new WakitService(
  process.env.WAKIT_API_KEY ?? "",
  process.env.WAKIT_BASE_URL ?? "https://api.wakit.in"
);

const jwtService = new JWTService(
  process.env.JWT_ACCESS_SECRET ?? "",
  process.env.JWT_REFRESH_SECRET ?? "",
  process.env.JWT_ACCESS_EXPIRY ?? "15m",
  process.env.JWT_REFRESH_EXPIRY ?? "30d",
  d1
);

const authMiddleware = async (c: any, next: any) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return c.json({ error: "Missing or invalid Authorization header" }, 401);
  }

  const token = authHeader.slice("Bearer ".length);
  try {
    const payload = jwtService.verifyAccessToken(token);
    c.set("userId", payload.sub);
    await next();
  } catch {
    return c.json({ error: "Invalid or expired token" }, 401);
  }
};

const requestOtpSchema = z.object({
  phoneNumber: z.string().min(1),
});

const verifyOtpSchema = z.object({
  requestId: z.string().min(1),
  otp: z.string().min(1).max(10),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

function toPublicUser(row: Record<string, unknown>) {
  let interests: string[] = [];
  try {
    interests = typeof row.interests === "string" ? JSON.parse(String(row.interests)) : (row.interests ?? []);
  } catch {
    interests = [];
  }
  return {
    id: row.id,
    phoneNumber: row.phone_number,
    name: row.name,
    handle: row.handle,
    city: row.city,
    zone: row.zone,
    interests,
    avatarUrl: row.avatar_url,
    createdAt: row.created_at,
  };
}

app.post("/request-otp", async (c) => {
  const body = await c.req.json();
  const result = requestOtpSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { phoneNumber } = result.data;
  const requestId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  let wakitRequestId: string;
  try {
    wakitRequestId = await wakit.requestOtp(phoneNumber);
  } catch {
    return c.json({ error: "Failed to request OTP" }, 502);
  }

  await d1.run(
    `INSERT INTO otp_requests (id, phone_number, request_id, expires_at, created_at, verified)
     VALUES (?, ?, ?, ?, datetime('now'), 0)`,
    [requestId, phoneNumber, wakitRequestId, expiresAt]
  );

  return c.json({ requestId, expiresAt }, 201);
});

app.post("/verify-otp", async (c) => {
  const body = await c.req.json();
  const result = verifyOtpSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { requestId, otp } = result.data;

  const row = await d1
    .prepare(
      `SELECT id, phone_number, request_id, verified FROM otp_requests WHERE id = ? AND expires_at > datetime('now') AND verified = 0 LIMIT 1`
    )
    .bind(requestId)
    .first();

  if (!row) {
    return c.json({ error: "Invalid or expired OTP request" }, 400);
  }

  const otpRequest = row as Record<string, unknown>;
  const wakitRequestId = String(otpRequest.request_id);
  const phoneNumber = String(otpRequest.phone_number);

  let verified: boolean;
  try {
    verified = await wakit.verifyOtp(wakitRequestId, otp);
  } catch {
    return c.json({ error: "Failed to verify OTP" }, 502);
  }

  if (!verified) {
    return c.json({ error: "Invalid OTP" }, 400);
  }

  await d1.run(`UPDATE otp_requests SET verified = 1 WHERE id = ?`, [requestId]);

  let userRow = await d1
    .prepare(
      `SELECT id, phone_number, name, handle, city, zone, interests, avatar_url, created_at FROM users WHERE phone_number = ?`
    )
    .bind(phoneNumber)
    .first();

  if (!userRow) {
    const userId = crypto.randomUUID();
    await d1.run(
      `INSERT INTO users (id, phone_number, name, created_at) VALUES (?, ?, ?, datetime('now'))`,
      [userId, phoneNumber, phoneNumber]
    );
    userRow = {
      id: userId,
      phone_number: phoneNumber,
      name: phoneNumber,
      handle: null,
      city: null,
      zone: null,
      interests: null,
      avatar_url: null,
      created_at: new Date().toISOString(),
    };
  }

  const userId = String((userRow as Record<string, unknown>).id);
  const accessToken = jwtService.signAccessToken({ sub: userId, phoneNumber });
  const refreshToken = jwtService.signRefreshToken({ sub: userId, phoneNumber });

  const accessExpiresIn = parseInt(process.env.JWT_ACCESS_EXPIRY_SECONDS ?? "900", 10);
  await jwtService.createSession(userId, accessToken, refreshToken, accessExpiresIn);

  return c.json({
    accessToken,
    refreshToken,
    user: toPublicUser(userRow as Record<string, unknown>),
  });
});

app.post("/refresh", async (c) => {
  const body = await c.req.json();
  const result = refreshSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { refreshToken } = result.data;

  let refreshed: { accessToken: string; userId: string };
  try {
    refreshed = await jwtService.refreshAccessToken(refreshToken);
  } catch {
    return c.json({ error: "Invalid or expired refresh token" }, 401);
  }

  return c.json({ accessToken: refreshed.accessToken });
});

app.post("/logout", authMiddleware, async (c) => {
  const userId = c.get("userId");
  await jwtService.revokeSession(userId);
  return c.json({ success: true });
});

app.get("/me", authMiddleware, async (c) => {
  const userId = c.get("userId");

  const row = await d1
    .prepare(
      `SELECT id, phone_number, name, handle, city, zone, interests, avatar_url, created_at FROM users WHERE id = ?`
    )
    .bind(userId)
    .first();

  if (!row) {
    return c.json({ error: "User not found" }, 404);
  }

  return c.json({ user: toPublicUser(row as Record<string, unknown>) });
});

app.all("*", (c) => {
  return c.json({ error: "Not implemented" }, 404);
});

export default app;
