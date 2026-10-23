import { z } from 'zod';
import { execute, getClient } from '../db.js';
import { makeError, ERROR_CODES } from '../errors.js';
import logger from '../logger.js';
import { withIdentity } from '../response.js';

const ReadMessagesSchema = z.object({
  agent_id: z.string({ required_error: 'agent_id is required' }),
  topics: z.array(z.string()).optional(),
  since: z.string().optional(),
  limit: z.number().int().min(1).max(200).optional().default(50),
  peek: z.boolean().optional().default(false),
  session_id: z.string().optional(),
});

async function readMessagesHandler(input) {
  const parsed = ReadMessagesSchema.safeParse(input);
  if (!parsed.success) {
    const firstIssue = parsed.error.issues[0];
    if (firstIssue.code === 'too_big') {
      return makeError(ERROR_CODES.PARAM_OUT_OF_RANGE, 'limit must not exceed 200.', { max: 200 });
    }
    const code = firstIssue.code === 'invalid_type' ? ERROR_CODES.INVALID_PARAM_TYPE : ERROR_CODES.MISSING_REQUIRED_PARAM;
    return makeError(code, firstIssue.message, { issues: parsed.error.issues });
  }

  const { agent_id, topics, since, limit, peek, session_id } = parsed.data;

  // Direct messages — anti-join on message_receipts (only unread rows returned)
  let directSql = `SELECT m.id, m.from_agent, m.to_agent, m.content, m.topic, m.timestamp
    FROM messages m
    LEFT JOIN message_receipts mr ON m.id = mr.message_id AND mr.agent_id = ?
    WHERE m.to_agent = ? AND mr.message_id IS NULL`;
  const directArgs = [agent_id, agent_id];

  if (since) {
    directSql += ' AND m.timestamp >= ?';
    directArgs.push(since);
  }
  if (session_id) {
    directSql += ' AND m.session_id = ?';
    directArgs.push(session_id);
  }
  directSql += ' ORDER BY m.timestamp ASC LIMIT ?';
  directArgs.push(limit);

  const directResult = await execute(directSql, directArgs);
  if (directResult?.error) {
    return makeError(ERROR_CODES.DB_READ_FAILED, 'Failed to read direct messages.', directResult.error);
  }
  const directMessages = directResult?.rows ?? [];

  // Broadcast fan-out on read (lazy)
  let broadcastMessages = [];
  if (topics && topics.length > 0) {
    const placeholders = topics.map(() => '?').join(', ');
    let broadcastSql = `SELECT m.id, m.from_agent, m.to_agent, m.content, m.topic, m.timestamp
      FROM messages m
      LEFT JOIN message_receipts r ON m.id = r.message_id AND r.agent_id = ?
      WHERE m.topic IN (${placeholders}) AND m.to_agent IS NULL
      AND r.message_id IS NULL`;
    const broadcastArgs = [agent_id, ...topics];

    if (since) {
      broadcastSql += ' AND m.timestamp >= ?';
      broadcastArgs.push(since);
    }
    if (session_id) {
      broadcastSql += ' AND m.session_id = ?';
      broadcastArgs.push(session_id);
    }
    broadcastSql += ' ORDER BY m.timestamp ASC LIMIT ?';
    broadcastArgs.push(limit);

    const broadcastResult = await execute(broadcastSql, broadcastArgs);
    if (broadcastResult?.error) {
      return makeError(ERROR_CODES.DB_READ_FAILED, 'Failed to read broadcast messages.', broadcastResult.error);
    }
    broadcastMessages = broadcastResult?.rows ?? [];
  }

  const allMessages = [...directMessages, ...broadcastMessages];

  // Write receipts only when peek=false (default)
  if (!peek && allMessages.length > 0) {
    try {
      const client = getClient();
      if (client) {
        const insertStmt = client.prepare(
          "INSERT INTO message_receipts (message_id, agent_id, status) VALUES (?, ?, ?) ON CONFLICT(message_id, agent_id) DO NOTHING"
        );
        const updateStmt = client.prepare(
          "UPDATE message_receipts SET status = 'delivered' WHERE message_id = ? AND agent_id = ? AND status = 'pending'"
        );
        const txn = client.transaction(async () => {
          for (const msg of allMessages) {
            await insertStmt.run(msg.id, agent_id, 'delivered');
            await updateStmt.run(msg.id, agent_id);
          }
        });
        await txn();
      } else {
        logger.warn({ event: 'receipt_update_skipped', msg: 'DB client unavailable — receipts not written for this read', data: { agent_id, count: allMessages.length } });
      }
    } catch (receiptErr) {
      logger.warn({ event: 'receipt_update_error', msg: 'Failed to update message receipts', data: { error: receiptErr.message } });
    }
  }

  const messages = allMessages.map((row) => ({
    id: row.id,
    from_agent: row.from_agent,
    content: row.content,
    topic: row.topic,
    timestamp: row.timestamp,
  }));

  logger.info({ event: 'message_read', msg: 'Messages read', data: { agent_id, count: messages.length, topics, peek } });
  return withIdentity({ messages });
}

export const readMessagesTool = {
  name: 'read_messages',
  description: 'Read messages addressed to an agent, with optional broadcast topic subscription.',
  inputSchema: {
    type: 'object',
    properties: {
      agent_id: { type: 'string', description: 'Agent ID to retrieve messages for' },
      topics: { type: 'array', items: { type: 'string' }, description: 'Optional broadcast topics to include' },
      since: { type: 'string', description: 'ISO 8601 timestamp — only return messages after this time' },
      limit: { type: 'number', description: 'Maximum messages to return per message type (direct and broadcast each apply this limit; default 50, max 200)' },
      peek: { type: 'boolean', description: 'If true, skip writing delivery receipts (default false)' },
      session_id: { type: 'string', description: 'Optional — scope reads to a specific session' },
    },
    required: ['agent_id'],
  },
  handler: readMessagesHandler,
};
