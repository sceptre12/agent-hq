// test/tools/db_resilience.test.js
//
// Durability hardening pass 1:
//  - createDbClient() sets busy_timeout at connect and enforces WAL journal
//    mode (belt-and-suspenders — WAL is this engine's connect-time default,
//    but we assert it explicitly rather than trust an undocumented default).
//  - cleanupOrphanSessions() removes sessions with no activity in N days,
//    and only those — recently-created or recently-active sessions survive.
//
// Uses a real file-backed DB (not :memory:) because WAL/-wal sidecar
// behavior does not apply to in-memory databases.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

// config.js reads DATA_DIR from process.env at import time (see health.test.js
// for the same pattern) — must be set before db.js/config.js are imported.
const tmpDir = mkdtempSync(path.join(tmpdir(), 'swarm-mcp-db-resilience-'));
process.env.DATA_DIR = tmpDir;

const { createDbClient, initSchema, getClient, cleanupOrphanSessions } = await import('../../src/db.js');

before(async () => {
  await createDbClient();
  await initSchema();
});

after(() => {
  rmSync(tmpDir, { recursive: true, force: true });
});

test('createDbClient: journal_mode is WAL', async () => {
  const rows = await getClient().prepare('PRAGMA journal_mode').all();
  assert.equal(rows[0].journal_mode, 'wal');
});

test('createDbClient: busy_timeout is set to 5000ms', async () => {
  const rows = await getClient().prepare('PRAGMA busy_timeout').all();
  assert.equal(rows[0].busy_timeout, 5000);
});

test('cleanupOrphanSessions: removes a session with no messages older than the cutoff', async () => {
  const db = getClient();
  const oldTs = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
  await db.prepare('INSERT INTO sessions (id, created_at) VALUES (?, ?)').run('orphan-no-messages', oldTs);

  const removed = await cleanupOrphanSessions();
  assert.ok(removed >= 1);

  const row = await db.prepare('SELECT id FROM sessions WHERE id = ?').get('orphan-no-messages');
  assert.equal(row, undefined);
});

test('cleanupOrphanSessions: keeps a recently-created session even with no messages', async () => {
  const db = getClient();
  const recentTs = new Date().toISOString();
  await db.prepare('INSERT INTO sessions (id, created_at) VALUES (?, ?)').run('fresh-session', recentTs);

  await cleanupOrphanSessions();

  const row = await db.prepare('SELECT id FROM sessions WHERE id = ?').get('fresh-session');
  assert.ok(row, 'recently-created session must survive cleanup');

  // cleanup for subsequent tests
  await db.prepare('DELETE FROM sessions WHERE id = ?').run('fresh-session');
});

test('cleanupOrphanSessions: keeps an old session that has a recent message, and deletes its messages/receipts when it does age out', async () => {
  const db = getClient();
  const oldTs = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
  const recentTs = new Date().toISOString();

  await db.prepare('INSERT INTO sessions (id, created_at) VALUES (?, ?)').run('old-session-recent-activity', oldTs);
  await db.prepare(
    'INSERT INTO messages (id, topic, from_agent, to_agent, content, timestamp, session_id) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).run('msg-recent-activity', 'direct', 'a', 'b', 'hi', recentTs, 'old-session-recent-activity');

  await cleanupOrphanSessions();

  const row = await db.prepare('SELECT id FROM sessions WHERE id = ?').get('old-session-recent-activity');
  assert.ok(row, 'session with recent message activity must survive cleanup despite an old created_at');

  // Now age the message out too and confirm the session (and its message) gets removed.
  const veryOldTs = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
  await db.prepare('UPDATE messages SET timestamp = ? WHERE id = ?').run(veryOldTs, 'msg-recent-activity');

  const removed = await cleanupOrphanSessions();
  assert.ok(removed >= 1);

  const sessionRow = await db.prepare('SELECT id FROM sessions WHERE id = ?').get('old-session-recent-activity');
  assert.equal(sessionRow, undefined);
  const msgRow = await db.prepare('SELECT id FROM messages WHERE id = ?').get('msg-recent-activity');
  assert.equal(msgRow, undefined, 'orphaned session messages must be deleted too');
});
