# MCP Tool API — Swarm Communication Layer

Agent identity is passed explicitly in every call (`from_agent` required). No registration, no API keys — agents are trusted internal callers.

---

## Bus Transport

The `/mcp` endpoint uses `StreamableHTTPServerTransport` (SSE). It is **not** plain JSON-RPC.

**Every POST to `/mcp` must include `Accept: application/json, text/event-stream`.** Without it the server returns `406 Not Acceptable`. The curl command exits with code 0 — the message is silently dropped. No error is thrown.

```bash
# Correct
curl -X POST http://localhost:$PORT/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '...'
```

`GET /health` is plain REST — does not require the `Accept` header.

> `$PORT` must be read from `$DATA_DIR/port` — never hardcoded. See [port-discovery.md](port-discovery.md).

---

## McpServer Lifecycle

A new `McpServer` instance must be created per request via `createMcpServer()`. A module-level singleton throws `"Already connected"` on the second request — this only surfaces under sequential or concurrent multi-request load, not in single-request unit tests.

```js
// Correct
function createMcpServer() {
  return new McpServer({ name: 'swarm-mcp', version: '1.0.0' });
}
```

---

## Tools

### `send_message`
```typescript
send_message({
  to: string,
  from_agent: string,
  content: string,
  topic?: string      // defaults to 'direct'
})
// Returns: { id: string, timestamp: string, status: "queued" | "sent" }
```

### `read_messages`
```typescript
read_messages({
  agent_id: string,    // messages addressed to this agent
  topics?: string[],   // include pending broadcast messages on these topics
  since?: string,      // ISO timestamp
  limit?: number,      // default 50, max 200
  peek?: boolean       // default false — if true, no receipt row written (non-consuming read)
})
// Returns: { messages: Array<{id, from_agent, content, topic, timestamp}> }
// Side effect: marks returned messages 'delivered' in message_receipts (BEGIN IMMEDIATE)
// When peek=true: SELECT runs but no receipt row is written — message stays unread.
```

Broadcast delivery (when `topics` provided): queries `messages WHERE topic IN (...) AND to_agent IS NULL`, creates receipt rows on first delivery for this agent (lazy fan-out on read). When `topics` is absent, only direct messages are returned.

`peek: true` use cases: bootstrap diagnostics, orchestrators inspecting an inbox without consuming, debugging tool to see pending message counts.

### `broadcast`
```typescript
broadcast({
  from_agent: string,
  topic: string,
  content: string,
  session_id?: string  // optional — tags message to an active session for cleanup
})
// Returns: { id: string, timestamp: string, topic: string, status: "queued" | "sent" }
// Fan-out on read — no recipient list at write time.
// Recipients consume via read_messages({ agent_id, topics: ['<topic>'] })
```

### `send_message`
`send_message` also accepts an optional `session_id` param (same semantics as `broadcast`).

### `start_session`
```typescript
start_session({
  from_agent: string,
  label?: string       // human-readable description of the swarm run
})
// Returns: { session_id: string, started_at: string }
```

### `end_session`
```typescript
end_session({
  from_agent: string,
  session_id: string
})
// Returns: { deleted_messages: number, deleted_receipts: number }
// Deletes in FK order: receipts first, then messages, then session row.
// Uses libSQL quirk 3 workaround — fetches IDs then deletes per-ID in a transaction.
// On partial failure: logs error, returns partial count. Caller must retry.
```

---

## Error Codes (`src/errors.js`)

```
MISSING_REQUIRED_PARAM   — required field absent
INVALID_PARAM_TYPE       — wrong type (Zod validation failure)
PARAM_OUT_OF_RANGE       — e.g. limit > 200
DB_WRITE_FAILED          — Turso write failed (fallback not active)
DB_READ_FAILED           — Turso read failed
FALLBACK_WRITE_FAILED    — both Turso and fallback write failed
MESSAGE_NOT_FOUND        — requested message ID does not exist
SERVER_SHUTTING_DOWN     — request received during graceful drain
RECONNECTING             — draining fallback queue; retry after 1-2s
```

If Turso is down but fallback succeeds, `send_message` returns `{ status: "queued" }` — not an error.

All tools return `{ error: { code, message } }` — never bare thrown exceptions.

---

## Client Retry

For `ECONNREFUSED` (e.g. pm2 restart window): 3 retries, 500ms exponential backoff. The fallback buffer protects against Turso unavailability only — not server process downtime.
