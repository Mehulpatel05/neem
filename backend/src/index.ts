import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { prettyJSON } from "hono/pretty-json";
import { createServer } from "http";
import { getRequestListener } from "@hono/node-server";
import { WebSocketServer, WebSocket } from "ws";

import authRoutes from "./routes/auth";
import postsRoutes from "./routes/posts";
import circlesRoutes from "./routes/circles";
import messagesRoutes from "./routes/messages";
import aiRoutes from "./routes/ai";
import usersRoutes from "./routes/users";
import notificationsRoutes from "./routes/notifications";

const app = new Hono();

app.use("*", logger());
app.use("*", prettyJSON());
app.use(
  "*",
  cors({
    origin: process.env.CORS_ORIGIN ?? "*",
    allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);

app.get("/health", (c) => {
  return c.json({
    status: "ok",
    service: "neem-backend",
    timestamp: new Date().toISOString(),
  });
});

app.route("/auth", authRoutes);
app.route("/posts", postsRoutes);
app.route("/circles", circlesRoutes);
app.route("/messages", messagesRoutes);
app.route("/ai", aiRoutes);
app.route("/users", usersRoutes);
app.route("/notifications", notificationsRoutes);

// API v1 aliases for mobile and web clients
app.route("/api/v1/auth", authRoutes);
app.route("/api/v1/posts", postsRoutes);
app.route("/api/v1/circles", circlesRoutes);
app.route("/api/v1/messages", messagesRoutes);
app.route("/api/v1/ai", aiRoutes);
app.route("/api/v1/users", usersRoutes);
app.route("/api/v1/notifications", notificationsRoutes);

app.notFound((c) => {
  return c.json({ error: "Not found" }, 404);
});

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: "Internal server error" }, 500);
});

export default app;

export interface HubMessage {
  type: string;
  roomId?: string;
  userId?: string;
  payload?: unknown;
  timestamp?: string;
}

interface Client {
  ws: WebSocket;
  userId: string;
  rooms: Set<string>;
}

export class WebSocketHub {
  private clients = new Map<string, Client>();
  private rooms = new Map<string, Set<string>>();
  private heartbeats = new Map<WebSocket, number>();
  private readonly pingInterval = 30000;
  private readonly pongTimeout = 5000;
  private intervalId?: NodeJS.Timeout;

  constructor(private readonly wss: WebSocketServer) {
    this.setup();
    this.startHeartbeat();
  }

  private setup(): void {
    this.wss.on("connection", (ws, req) => {
      const userId = this.extractUserId(req);
      if (!userId) {
        ws.close(1008, "Missing userId");
        return;
      }

      const client: Client = { ws, userId, rooms: new Set() };
      this.clients.set(userId, client);

      ws.on("message", (data) => this.handleMessage(userId, data));
      ws.on("close", () => this.removeClient(userId));
      ws.on("error", () => this.removeClient(userId));
      ws.on("pong", () => this.heartbeats.set(ws, Date.now()));

      this.send(ws, {
        type: "CONNECTED",
        userId,
        timestamp: new Date().toISOString(),
      });
    });
  }

  private extractUserId(req: import("http").IncomingMessage): string | null {
    if (!req.url) return null;
    const parsed = new URL(req.url, `http://${req.headers.host ?? "localhost"}`);
    return parsed.searchParams.get("userId") ?? null;
  }

  private handleMessage(userId: string, data: unknown): void {
    try {
      const message = JSON.parse(String(data)) as HubMessage;
      switch (message.type) {
        case "JOIN":
          if (message.roomId) this.join(userId, message.roomId);
          break;
        case "LEAVE":
          if (message.roomId) this.leave(userId, message.roomId);
          break;
        case "PONG":
          break;
        default:
          this.sendToUser(userId, { type: "ERROR", error: "Unknown message type" });
      }
    } catch {
      this.sendToUser(userId, { type: "ERROR", error: "Invalid message format" });
    }
  }

  join(userId: string, roomId: string): void {
    const client = this.clients.get(userId);
    if (!client) return;
    let members = this.rooms.get(roomId);
    if (!members) {
      members = new Set();
      this.rooms.set(roomId, members);
    }
    members.add(userId);
    client.rooms.add(roomId);
    this.broadcast(
      roomId,
      { type: "JOINED", roomId, userId, timestamp: new Date().toISOString() },
      userId
    );
  }

  leave(userId: string, roomId: string): void {
    const client = this.clients.get(userId);
    if (!client) return;
    const members = this.rooms.get(roomId);
    if (members) {
      members.delete(userId);
      if (members.size === 0) this.rooms.delete(roomId);
    }
    client.rooms.delete(roomId);
    this.broadcast(
      roomId,
      { type: "LEFT", roomId, userId, timestamp: new Date().toISOString() },
      userId
    );
  }

  private removeClient(userId: string): void {
    const client = this.clients.get(userId);
    if (!client) return;
    this.heartbeats.delete(client.ws);
    for (const roomId of client.rooms) {
      const members = this.rooms.get(roomId);
      if (members) {
        members.delete(userId);
        if (members.size === 0) this.rooms.delete(roomId);
        else
          this.broadcast(
            roomId,
            { type: "LEFT", roomId, userId, timestamp: new Date().toISOString() },
            userId
          );
      }
    }
    this.clients.delete(userId);
  }

  private send(ws: WebSocket, message: unknown): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  }

  sendToUser(userId: string, message: unknown): void {
    const client = this.clients.get(userId);
    if (client) this.send(client.ws, message);
  }

  broadcast(roomId: string, message: unknown, excludeUserId?: string): void {
    const members = this.rooms.get(roomId);
    if (!members) return;
    const payload = JSON.stringify(message);
    for (const userId of members) {
      if (excludeUserId && userId === excludeUserId) continue;
      const client = this.clients.get(userId);
      if (client) this.send(client.ws, payload);
    }
  }

  broadcastCounter(type: "upvote" | "unread", roomId: string, count: number): void {
    this.broadcast(roomId, {
      type: `counter:${type}`,
      roomId,
      count,
      timestamp: new Date().toISOString(),
    });
  }

  private startHeartbeat(): void {
    this.intervalId = setInterval(() => {
      const now = Date.now();
      for (const [ws, lastPong] of this.heartbeats) {
        if (now - lastPong > this.pongTimeout) {
          ws.terminate();
          this.heartbeats.delete(ws);
        } else if (ws.readyState === WebSocket.OPEN) {
          ws.ping();
        }
      }
    }, this.pingInterval);
  }

  destroy(): void {
    if (this.intervalId) clearInterval(this.intervalId);
    for (const [userId] of this.clients) {
      this.removeClient(userId);
    }
    this.clients.clear();
    this.rooms.clear();
    this.heartbeats.clear();
  }
}

const port = parseInt(process.env.PORT ?? "8787", 10);

const server = createServer(getRequestListener(app.fetch));

const wss = new WebSocketServer({ server, path: "/ws" });
export const hub = new WebSocketHub(wss);

if (require.main === module) {
  server.listen(port, () => {
    console.log(`Neem backend listening on port ${port}`);
  });
}
