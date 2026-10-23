-- Swarm Communication Layer — Idempotent DDL
-- Safe to run on every startup: CREATE TABLE/INDEX IF NOT EXISTS ensures no-op on re-run.

-- Core messages table (pure content store — no status field)
CREATE TABLE IF NOT EXISTS messages (
  id          TEXT PRIMARY KEY,    -- UUID v4 (agents may generate offline)
  topic       TEXT NOT NULL,       -- 'direct' for point-to-point, topic name for broadcast
  from_agent  TEXT NOT NULL,       -- sender identity
  to_agent    TEXT,                -- NULL for broadcast messages
  content     TEXT NOT NULL,       -- message body (plain text or JSON string)
  timestamp   TEXT NOT NULL        -- ISO 8601 UTC
);

-- Per-agent delivery tracking (fan-out on read model)
CREATE TABLE IF NOT EXISTS message_receipts (
  message_id  TEXT NOT NULL,       -- FK -> messages.id
  agent_id    TEXT NOT NULL,       -- recipient agent
  status      TEXT NOT NULL,       -- 'pending', 'delivered', 'read'
  PRIMARY KEY (message_id, agent_id)
);

-- Indexes for efficient query patterns
CREATE INDEX IF NOT EXISTS idx_messages_to_agent_timestamp ON messages(to_agent, timestamp);
CREATE INDEX IF NOT EXISTS idx_messages_topic_timestamp ON messages(topic, timestamp);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp);
CREATE INDEX IF NOT EXISTS idx_receipts_agent_status ON message_receipts(agent_id, status);

-- Session lifecycle tracking
CREATE TABLE IF NOT EXISTS sessions (
  id          TEXT PRIMARY KEY,
  created_at  TEXT NOT NULL,
  ended_at    TEXT
);

-- Session scoping on messages:
-- ALTER TABLE messages ADD COLUMN session_id TEXT is NOT idempotent in SQLite.
-- That migration + its index are run in initSchema() (db.js) and createTestDb() (test/helpers/db.js)
-- with a duplicate-column guard so the server can restart against an existing DB.
