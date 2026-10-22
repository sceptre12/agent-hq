# Panel Review — Bus Topic Schema

> **bus-schema.md is the single authoritative source for all message format definitions.**

> **Naming note (Gate 2 refit):** every per-check topic below is prefixed `panel-check-*`
> rather than the source corpus's bare `check-*`. doc-reviewer (already installed at
> `~/.claude/skills/doc-reviewer`) defines its own, unrelated Check 1–14 taxonomy,
> including its own "Check 7: Cold Read Gate" — the two taxonomies share no domain overlap
> (panel-review's checks are RACI-assigned architecture-review dimensions defined only by
> a one-line Domain string per role in `agent-roles.md`; doc-reviewer's are a fixed 14-step
> document QA sequence with a ~700-line spec). A concrete proof of the mismatch: this
> skill's `panel-check-9` is Security Engineer's domain (credential handling, injection
> risks, token scoping, blast radius); doc-reviewer's Check 9 is the Export Surface Check
> (TypeScript `export` verification) — unrelated subjects. This same collision was already
> flagged from the pr-review side: pr-review's own `bus-schema.md` (ported from the same
> source corpus) explicitly names this skill and recommends "apply the same prefix
> convention there if/when it's ported, or a distinct prefix if that skill later needs its
> own namespace" — `panel-check-*` is that distinct prefix (pr-review already claimed
> `pr-check-*`, so panel-review cannot reuse it without colliding with pr-review instead of
> doc-reviewer).
>
> This skill's checks are **not** a second copy of doc-reviewer's canonical taxonomy and
> must never be cross-referenced by bare number ("check 7," "the cold read check") once
> both skills are installed — always use the full `panel-check-N` / `doc-reviewer Check N`
> form to disambiguate.

## Topics

| Topic | Purpose | Producer | Consumer | Payload Shape | Quorum Rule |
|-------|---------|----------|----------|---------------|-------------|
| `panel-check-cold-read` | Cold Read findings + C member responses | `context-designer` | `doc-architect` | FINDING / VALIDATE pipe-delimited | All C members respond to each FINDING |
| `panel-check-cold-read-closed` | Doc Architect signals Cold Read quorum met | Doc Architect | gate-checker | `CLOSED | panel-check-cold-read | ...` | N/A |
| `panel-check-1` … `panel-check-11` | Per-check findings + C member responses | Responsible agent | C members | FINDING / VALIDATE pipe-delimited | All C members respond to each FINDING |
| `panel-check-1-closed` … `panel-check-11-closed` | Accountable signals quorum met | Accountable agent | gate-checker | `CLOSED | panel-check-N | ...` | N/A |
| `rendezvous` | Wave 1 completion signaling | All 11 Wave 1 agents | gate-checker | `PHASE1_DONE | [agent-id] | [SESSION_ID]` | 11 distinct agent_ids required |
| `phase2-rendezvous` | Wave 2 completion signaling | All 11 Wave 2 agents | phase2 gate-checker | `PHASE2_DONE | [agent-id] | [SESSION_ID]` | 11 distinct agent_ids required |

> **SESSION_ID / run_id equivalence:** `session_id` and `SESSION_ID` refer to the same
> value throughout this skill. All bus messages and MCP tool calls use the same string,
> and it must be passed **explicitly** on every call (`send_message`, `broadcast`,
> `read_messages`) — it is never ambient, even after `start_session`
> (`architecture/swarm-communication-layer.md` discrepancy #6). A call that omits it
> produces an untagged row `end_session` will never clean up, and other agents filtering by
> `session_id` will silently miss it.

## `read_messages` call contract (verified from source, swarm-communication-layer
`src/tools/read_messages.js`)

- **`agent_id` (string) is REQUIRED.** The tool's Zod schema (`ReadMessagesSchema`) has no
  default and no `.optional()` on `agent_id` — a call that omits it never reaches the bus
  logic at all; it fails validation and returns a structured error (see below). Every caller
  must pick and pass a stable identity string for itself (e.g. `"gate1-checker"`,
  `"synthesizer"`, or a per-agent id).
- **`topics` (array of strings) is the correct, PLURAL parameter name — never `topic`
  (singular).** `topics` is optional, but broadcast messages (anything sent via `broadcast`,
  which includes every check topic, `rendezvous`, and `phase2-rendezvous`) are ONLY returned
  when `topics` is present and includes that topic name. A call with `agent_id` set but
  `topics` omitted, or misspelled as singular `topic`, returns a **successful, error-free**
  response containing zero broadcast messages — it looks exactly like "nobody has posted
  yet" even though the topic has messages.
- **`session_id` (string, optional)** scopes the read to one review run — see the
  equivalence note above; pass it explicitly.
- **`peek` (boolean, default `false`)** controls whether reading writes delivery receipts.
  With the default `peek: false`, a successful read marks every returned broadcast message
  as delivered to that `agent_id`, and the SAME message will never be returned to that same
  `agent_id` again. Any caller that needs to re-read the same topic more than once (e.g. a
  gate-checker polling in a loop, or the synthesizer re-reading after Wave 2) **must** pass
  `peek: true`, or its own accumulated view of the topic will shrink instead of grow.
- **Response shapes — an error is its own distinct object, never an empty result:**
  - Success: `{"messages": [...], "data_dir": "...", "port": ...}` — `messages` may
    legitimately be `[]` when nobody has posted yet. This is a normal, healthy empty poll.
  - Error: `{"error": {"code": "...", "message": "...", "data": {...}}, "data_dir": "...",
    "port": ...}` — returned as **ordinary tool output**, not a thrown exception and not an
    MCP-protocol-level error, whenever the input fails schema validation (missing
    `agent_id`, wrong type, `limit` out of range, etc. — see `ERROR_CODES` in
    `src/errors.js`). Any caller polling this tool MUST check for a top-level `error` key on
    every response and treat its presence as a stop-the-line anomaly, never as "no messages
    yet." Conflating the two was the root cause of a live incident where a gate polled to
    timeout against an error response and let the panel proceed as if nobody had signalled,
    even though messages were on the bus the whole time.

## Message Shape

Every message posted to a check topic must be **pipe-delimited plain text** (this is the canonical format). Structured JSON is not used — agents pass content as plain text strings in the `content` field of the MCP broadcast call.

Canonical formats:
- FINDING: `FINDING | panel-check-N | [Blocking/Medium/Advisory] | [description] | Fix: [recommendation]`
- VALIDATE/CHALLENGE/ESCALATE/ADD: `VALIDATE | panel-check-N | from [agent-id] | [reasoning]`
- CLOSED: `CLOSED | panel-check-N | [agent-id] | [quorum summary]`
- PASS: `PASS | panel-check-N | No issues found`
- PHASE1_DONE: `PHASE1_DONE | [agent-id] | [SESSION_ID]`
- PHASE2_DONE: `PHASE2_DONE | [agent-id] | [SESSION_ID]`

## Rendezvous Topic Detail

### phase1 — `rendezvous`

| Field | Value |
|-------|-------|
| topic | `rendezvous` |
| producer | All 11 Wave 1 agents (broadcast after all owned checks confirmed) |
| consumer | gate-checker |
| quorum rule | 11 distinct agent_ids required; duplicates from retries are ignored |

Format defined in Message Shape section — do not redefine here.

### phase2 — `phase2-rendezvous`

| Field | Value |
|-------|-------|
| topic | `phase2-rendezvous` |
| producer | All 11 Wave 2 agents (broadcast after all owned checks confirmed) |
| consumer | phase2 gate-checker |
| quorum rule | 11 distinct agent_ids required; duplicates from retries are ignored |

Format defined in Message Shape section — do not redefine here.

## Quorum Rule

A check topic is eligible to close when every agent listed as Consulted (C) for that
check has posted at least one of VALIDATE / CHALLENGE / ESCALATE / ADD against each
FINDING on that topic.

The Accountable (A) agent monitors the topic, tracks which C agents have responded to
each finding_id, and posts CLOSED to `panel-check-N-closed` when all C responses are in.

## Timeouts

| Gate | Topic | Timeout | Quorum |
|------|-------|---------|--------|
| PHASE1_DONE gate (rendezvous) | `rendezvous` | 8 minutes | 11 distinct agent_ids |
| PHASE2_DONE gate (phase2-rendezvous) | `phase2-rendezvous` | 10 minutes | 11 distinct agent_ids |
| Per-check threads | `panel-check-N` | 10 minutes | All C members responded |

If quorum is not reached within the timeout, the Workflow closes the thread automatically
and marks it `TIMED_OUT` in the synthesizer brief. The synthesizer includes a note in the
findings table for any timed-out thread.

## Session Isolation

All messages include `session_id`, passed explicitly on every call (never ambient — see
the equivalence note above). Every `read_messages` call filters by `session_id`. Parallel
review runs do not bleed into each other because each run's swarm bus is its own isolated
PM2 process with its own `DATA_DIR`, its own DB file, and its own port — never a shared
server (`architecture/swarm-communication-layer.md`, "What This Is").

## Bus health / troubleshooting

`GET /health`'s advertised `log_file` path does not exist under PM2
(`architecture/swarm-communication-layer.md` discrepancy #7). To debug a stuck or silent
agent, read the PM2 logs for the session's `APP_NAME` (`pm2 logs <app_name>`, or the
PM2-managed log files under the session's `DATA_DIR/logs`) — not the advertised path.
