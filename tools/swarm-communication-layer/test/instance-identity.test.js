// test/instance-identity.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { setResolvedPort, getResolvedPort } from '../src/instance-identity.js';

test('instance-identity: getResolvedPort returns null before any port is set', () => {
  assert.equal(getResolvedPort(), null);
});

test('instance-identity: getResolvedPort returns the value passed to setResolvedPort', () => {
  setResolvedPort(7799);
  assert.equal(getResolvedPort(), 7799);
});
