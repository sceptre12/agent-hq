// src/tools/start_session.js
import { z } from 'zod';
import { execute } from '../db.js';
import { makeError, ERROR_CODES } from '../errors.js';
import logger from '../logger.js';
import { withIdentity } from '../response.js';

const StartSessionSchema = z.object({
  session_id: z.string({ required_error: 'session_id is required' }),
});

async function startSessionHandler(input) {
  const parsed = StartSessionSchema.safeParse(input);
  if (!parsed.success) {
    const firstIssue = parsed.error.issues[0];
    const code =
      firstIssue.code === 'invalid_type'
        ? ERROR_CODES.INVALID_PARAM_TYPE
        : ERROR_CODES.MISSING_REQUIRED_PARAM;
    return makeError(code, firstIssue.message);
  }

  const { session_id } = parsed.data;
  const created_at = new Date().toISOString();

  const result = await execute(
    'INSERT INTO sessions (id, created_at) VALUES (?, ?) ON CONFLICT(id) DO NOTHING',
    [session_id, created_at],
    { isWrite: true },
  );

  if (result === null || result?.error) {
    return makeError(ERROR_CODES.DB_WRITE_FAILED, 'Failed to create session.');
  }

  const rowResult = await execute(
    'SELECT id, created_at, ended_at FROM sessions WHERE id = ?',
    [session_id],
  );

  if (rowResult?.error || !rowResult?.rows?.length) {
    return makeError(ERROR_CODES.DB_READ_FAILED, 'Session created but could not be read back.');
  }

  const row = rowResult.rows[0];
  logger.info({ event: 'session_started', msg: 'Session started', data: { session_id } });
  return withIdentity({ session_id: row.id, created_at: row.created_at });
}

export const startSessionTool = {
  name: 'start_session',
  description:
    'Register a new session. Call before dispatching agents. Pass session_id to every agent brief.',
  inputSchema: {
    type: 'object',
    properties: {
      session_id: {
        type: 'string',
        description: 'Caller-defined session ID (e.g. "run42" or a UUID)',
      },
    },
    required: ['session_id'],
  },
  handler: startSessionHandler,
};
