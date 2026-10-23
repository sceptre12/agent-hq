// test/tools/read_messages.test.js
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { createTestDb, seedMessage } from '../helpers/db.js';

let db;

before(async () => {
  db = await createTestDb();
});

test('direct message: not returned after receipt exists', async () => {
  await seedMessage(db, { id: 'dm-1', to_agent: 'agent-a', from_agent: 'agent-b' });
  await db.prepare(
    "INSERT INTO message_receipts (message_id, agent_id, status) VALUES (?, ?, 'delivered')"
  ).run('dm-1', 'agent-a');

  const rows = await db.prepare(`
    SELECT m.id FROM messages m
    LEFT JOIN message_receipts mr ON m.id = mr.message_id AND mr.agent_id = ?
    WHERE m.to_agent = ? AND mr.message_id IS NULL
  `).all('agent-a', 'agent-a');

  assert.equal(rows.length, 0, 'already-delivered message must not be returned');
});

test('direct message: returned when no receipt exists', async () => {
  await seedMessage(db, { id: 'dm-2', to_agent: 'agent-b', from_agent: 'agent-a' });

  const rows = await db.prepare(`
    SELECT m.id FROM messages m
    LEFT JOIN message_receipts mr ON m.id = mr.message_id AND mr.agent_id = ?
    WHERE m.to_agent = ? AND mr.message_id IS NULL
  `).all('agent-b', 'agent-b');

  assert.ok(rows.some(r => r.id === 'dm-2'), 'unread message must be returned');
});

test('peek: does not insert receipt when peek=true', async () => {
  await seedMessage(db, { id: 'dm-3', to_agent: 'agent-c', from_agent: 'agent-x' });

  await db.prepare(`
    SELECT m.id FROM messages m
    LEFT JOIN message_receipts mr ON m.id = mr.message_id AND mr.agent_id = ?
    WHERE m.to_agent = ? AND mr.message_id IS NULL
  `).all('agent-c', 'agent-c');
  // peek mode: no INSERT

  const receipt = await db.prepare(
    'SELECT * FROM message_receipts WHERE message_id = ? AND agent_id = ?'
  ).get('dm-3', 'agent-c');
  assert.equal(receipt, undefined, 'peek must not write a receipt');
});

test('peek=false: inserts receipt after read', async () => {
  await seedMessage(db, { id: 'dm-4', to_agent: 'agent-d', from_agent: 'agent-x' });

  await db.prepare(
    "INSERT INTO message_receipts (message_id, agent_id, status) VALUES (?, ?, 'delivered') ON CONFLICT(message_id, agent_id) DO NOTHING"
  ).run('dm-4', 'agent-d');

  const receipt = await db.prepare(
    'SELECT * FROM message_receipts WHERE message_id = ? AND agent_id = ?'
  ).get('dm-4', 'agent-d');
  assert.ok(receipt, 'non-peek read must write a receipt');
});
