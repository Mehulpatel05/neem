import { Hono } from "hono";
import { z } from "zod";
import { R2Service } from "../services/r2.service";
import { JWTService } from "../services/jwt.service";
import { D1Service } from "../services/d1.service";

type Variables = {
  userId: string;
};

const app = new Hono<{ Variables: Variables }>();

const r2 = new R2Service(
  process.env.R2_ACCOUNT_ID ?? "",
  process.env.R2_ACCESS_KEY_ID ?? "",
  process.env.R2_SECRET_ACCESS_KEY ?? "",
  process.env.R2_BUCKET_NAME ?? "neem",
  process.env.R2_PUBLIC_URL ?? ""
);

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

const presignedUrlSchema = z.object({
  folder: z.enum(["profile", "media", "audio", "data", "uploads"]).default("uploads"),
  filename: z.string().min(1).max(200),
  contentType: z.string().default("application/octet-stream"),
});

const uploadBase64Schema = z.object({
  folder: z.enum(["profile", "media", "audio", "data", "uploads"]).default("uploads"),
  filename: z.string().min(1).max(200),
  contentType: z.string().default("application/octet-stream"),
  data: z.string().min(1),
});

const deleteFileSchema = z.object({
  key: z.string().min(1),
});

app.post("/presigned-url", authMiddleware, async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const parsed = presignedUrlSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Validation error", issues: parsed.error.flatten().fieldErrors }, 400);
  }

  const { folder, filename, contentType } = parsed.data;
  const safeFilename = `${Date.now()}_${filename.replace(/[^a-zA-Z0-9._-]/g, "_")}`;
  const key = r2.getUserKey(userId, folder, safeFilename);

  const presigned = await r2.getPresignedUploadUrl(key, contentType, 600);
  return c.json({
    uploadUrl: presigned.url,
    key: presigned.key,
    publicUrl: presigned.publicUrl,
  });
});

app.post("/upload", authMiddleware, async (c) => {
  const userId = c.get("userId");
  const contentTypeHeader = c.req.header("Content-Type") || "";

  if (contentTypeHeader.includes("application/json")) {
    const body = await c.req.json();
    const parsed = uploadBase64Schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: "Validation error", issues: parsed.error.flatten().fieldErrors }, 400);
    }
    const { folder, filename, contentType, data } = parsed.data;
    const buffer = Buffer.from(data, "base64");
    const safeFilename = `${Date.now()}_${filename.replace(/[^a-zA-Z0-9._-]/g, "_")}`;
    const key = r2.getUserKey(userId, folder, safeFilename);
    const publicUrl = await r2.putObject(key, buffer, contentType);
    return c.json({ key, publicUrl, size: buffer.length });
  }

  const folder = c.req.query("folder") || "uploads";
  const filename = c.req.query("filename") || `file_${Date.now()}`;
  const mimeType = contentTypeHeader || "application/octet-stream";
  const arrayBuffer = await c.req.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  const safeFilename = `${Date.now()}_${filename.replace(/[^a-zA-Z0-9._-]/g, "_")}`;
  const key = r2.getUserKey(userId, folder, safeFilename);
  const publicUrl = await r2.putObject(key, buffer, mimeType);

  return c.json({ key, publicUrl, size: buffer.length });
});

app.get("/files", authMiddleware, async (c) => {
  const userId = c.get("userId");
  const folder = c.req.query("folder");
  const files = await r2.listUserFiles(userId, folder);
  return c.json({ files, count: files.length, userFolder: `users/${userId}/` });
});

app.get("/users/:userId/:folder/:filename", async (c) => {
  const userId = c.req.param("userId");
  const folder = c.req.param("folder");
  const filename = c.req.param("filename");
  const key = `users/${userId}/${folder}/${filename}`;

  try {
    const obj = await r2.getObject(key);
    return new Response(obj.data, {
      headers: {
        "Content-Type": obj.contentType,
        "Cache-Control": "public, max-age=86400",
      },
    });
  } catch {
    return c.json({ error: "File not found" }, 404);
  }
});

app.get("/updates/:filename", async (c) => {
  const filename = c.req.param("filename");
  const key = `updates/${filename}`;
  try {
    const obj = await r2.getObject(key);
    return new Response(obj.data, {
      headers: {
        "Content-Type": "application/vnd.android.package-archive",
        "Content-Disposition": `attachment; filename="${filename}"`,
      },
    });
  } catch {
    return c.json({ error: "Update package not found" }, 404);
  }
});

app.get("/user-data", authMiddleware, async (c) => {
  const userId = c.get("userId");
  const key = r2.getUserKey(userId, "data", "user_data.json");
  try {
    const result = await r2.getObject(key);
    const json = JSON.parse(result.data.toString("utf-8"));
    return c.json({ data: json });
  } catch {
    return c.json({ data: null, message: "No stored data found for user" }, 404);
  }
});

app.post("/user-data", authMiddleware, async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const key = r2.getUserKey(userId, "data", "user_data.json");
  const publicUrl = await r2.putObject(key, JSON.stringify(body, null, 2), "application/json");
  return c.json({ success: true, key, publicUrl });
});

app.delete("/file", authMiddleware, async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const parsed = deleteFileSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Validation error", issues: parsed.error.flatten().fieldErrors }, 400);
  }

  const { key } = parsed.data;
  const userPrefix = `users/${userId}/`;
  if (!key.startsWith(userPrefix)) {
    return c.json({ error: "Unauthorized access to file key" }, 403);
  }

  await r2.deleteObject(key);
  return c.json({ success: true, deletedKey: key });
});

export default app;
