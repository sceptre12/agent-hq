import path from 'node:path';

const DATA_DIR = path.resolve(process.env.DATA_DIR ?? './data');
const APP_NAME = process.env.APP_NAME ?? 'swarm-mcp';
const BIND_HOST = process.env.BIND_HOST ?? '127.0.0.1';

const PORT_RANGE_START = parseInt(
  process.env.PORT_RANGE_START ?? process.env.PORT_HINT ?? process.env.PORT ?? '7777',
  10,
);
const PORT_HINT = parseInt(
  process.env.PORT_HINT ?? process.env.PORT_RANGE_START ?? process.env.PORT ?? '7777',
  10,
);
const PORT_RANGE_END = parseInt(process.env.PORT_RANGE_END ?? '7800', 10);

function resolveDbUrl(raw) {
  const stripped = raw.startsWith('file:') ? raw.slice(5) : raw;
  return path.isAbsolute(stripped) ? stripped : path.resolve(stripped);
}

const TURSO_DATABASE_URL = resolveDbUrl(
  process.env.TURSO_DATABASE_URL ?? path.join(DATA_DIR, 'swarm.db'),
);
const LOG_FILE_PATH = path.resolve(
  process.env.LOG_FILE_PATH ?? path.join(DATA_DIR, 'logs', 'server.log'),
);
const FALLBACK_FILE_PATH = path.resolve(
  process.env.FALLBACK_FILE_PATH ?? path.join(DATA_DIR, 'fallback.ndjson'),
);

const NODE_ENV = process.env.NODE_ENV ?? 'development';
const RECONNECT_POLL_INTERVAL = parseInt(process.env.RECONNECT_POLL_INTERVAL ?? '5000', 10);
const FALLBACK_SYNC_BATCH_SIZE = parseInt(process.env.FALLBACK_SYNC_BATCH_SIZE ?? '50', 10);

const config = Object.freeze({
  DATA_DIR,
  APP_NAME,
  BIND_HOST,
  PORT_HINT,
  PORT_RANGE_START,
  PORT_RANGE_END,
  TURSO_DATABASE_URL,
  LOG_FILE_PATH,
  FALLBACK_FILE_PATH,
  NODE_ENV,
  RECONNECT_POLL_INTERVAL,
  FALLBACK_SYNC_BATCH_SIZE,
});

export default config;
