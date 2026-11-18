import { Hono } from "hono";
import { z } from "zod";
import { D1Service } from "../services/d1.service";
import { JWTService } from "../services/jwt.service";

interface AuthUser {
  sub: string;
  phoneNumber?: string;
  type: string;
}

type Variables = {
  user: AuthUser;
};

const app = new Hono<{ Variables: Variables }>();

const d1 = new D1Service(
  process.env.CLOUDFLARE_ACCOUNT_ID ?? "",
  process.env.CLOUDFLARE_DATABASE_ID ?? "",
  process.env.CLOUDFLARE_API_TOKEN ?? ""
);

const jwtService = new JWTService(
  process.env.JWT_ACCESS_SECRET ?? "neem-access-secret",
  process.env.JWT_REFRESH_SECRET ?? "neem-refresh-secret",
  "15m",
  "7d",
  d1
);

const authMiddleware = async (c: any, next: () => Promise<unknown>) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return c.json({ error: "Missing or invalid authorization header" }, 401);
  }

  const token = authHeader.substring(7);
  let payload: unknown;
  try {
    payload = jwtService.verifyAccessToken(token);
  } catch {
    return c.json({ error: "Invalid or expired token" }, 401);
  }

  c.set("user", payload as AuthUser);
  await next();
};

const circleListQuerySchema = z.object({
  zone: z.string().optional(),
  city: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

const createCircleSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(2000).optional(),
  city: z.string().min(1).max(100),
  zone: z.string().min(1).max(100),
  totalSeats: z.coerce.number().int().min(1),
  eventDate: z.string().datetime(),
});

// GET /circles - List active circles with optional filters. Includes seatsLeft.
app.get("/", async (c) => {
  const query = {
    zone: c.req.query("zone") ?? undefined,
    city: c.req.query("city") ?? undefined,
    limit: c.req.query("limit") ?? undefined,
    offset: c.req.query("offset") ?? undefined,
  };

  const result = circleListQuerySchema.safeParse(query);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { zone, city, limit, offset } = result.data;

  let sql = `
    SELECT c.id, c.title, c.description, c.city, c.zone, c.total_seats, c.seats_left AS seatsLeft,
           c.event_date AS eventDate, c.creator_id AS creatorId, c.created_at AS createdAt,
           (SELECT COUNT(*) FROM circle_members cm WHERE cm.circle_id = c.id) AS membersCount
    FROM circles c
    WHERE c.is_active = 1
  `;
  const params: unknown[] = [];

  if (zone) {
    sql += " AND c.zone = ?";
    params.push(zone);
  }
  if (city) {
    sql += " AND c.city = ?";
    params.push(city);
  }

  sql += " ORDER BY c.created_at DESC LIMIT ? OFFSET ?";
  params.push(limit, offset);

  const rows = await d1.run(sql, params);
  return c.json({ circles: rows.results, limit, offset });
});

// GET /circles/:id - Get single circle with members count.
app.get("/:id", async (c) => {
  const { id } = c.req.param();

  const sql = `
    SELECT c.id, c.title, c.description, c.city, c.zone, c.total_seats, c.seats_left AS seatsLeft,
           c.event_date AS eventDate, c.creator_id AS creatorId, c.created_at AS createdAt,
           (SELECT COUNT(*) FROM circle_members cm WHERE cm.circle_id = c.id) AS membersCount
    FROM circles c
    WHERE c.id = ? AND c.is_active = 1
  `;

  const row = await d1.prepare(sql).bind(id).first();
  if (!row) {
    return c.json({ error: "Circle not found" }, 404);
  }

  return c.json({ circle: row });
});

// POST /circles - Create circle. Creator is the current user.
app.post("/", authMiddleware, async (c) => {
  const user = c.get("user");

  const body = await c.req.json();
  const result = createCircleSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { title, description, city, zone, totalSeats, eventDate } = result.data;

  await d1.run(
    `INSERT INTO circles (id, title, description, city, zone, total_seats, seats_left, event_date, creator_id, is_active, created_at)
     VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, ?, ?, ?, ?, 1, datetime('now'))`,
    [title, description ?? null, city, zone, totalSeats, totalSeats, eventDate, user.sub]
  );

  const idRow = await d1.prepare("SELECT last_insert_rowid() AS id").first();
  const circleId = (idRow as Record<string, unknown> | null)?.id as string | null;
  if (!circleId) {
    return c.json({ error: "Failed to create circle" }, 500);
  }

  const circle = await d1.prepare(
    `SELECT id, title, description, city, zone, total_seats, seats_left AS seatsLeft, event_date AS eventDate, creator_id AS creatorId, created_at AS createdAt FROM circles WHERE id = ?`
  )
    .bind(circleId)
    .first();

  return c.json({ circle }, 201);
});

// POST /circles/:id/join - Join a circle (decrement seatsLeft, insert into circle_members).
app.post("/:id/join", authMiddleware, async (c) => {
  const user = c.get("user");
  const { id } = c.req.param();

  const existing = await d1.prepare(
    `SELECT 1 FROM circle_members WHERE circle_id = ? AND user_id = ?`
  )
    .bind(id, user.sub)
    .first();
  if (existing) {
    return c.json({ error: "Already a member of this circle" }, 409);
  }

  const circle = await d1.prepare(
    `SELECT seats_left FROM circles WHERE id = ? AND is_active = 1`
  )
    .bind(id)
    .first();
  if (!circle) {
    return c.json({ error: "Circle not found" }, 404);
  }

  const seatsLeft = Number((circle as Record<string, unknown>).seats_left);
  if (seatsLeft <= 0) {
    return c.json({ error: "No seats available" }, 400);
  }

  await d1.batch([
    {
      sql: `UPDATE circles SET seats_left = seats_left - 1 WHERE id = ?`,
      params: [id],
    },
    {
      sql: `INSERT INTO circle_members (id, circle_id, user_id, joined_at) VALUES (lower(hex(randomblob(16))), ?, ?, datetime('now'))`,
      params: [id, user.sub],
    },
  ]);

  return c.json({ message: "Joined circle" });
});

// POST /circles/:id/leave - Leave a circle (increment seatsLeft, delete from circle_members).
app.post("/:id/leave", authMiddleware, async (c) => {
  const user = c.get("user");
  const { id } = c.req.param();

  const member = await d1.prepare(
    `SELECT 1 FROM circle_members WHERE circle_id = ? AND user_id = ?`
  )
    .bind(id, user.sub)
    .first();
  if (!member) {
    return c.json({ error: "Not a member of this circle" }, 400);
  }

  await d1.batch([
    {
      sql: `UPDATE circles SET seats_left = seats_left + 1 WHERE id = ?`,
      params: [id],
    },
    {
      sql: `DELETE FROM circle_members WHERE circle_id = ? AND user_id = ?`,
      params: [id, user.sub],
    },
  ]);

  return c.json({ message: "Left circle" });
});

// GET /circles/:id/members - List members of a circle.
app.get("/:id/members", async (c) => {
  const { id } = c.req.param();

  const sql = `
    SELECT u.id, u.phone_number AS phoneNumber, u.name, cm.joined_at AS joinedAt
    FROM circle_members cm
    JOIN users u ON u.id = cm.user_id
    WHERE cm.circle_id = ?
    ORDER BY cm.joined_at ASC
  `;
  const rows = await d1.prepare(sql).bind(id).all();
  return c.json({ members: rows });
});

// GET /circles/my - List circles the current user is a member of.
app.get("/my", authMiddleware, async (c) => {
  const user = c.get("user");

  const sql = `
    SELECT c.id, c.title, c.description, c.city, c.zone, c.total_seats, c.seats_left AS seatsLeft,
           c.event_date AS eventDate, c.creator_id AS creatorId, c.created_at AS createdAt,
           (SELECT COUNT(*) FROM circle_members cm2 WHERE cm2.circle_id = c.id) AS membersCount
    FROM circles c
    JOIN circle_members cm ON cm.circle_id = c.id
    WHERE cm.user_id = ? AND c.is_active = 1
    ORDER BY c.created_at DESC
  `;
  const rows = await d1.prepare(sql).bind(user.sub).all();
  return c.json({ circles: rows });
});

app.all("*", (c) => {
  return c.json({ error: "Not implemented" }, 404);
});

export default app;
