// test/response.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';

// config.js reads DATA_DIR from process.env at import time and is frozen —
// must be set before response.js (which imports config.js) is loaded.
process.env.DATA_DIR = '/tmp/response-test-data-dir';

const config = (await import('../src/config.js')).default;
const { setResolvedPort } = await import('../src/instance-identity.js');
const { withIdentity } = await import('../src/response.js');

setResolvedPort(7788);

test('withIdentity merges data_dir and port without disturbing existing fields', () => {
  const input = { id: 'msg-1', timestamp: '2026-07-21T00:00:00.000Z', status: 'sent' };
  const output = withIdentity(input);
  assert.equal(output.id, 'msg-1');
  assert.equal(output.timestamp, '2026-07-21T00:00:00.000Z');
  assert.equal(output.status, 'sent');
  assert.equal(output.data_dir, config.DATA_DIR);
  assert.equal(output.port, 7788);
});

test('withIdentity works on error-shaped objects (used inside makeError)', () => {
  const input = { error: { code: 'SESSION_NOT_FOUND', message: 'not found' } };
  const output = withIdentity(input);
  assert.deepEqual(output.error, { code: 'SESSION_NOT_FOUND', message: 'not found' });
  assert.equal(output.data_dir, config.DATA_DIR);
  assert.equal(output.port, 7788);
});
