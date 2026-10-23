/**
 * response.js — instance-identity response envelope
 * ESM module
 *
 * Merges this bus instance's identity (data_dir, port) into every tool
 * response so a client accidentally talking to the wrong instance (e.g.
 * because it hardcoded a port instead of reading $DATA_DIR/port) sees a
 * mismatch immediately instead of silently cross-talking with another
 * session. data_dir is static (known at import time via config.js); port
 * is only known once bindExclusive() resolves at startup, hence the
 * instance-identity.js indirection.
 */

import config from './config.js';
import { getResolvedPort } from './instance-identity.js';

export function withIdentity(result) {
  return {
    ...result,
    data_dir: config.DATA_DIR,
    port: getResolvedPort(),
  };
}
