# Open Questions — swarm-communication-layer

Curated 2026-05-02.

---

## Pending

| Question | Source session | Notes |
|----------|---------------|-------|
| Should the MCP server be registered in Claude Desktop config or is per-project manual connection preferred? | pid-21283 | Architecture specifies HTTP/SSE on PORT — registration method is a deployment decision not yet made |
| Should `RECONNECTING` error code trigger the same retry logic as `ECONNREFUSED` in agent MCP clients? | pid-32247 (learnings) | Architecture recommends 3 retries / 500ms backoff for ECONNREFUSED — RECONNECTING may need same treatment |
| Should `end_session` do a best-effort partial delete on failure or roll back entirely? | pid-context-update (2026-05-13) | Current behavior: logs error, returns partial count, caller must retry. Full rollback would be safer but requires explicit transaction design. |
| Should the server validate that `session_id` exists before accepting messages tagged to it? | pid-context-update (2026-05-13) | Current: no validation — agents tag their own messages. Validation would prevent orphan-tagged messages but adds a read per write. |

---

## Resolved

| Question | Resolution | Date |
|----------|-----------|------|
| What is the Turso URL/auth config pattern? | Local file DB only — `TURSO_DATABASE_URL` defaults to `./data/swarm.db`, no auth token required | 2026-05-02 |
| Does `read_messages` support filtering? | Yes — `topics`, `since`, `limit` all supported per architecture.md | 2026-05-02 |
| Where does the log file live? | `LOG_FILE_PATH` env var, default `$DATA_DIR/logs/server.log` (isolated per session) | 2026-05-05 |
| What is the fallback sync strategy? | On-reconnect only — polling loop in `db.js` triggers sync when Turso becomes available | 2026-05-02 |
