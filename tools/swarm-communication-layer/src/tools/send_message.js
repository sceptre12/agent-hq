/**
 * send_message.js — MCP tool: send_message
 * ESM module
 *
 * Sends a direct message from one agent to another.
 * Tries Turso first; if fallback is active, writes to the NDJSON buffer.
 * Never throws — returns structured errors via makeError().
 *
 * Returns: { id, timestamp, status: "sent" | "queued" }
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

const SendMessageSchema = z.object({
  to: z.string({ required_error: 'to is required' }),
  from_agent: z.string({ required_error: 'from_agent is required' }),
  content: z.string({ required_error: 'content is required' }),
  topic: z.string().optional().default('direct'),
  session_id: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

async function sendMessageHandler(input) {
  // Validate input
  const parsed = SendMessageSchema.safeParse(input);
  if (!parsed.success) {
    const firstIssue = parsed.error.issues[0];
    const code = firstIssue.code === 'invalid_type' ? ERROR_CODES.INVALID_PARAM_TYPE : ERROR_CODES.MISSING_REQUIRED_PARAM;
    return makeError(code, firstIssue.message, { issues: parsed.error.issues });
  }

  const { to, from_agent, content, topic, session_id } = parsed.data;
  const id = randomUUID();
  const timestamp = new Date().toISOString();

  const message = { id, topic, from_agent, to_agent: to, content, timestamp, session_id: session_id ?? null };

  // Attempt Turso write
  if (!fallback.isActive()) {
    try {
      const result = await execute(
        'INSERT INTO messages (id, topic, from_agent, to_agent, content, timestamp, session_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [id, topic, from_agent, to, content, timestamp, session_id ?? null],
        { isWrite: true },
      );

      if (result !== null && !result?.error) {
        logger.info({ event: 'message_sent', msg: 'Message sent via Turso', data: { id, from_agent, to, topic } });
        return withIdentity({ id, timestamp, status: 'sent' });
      }
    } catch (err) {
      logger.warn({ event: 'db_write_error', msg: 'Turso write failed — routing to fallback', data: { error: err.message } });
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

  logger.info({ event: 'message_sent', msg: 'Message queued in fallback buffer', data: { id, from_agent, to, topic } });
  return withIdentity({ id, timestamp, status: 'queued' });
}

// ---------------------------------------------------------------------------
// MCP tool registration shape (compatible with @modelcontextprotocol/sdk)
// ---------------------------------------------------------------------------

export const sendMessageTool = {
  name: 'send_message',
  description: 'Send a direct message from one agent to another.',
  inputSchema: {
    type: 'object',
    properties: {
      to: { type: 'string', description: 'Recipient agent ID' },
      from_agent: { type: 'string', description: 'Sender agent ID' },
      content: { type: 'string', description: 'Message body (plain text or JSON string)' },
      topic: { type: 'string', description: "Message topic (default: 'direct')" },
      session_id: { type: 'string', description: 'Optional session tag — include for all messages in a swarm run' },
    },
    required: ['to', 'from_agent', 'content'],
  },
  handler: sendMessageHandler,
};
