import { createServer } from 'node:http';
import { mkdirSync } from 'node:fs';
import fs from 'node:fs/promises';
import path, { dirname } from 'node:path';
import { randomUUID } from 'node:crypto';
import { portNumbers } from 'get-port';

import config from './config.js';
import { setResolvedPort } from './instance-identity.js';

mkdirSync(config.DATA_DIR, { recursive: true });
mkdirSync(dirname(config.LOG_FILE_PATH), { recursive: true });
mkdirSync(dirname(config.FALLBACK_FILE_PATH), { recursive: true });

import logger from './logger.js';
import {
  createDbClient,
  initSchema,
  startReconnectLoop,
  stopReconnectLoop,
  getClient,
  cleanupOrphanSessions,
} from './db.js';
import { healthHandler } from './health.js';
import * as fallback from './fallback.js';
import { createMcpServer } from './mcp-server.js';
import { trackRequest, beginShutdown, getInFlightCount, onDrain } from './request-tracker.js';

import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

// Resolved at startup — see start()
let resolvedPort;

const httpServer = createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${resolvedPort}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    if (!trackRequest(res)) return;
    await healthHandler(req, res);
    return;
  }

  if (url.pathname === '/mcp') {
    if (!trackRequest(res)) return;

    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined, // stateless mode
    });

    try {
      const mcpServer = createMcpServer();
      await mcpServer.connect(transport);
      await transport.handleRequest(req, res);
    } catch (err) {
      logger.error({ event: 'mcp_request_error', msg: 'MCP request failed', data: { error: err.message } });
      if (!res.headersSent) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Internal server error' }));
      }
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});


process.on('SIGTERM', async () => {
  logger.info({ event: 'server_shutdown', msg: 'SIGTERM received — starting graceful shutdown', data: {} });

  // Step 1: Stop accepting new connections
  beginShutdown();
  httpServer.close();

  // Step 2: Drain in-flight tool calls (5s timeout)
  await new Promise((resolve) => {
    if (getInFlightCount() === 0) {
      resolve();
      return;
    }
    const timeout = setTimeout(() => {
      logger.warn({ event: 'server_shutdown', msg: 'Drain timeout reached — forcing shutdown', data: { inFlightCount: getInFlightCount() } });
      resolve();
    }, 5000);
    onDrain(() => {
      clearTimeout(timeout);
      resolve();
    });
  });

  // Step 3: Flush fallback write queue
  try {
    if (fallback.isActive() && !fallback.isDraining()) {
      // Wait for any queued fallback writes to complete (p-queue drains naturally)
      // We don't call sync() here — that requires Turso; defer to next startup
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
  } catch (err) {
    logger.warn({ event: 'server_shutdown', msg: 'Error flushing fallback queue', data: { error: err.message } });
  }

  // Step 4: Stop reconnection loop and close Turso connection
  stopReconnectLoop();
  try {
    const dbClient = getClient();
    if (dbClient && typeof dbClient.close === 'function') {
      await dbClient.close();
    }
  } catch (err) {
    logger.warn({ event: 'server_shutdown', msg: 'Error closing Turso connection', data: { error: err.message } });
  }

  // Step 5: Flush log (pino flushes on process exit; explicit flush for file transport)
  if (typeof logger.flush === 'function') {
    logger.flush();
  }

  // Step 6: Exit
  process.exit(0);
});


// Step 2/6: Bind the HTTP server exclusively to the first free port in the configured
// range. `exclusive: true` forces a real, dedicated OS-level bind on every attempt —
// it refuses to join a pre-existing shared listen handle (the behavior that let
// same-port sibling processes, including unrelated pm2 cluster-mode apps, silently
// multiplex onto one socket). A get-port-style "probe, release, hope nobody else
// grabs it" check is inherently racy across processes (get-port's own `reserve`
// option is documented as process-local only — see node_modules/get-port/index.js);
// binding directly and reacting to the real EADDRINUSE is the only exclusive method.
async function bindExclusive(host, start, end) {
  let lastErr;
  for (const port of portNumbers(start, end)) {
    try {
      await new Promise((resolve, reject) => {
        const onError = (err) => {
          httpServer.removeListener('listening', onListening);
          reject(err);
        };
        const onListening = () => {
          httpServer.removeListener('error', onError);
          resolve();
        };
        httpServer.once('error', onError);
        httpServer.once('listening', onListening);
        httpServer.listen({ port, host, exclusive: true });
      });
      return port;
    } catch (err) {
      if (err.code !== 'EADDRINUSE') throw err;
      lastErr = err;
      // Port genuinely taken (by this or any other process) — walk to the next candidate.
    }
  }
  throw new Error(
    `No free port available in range ${start}-${end} on ${host}: ${lastErr ? lastErr.message : 'range exhausted'}`,
  );
}

// pino's file transport (NODE_ENV=production) writes via a worker thread —
// calling process.exit() right after logger.error() can terminate the process
// before that write lands, silently losing the one diagnostic we need most.
// flushLogger() waits for pino to drain (bounded, so a stuck transport can
// never hang shutdown).
function flushLogger() {
  return new Promise((resolve) => {
    if (typeof logger.flush !== 'function') {
      resolve();
      return;
    }
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      resolve();
    };
    logger.flush(finish);
    setTimeout(finish, 2000);
  });
}

// Fail-loud DB open: no retry loop, no silent partial start. On failure this
// logs exactly one structured diagnostic (path + best-available error code +
// a likely-cause heuristic) and exits non-zero so pm2/the operator sees a
// clean crash instead of a server that limps along without a database.
async function connectDbOrExit() {
  try {
    await createDbClient();
  } catch (err) {
    const msg = err.message ?? String(err);
    let likelyCause = 'unknown — see message/code above';
    if (/locked|busy/i.test(msg)) {
      likelyCause = 'database file is locked by another process (check for a stale/duplicate swarm-mcp instance)';
    } else if (/not found|no such file/i.test(msg)) {
      likelyCause = 'DATA_DIR/db path or its parent directory does not exist';
    } else if (/is a directory/i.test(msg)) {
      likelyCause = 'TURSO_DATABASE_URL points at a directory, not a file';
    } else if (/permission|denied|EACCES|EPERM/i.test(msg)) {
      likelyCause = 'insufficient filesystem permissions on the db path';
    }

    const diagnostic = {
      event: 'db_startup_failed',
      msg: 'Fatal: could not open database at startup — exiting (no retry)',
      data: {
        path: config.TURSO_DATABASE_URL,
        code: err.code ?? null,
        errno: err.errno ?? null,
        message: msg,
        likely_cause: likelyCause,
      },
    };
    logger.error(diagnostic);
    // Redundant synchronous copy to stderr (captured by pm2's error_file):
    // guarantees the diagnostic survives even if the async file transport
    // above doesn't finish draining before exit.
    // eslint-disable-next-line no-console
    console.error('[swarm-mcp] Fatal startup error (db):', JSON.stringify(diagnostic));
    await flushLogger();
    process.exit(1);
  }
}

async function start() {
  // Step 3: Connect to Turso, run initSchema()
  await connectDbOrExit();
  await initSchema();

  // Orphan-session hygiene — best-effort, non-fatal. A failure here means
  // stale rows persist (harmless) rather than blocking startup.
  try {
    await cleanupOrphanSessions();
  } catch (err) {
    logger.warn({ event: 'orphan_session_cleanup_error', msg: 'Orphan-session cleanup failed — continuing startup', data: { error: err.message } });
  }

  // Step 4: Start reconnection loop (begins polling only when Turso fails)
  startReconnectLoop();

  // Step 6: Bind exclusively — never silently share a port with another process.
  resolvedPort = await bindExclusive(config.BIND_HOST, config.PORT_RANGE_START, config.PORT_RANGE_END);
  setResolvedPort(resolvedPort);

  // Guard against post-bind runtime socket errors (e.g. EMFILE) crashing hard/uncaught.
  httpServer.on('error', (err) => {
    logger.error({ event: 'server_error', msg: 'HTTP server error', data: { error: err.message, code: err.code } });
  });

  // Step 7: Write resolved port to $DATA_DIR/port
  await fs.writeFile(path.join(config.DATA_DIR, 'port'), String(resolvedPort));

  // Step 8: Signal pm2 readiness
  if (process.send) {
    process.send('ready');
  }

  // Step 9: Log server_start
  logger.info({
    event: 'server_start',
    msg: `swarm-mcp listening on port ${resolvedPort}`,
    data: {
      port: resolvedPort,
      db: config.TURSO_DATABASE_URL,
      fallback: config.FALLBACK_FILE_PATH,
      node_env: config.NODE_ENV,
    },
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('[swarm-mcp] Fatal startup error:', err);
  process.exit(1);
});
