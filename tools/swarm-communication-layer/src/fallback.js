/**
 * fallback.js — NDJSON fallback write buffer and sync-on-reconnect protocol
 * ESM module
 *
 * p-queue (v8, ESM) with concurrency 1 serializes concurrent fs.appendFile calls.
 * The sync protocol is triggered by db.js when Turso reconnects.
 *
 * State flags:
 *   fallback_active   — true when Turso is unreachable and writes are being buffered
 *   fallback_draining — true during sync; new fallback writes are rejected while draining
 */

import { appendFile, readFile, writeFile, rename } from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';
import PQueue from 'p-queue';
import config from './config.js';
import logger from './logger.js';
import { makeError, ERROR_CODES } from './errors.js';

// ---------------------------------------------------------------------------
// p-queue instance — concurrency 1 to serialize appendFile calls
// ---------------------------------------------------------------------------

const queue = new PQueue({ concurrency: 1 });

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let fallback_active = false;
let fallback_draining = false;

export function isActive() {
  return fallback_active;
}

export function isDraining() {
  return fallback_draining;
}

export function activate() {
  fallback_active = true;
}

// ---------------------------------------------------------------------------
// write(messageObj)
// Appends a single message object as a JSON line to the fallback NDJSON file.
// Rejects writes while draining (sync in progress).
// ---------------------------------------------------------------------------

export async function write(messageObj) {
  if (fallback_draining) {
    return makeError(ERROR_CODES.RECONNECTING, 'Fallback buffer is draining — retry in 1-2 seconds.');
  }

  return queue.add(async () => {
    try {
      const line = JSON.stringify(messageObj) + '\n';
      await appendFile(config.FALLBACK_FILE_PATH, line, 'utf8');
      logger.debug({ event: 'fallback_write', msg: 'Message written to fallback buffer', data: { id: messageObj.id } });
      return { ok: true };
    } catch (err) {
      logger.error({ event: 'fallback_write_error', msg: 'Failed to write to fallback file', data: { error: err.message } });
      return makeError(ERROR_CODES.FALLBACK_WRITE_FAILED, err.message);
    }
  });
}

// ---------------------------------------------------------------------------
// sync(dbExecute)
// Full Fallback Sync Protocol — see architecture.md for step-by-step spec.
// Called by db.js reconnect loop on Turso reconnect.
// ---------------------------------------------------------------------------

export async function sync(dbExecute) {
  // Step 1: Set fallback_draining — reject new fallback writes
  fallback_draining = true;

  // Step 2: Drain the p-queue
  await drainQueue();

  // Step 3 & 4: Read NDJSON file line by line and batch
  let lines;
  try {
    lines = await readLines(config.FALLBACK_FILE_PATH);
  } catch (err) {
    // File may not exist if no messages were ever written to fallback
    if (err.code === 'ENOENT') {
      finishSync();
      return;
    }
    throw err;
  }

  if (lines.length === 0) {
    finishSync();
    return;
  }

  const batches = chunkArray(lines, config.FALLBACK_SYNC_BATCH_SIZE);
  let fullSuccess = true;

  for (const batch of batches) {
    const validRecords = [];
    const deadLetterLines = [];

    for (const line of batch) {
      try {
        const record = JSON.parse(line);
        if (!record.id || !record.topic || !record.from_agent || !record.content || !record.timestamp) {
          throw new Error('Missing required fields');
        }
        validRecords.push(record);
      } catch {
        logger.warn({ event: 'fallback_sync_malformed', msg: 'Malformed fallback record — routing to dead letter file', data: { line } });
        deadLetterLines.push(line);
      }
    }

    // Append malformed records to dead letter file
    if (deadLetterLines.length > 0) {
      try {
        await appendFile(config.FALLBACK_FILE_PATH + '.error', deadLetterLines.join('\n') + '\n', 'utf8');
      } catch (dlErr) {
        logger.error({ event: 'fallback_dead_letter_error', msg: 'Failed to write to dead letter file', data: { error: dlErr.message } });
      }
    }

    // Step 5: INSERT OR IGNORE per batch with retry
    if (validRecords.length > 0) {
      const batchSuccess = await insertBatchWithRetry(validRecords, dbExecute);
      if (!batchSuccess) {
        fullSuccess = false;
        break; // Step 6: abort sync on persistent failure — retry on next reconnect
      }
    }
  }

  // Step 7: Truncate fallback file only on full success
  if (fullSuccess) {
    try {
      await writeFile(config.FALLBACK_FILE_PATH, '', 'utf8');
    } catch (truncErr) {
      logger.error({ event: 'fallback_truncate_error', msg: 'Failed to truncate fallback file', data: { error: truncErr.message } });
    }
  }

  finishSync(fullSuccess);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function drainQueue() {
  if (queue.size === 0 && queue.pending === 0) return Promise.resolve();
  return queue.onIdle();
}

async function readLines(filePath) {
  const content = await readFile(filePath, 'utf8');
  return content.split('\n').filter((line) => line.trim().length > 0);
}

function chunkArray(arr, size) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

async function insertBatchWithRetry(records, dbExecute, attempt = 0) {
  const MAX_RETRIES = 3;
  const BASE_DELAY_MS = 200;

  try {
    for (const record of records) {
      await dbExecute(
        'INSERT OR IGNORE INTO messages (id, topic, from_agent, to_agent, content, timestamp) VALUES (?, ?, ?, ?, ?, ?)',
        [record.id, record.topic, record.from_agent, record.to_agent ?? null, record.content, record.timestamp],
        { isWrite: true },
      );
    }
    return true;
  } catch (err) {
    if (attempt < MAX_RETRIES) {
      const delay = BASE_DELAY_MS * Math.pow(2, attempt);
      logger.warn({ event: 'fallback_sync_retry', msg: `Batch insert failed, retrying (attempt ${attempt + 1}/${MAX_RETRIES})`, data: { error: err.message, delay } });
      await sleep(delay);
      return insertBatchWithRetry(records, dbExecute, attempt + 1);
    }

    logger.error({ event: 'fallback_sync_error', msg: 'Batch insert failed after max retries — aborting sync', data: { error: err.message } });
    return false;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function finishSync(success = true) {
  fallback_draining = false;
  if (success) {
    fallback_active = false;
    logger.info({ event: 'fallback_deactivated', msg: 'Fallback deactivated — Turso sync complete', data: {} });
  } else {
    // Keep fallback active — Turso reconnect loop will retry on next poll
    logger.warn({ event: 'fallback_sync_incomplete', msg: 'Sync incomplete — fallback remains active', data: {} });
  }
}
