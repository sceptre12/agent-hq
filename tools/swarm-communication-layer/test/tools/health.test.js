// test/tools/health.test.js
//
// Guards the /health identity fields (app_name, data_dir, pid) added so that
// multiple swarm-mcp instances (different DATA_DIR/APP_NAME) can be told apart
// when diagnosing a port-sharing incident — see src/health.js.
import { test } from 'node:test';
import assert from 'node:assert/strict';

// config.js reads DATA_DIR/APP_NAME from process.env at import time, so these
// must be set before health.js (which imports config.js) is loaded. Node's test
// runner executes each test file in its own process, so this is safe here.
process.env.APP_NAME = 'health-test-app';
process.env.DATA_DIR = '/tmp/health-test-data-dir';

const { healthHandler } = await import('../../src/health.js');
const config = (await import('../../src/config.js')).default;

function createMockRes() {
  return {
    statusCode: null,
    headers: null,
    body: null,
    writeHead(status, headers) {
      this.statusCode = status;
      this.headers = headers;
    },
    end(body) {
      this.body = body;
    },
  };
}

test('health: response carries instance identity fields (app_name, data_dir, pid)', async () => {
  const res = createMockRes();
  await healthHandler({}, res);

  const payload = JSON.parse(res.body);
  assert.equal(payload.app_name, config.APP_NAME);
  assert.equal(payload.data_dir, config.DATA_DIR);
  assert.equal(payload.pid, process.pid);
});

test('health: identity fields alongside existing status fields', async () => {
  const res = createMockRes();
  await healthHandler({}, res);

  const payload = JSON.parse(res.body);
  assert.ok('status' in payload);
  assert.ok('turso' in payload);
  assert.ok('uptime_seconds' in payload);
  assert.ok('log_file' in payload);
});

test('health: db_ok is false (and status degraded) when no DB client has been created', async () => {
  // This test file never calls createDbClient(), so db.js's module-level
  // client is null — checkDbOk() must treat that as "not ok" without throwing.
  const res = createMockRes();
  await healthHandler({}, res);

  const payload = JSON.parse(res.body);
  assert.equal(payload.db_ok, false);
  assert.equal(payload.status, 'degraded');
});
