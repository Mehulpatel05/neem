import { Hono, type Context, type Next } from "hono";
import { z } from "zod";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";

const app = new Hono();

// ---------------------------------------------------------------------------
// Validation schemas
// ---------------------------------------------------------------------------

const StructurePostSchema = z.object({
  rawInput: z.string().min(1, "rawInput is required"),
  language: z.enum(["hinglish", "english"]).optional().default("english"),
  isAnonymous: z.boolean().optional().default(false),
});

const StructureMeetupSchema = z.object({
  rawInput: z.string().min(1, "rawInput is required"),
});

const TelemetrySignalSchema = z.object({
  type: z.string().min(1, "signal type is required"),
  timestamp: z.union([z.string(), z.number()]),
  payload: z.record(z.any()).optional(),
});

const TelemetryBatchSchema = z.object({
  signals: z.array(TelemetrySignalSchema).min(1, "signals must not be empty"),
});

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type JWTPayload = {
  sub: string;
  phoneNumber?: string;
  type: string;
  iat?: number;
  exp?: number;
};

type StructuredPost = {
  title: string;
  category: string;
  content: string;
  suggestedZones: string[];
  tags: string[];
};

type StructuredMeetup = {
  title: string;
  description: string;
  category: string;
  suggestedSeats: number;
  suggestedDate: string;
};

// ---------------------------------------------------------------------------
// JWT auth middleware (Bearer token)
// ---------------------------------------------------------------------------

const authMiddleware = async (c: Context, next: Next) => {
  const authHeader = c.req.header("authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return c.json({ error: "Missing or invalid Authorization header" }, 401);
  }

  const token = authHeader.slice(7).trim();
  const secret = process.env.JWT_ACCESS_SECRET;
  if (!secret) {
    return c.json({ error: "Authentication is not configured" }, 500);
  }

  try {
    const payload = jwt.verify(token, secret, { algorithms: ["HS256"] }) as JWTPayload;
    c.set("user", payload);
    await next();
  } catch {
    return c.json({ error: "Invalid or expired token" }, 401);
  }
};

app.use("/*", authMiddleware);

// ---------------------------------------------------------------------------
// Groq integration
// ---------------------------------------------------------------------------

const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

async function callGroq(systemPrompt: string, userPrompt: string): Promise<unknown> {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    return null;
  }

  try {
    const response = await fetch(GROQ_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        temperature: 0.4,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      return null;
    }

    const data = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
    };

    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      return null;
    }

    return JSON.parse(content);
  } catch {
    return null;
  }
}

function isStructuredPost(value: unknown): value is StructuredPost {
  if (!value || typeof value !== "object") {
    return false;
  }
  const obj = value as Record<string, unknown>;
  return (
    typeof obj.title === "string" &&
    typeof obj.category === "string" &&
    typeof obj.content === "string" &&
    Array.isArray(obj.suggestedZones) &&
    Array.isArray(obj.tags)
  );
}

function isStructuredMeetup(value: unknown): value is StructuredMeetup {
  if (!value || typeof value !== "object") {
    return false;
  }
  const obj = value as Record<string, unknown>;
  return (
    typeof obj.title === "string" &&
    typeof obj.description === "string" &&
    typeof obj.category === "string" &&
    typeof obj.suggestedSeats === "number" &&
    typeof obj.suggestedDate === "string"
  );
}

// ---------------------------------------------------------------------------
// Mock fallbacks
// ---------------------------------------------------------------------------

function mockStructurePost(rawInput: string, language: string): StructuredPost {
  const title = rawInput.trim().slice(0, 80) || "Untitled Post";
  return {
    title,
    category: "general",
    content: rawInput.trim(),
    suggestedZones: ["local"],
    tags: language === "hinglish" ? ["hinglish", "voice-note"] : ["english", "voice-note"],
  };
}

function mockStructureMeetup(rawInput: string): StructuredMeetup {
  const title = rawInput.trim().slice(0, 80) || "Untitled Meetup";
  const suggestedDate = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
  return {
    title,
    description: rawInput.trim(),
    category: "community",
    suggestedSeats: 10,
    suggestedDate,
  };
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

app.post("/structure-post", async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const parsed = StructurePostSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Validation failed", issues: parsed.error.flatten() }, 400);
  }

  const { rawInput, language, isAnonymous } = parsed.data;

  const systemPrompt =
    "You are a post structuring assistant. Convert raw voice/text input into a structured social post. " +
    "Return ONLY a JSON object with keys: title (string), category (string), content (string), " +
    "suggestedZones (array of strings), tags (array of strings). No extra text.";

  const groqResult = await callGroq(
    systemPrompt,
    `Language: ${language}\nAnonymous: ${isAnonymous}\nRaw input: ${rawInput}`
  );

  const structured: StructuredPost = isStructuredPost(groqResult) ? groqResult : mockStructurePost(rawInput, language);

  return c.json(structured);
});

app.post("/structure-meetup", async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const parsed = StructureMeetupSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Validation failed", issues: parsed.error.flatten() }, 400);
  }

  const { rawInput } = parsed.data;

  const systemPrompt =
    "You are a meetup structuring assistant. Convert raw input into a structured meetup. " +
    "Return ONLY a JSON object with keys: title (string), description (string), category (string), " +
    "suggestedSeats (number), suggestedDate (ISO date string). No extra text.";

  const groqResult = await callGroq(systemPrompt, `Raw input: ${rawInput}`);

  const structured: StructuredMeetup = isStructuredMeetup(groqResult) ? groqResult : mockStructureMeetup(rawInput);

  return c.json(structured);
});

app.post("/telemetry/batch", async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const parsed = TelemetryBatchSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Validation failed", issues: parsed.error.flatten() }, 400);
  }

  const { signals } = parsed.data;

  const receivedAt = new Date().toISOString();
  (globalThis as Record<string, unknown>).__neem_telemetry__ =
    (globalThis as Record<string, unknown>).__neem_telemetry__ ?? [];
  const store: Array<{ receivedAt: string; count: number }> = (globalThis as Record<string, unknown>)
    .__neem_telemetry__ as Array<{ receivedAt: string; count: number }>;
  store.push({ receivedAt, count: signals.length });

  return c.json({ received: signals.length });
});

app.all("*", (c) => {
  return c.json({ error: "Not implemented" }, 404);
});

export default app;
