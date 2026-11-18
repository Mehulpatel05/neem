import { Hono } from "hono";
import { z } from "zod";
import { D1Service } from "../services/d1.service";
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

const updateProfileSchema = z.object({
  displayName: z.string().min(1).max(100).optional(),
  handle: z.string().min(1).max(50).regex(/^[a-zA-Z0-9_]+$/).optional(),
  city: z.string().min(1).max(100).optional(),
  zone: z.string().min(1).max(100).optional(),
  interests: z.array(z.string().min(1).max(50)).max(5).optional(),
  avatarUrl: z.string().url().optional(),
});

const interestsSchema = z.object({
  interests: z.array(z.string().min(1).max(50)).max(5, "Maximum 5 interests allowed"),
});

const idParamSchema = z.object({
  id: z.string().min(1),
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
    displayName: row.name,
    handle: row.handle,
    city: row.city,
    zone: row.zone,
    interests,
    avatarUrl: row.avatar_url,
    createdAt: row.created_at,
  };
}

app.get("/me", authMiddleware, async (c) => {
  const userId = c.get("userId");

  const row = await d1
    .prepare(
      `SELECT id, name, handle, city, zone, interests, avatar_url, created_at FROM users WHERE id = ?`
    )
    .bind(userId)
    .first();

  if (!row) {
    return c.json({ error: "User not found" }, 404);
  }

  return c.json({ user: toPublicUser(row as Record<string, unknown>) });
});

app.put("/me", authMiddleware, async (c) => {
  const userId = c.get("userId");

  const body = await c.req.json();
  const result = updateProfileSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { displayName, handle, city, zone, interests, avatarUrl } = result.data;

  const updates: string[] = [];
  const params: unknown[] = [];

  if (displayName !== undefined) {
    updates.push("name = ?");
    params.push(displayName);
  }
  if (handle !== undefined) {
    updates.push("handle = ?");
    params.push(handle);
  }
  if (city !== undefined) {
    updates.push("city = ?");
    params.push(city);
  }
  if (zone !== undefined) {
    updates.push("zone = ?");
    params.push(zone);
  }
  if (interests !== undefined) {
    updates.push("interests = ?");
    params.push(JSON.stringify(interests));
  }
  if (avatarUrl !== undefined) {
    updates.push("avatar_url = ?");
    params.push(avatarUrl);
  }

  if (updates.length === 0) {
    return c.json({ error: "No fields to update" }, 400);
  }

  params.push(userId);

  await d1.run(`UPDATE users SET ${updates.join(", ")} WHERE id = ?`, params);

  const row = await d1
    .prepare(
      `SELECT id, name, handle, city, zone, interests, avatar_url, created_at FROM users WHERE id = ?`
    )
    .bind(userId)
    .first();

  if (!row) {
    return c.json({ error: "User not found" }, 404);
  }

  return c.json({ user: toPublicUser(row as Record<string, unknown>) });
});

app.get("/:id", async (c) => {
  const { id } = idParamSchema.parse(c.req.param());

  const row = await d1
    .prepare(
      `SELECT id, name, handle, city, zone, interests, avatar_url, created_at FROM users WHERE id = ?`
    )
    .bind(id)
    .first();

  if (!row) {
    return c.json({ error: "User not found" }, 404);
  }

  return c.json({ user: toPublicUser(row as Record<string, unknown>) });
});

app.post("/me/interests", authMiddleware, async (c) => {
  const userId = c.get("userId");

  const body = await c.req.json();
  const result = interestsSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { interests } = result.data;

  await d1.prepare(`UPDATE users SET interests = ? WHERE id = ?`).bind(JSON.stringify(interests), userId).run();

  return c.json({ interests });
});

app.get("/me/bookmarks", authMiddleware, async (c) => {
  const userId = c.get("userId");

  const rows = await d1
    .prepare(
      `SELECT p.id, p.author_id AS authorId, p.content, p.city, p.zone, p.created_at AS createdAt
       FROM bookmarks b
       JOIN posts p ON p.id = b.post_id
       WHERE b.user_id = ?
       ORDER BY b.created_at DESC`
    )
    .bind(userId)
    .all();

  return c.json({ bookmarks: rows });
});

app.delete("/me", authMiddleware, async (c) => {
  const userId = c.get("userId");

  await d1.batch([
    { sql: `DELETE FROM bookmarks WHERE user_id = ?`, params: [userId] },
    { sql: `DELETE FROM notifications WHERE user_id = ?`, params: [userId] },
    { sql: `DELETE FROM circle_members WHERE user_id = ?`, params: [userId] },
    { sql: `DELETE FROM conversation_participants WHERE user_id = ?`, params: [userId] },
    { sql: `DELETE FROM messages WHERE sender_id = ?`, params: [userId] },
    { sql: `DELETE FROM circles WHERE creator_id = ?`, params: [userId] },
    { sql: `DELETE FROM posts WHERE author_id = ?`, params: [userId] },
    { sql: `DELETE FROM sessions WHERE user_id = ?`, params: [userId] },
    { sql: `DELETE FROM users WHERE id = ?`, params: [userId] },
  ]);

  return c.json({ success: true, message: "Account deleted" });
});

app.all("*", (c) => {
  return c.json({ error: "Not implemented" }, 404);
});

export default app;
