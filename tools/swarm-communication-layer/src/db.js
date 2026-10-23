import { readFile } from 'node:fs/promises';
import { connect } from '@tursodatabase/database';
import config from './config.js';
import logger from './logger.js';
import { makeError, ERROR_CODES } from './errors.js';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let db = null;
let connected = false;
let reconnectTimer = null;

// Lazy import to break circular dep: fallback imports db, db imports fallback only in reconnect path
let fallbackModule = null;

async function getFallback() {
  if (!fallbackModule) {
    fallbackModule = await import('./fallback.js');
  }
  return fallbackModule;
}

// ---------------------------------------------------------------------------
// Client initialisation
//
// Resilience: busy_timeout (~5s) is passed at connect() so concurrent-writer
// contention retries internally instead of surfacing SQLITE_BUSY immediately.
// journal_mode=WAL is this engine's connect-time default (verified empirically
// against @tursodatabase/database 0.2.2 — a fresh file-backed connection reports
// `PRAGMA journal_mode` = 'wal' with no pragma issued); the explicit PRAGMA below
// is defense-in-depth in case that default ever changes upstream, and is a cheap
// no-op when it's already WAL.
// ---------------------------------------------------------------------------

const BUSY_TIMEOUT_MS = 5000;

export async function createDbClient() {
  db = await connect(config.TURSO_DATABASE_URL, { timeout: BUSY_TIMEOUT_MS });
  await db.exec('PRAGMA journal_mode=WAL;');
  return db;
}

// ---------------------------------------------------------------------------
// execute() abstraction
// Reads return { rows: [] }. Writes return { changes: n }.
// If fallback is active, write callers receive null (they check fallback.isActive()).
// Read failures when disconnected return a structured error.
// ---------------------------------------------------------------------------

export async function execute(sql, args = [], { isWrite = false } = {}) {
  const fallback = await getFallback();

  if (!connected) {
    if (isWrite && fallback.isActive()) {
      return null;
    }
    return { error: makeError(ERROR_CODES.DB_READ_FAILED, 'DB is unavailable and this operation cannot be buffered.') };
  }

  try {
    const stmt = db.prepare(sql);
    if (isWrite) {
      const result = await stmt.run(...args);
      return result; // { changes, lastInsertRowid }
    } else {
      const rows = await stmt.all(...args);
      return { rows };
    }
  } catch (err) {
    logger.error({ event: 'db_execute_error', msg: 'DB execute failed', data: { sql, error: err.message } });

    if (isWrite) {
      if (!fallback.isActive()) {
        fallback.activate();
        logger.warn({ event: 'fallback_activated', msg: 'DB write failed — fallback buffer activated', data: {} });
      }
      connected = false;
      startReconnectLoop();
      return null;
    }

    return { error: makeError(ERROR_CODES.DB_READ_FAILED, err.message) };
  }
}

// ---------------------------------------------------------------------------
// Schema initialisation — idempotent, runs on every startup
// ---------------------------------------------------------------------------

export async function initSchema() {
  if (!db) throw new Error('DB client not initialised before initSchema()');

  const schemaPath = new URL('../schema.sql', import.meta.url).pathname;
  const sql = await readFile(schemaPath, 'utf8');

  await db.exec(sql);

  // ALTER TABLE is not idempotent in SQLite — ignore "duplicate column" on re-run
  try {
    await db.exec('ALTER TABLE messages ADD COLUMN session_id TEXT;');
  } catch (err) {
    if (!err.message.includes('duplicate column name')) throw err;
  }
  await db.exec(
    'CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);'
  );

  connected = true;
  logger.info({ event: 'turso_connected', msg: 'DB connected and schema initialised', data: { url: config.TURSO_DATABASE_URL } });
}

// ---------------------------------------------------------------------------
// Orphan-session hygiene — startup-only, best-effort
//
// A session is "orphaned" once none of its activity (its own created_at, or
// any message filed under it) falls within the last ORPHAN_SESSION_MAX_AGE_MS.
// Sessions with no messages at all age out purely on created_at (the "started
// but never used" case).
//
// Turso does not support EXISTS/IN-subqueries in WHERE clauses (confirmed
// empirically: "Parse error: EXISTS in WHERE clause is not supported" — same
// constraint end_session.js works around for its IN-subquery). So candidate
// selection and the recent-activity check are both done as flat queries,
// looped per candidate; only sessions older than the cutoff are ever
// candidates, so this stays cheap in practice.
// ---------------------------------------------------------------------------

const ORPHAN_SESSION_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

export async function cleanupOrphanSessions(maxAgeMs = ORPHAN_SESSION_MAX_AGE_MS) {
  if (!db) throw new Error('DB client not initialised before cleanupOrphanSessions()');

  const cutoff = new Date(Date.now() - maxAgeMs).toISOString();

  const candidates = await db
    .prepare('SELECT id FROM sessions WHERE created_at < ?')
    .all(cutoff);

  const staleIds = [];
  for (const { id: sessionId } of candidates) {
    const recentActivity = await db
      .prepare('SELECT COUNT(*) as n FROM messages WHERE session_id = ? AND timestamp >= ?')
      .get(sessionId, cutoff);
    if (!recentActivity || recentActivity.n === 0) {
      staleIds.push(sessionId);
    }
  }

  if (staleIds.length === 0) return 0;

  for (const sessionId of staleIds) {
    const msgIdsResult = await db
      .prepare('SELECT id FROM messages WHERE session_id = ?')
      .all(sessionId);

    for (const { id: msgId } of msgIdsResult) {
      await db.prepare('DELETE FROM message_receipts WHERE message_id = ?').run(msgId);
    }
    await db.prepare('DELETE FROM messages WHERE session_id = ?').run(sessionId);
    await db.prepare('DELETE FROM sessions WHERE id = ?').run(sessionId);
  }

  logger.info({
    event: 'orphan_sessions_cleaned',
    msg: `Removed ${staleIds.length} orphaned session(s) with no activity in ${Math.round(maxAgeMs / 86400000)}d`,
    data: { count: staleIds.length },
  });

  return staleIds.length;
}

// ---------------------------------------------------------------------------
// Connection status
// ---------------------------------------------------------------------------

export function getConnectionStatus() {
  return { connected };
}

export function getClient() {
  return db;
}

// ---------------------------------------------------------------------------
// Reconnect loop — polls SELECT 1 every RECONNECT_POLL_INTERVAL ms
// ---------------------------------------------------------------------------

export function startReconnectLoop() {
  if (reconnectTimer !== null) return;

  reconnectTimer = setInterval(async () => {
    if (connected) {
      clearInterval(reconnectTimer);
      reconnectTimer = null;
      return;
    }

    try {
      if (!db) return;
      await db.prepare('SELECT 1').get();

      logger.info({ event: 'turso_connected', msg: 'DB reconnected — starting fallback sync', data: {} });

      const fallback = await getFallback();

      if (fallback.isActive()) {
        try {
          logger.info({ event: 'fallback_sync_start', msg: 'Beginning fallback sync', data: {} });
          await fallback.sync(execute);
          logger.info({ event: 'fallback_sync_complete', msg: 'Fallback sync complete', data: {} });
        } catch (syncErr) {
          logger.error({ event: 'fallback_sync_error', msg: 'Fallback sync failed', data: { error: syncErr.message } });
        }
      }

      connected = true;
      clearInterval(reconnectTimer);
      reconnectTimer = null;
    } catch {
      // Still down — keep polling
    }
  }, config.RECONNECT_POLL_INTERVAL);
}

export function stopReconnectLoop() {
  if (reconnectTimer !== null) {
    clearInterval(reconnectTimer);
    reconnectTimer = null;
  }
}
