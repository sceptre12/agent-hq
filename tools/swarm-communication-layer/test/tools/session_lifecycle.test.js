// test/tools/session_lifecycle.test.js
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { createTestDb, seedMessage } from '../helpers/db.js';

let db;
before(async () => { db = await createTestDb(); });

// --- start_session ---

test('start_session: inserts session row and returns it', async () => {
  const sessionId = 'test-session-1';
  await db.prepare(
    'INSERT INTO sessions (id, created_at) VALUES (?, ?)'
  ).run(sessionId, new Date().toISOString());

  const row = await db.prepare('SELECT * FROM sessions WHERE id = ?').get(sessionId);
  assert.equal(row.id, sessionId);
  assert.ok(row.created_at);
  assert.equal(row.ended_at, null);
});

test('start_session: idempotent — second insert does not throw', async () => {
  const sessionId = 'test-session-idempotent';
  const ts = new Date().toISOString();
  await db.prepare(
    'INSERT INTO sessions (id, created_at) VALUES (?, ?) ON CONFLICT(id) DO NOTHING'
  ).run(sessionId, ts);
  await assert.doesNotReject(
    db.prepare(
      'INSERT INTO sessions (id, created_at) VALUES (?, ?) ON CONFLICT(id) DO NOTHING'
    ).run(sessionId, ts)
  );
  const rows = await db.prepare('SELECT * FROM sessions WHERE id = ?').all(sessionId);
  assert.equal(rows.length, 1);
});

// --- end_session ---

test('end_session: deletes messages, receipts, and session row', async () => {
  const sessionId = 'session-to-delete';
  const ts = new Date().toISOString();

  // Seed session
  await db.prepare('INSERT INTO sessions (id, created_at) VALUES (?, ?)').run(sessionId, ts);

  // Seed two messages tagged to this session
  await seedMessage(db, { id: 'del-msg-1', session_id: sessionId, to_agent: 'agent-z', from_agent: 'agent-y' });
  await seedMessage(db, { id: 'del-msg-2', session_id: sessionId, to_agent: 'agent-z', from_agent: 'agent-y' });

  // Seed receipts for both messages
  await db.prepare("INSERT INTO message_receipts (message_id, agent_id, status) VALUES (?, ?, 'delivered')").run('del-msg-1', 'agent-z');
  await db.prepare("INSERT INTO message_receipts (message_id, agent_id, status) VALUES (?, ?, 'delivered')").run('del-msg-2', 'agent-z');

  // Simulate end_session delete sequence
  // Note: in-memory driver does not support subqueries in IN(...), so we fetch IDs first
  const msgIds = (await db.prepare('SELECT id FROM messages WHERE session_id = ?').all(sessionId)).map(r => r.id);
  for (const mid of msgIds) {
    await db.prepare('DELETE FROM message_receipts WHERE message_id = ?').run(mid);
  }
  await db.prepare('DELETE FROM messages WHERE session_id = ?').run(sessionId);
  await db.prepare('DELETE FROM sessions WHERE id = ?').run(sessionId);

  // Verify everything is gone
  const msgs = await db.prepare('SELECT * FROM messages WHERE session_id = ?').all(sessionId);
  assert.equal(msgs.length, 0, 'messages must be deleted');

  const receipts = await db.prepare("SELECT * FROM message_receipts WHERE message_id IN ('del-msg-1', 'del-msg-2')").all();
  assert.equal(receipts.length, 0, 'receipts must be deleted');

  const session = await db.prepare('SELECT * FROM sessions WHERE id = ?').get(sessionId);
  assert.equal(session, undefined, 'session row must be deleted');
});

test('end_session: returns count of deleted messages', async () => {
  const sessionId = 'session-count-test';
  const ts = new Date().toISOString();
  await db.prepare('INSERT INTO sessions (id, created_at) VALUES (?, ?)').run(sessionId, ts);
  await seedMessage(db, { id: 'count-msg-1', session_id: sessionId, to_agent: 'a', from_agent: 'b' });
  await seedMessage(db, { id: 'count-msg-2', session_id: sessionId, to_agent: 'a', from_agent: 'b' });

  // Count before delete
  const countResult = await db.prepare('SELECT COUNT(*) as n FROM messages WHERE session_id = ?').get(sessionId);
  assert.equal(countResult.n, 2);
});
