import { Hono } from "hono";
import { D1Service } from "../services/d1.service";
import { JWTService } from "../services/jwt.service";
import { z } from "zod";

type Variables = {
  userId: string;
};

const app = new Hono<{ Variables: Variables }>();

const databaseUrl = process.env.D1_DATABASE_URL ?? "";
const databaseId = databaseUrl.match(/\/d1\/database\/([^/?#]+)/)?.[1] ?? process.env.D1_DATABASE_ID ?? "";

const d1 = new D1Service(
  process.env.D1_ACCOUNT_ID ?? "",
  databaseId,
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

const paginationSchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

const idParamSchema = z.object({
  id: z.string().min(1),
});

// GET /notifications - list notifications for the current user with pagination
app.get("/", authMiddleware, async (c) => {
  const userId = c.get("userId");
  const { page = 1, limit = 20 } = paginationSchema.parse(c.req.query());
  const offset = (page - 1) * limit;

  const rows = await d1
    .prepare(
      `SELECT id, type, title, body, data, is_read, created_at
       FROM notifications
       WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`
    )
    .bind(userId, limit, offset)
    .all();

  const notifications = rows.map((row) => {
    const record = row as Record<string, unknown>;
    let data: unknown = {};
    try {
      data = typeof record.data === "string" ? JSON.parse(String(record.data)) : record.data ?? {};
    } catch {
      data = {};
    }
    return {
      id: record.id,
      type: record.type,
      title: record.title,
      body: record.body,
      data,
      isRead: Boolean(record.is_read),
      createdAt: record.created_at,
    };
  });

  return c.json({ notifications, page, limit });
});

// PUT /notifications/read-all - mark all notifications as read
app.put("/read-all", authMiddleware, async (c) => {
  const userId = c.get("userId");

  await d1
    .prepare(`UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0`)
    .bind(userId)
    .run();

  return c.json({ success: true, message: "All notifications marked as read" });
});

// GET /notifications/unread-count - get unread notification count
app.get("/unread-count", authMiddleware, async (c) => {
  const userId = c.get("userId");

  const row = await d1
    .prepare(`SELECT COUNT(*) AS count FROM notifications WHERE user_id = ? AND is_read = 0`)
    .bind(userId)
    .first();

  const count = Number((row as Record<string, unknown> | null)?.count ?? 0);

  return c.json({ unreadCount: count });
});

// PUT /notifications/:id/read - mark a single notification as read
app.put("/:id/read", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const userId = c.get("userId");

  const existing = await d1
    .prepare(`SELECT id FROM notifications WHERE id = ? AND user_id = ?`)
    .bind(id, userId)
    .first();

  if (!existing) {
    return c.json({ error: "Notification not found" }, 404);
  }

  await d1
    .prepare(`UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?`)
    .bind(id, userId)
    .run();

  return c.json({ success: true, message: "Notification marked as read" });
});

// DELETE /notifications/:id - delete a notification
app.delete("/:id", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const userId = c.get("userId");

  const existing = await d1
    .prepare(`SELECT id FROM notifications WHERE id = ? AND user_id = ?`)
    .bind(id, userId)
    .first();

  if (!existing) {
    return c.json({ error: "Notification not found" }, 404);
  }

  await d1
    .prepare(`DELETE FROM notifications WHERE id = ? AND user_id = ?`)
    .bind(id, userId)
    .run();

  return c.json({ success: true, message: "Notification deleted" });
});

export default app;
