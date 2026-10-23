/**
 * errors.js — Error codes and structured error factory
 * ESM module
 */

import { withIdentity } from './response.js';

export const ERROR_CODES = Object.freeze({
  MISSING_REQUIRED_PARAM: 'MISSING_REQUIRED_PARAM',
  INVALID_PARAM_TYPE: 'INVALID_PARAM_TYPE',
  PARAM_OUT_OF_RANGE: 'PARAM_OUT_OF_RANGE',
  DB_WRITE_FAILED: 'DB_WRITE_FAILED',
  DB_READ_FAILED: 'DB_READ_FAILED',
  FALLBACK_WRITE_FAILED: 'FALLBACK_WRITE_FAILED',
  MESSAGE_NOT_FOUND: 'MESSAGE_NOT_FOUND',
  SERVER_SHUTTING_DOWN: 'SERVER_SHUTTING_DOWN',
  RECONNECTING: 'RECONNECTING',
  SESSION_NOT_FOUND: 'SESSION_NOT_FOUND',
});

/**
 * makeError — Returns a structured error response object.
 * Tools return this directly — never throw.
 *
 * @param {string} code — one of ERROR_CODES
 * @param {string} message — human-readable description
 * @param {*} [data] — optional additional context
 * @returns {{ error: { code: string, message: string, data?: * }, data_dir: string, port: number|null }}
 */
export function makeError(code, message, data) {
  const err = { code, message };
  if (data !== undefined) {
    err.data = data;
  }
  return withIdentity({ error: err });
}
