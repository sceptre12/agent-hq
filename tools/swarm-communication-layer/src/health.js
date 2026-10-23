/**
 * health.js — GET /health route handler
 * ESM module
 *
 * Returns structured health JSON reflecting current Turso connection and fallback state.
 * "degraded" when fallback is active (Turso unreachable).
 * Logs health_check event at debug level.
 */

import { getConnectionStatus, getClient } from './db.js';
import { isActive as isFallbackActive } from './fallback.js';
import logger from './logger.js';
import config from './config.js';

const START_TIME = Date.now();

/**
 * checkDbOk — cheap `SELECT 1` at request time. Returns false (never throws)
 * on any failure: no client yet, connection dropped, or query error.
 */
async function checkDbOk() {
  try {
    const client = getClient();
    if (!client) return false;
    await client.prepare('SELECT 1').get();
    return true;
  } catch {
    return false;
  }
}

/**
 * healthHandler — Express-compatible request handler for GET /health
 * @param {import('node:http').IncomingMessage} req
 * @param {import('node:http').ServerResponse} res
 */
export async function healthHandler(req, res) {
  const { connected } = getConnectionStatus();
  const fallback_active = isFallbackActive();
  const db_ok = await checkDbOk();
  const uptime_seconds = Math.floor((Date.now() - START_TIME) / 1000);

  const payload = {
    status: fallback_active || !db_ok ? 'degraded' : 'ok',
    turso: connected ? 'connected' : 'disconnected',
    fallback_active,
    db_ok,
    uptime_seconds,
    log_file: config.LOG_FILE_PATH,
    app_name: config.APP_NAME,
    data_dir: config.DATA_DIR,
    pid: process.pid,
  };

  logger.debug({ event: 'health_check', msg: 'Health check requested', data: payload });

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}
