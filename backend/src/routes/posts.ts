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

const paginationSchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

const idParamSchema = z.object({
  id: z.string().min(1),
});

const createPostSchema = z.object({
  content: z.string().min(1).max(280),
  city: z.string().min(1).max(100).optional(),
  zone: z.string().min(1).max(100).optional(),
});

function toPublicPost(row: Record<string, unknown>, viewerId?: string) {
  let upvotedByViewer = false;
  let bookmarkedByViewer = false;
  try {
    upvotedByViewer = viewerId ? Boolean(row.upvoted_by_viewer) : false;
  } catch {
    upvotedByViewer = false;
  }
  try {
    bookmarkedByViewer = viewerId ? Boolean(row.bookmarked_by_viewer) : false;
  } catch {
    bookmarkedByViewer = false;
  }

  return {
    id: row.id,
    authorId: row.author_id,
    content: row.content,
    city: row.city,
    zone: row.zone,
    upvoteCount: Number(row.upvote_count ?? 0),
    replyCount: Number(row.reply_count ?? 0),
    isBlocked: Boolean(row.is_blocked),
    upvotedByViewer,
    bookmarkedByViewer,
    createdAt: row.created_at,
  };
}

// GET /posts - list posts with pagination
app.get("/", authMiddleware, async (c) => {
  const viewerId = c.get("userId");
  const { page = 1, limit = 20 } = paginationSchema.parse(c.req.query());
  const offset = (page - 1) * limit;

  const rows = await d1
    .prepare(
      `SELECT p.id, p.author_id AS authorId, p.content, p.city, p.zone, p.upvote_count AS upvoteCount,
              p.reply_count AS replyCount, p.is_blocked AS isBlocked, p.created_at AS createdAt,
              EXISTS(SELECT 1 FROM upvotes u WHERE u.post_id = p.id AND u.user_id = ?) AS upvotedByViewer,
              EXISTS(SELECT 1 FROM bookmarks b WHERE b.post_id = p.id AND b.user_id = ?) AS bookmarkedByViewer
       FROM posts p
       WHERE p.is_blocked = 0
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`
    )
    .bind(viewerId, viewerId, limit, offset)
    .all();

  return c.json({
    posts: (rows as unknown[]).map((row) => toPublicPost(row as Record<string, unknown>, viewerId)),
    page,
    limit,
  });
});

// GET /posts/:id - get a single post
app.get("/:id", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const viewerId = c.get("userId");

  const row = await d1
    .prepare(
      `SELECT p.id, p.author_id AS authorId, p.content, p.city, p.zone, p.upvote_count AS upvoteCount,
              p.reply_count AS replyCount, p.is_blocked AS isBlocked, p.created_at AS createdAt,
              EXISTS(SELECT 1 FROM upvotes u WHERE u.post_id = p.id AND u.user_id = ?) AS upvotedByViewer,
              EXISTS(SELECT 1 FROM bookmarks b WHERE b.post_id = p.id AND b.user_id = ?) AS bookmarkedByViewer
       FROM posts p
       WHERE p.id = ?`
    )
    .bind(viewerId, viewerId, id)
    .first();

  if (!row) {
    return c.json({ error: "Post not found" }, 404);
  }

  return c.json({ post: toPublicPost(row as Record<string, unknown>, viewerId) });
});

// POST /posts - create a post
app.post("/", authMiddleware, async (c) => {
  const userId = c.get("userId");

  const body = await c.req.json();
  const result = createPostSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { content, city, zone } = result.data;

  await d1
    .prepare(
      `INSERT INTO posts (id, author_id, content, city, zone, upvote_count, reply_count, is_blocked, created_at)
       VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, 0, 0, 0, datetime('now'))`
    )
    .bind(userId, content, city ?? null, zone ?? null)
    .run();

  const row = await d1
    .prepare(`SELECT id FROM posts WHERE author_id = ? ORDER BY created_at DESC LIMIT 1`)
    .bind(userId)
    .first();

  if (!row) {
    return c.json({ error: "Failed to create post" }, 500);
  }

  return c.json(
    { post: toPublicPost({ id: (row as Record<string, unknown>).id, author_id: userId, content, city, zone, upvote_count: 0, reply_count: 0, is_blocked: 0, created_at: new Date().toISOString() } as Record<string, unknown>, userId) },
    201
  );
});

// POST /posts/:id/upvote - upvote a post
app.post("/:id/upvote", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const userId = c.get("userId");

  const existing = await d1
    .prepare(`SELECT id FROM posts WHERE id = ?`)
    .bind(id)
    .first();

  if (!existing) {
    return c.json({ error: "Post not found" }, 404);
  }

  const alreadyVoted = await d1
    .prepare(`SELECT id FROM upvotes WHERE post_id = ? AND user_id = ?`)
    .bind(id, userId)
    .first();

  if (alreadyVoted) {
    return c.json({ error: "Already upvoted" }, 400);
  }

  await d1.batch([
    { sql: `INSERT INTO upvotes (id, post_id, user_id, created_at) VALUES (lower(hex(randomblob(16))), ?, ?, datetime('now'))`, params: [id, userId] },
    { sql: `UPDATE posts SET upvote_count = upvote_count + 1 WHERE id = ?`, params: [id] },
  ]);

  const row = await d1
    .prepare(`SELECT upvote_count FROM posts WHERE id = ?`)
    .bind(id)
    .first();

  return c.json({
    upvoted: true,
    upvoteCount: Number((row as Record<string, unknown>)?.upvote_count ?? 0),
  });
});

// POST /posts/:id/bookmark - bookmark a post
app.post("/:id/bookmark", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const userId = c.get("userId");

  const existing = await d1
    .prepare(`SELECT id FROM posts WHERE id = ?`)
    .bind(id)
    .first();

  if (!existing) {
    return c.json({ error: "Post not found" }, 404);
  }

  const alreadyBookmarked = await d1
    .prepare(`SELECT id FROM bookmarks WHERE post_id = ? AND user_id = ?`)
    .bind(id, userId)
    .first();

  if (alreadyBookmarked) {
    return c.json({ error: "Already bookmarked" }, 400);
  }

  await d1
    .prepare(`INSERT INTO bookmarks (id, post_id, user_id, created_at) VALUES (lower(hex(randomblob(16))), ?, ?, datetime('now'))`)
    .bind(id, userId)
    .run();

  return c.json({ bookmarked: true });
});

// GET /posts/:id/replies - list replies to a post
app.get("/:id/replies", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const viewerId = c.get("userId");
  const { page = 1, limit = 50 } = paginationSchema.parse(c.req.query());
  const offset = (page - 1) * limit;

  const postExists = await d1
    .prepare(`SELECT id FROM posts WHERE id = ?`)
    .bind(id)
    .first();

  if (!postExists) {
    return c.json({ error: "Post not found" }, 404);
  }

  const rows = await d1
    .prepare(
      `SELECT r.id, r.author_id AS authorId, r.content, r.city, r.zone, r.upvote_count AS upvoteCount,
              r.created_at AS createdAt,
              EXISTS(SELECT 1 FROM upvotes u WHERE u.post_id = r.id AND u.user_id = ?) AS upvotedByViewer
       FROM post_replies r
       WHERE r.post_id = ?
       ORDER BY r.created_at DESC
       LIMIT ? OFFSET ?`
    )
    .bind(viewerId, id, limit, offset)
    .all();

  return c.json({
    replies: (rows as unknown[]).map((row) => ({
      id: (row as Record<string, unknown>).id,
      authorId: (row as Record<string, unknown>).authorId,
      content: (row as Record<string, unknown>).content,
      city: (row as Record<string, unknown>).city,
      zone: (row as Record<string, unknown>).zone,
      upvoteCount: Number((row as Record<string, unknown>).upvoteCount ?? 0),
      upvotedByViewer: Boolean((row as Record<string, unknown>).upvotedByViewer),
      createdAt: (row as Record<string, unknown>).createdAt,
    })),
    page,
    limit,
  });
});

// POST /posts/:id/replies - create a reply to a post
app.post("/:id/replies", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const userId = c.get("userId");

  const body = await c.req.json();
  const result = createPostSchema.safeParse(body);
  if (!result.success) {
    return c.json({ error: "Validation error", issues: result.error.flatten().fieldErrors }, 400);
  }

  const { content, city, zone } = result.data;

  const postExists = await d1
    .prepare(`SELECT id FROM posts WHERE id = ?`)
    .bind(id)
    .first();

  if (!postExists) {
    return c.json({ error: "Post not found" }, 404);
  }

  await d1.batch([
    {
      sql: `INSERT INTO post_replies (id, post_id, author_id, content, city, zone, upvote_count, created_at)
            VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, ?, 0, datetime('now'))`,
      params: [id, userId, content, city ?? null, zone ?? null],
    },
    { sql: `UPDATE posts SET reply_count = reply_count + 1 WHERE id = ?`, params: [id] },
  ]);

  return c.json(
    {
      reply: {
        id: "",
        postId: id,
        authorId: userId,
        content,
        city,
        zone,
        upvoteCount: 0,
        createdAt: new Date().toISOString(),
      },
    },
    201
  );
});

// POST /posts/:id/report - report a post
app.post("/:id/report", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const userId = c.get("userId");

  const postExists = await d1
    .prepare(`SELECT id FROM posts WHERE id = ?`)
    .bind(id)
    .first();

  if (!postExists) {
    return c.json({ error: "Post not found" }, 404);
  }

  const alreadyReported = await d1
    .prepare(`SELECT id FROM reports WHERE post_id = ? AND reporter_id = ?`)
    .bind(id, userId)
    .first();

  if (alreadyReported) {
    return c.json({ error: "Already reported" }, 400);
  }

  await d1
    .prepare(`INSERT INTO reports (id, post_id, reporter_id, created_at) VALUES (lower(hex(randomblob(16))), ?, ?, datetime('now'))`)
    .bind(id, userId)
    .run();

  return c.json({ reported: true });
});

// POST /posts/:id/block - block a post (hide from viewer)
app.post("/:id/block", authMiddleware, async (c) => {
  const { id } = idParamSchema.parse(c.req.param());
  const userId = c.get("userId");

  const postExists = await d1
    .prepare(`SELECT id FROM posts WHERE id = ?`)
    .bind(id)
    .first();

  if (!postExists) {
    return c.json({ error: "Post not found" }, 404);
  }

  const alreadyBlocked = await d1
    .prepare(`SELECT id FROM blocked_posts WHERE post_id = ? AND user_id = ?`)
    .bind(id, userId)
    .first();

  if (alreadyBlocked) {
    return c.json({ error: "Already blocked" }, 400);
  }

  await d1
    .prepare(`INSERT INTO blocked_posts (id, post_id, user_id, created_at) VALUES (lower(hex(randomblob(16))), ?, ?, datetime('now'))`)
    .bind(id, userId)
    .run();

  return c.json({ blocked: true });
});

app.all("*", (c) => {
  return c.json({ error: "Not implemented" }, 404);
});

export default app;
