// src/tools/end_session.js
import { z } from 'zod';
import { execute, getClient } from '../db.js';
import { makeError, ERROR_CODES } from '../errors.js';
import logger from '../logger.js';
import { withIdentity } from '../response.js';

const EndSessionSchema = z.object({
  session_id: z.string({ required_error: 'session_id is required' }),
});

async function endSessionHandler(input) {
  const parsed = EndSessionSchema.safeParse(input);
  if (!parsed.success) {
    const firstIssue = parsed.error.issues[0];
    const code = firstIssue.code === 'invalid_type' ? ERROR_CODES.INVALID_PARAM_TYPE : ERROR_CODES.MISSING_REQUIRED_PARAM;
    return makeError(code, firstIssue.message);
  }

  const { session_id } = parsed.data;

  // Verify session exists
  const sessionResult = await execute('SELECT id FROM sessions WHERE id = ?', [session_id]);
  if (sessionResult?.error) {
    return makeError(ERROR_CODES.DB_READ_FAILED, 'Failed to look up session.');
  }
  if (!sessionResult?.rows?.length) {
    return makeError(ERROR_CODES.SESSION_NOT_FOUND, `Session '${session_id}' not found.`);
  }

  // Count messages before deletion (for return value)
  const countResult = await execute(
    'SELECT COUNT(*) as n FROM messages WHERE session_id = ?',
    [session_id],
  );
  const deletedMessages = countResult?.rows?.[0]?.n ?? 0;

  // Fetch message IDs for this session (avoids IN-subquery which Turso does not support)
  const msgIdsResult = await execute(
    'SELECT id FROM messages WHERE session_id = ?',
    [session_id],
  );
  if (msgIdsResult?.error) {
    return makeError(ERROR_CODES.DB_READ_FAILED, 'Failed to fetch message IDs for session.');
  }
  const msgIds = (msgIdsResult?.rows ?? []).map((r) => r.id);

  // Delete in FK order: receipts → messages → session row
  const client = getClient();
  if (!client) {
    return makeError(ERROR_CODES.DB_WRITE_FAILED, 'DB client unavailable — retry when server reconnects.');
  }

  try {
    const txn = client.transaction(async () => {
      // Delete receipts one-by-one (Turso does not support IN-subquery)
      for (const msgId of msgIds) {
        await client.prepare('DELETE FROM message_receipts WHERE message_id = ?').run(msgId);
      }
      await client.prepare('DELETE FROM messages WHERE session_id = ?').run(session_id);
      await client.prepare('DELETE FROM sessions WHERE id = ?').run(session_id);
    });
    await txn();
  } catch (err) {
    logger.error({ event: 'session_cleanup_error', msg: 'end_session deletion failed', data: { session_id, error: err.message } });
    return makeError(ERROR_CODES.DB_WRITE_FAILED, 'Session cleanup failed — partial deletion may have occurred. Retry.', { session_id });
  }

  logger.info({ event: 'session_ended', msg: 'Session ended and cleaned up', data: { session_id, deleted_messages: deletedMessages } });
  return withIdentity({ session_id, deleted_messages: deletedMessages });
}

export const endSessionTool = {
  name: 'end_session',
  description: 'Clean up all messages and receipts for a session, then delete the session record.',
  inputSchema: {
    type: 'object',
    properties: {
      session_id: { type: 'string', description: 'Session ID to clean up' },
    },
    required: ['session_id'],
  },
  handler: endSessionHandler,
};
