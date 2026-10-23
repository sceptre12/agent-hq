/**
 * logger.js — pino logger instance
 * ESM module
 *
 * NODE_ENV=production: pino/file transport writing to LOG_FILE_PATH
 * NODE_ENV!=production: pino default pretty output to stdout
 *
 * Base log shape: { timestamp, level, service: "swarm-mcp", event, msg, data }
 */

import pino from 'pino';

const LOG_FILE_PATH = process.env.LOG_FILE_PATH ?? './logs/server.log';
const NODE_ENV = process.env.NODE_ENV ?? 'development';

let transport;

if (NODE_ENV === 'production') {
  transport = pino.transport({
    target: 'pino/file',
    options: { destination: LOG_FILE_PATH, mkdir: true },
  });
}

const logger = pino(
  {
    base: { service: 'swarm-mcp' },
    timestamp: pino.stdTimeFunctions.isoTime,
    messageKey: 'msg',
    formatters: {
      level(label) {
        return { level: label };
      },
    },
  },
  transport,
);

export default logger;
