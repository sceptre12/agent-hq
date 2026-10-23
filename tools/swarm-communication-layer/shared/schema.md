# Schema — Swarm Communication Layer

---

## Tables

```sql
-- Session grouping (optional — orchestrators use for cleanup)
sessions(
  id          TEXT PRIMARY KEY,    -- UUID v4
  label       TEXT,                -- human-readable run description
  started_at  TEXT NOT NULL,       -- ISO 8601 UTC
  ended_at    TEXT                 -- NULL until end_session called
)

-- Pure content store — no status field
messages(
  id          TEXT PRIMARY KEY,    -- UUID v4 (agents may generate offline)
  topic       TEXT NOT NULL,       -- 'direct' for point-to-point, topic name for broadcast
  from_agent  TEXT NOT NULL,
  to_agent    TEXT,                -- NULL for broadcast messages
  content     TEXT NOT NULL,       -- plain text or JSON string
  timestamp   TEXT NOT NULL,       -- ISO 8601 UTC
  session_id  TEXT                 -- NULL for messages outside a session; FK -> sessions.id
)

-- Per-agent delivery tracking (fan-out on read)
message_receipts(
  message_id  TEXT NOT NULL,       -- FK -> messages.id
  agent_id    TEXT NOT NULL,
  status      TEXT NOT NULL,       -- 'pending', 'delivered', 'read'
  PRIMARY KEY (message_id, agent_id)
)
```

`message_receipts` is the sole status authority for all messages. `messages` holds content only — no status column. Every message (direct or broadcast) has at least one receipt row.

`session_id` on `messages` is nullable for backward compatibility — old messages without a session tag must not be pruned by `end_session`. Session grouping is optional; agents tag messages voluntarily.

Fan-out on write was rejected — recipient list is dynamic and retrofitting delivery tracking requires a live migration.

---

## Indexes

```sql
CREATE INDEX idx_messages_to_agent_timestamp ON messages(to_agent, timestamp);
CREATE INDEX idx_messages_topic_timestamp ON messages(topic, timestamp);
CREATE INDEX idx_messages_timestamp ON messages(timestamp);
CREATE INDEX idx_receipts_agent_status ON message_receipts(agent_id, status);
```

---

## Initialization

Schema runs on every startup via `db.js:initSchema()` — idempotent DDL, repeated startups are a no-op. No separate migration command. `schema.sql` is at the project root; `db.js` resolves it via `new URL('../schema.sql', import.meta.url)`.

---

## Evolution Policy

- Additive (new columns): `ALTER TABLE ... ADD COLUMN` (libSQL supports this)
- New tables: `CREATE TABLE IF NOT EXISTS`
- Rename or type change: adopt a migration tool at that point
