import dotenv from "dotenv";
dotenv.config();

import { D1Service } from "./services/d1.service";

const d1 = new D1Service(
  process.env.D1_ACCOUNT_ID ?? "",
  process.env.D1_DATABASE_ID ?? "",
  process.env.D1_API_TOKEN ?? ""
);

const statements = [
  `CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    phone_number TEXT NOT NULL UNIQUE,
    name TEXT,
    display_name TEXT,
    handle TEXT UNIQUE,
    city TEXT,
    zone TEXT,
    interests TEXT DEFAULT '[]',
    trust_score REAL DEFAULT 0.0,
    avatar_url TEXT,
    is_anonymous INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT
  );`,

  `CREATE TABLE IF NOT EXISTS otp_requests (
    id TEXT PRIMARY KEY,
    phone_number TEXT NOT NULL,
    request_id TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    verified INTEGER DEFAULT 0
  );`,

  `CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    refresh_token_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );`,

  `CREATE TABLE IF NOT EXISTS posts (
    id TEXT PRIMARY KEY,
    author_id TEXT NOT NULL,
    category TEXT DEFAULT 'general',
    city TEXT,
    zone TEXT,
    content TEXT NOT NULL,
    is_anonymous INTEGER DEFAULT 0,
    upvote_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    is_blocked INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT,
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
  );`,

  `CREATE TABLE IF NOT EXISTS post_replies (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL,
    author_id TEXT NOT NULL,
    content TEXT NOT NULL,
    city TEXT,
    zone TEXT,
    upvote_count INTEGER DEFAULT 0,
    parent_reply_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
  );`,

  `CREATE TABLE IF NOT EXISTS upvotes (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(post_id, user_id)
  );`,

  `CREATE TABLE IF NOT EXISTS bookmarks (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    post_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(user_id, post_id)
  );`,

  `CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL,
    reporter_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(post_id, reporter_id)
  );`,

  `CREATE TABLE IF NOT EXISTS blocked_posts (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(post_id, user_id)
  );`,

  `CREATE TABLE IF NOT EXISTS circles (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    city TEXT,
    zone TEXT,
    creator_id TEXT NOT NULL,
    total_seats INTEGER NOT NULL DEFAULT 0,
    seats_left INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    event_date TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT,
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE
  );`,

  `CREATE TABLE IF NOT EXISTS circle_members (
    id TEXT PRIMARY KEY,
    circle_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    joined_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(circle_id, user_id)
  );`,

  `CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );`,

  `CREATE TABLE IF NOT EXISTS conversation_participants (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    joined_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_read_at TEXT,
    left_at TEXT,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(conversation_id, user_id)
  );`,

  `CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    content TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'text',
    media_url TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
  );`,

  `CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data TEXT DEFAULT '{}',
    is_read INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );`,

  `CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);`,
  `CREATE INDEX IF NOT EXISTS idx_otp_requests_req ON otp_requests(id);`,
  `CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);`,
  `CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at);`,
  `CREATE INDEX IF NOT EXISTS idx_circles_creator ON circles(creator_id);`,
  `CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id);`,
  `CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);`
];

async function migrate() {
  console.log("Starting D1 database migration...");
  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i];
    try {
      await d1.run(stmt);
      console.log(`[${i + 1}/${statements.length}] Applied statement successfully.`);
    } catch (err: any) {
      console.error(`Error applying statement ${i + 1}:`, err.message);
      throw err;
    }
  }
  console.log("All migrations applied successfully!");
}

migrate().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
