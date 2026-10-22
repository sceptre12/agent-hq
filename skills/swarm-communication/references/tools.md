# Swarm Communication — Tool Reference

Companion to [SKILL.md](../SKILL.md). Full parameter schemas and return shapes for the
five MCP tools.

`session_id` is shown as optional below because the server itself does not require or
enforce it (nullable column, no FK check). SKILL.md step 5 overrides that at the
usage level: pass it explicitly and always — omitting it produces a permanently
untagged row that `end_session` can never find and clean up, not just a stale one.

## Response identity fields (all tools)

Every tool response — success or error — includes two additional fields beyond what's
documented per-tool below: `data_dir` (this instance's `$DATA_DIR`, absolute path) and
`port` (this instance's actual bound port). Verify these match your own session's
expected values on every call; see `SKILL.md` Step 2 for what to do on a mismatch.

---

## send_message

```
send_message({
  to:          string   — recipient agent ID (required)
  from_agent:  string   — your agent ID (required)
  content:     string   — message body, plain text or JSON string (required)
  topic:       string   — defaults to "direct" (optional)
  session_id:  string   — session tag; pass explicitly on every call (see note above)
})
```

Returns: `{ "id": "<uuid>", "timestamp": "<ISO 8601>", "status": "sent" | "queued" }`

`sent` = written to DB. `queued` = Turso unavailable, written to fallback — syncs on
reconnect.

---

## read_messages

```
read_messages({
  agent_id:   string     — your agent ID (required)
  topics:     string[]   — broadcast topics to also check (optional)
  since:      string     — ISO 8601 timestamp; only return messages after this (optional)
  limit:      number     — max messages, default 50, max 200 (optional)
  peek:       boolean    — if true, skip receipt writes; default false (optional)
  session_id: string     — session tag; pass explicitly on every call (see note above)
})
```

Returns: `{ "messages": [{ "id", "from_agent", "content", "topic", "timestamp" }] }`

Side effect: marks returned messages as `delivered`, **unless `peek: true`** — in that case
no receipts are written. Use `peek: true` for inspection without consuming messages.

**Polling frequency:** during active swarm runs, poll at **2-5s intervals**. A 30s
interval causes gate stalls — orchestrators blocking on PROCEED/HOLD wait unnecessarily.

Broadcast is lazy fan-out on read: `to_agent = NULL` in the DB; a receipt is created
per-agent on first read of the topic. Agents must know which topics to poll — define them
in the orchestrator brief.

---

## broadcast

```
broadcast({
  from_agent:  string   — your agent ID (required)
  topic:       string   — topic name (required)
  content:     string   — message body (required)
  session_id:  string   — session tag; pass explicitly on every call (see note above)
})
```

Returns: `{ "id": "<uuid>", "timestamp": "<ISO 8601>", "topic": "<topic>", "status": "sent" | "queued" }`

---

## start_session

```
start_session({
  session_id:  string   — caller-defined session ID (required)
})
```

Returns: `{ session_id: string, created_at: string }`
Idempotent — safe to call if the session already exists.
Call this before dispatching any agents. Pass `session_id` to every agent brief.

---

## end_session

```
end_session({
  session_id:  string   — session to clean up (required)
})
```

Returns: `{ session_id: string, deleted_messages: number }`
Deletes all messages and receipts for the session, then the session record itself. Only
rows tagged with this exact `session_id` are affected — untagged rows (SKILL.md step 5)
are invisible to this cleanup. Call when the swarm finishes — success or failure.
