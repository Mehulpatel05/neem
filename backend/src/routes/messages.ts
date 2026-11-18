import { Hono, Context, Next } from "hono";
import { z, ZodError } from "zod";
import { D1Service } from "../services/d1.service";
import { JWTService, JWTPayload } from "../services/jwt.service";

const d1 = new D1Service(
  process.env.D1_ACCOUNT_ID ?? process.env.CLOUDFLARE_ACCOUNT_ID ?? "",
  process.env.D1_DATABASE_ID ?? "",
  process.env.D1_API_TOKEN ?? ""
);

const jwtService = new JWTService(
  process.env.JWT_ACCESS_SECRET ?? "",
  process.env.JWT_REFRESH_SECRET ?? "",
  process.env.JWT_ACCESS_EXPIRY ?? process.env.JWT_ACCESS_EXPIRES_IN ?? "15m",
  process.env.JWT_REFRESH_EXPIRY ?? process.env.JWT_REFRESH_EXPIRES_IN ?? "30d",
  d1
);

type AppContext = {
  Variables: {
    user: JWTPayload;
    validated: unknown;
  };
};

const createConversationSchema = z.object({
  participantId: z.string().uuid(),
});

const sendMessageSchema = z.object({
  content: z.string().min(1).max(4000),
  type: z.enum(["text", "image", "voice"]),
  mediaUrl: z.string().url().optional(),
});

const jwtAuth = async (c: Context<AppContext>, next: Next) => {
  const auth = c.req.header("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) {
    return c.json({ error: "Unauthorized" }, 401);
  }

  try {
    const payload = jwtService.verifyAccessToken(auth.slice("Bearer ".length));
    c.set("user", payload);
    await next();
  } catch {
    return c.json({ error: "Unauthorized" }, 401);
  }
};

const validateBody = (schema: z.ZodSchema<unknown>) => {
  return async (c: Context<AppContext>, next: Next) => {
    try {
      c.set("validated", schema.parse(await c.req.json()));
      await next();
    } catch (err) {
      if (err instanceof ZodError) {
        return c.json({ error: "Validation error", issues: err.errors }, 400);
      }
      return c.json({ error: "Invalid request body" }, 400);
    }
  };
};

const ensureParticipant = async (conversationId: string, userId: string): Promise<boolean> => {
  const row = await d1.prepare(
    `SELECT 1 FROM conversation_participants WHERE conversation_id = ? AND user_id = ? AND left_at IS NULL LIMIT 1`
  )
    .bind(conversationId, userId)
    .first();
  return row !== null;
};

const app = new Hono<AppContext>();

app.all("*", (c) => {
  return c.json({ error: "Not implemented" }, 404);
});

// 1. List conversations for current user with last message preview
app.get("/conversations", jwtAuth, async (c) => {
  const userId = c.get("user").sub;

  try {
    const rows = await d1.prepare(
      `SELECT
        c.id,
        c.type,
        c.created_at,
        c.updated_at,
        (SELECT m.content FROM messages m
          WHERE m.conversation_id = c.id AND m.deleted_at IS NULL
          ORDER BY m.created_at DESC LIMIT 1) AS last_message_content,
        (SELECT m.created_at FROM messages m
          WHERE m.conversation_id = c.id AND m.deleted_at IS NULL
          ORDER BY m.created_at DESC LIMIT 1) AS last_message_at,
        (SELECT m.sender_id FROM messages m
          WHERE m.conversation_id = c.id AND m.deleted_at IS NULL
          ORDER BY m.created_at DESC LIMIT 1) AS last_message_sender_id,
        (SELECT COUNT(*) FROM messages m
          WHERE m.conversation_id = c.id AND m.deleted_at IS NULL
            AND m.sender_id != ?
            AND m.created_at > COALESCE(cp.read_at, '1970-01-01')) AS unread_count
      FROM conversations c
      JOIN conversation_participants cp
        ON cp.conversation_id = c.id AND cp.user_id = ? AND cp.left_at IS NULL
      ORDER BY (last_message_at IS NULL), last_message_at DESC, c.updated_at DESC`
    )
      .bind(userId, userId)
      .all();

    return c.json({ conversations: rows });
  } catch (err) {
    return c.json({ error: "Failed to load conversations" }, 500);
  }
});

// 2. List messages in a conversation (paginated)
app.get("/conversations/:id/messages", jwtAuth, async (c) => {
  const userId = c.get("user").sub;
  const conversationId = c.req.param("id")!;

  const isParticipant = await ensureParticipant(conversationId, userId);
  if (!isParticipant) {
    return c.json({ error: "Forbidden" }, 403);
  }

  const limit = Math.min(Math.max(parseInt(c.req.query("limit") ?? "50", 10), 1), 100);
  const offset = Math.max(parseInt(c.req.query("offset") ?? "0", 10), 0);

  try {
    const rows = await d1.prepare(
      `SELECT id, conversation_id, sender_id, content, type, media_url, created_at, deleted_at
       FROM messages
       WHERE conversation_id = ? AND deleted_at IS NULL
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`
    )
      .bind(conversationId, limit, offset)
      .all();

    return c.json({ messages: rows, limit, offset });
  } catch (err) {
    return c.json({ error: "Failed to load messages" }, 500);
  }
});

// 3. Create a direct conversation
app.post("/conversations", jwtAuth, validateBody(createConversationSchema), async (c) => {
  const userId = c.get("user").sub;
  const { participantId } = c.get("validated") as { participantId: string };

  if (participantId === userId) {
    return c.json({ error: "Cannot create conversation with yourself" }, 400);
  }

  const conversationId = crypto.randomUUID();

  try {
    await d1.run(
      `INSERT INTO conversations (id, type, created_at, updated_at)
       VALUES (?, 'direct', datetime('now'), datetime('now'))`,
      [conversationId]
    );

    await d1.batch([
      {
        sql: `INSERT INTO conversation_participants (id, conversation_id, user_id, joined_at)
              VALUES (lower(hex(randomblob(16))), ?, ?, datetime('now'))`,
        params: [conversationId, userId],
      },
      {
        sql: `INSERT INTO conversation_participants (id, conversation_id, user_id, joined_at)
              VALUES (lower(hex(randomblob(16))), ?, ?, datetime('now'))`,
        params: [conversationId, participantId],
      },
    ]);

    return c.json(
      { conversation: { id: conversationId, type: "direct", participantId } },
      201
    );
  } catch (err) {
    return c.json({ error: "Failed to create conversation" }, 500);
  }
});

// 4. Send a message
app.post(
  "/conversations/:id/messages",
  jwtAuth,
  validateBody(sendMessageSchema),
  async (c) => {
    const userId = c.get("user").sub;
    const conversationId = c.req.param("id")!;

    const isParticipant = await ensureParticipant(conversationId, userId);
    if (!isParticipant) {
      return c.json({ error: "Forbidden" }, 403);
    }

    const { content, type, mediaUrl } = c.get("validated") as {
      content: string;
      type: "text" | "image" | "voice";
      mediaUrl?: string;
    };

    const messageId = crypto.randomUUID();

    try {
      await d1.run(
        `INSERT INTO messages (id, conversation_id, sender_id, content, type, media_url, created_at)
         VALUES (?, ?, ?, ?, ?, ?, datetime('now'))`,
        [messageId, conversationId, userId, content, type, mediaUrl ?? null]
      );

      await d1.run(
        `UPDATE conversations SET updated_at = datetime('now') WHERE id = ?`,
        [conversationId]
      );

      const message = await d1.prepare(
        `SELECT id, conversation_id, sender_id, content, type, media_url, created_at, deleted_at
         FROM messages WHERE id = ?`
      )
        .bind(messageId)
        .first();

      return c.json({ message }, 201);
    } catch (err) {
      return c.json({ error: "Failed to send message" }, 500);
    }
  }
);

// 5. Mark conversation as read
app.put("/conversations/:id/read", jwtAuth, async (c) => {
  const userId = c.get("user").sub;
  const conversationId = c.req.param("id")!;

  const isParticipant = await ensureParticipant(conversationId, userId);
  if (!isParticipant) {
    return c.json({ error: "Forbidden" }, 403);
  }

  try {
    await d1.run(
      `UPDATE conversation_participants
       SET read_at = datetime('now')
       WHERE conversation_id = ? AND user_id = ? AND left_at IS NULL`,
      [conversationId, userId]
    );

    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: "Failed to mark conversation as read" }, 500);
  }
});

// 6. Get single message
app.get("/messages/:id", jwtAuth, async (c) => {
  const userId = c.get("user").sub;
  const messageId = c.req.param("id")!;

  try {
    const message = await d1.prepare(
      `SELECT m.id, m.conversation_id, m.sender_id, m.content, m.type, m.media_url, m.created_at, m.deleted_at
       FROM messages m
       WHERE m.id = ? AND m.deleted_at IS NULL`
    )
      .bind(messageId)
      .first();

    if (!message) {
      return c.json({ error: "Message not found" }, 404);
    }

    const isParticipant = await ensureParticipant(
      String((message as Record<string, unknown>).conversation_id),
      userId
    );
    if (!isParticipant) {
      return c.json({ error: "Forbidden" }, 403);
    }

    return c.json({ message });
  } catch (err) {
    return c.json({ error: "Failed to load message" }, 500);
  }
});

// 7. Delete message (soft delete)
app.delete("/messages/:id", jwtAuth, async (c) => {
  const userId = c.get("user").sub;
  const messageId = c.req.param("id")!;

  try {
    const existing = await d1.prepare(
      `SELECT sender_id FROM messages WHERE id = ? AND deleted_at IS NULL LIMIT 1`
    )
      .bind(messageId)
      .first();

    if (!existing) {
      return c.json({ error: "Message not found" }, 404);
    }

    if (String((existing as Record<string, unknown>).sender_id) !== userId) {
      return c.json({ error: "Forbidden" }, 403);
    }

    await d1.run(
      `UPDATE messages SET deleted_at = datetime('now') WHERE id = ?`,
      [messageId]
    );

    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: "Failed to delete message" }, 500);
  }
});

export default app;
