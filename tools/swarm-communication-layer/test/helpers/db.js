// test/helpers/db.js
import { connect } from '@tursodatabase/database';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function createTestDb() {
  const db = await connect(':memory:');
  const schemaPath = path.resolve(__dirname, '../../schema.sql');
  const sql = await readFile(schemaPath, 'utf8');
  await db.exec(sql);
  // ALTER TABLE is not in schema.sql (not idempotent); run it here for fresh test DBs
  try {
    await db.exec('ALTER TABLE messages ADD COLUMN session_id TEXT;');
  } catch (err) {
    if (!err.message.includes('duplicate column name')) throw err;
  }
  await db.exec(
    'CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);'
  );
  return db;
}

export async function seedMessage(db, overrides = {}) {
  const msg = {
    id: overrides.id ?? 'msg-1',
    topic: overrides.topic ?? 'direct',
    from_agent: overrides.from_agent ?? 'sender',
    to_agent: overrides.to_agent ?? 'receiver',
    content: overrides.content ?? 'hello',
    timestamp: overrides.timestamp ?? new Date().toISOString(),
    session_id: overrides.session_id ?? null,
  };
  await db.prepare(
    'INSERT INTO messages (id, topic, from_agent, to_agent, content, timestamp, session_id) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).run(msg.id, msg.topic, msg.from_agent, msg.to_agent, msg.content, msg.timestamp, msg.session_id);
  return msg;
}
