/**
 * broadcast.js — MCP tool: broadcast
 * ESM module
 *
 * Sends a broadcast message to a topic. Sets to_agent = NULL — recipients consume
 * via read_messages({ topics: ['<topic>'] }) using lazy fan-out on read.
 *
 * Never throws — returns structured errors via makeError().
 *
 * Returns: { id, timestamp, topic, status: "sent" | "queued" }
 */

import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { execute } from '../db.js';
import * as fallback from '../fallback.js';
import { makeError, ERROR_CODES } from '../errors.js';
import logger from '../logger.js';
import { withIdentity } from '../response.js';

// ---------------------------------------------------------------------------
// Input schema
// ---------------------------------------------------------------------------

const BroadcastSchema = z.object({
  from_agent: z.string({ required_error: 'from_agent is required' }),
  topic: z.string({ required_error: 'topic is required' }),
  content: z.string({ required_error: 'content is required' }),
  session_id: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

async function broadcastHandler(input) {
  // Validate input
  const parsed = BroadcastSchema.safeParse(input);
  if (!parsed.success) {
    const firstIssue = parsed.error.issues[0];
    const code = firstIssue.code === 'invalid_type' ? ERROR_CODES.INVALID_PARAM_TYPE : ERROR_CODES.MISSING_REQUIRED_PARAM;
    return makeError(code, firstIssue.message, { issues: parsed.error.issues });
  }

  const { from_agent, topic, content, session_id } = parsed.data;
  const id = randomUUID();
  const timestamp = new Date().toISOString();

  // Broadcast message: to_agent = NULL
  const message = { id, topic, from_agent, to_agent: null, content, timestamp, session_id: session_id ?? null };

  // Attempt Turso write
  if (!fallback.isActive()) {
    try {
      const result = await execute(
        'INSERT INTO messages (id, topic, from_agent, to_agent, content, timestamp, session_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [id, topic, from_agent, null, content, timestamp, session_id ?? null],
        { isWrite: true },
      );

      if (result !== null && !result?.error) {
        logger.info({ event: 'broadcast_sent', msg: 'Broadcast sent via Turso', data: { id, from_agent, topic } });
        return withIdentity({ id, timestamp, topic, status: 'sent' });
      }
    } catch (err) {
      logger.warn({ event: 'db_write_error', msg: 'Turso write failed — routing broadcast to fallback', data: { error: err.message } });
    }
  }

  // Fallback path
  if (fallback.isDraining()) {
    return makeError(ERROR_CODES.RECONNECTING, 'Fallback buffer is draining — retry in 1-2 seconds.');
  }

  const writeResult = await fallback.write(message);
  if (writeResult?.error) {
    return makeError(ERROR_CODES.FALLBACK_WRITE_FAILED, 'Both Turso and fallback file writes failed.', writeResult.error);
  }

  logger.info({ event: 'broadcast_sent', msg: 'Broadcast queued in fallback buffer', data: { id, from_agent, topic } });
  return withIdentity({ id, timestamp, topic, status: 'queued' });
}

// ---------------------------------------------------------------------------
// MCP tool registration shape
// ---------------------------------------------------------------------------

export const broadcastTool = {
  name: 'broadcast',
  description: 'Broadcast a message to a topic. Recipients consume via read_messages({ topics }).',
  inputSchema: {
    type: 'object',
    properties: {
      from_agent: { type: 'string', description: 'Sender agent ID' },
      topic: { type: 'string', description: 'Topic name to broadcast to' },
      content: { type: 'string', description: 'Message body (plain text or JSON string)' },
      session_id: { type: 'string', description: 'Optional session tag' },
    },
    required: ['from_agent', 'topic', 'content'],
  },
  handler: broadcastHandler,
};
