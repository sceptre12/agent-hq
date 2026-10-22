# swarm-communication — skill design record (ADR 0011)

One-line summary: the ported skill that teaches an agent how to *use* the swarm bus (5
MCP tools, port/deployment-mode discovery, explicit session scoping, PM2-only logs) — it
is bus-usage infrastructure, not a review mechanism, and defines no review-ladder rung.

## What This Is

A runbook skill, not a design record for the bus itself — that lives in
`architecture/swarm-communication-layer.md` (cross-linked throughout below). This skill
exists so any orchestrator or worker agent can discover a live bus, call its 5 tools
correctly, and tear down after itself, without re-deriving the bus's HTTP/MCP contract
from source each time. It explicitly disclaims being a review mechanism: neither the
frontmatter description nor the Trigger section carries a review-ladder rung hint
(`tools/review-ladder.md`), and both say so directly — this is I/O infrastructure a
reviewing skill might *use* to report findings, never itself a step on that ladder.

## Components

- `skills/swarm-communication/SKILL.md` (159 lines) — frontmatter (name/description,
  explicit "not a review mechanism" disclaimer, no `model:` pin, no
  `disable-model-invocation` — auto-invoke eligible), Trigger, Steps 1-9, a Red flags
  table (6 rows), Exit criteria (6 checks), Provenance/Lineage footer.
- `skills/swarm-communication/references/tools.md` (99 lines) — full parameter schemas
  and return shapes for the 5 MCP tools; a session_id usage note overriding the
  server's own nullable-column laxity (see Constraints).
- `skills/swarm-communication/references/patterns.md` (180 lines) — agent-ID and topic
  naming conventions, session lifecycle detail, 4 coordination patterns, error-code
  table, debugging pointer, per-session teardown detail.
- **Symlink-installed** at `~/.claude/skills/swarm-communication` (created 2026-07-04
  23:47), alongside sibling ports `doc-reviewer`/`panel-consultation`/`review-validator`,
  which are all live under `~/.claude/skills/` (ADR 0009 convention). The hq-side
  directory is ground truth and the activation step (the symlink) has run.

## Interfaces

- **Trigger surface:** auto-invoke eligible (no `disable-model-invocation` flag, matches
  source). Fires on any need to send/read/broadcast messages, or manage a session's
  lifecycle, over the bus.
- **Bus contracts it relies on** — all defined and owned by
  `architecture/swarm-communication-layer.md`, not restated here as authority:
  - `POST $BASE_URL/mcp` (`StreamableHTTPServerTransport`, `Accept: application/json,
    text/event-stream` required or the call 406s silently).
  - `GET $BASE_URL/health` → `{status, turso, fallback_active, uptime_seconds, log_file}`.
  - The 5 tools: `send_message`, `read_messages`, `broadcast`, `start_session`,
    `end_session` — signatures and return shapes per that record's Components section
    (this skill's `references/tools.md` restates them for at-hand use, not as a second
    authority — on drift, the architecture record's verified-against-source shapes win).
  - Port discovery via `$DATA_DIR/port` (never hardcoded) — same file the bus writes
    before signaling `pm2` ready.
- **Ladder position:** none. This is bus-usage infrastructure; `tools/review-ladder.md`
  rung hints (Rung 0-4, as used by e.g. `doc-reviewer`/`panel-consultation`) do not apply
  to this skill and it carries no up/down pointer to that ladder.

## Constraints

- Depends entirely on a live bus process — this skill has no fallback of its own beyond
  what `references/patterns.md`'s Error Handling table describes (retry/backoff on
  transient codes); it cannot start a bus for a worker agent (orchestrator-only, Step 3).
- Two deployment modes can be live at once in principle (shared single instance vs.
  per-session), and the skill cannot assume which one is running — it must check
  (Step 1) before touching `DATA_DIR`/`APP_NAME`.
- `session_id` is nullable and unenforced server-side (no FK check) — the skill's
  correctness for cleanup depends entirely on every caller passing it explicitly; the
  skill cannot detect a caller that silently omitted it.
- `/health`'s advertised `log_file` field is not a trustworthy path under PM2 — the
  skill's only reliable log-access path is `pm2 logs $APP_NAME`.

## Settled decisions (port-time refits — read against the freshly ported skill; artifact wins)

- **Deployment-mode confirmation added (Step 1) — the single largest refit.** Source
  assumed one topology only: a per-session server the orchestrator starts with
  `DATA_DIR=/tmp/$SESSION_ID`. Live reality checked at port time is a **shared,
  single-instance** PM2 app (commonly `swarm-mcp`, `DATA_DIR` defaulting to `./data`
  inside the bus repo) that may be serving other sessions concurrently. The installed
  skill now requires `pm2 list` before acting on any `DATA_DIR`/`APP_NAME` assumption,
  and gates teardown (Step 9) on having confirmed mode — deleting the shared instance
  would take down every other session using it.
- **`session_id` hardened from "include for all messages" (source, soft/optional
  guidance) to a mandatory-explicit rule (Step 5), matching
  `architecture/swarm-communication-layer.md` discrepancy #6 (found live by port-time
  verification D5).** The server does not enforce or auto-attach it from
  `start_session` — an omitted `session_id` produces a permanent leak (an untagged row
  `end_session` can never find), not mere staleness. Own step, own Red-flags row, own
  Exit-criteria line; `references/tools.md` and `references/patterns.md` both carry the
  same override note rather than the source's softer wording.
- **PM2-only log access hardened (Step 7), matching
  `architecture/swarm-communication-layer.md` discrepancy #7 (found live by D5).**
  Source documented a per-session `$DATA_DIR/logs/server.log` path as reachable in
  production alongside `pm2 logs`. That path is dev-mode-only and does not exist under
  PM2; the installed skill states `pm2 logs "$APP_NAME"` as the sole authoritative
  production log accessor and drops the server.log production claim entirely.
- **Model-pin and nested re-invocation removed.** Source frontmatter pinned `model:
  haiku` and carried a "Model Delegation" section instructing the skill to shell out to
  a nested `claude --model ... -p` re-invocation if not already on that model. Both are
  gone from the installed skill — model selection belongs to whichever agent or
  orchestrator dispatched it (matches hq's own Rule 3/4: the dispatcher pins the model,
  not a nested CLI call from inside a skill), and the Red flags table now carries an
  explicit row rejecting the rationalization.
- **Work-machine-specific paths genericized.** Source hardcoded an nvm-managed `pm2`
  binary path and a work-user home-directory-rooted project path in three places (server
  start, mid-run recovery, teardown). The installed skill resolves `pm2` "however your
  shell normally resolves it" and uses the repo-relative `~/projects/swarm-communication-
  layer` default — no literal work-machine path remains in the skill (also required by
  this workspace's leak discipline: no exportable file may carry a literal work
  identifier).
- **Review-ladder disclaimer added.** Source predates `tools/review-ladder.md` entirely
  and makes no claim either way. The installed skill adds an explicit "not a review
  mechanism, no rung applies" statement in both frontmatter and Trigger — a port-time
  addition, not an upstream behavior change, made because sibling ports
  (`doc-reviewer`, `panel-consultation`) do carry rung hints and this skill needed to
  disclaim membership explicitly rather than be assumed to have one by omission.
- **`SESSION_NOT_FOUND` added to the error table** (`references/patterns.md`), absent
  from source's 6-row table. Matches `architecture/swarm-communication-layer.md`'s
  verified-against-source `src/errors.js` (10 codes total; this skill's table is a
  practical subset, not a restatement of all 10).
- **Red flags and Exit criteria sections added** — absent upstream, added per
  `tools/skill-authoring.md` convention (same convention applied to sibling ports
  `panel-consultation`, `review-validator`).
- **`"o-memory"` gate-request pattern (Pattern 4) annotated.** Source used the name with
  no explanation. The installed `references/patterns.md` adds a disclaimer: it names a
  consumer-side orchestrator role belonging to a separate, not-yet-ported pipeline (see
  `architecture/swarm-communication-layer.md` Known Issues #2-3) — not a role this skill
  defines. Callers without that pipeline address their own orchestrator's `agent_id`
  instead.
- **Provenance/Lineage footer added** — absent upstream; now present per the same
  skill-authoring convention.

## Source lineage

Lineage: X-context-docs `skills/swarm-communication@0e9281e` (commit verified directly
against the X-context-docs repo — read-only source, not modified). Bus design and its
own discrepancy/decision record: `architecture/swarm-communication-layer.md`
(X-context-docs `custom-projects/swarm-communication-layer@87ed5a6`); this skill's
port-time refits above cross-reference that record's discrepancies #6 and #7 rather than
duplicating their evidence.
