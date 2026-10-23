# agent-topology — design record (Rule 5 architecture artifact)

> **Superseded 2026-09-07 by native primitives — see decisions/0037. Retained as design
> record.**

One-line summary: a star-topology enforcement layer — one Router, N Workers — where an
`agents` registry in SQLite is the single source of truth for who exists, and role
authority is enforced by a middleware layer over 10 MCP tools rather than by prompt text.

- **Status:** RATIFIED-WITH-AMENDMENTS; **OQ4 RE-RULED — branch (iii) selected by the
  owner, 2026-09-02** (session-persistent, process-ephemeral workers; T2 ADDENDUM
  amendments 1 and 7 applied — see §6). The original OQ4(a) detached one-shot `claude -p`
  ruling was falsified by ADR 0014 T2 (one-shot children cannot receive route-existing
  dispatch or heartbeat across work cycles) — see the T2 ADDENDUM in
  `architecture/agent-topology-ratification.md`. **Branch (iii)'s core mechanism
  (`-p --resume`) is EMPIRICALLY UNVERIFIED in this environment — read the risk record in
  §6 before building D6 or D9.** OQ1–OQ3, OQ5–OQ8 stand; see ADR
  `decisions/0035-agent-topology-hq-exception.md` for the standards-exception,
  tier-ladder, per-role-install, and identity-model rulings.
- **Date:** 2026-09-02
- **Source spec:** Notion "Topology Tooling — Build Spec (Claude Code)"
  + companion "Router Protocol — Main Chat (Sonnet)"
  fetched 2026-09-02, saved verbatim to the session
  scratchpad. **The spec on disk is authoritative for everything below.**
- **Authorship marking convention:** every element is tagged `[SPEC]` (traces to a cited
  line of the spec), `[MINE]` (my reasoned decision, rationale given), or `[OPEN]`
  (unresolved — must not be built until the owner rules).

## 0. Evidence base for this record

Every load-bearing external fact below was verified by a command run while authoring.

| Claim | How verified |
|---|---|
| hq source cap is **300 lines**, soft default, skills+tests blanket-exempt | `decisions/0016-source-file-length-limit.md` clauses 1,2,3,5,7; `tools/check-file-length.sh:15` `LIMIT=300` |
| hq doc cap is **500 lines**, blocking, owner-approval to cross | `decisions/0021`, `0029`; `tools/check-doc-length.sh` `LIMIT=500` |
| `skills/` is excluded wholesale from **both** checkers | `check-file-length.sh` and `check-doc-length.sh` `EXCLUDE_DIR_NAMES` both contain `skills` |
| `.sql` files are **not scanned** by the source checker | `check-file-length.sh:18` `EXTENSIONS=(ts tsx js jsx mjs cjs py go rs java rb c h hpp cpp cc swift kt scala php sh bash zsh lua)` — no `sql` |
| hq skills are authored in hq and **symlink-installed** to `~/.claude/skills/<name>` | ADR 0009 Decision clause; 22 live symlinks confirmed in `~/.claude/skills/` |
| STANDARDS §7: "Code repos are **siblings** under `~/projects/`, never nested inside `hq`" | `STANDARDS.md:82-86` |
| ADR 0010 restates the same for the bus: "code repos never live inside hq" | `decisions/0010-...md`, Targets clause |
| …but hq **already contains** a tracked multi-file Node codebase | `git ls-files plans/<project>/harness` → **25 tracked files** (`harness.js`, `lib/*.js`, `package-lock.json`, a `test/` dir) |
| The existing swarm bus has **no** agents/registry/role/spawn/hop/envelope/heartbeat concept | `command grep -rinE 'agents\|registry\|spawn\|role\|hop_count\|envelope\|heartbeat\|whoami' --include='*.js' --include='*.sql' src schema.sql` in `~/projects/agent-hq/tools/swarm-communication-layer` → **3 incidental hits**, none structural ("Register a new session", "response envelope" = instance-identity, "agents may generate offline" comment). Positive control: 13 `src/*.js` files match `message`. |
| No prior art for this spec anywhere in hq | `command grep -rilE 'agent-topology\|spawn_agent\|registry_write\|write asymmetry\|hop_count\|router protocol' --include='*.md' .` in hq → **0 hits**. Positive controls on the same corpus: `router` → **183** files, `registry` → **53** files. |
| The bus resolves caller identity from a **self-reported** parameter | `src/tools/send_message.js` `SendMessageSchema`: `from_agent: z.string({required_error:'from_agent is required'})`; `src/server.js:47` `sessionIdGenerator: undefined // stateless mode`; no `headers`/`_meta`/`clientInfo` extraction anywhere in `src/mcp-server.js`, `src/request-tracker.js`, `src/server.js` |

## 1. Prior art: does this duplicate the swarm bus?

**Verdict: COMPLEMENTS, with one overlapping edge.** [MINE]

The swarm-communication-layer bus (`~/projects/agent-hq/tools/swarm-communication-layer`, design record
`architecture/swarm-communication-layer.md`, skill `skills/swarm-communication/`) is a
**transport**: `messages` / `message_receipts` / `sessions` tables and 5 tools
(`send_message`, `read_messages`, `broadcast`, `start_session`, `end_session`). Its schema
(read in full) has no agent identity, no role, no parent, no lifecycle status, and no
authority model — any caller may send as any `from_agent`.

This spec is an **authority and topology layer**: who exists, what role they hold, who may
mutate state, and which edges of the graph are legal. It is not a transport, and the bus
cannot be extended into one without adding all of it.

- **Non-overlapping (this spec only):** `agents` registry, role/write asymmetry, `whoami`,
  `spawn_agent`, `report_result`/`escalate`, heartbeat/staleness.
- **Overlapping (one edge):** `route_message` vs. the bus's `send_message`, and the spec's
  `messages` envelope vs. the bus's `messages` table. Both move a body from A to B.
- **Neither replaces the other.** The bus is used today by `wave-execution`,
  `loop-controller`, `panel-review`, `fix-verifier` (all reference the swarm-communication
  skill). Nothing here should touch it.

See **OQ5** — whether `route_message` should wrap the bus or own its own table is a real
design fork the spec never addresses.

## 2. Design principle and the two things it forces

`[SPEC]` "Topology lives in shared state, not in any agent's memory… Role identity must be
enforced by tool access (capability asymmetry), not by prompt text alone."

Two consequences drive the whole design:

1. **The registry row *is* the agent.** `[SPEC]` "A row in the registry *is* an agent's
   existence; spawn and registration are atomic." Nothing may create an agent except
   through a registry write.
2. **Authority is resolved, never asserted.** A caller's role comes from its registry row,
   looked up by an identity the caller cannot forge. This is the single hardest
   requirement in the spec and is currently **unsatisfiable** — see OQ1.

## 3. Components and module decomposition

Root: **`tools/agent-topology/`** inside hq `[RATIFIED — OQ2, T6 2026-09-02]`. Chosen
because hq already keeps executable machinery under `tools/` (79 `.sh` files, a `.py`, and
the multi-file `tools/container-exec/` and `tools/lib/` subtrees). The owner's stated
reason for the inside-hq exception — this system will be **ported to a separate work
environment** — promotes portability to a first-class requirement (ratification rulings
P1–P5); see part 2 §12. Consequence for this section: both role SKILL.md files move INTO this
root at `tools/agent-topology/skills/agent-topology-{router,worker}/SKILL.md` (P1),
`config.js` gains a `CLAUDE_BIN` env var (default `claude` on PATH, P2), and the
acceptance gate gains a portability grep (`command grep -rn '/Users/\|projects/hq'
tools/agent-topology --exclude-dir=node_modules` → 0 hits) as a final check. **Widened
form (T2 addendum, mechanical correction 3):** the `--include='*.js'` filter is dropped so
`schema.sql`, `package.json`, and both SKILL.md files are inside the gate too.

Every module below is sized to sit comfortably under the **300-line** ADR 0016 default. The
decomposition is driven by that cap plus the spec's own instruction: `[SPEC]` "Keep tool
handlers thin; put invariant enforcement in one middleware layer."

| Module | Responsibility | Cap note |
|---|---|---|
| `schema.sql` | DDL for `agents` + `messages` | `.sql` unscanned by the checker |
| `config.js` | env surface: `DATA_DIR` (default `~/.agent-topology/data/`), `CLAUDE_BIN` (default `claude` on PATH, P2), `MAX_HOPS` (3), `STALE_THRESHOLD` (10m), port range | small |
| `errors.js` | frozen `ERROR_CODES` incl. `PERMISSION_DENIED`; `makeError()` | small |
| `db.js` | connect + `initSchema()`; single-writer SQLite | ~80 |
| `identity.js` | capability-token mint/verify → `agent_id`. **OQ1 RATIFIED: capability token, not runtime identity — see §5.** | ~60 |
| `middleware.js` | THE single enforcement seam: identity → role gate → envelope gate → hop gate | ~120 |
| `registry.js` | row CRUD primitives; single-active-router guard; status transitions | ~150 |
| `envelope.js` | envelope construct/validate, `hop_count` arithmetic | ~70 |
| `preamble.js` | Worker Preamble template + `{parent_id}/{scope}/{tier}/{auth_token}` interpolation (F4: fourth slot) | ~50 |
| `provision.js` | worker-environment skill provisioning, **copy-based** (not symlink), see part 2 §7 | ~80 |
| `tools/whoami.js` … `tools/heartbeat.js`, `tools/read_messages.js` (10 files) | thin handlers, one per tool | ~40–90 each |
| `mcp-server.js` | **per-request** tool registration factory | ~90 |
| `server.js` | HTTP entry, `/health`, port file | ~120 |
| `test/*.test.js` | 6 acceptance tests + unit tests | blanket-exempt (ADR 0016 cl. 7) |

**Why this satisfies ADR 0016 rather than dodging it:** the split follows real seams
(transport / enforcement / state / handlers), which is the "split, don't butcher" remedy
clause 3 mandates. No file is padded or compressed to hit a number.

**Two lessons carried over from the bus, free** `[MINE]`:
- Register tools via a **per-request factory** — a module-level `McpServer` singleton throws
  "Already connected" on the second request (`architecture/swarm-communication-layer.md`,
  Components §`src/server.js`).
- Register with the **3-arg `registerTool(name, {description, inputSchema}, handler)`** form.
  The `server.tool()` form silently delivers request metadata instead of tool args and is
  banned in that repo.

## 4. Data model

### `agents` `[SPEC, enums RATIFIED — OQ3]`

`agent_id` (uuid PK), `name` (unique among LIVE — `spawning|active`, ratification
ADDENDUM 3), `role`, `tier`, `scope` (one-line domain, route-existing matching), `status`,
`parent_id` (NULLABLE), `thread_ref` (host-runtime session/thread id, NULLABLE — NULL for
the router row and until a worker's active flip), `token_hash` (NOT NULL, lowercase-hex
SHA-256 of the raw token, UNIQUE-indexed — ADDENDUM 3, D2.1), `created_at`,
`last_active_at`. All columns not marked NULLABLE are NOT NULL. **This list is the
normative column inventory: a column absent here does not exist in the schema.**

**The enum values were damaged in the fetched source** — the Notion table renderer split
each pipe-separated enum across two cells and truncated the tail. OQ3 ruled the sets below
as the load-bearing CHECK-constraint/partial-index values, on two grounds: (i) the
`done`/`escalated`/`dead` status values are each independently attested elsewhere in the
same fetched spec (build-spec lines 108, 111, 118 — not bare inference), and (ii) the
escalation ladder is reconciled against ADR 0014, which the ratifier ruled governs inside
hq (see below). **Ratified sets:**

- `role` ← `router | worker` (unchanged, not truncated).
- `tier` ← `light | default | strong | fable`. `fable` rows are **router-dispatch-only** —
  a worker row is never minted at `fable`; only the router's own escalation path may hand a
  task to a Fable-tier dispatch. The spec's own `light | default | strong` (Router Protocol
  Rule 2) is extended with the fourth value to reconcile with ADR 0014, which places Fable
  above Opus (`strong`) as a dispatch-only apex tier.
- `status` ← `spawning | active | done | escalated | dead`.

**Escalation-ladder reconciliation (OQ3.ii, RATIFIED):** ADR 0014 governs the ladder inside
hq. Spec E3 ("a prior attempt failed or was bounced back → escalate one tier up") handles
the first hop, e.g. `default → strong`. From `strong` (Opus) upward, ADR 0014 owns it:
first Opus failure → one retry with upgraded spec + verification rigour; second Opus
failure → mandatory Fable dispatch; never a third Opus attempt (`decisions/0014:55`, T1).
So an `escalated` row leaving `strong` for a second time becomes a Fable-tier dispatch, not
a same-tier retry.

**D0 (non-blocking, Haiku):** before D1–D13 fire, a cheap re-fetch of the Notion `agents`
table cell-by-cell confirms (or extends) these sets. If Notion still truncates the render,
the ratified sets above govern regardless and D0's result does not block or change any
later dispatch.

#### D0 OUTCOME — Notion enum recovery attempt (2026-09-02)

Dispatch D0 ran 2026-09-02 to recover truncated `tier` and `status` enum values from the
Notion source. **Finding: NOT RECOVERABLE.** The live re-fetch (timestamp 2026-09-02T23:37:31.579Z)
was byte-identical to the previously saved copy — line-by-line diff of the JSON `text` field
shows only a trailing-newline difference; `page_last_edited_at` matched the original fetch
timestamp exactly. `notion-search` scoped to the page returned the same truncated snippet.
No block-level IDs are exposed in the returned markup, so no raw-block fetch was possible.
The live page does NOT differ from the saved copy in any way beyond the known truncation — the
spec has not been edited since first fetch.

**Enum values recovered from the source (FINAL):**
- `tier`: `light` (verbatim from table), `default` (verbatim from table), `strong` (prose only,
  spec lines 112, 188, never in table). No other values present. The table's last cell ends with
  a trailing `\` signalling content the tool never returned.
- `status`: `spawning` (table), `active` (table), `done` (prose, lines 108, 187), `escalated`
  (prose, line 111), `dead` (prose, lines 118, 145, 180; line 180 explicit: "`registry_write`
  status to `dead`"). The string `"ongoing"` (line 119) is ambiguous — a quoted informal
  descriptor only, never an explicit status assignment, NOT confirmed as a sixth value.

**Verification method:** `command grep` (not the function-wrapped version) used throughout.
Negative controls tested with zero hits each: `heavy`, `medium`, `haiku`, `sonnet`, `opus`,
each reported as `0 hits (control: 228)` (228 lines in the saved spec file, line count verified).

**Consequence, stated plainly:** D0 CONFIRMS the ratified enum set rather than displacing it.
The `tier` ladder `light | default | strong | fable` stands on **ADR 0014's authority, not on
the spec's lost text.** The value `fable` appears NOWHERE in the Notion source spec — it exists
solely because ADR 0014's T1 makes Fable mandatory after two Opus failures, which deliberate
deviates from the spec's own "one tier up" escalation rule. This is a recorded, attributed
deviation from the source document, ratified via OQ3 (architecture §9).

**Raw capture (re-checkable):** `<session-scratchpad>/d0-enum-refetch/raw-refetch.md`

**Provenance gap, named (T2 addendum, mechanical correction 5):** the archived raw capture
above holds no `notion-search` output — `command grep -c 'search' raw-refetch.md` → 0 hits
(control: `fetch` → 2 hits). Only the re-fetch half of D0's cited evidence is archived and
re-checkable; the search half is unarchived (archive-raw lesson). This does not reopen the
finding — the substantive conclusion ("NOT RECOVERABLE", ratified sets govern) stands on the
re-fetch's independent confirmation (byte-identical live re-fetch, matching
`page_last_edited_at`), which is fully archived above.

### `messages` envelope `[SPEC]`

```json
{ "envelope": { "from": "<agent_id>", "to": "<agent_id>", "task_id": "<uuid>",
                "hop_count": 0, "kind": "task | result | escalate | status" },
  "body": "<content>" }
```
`[SPEC]` Reject any message without an envelope; reject when `hop_count` exceeds
`MAX_HOPS` (default 3).

**OQ7 RATIFIED: forward-looking scaffolding, no relay path intended.** In the pure star
topology `route_message` takes `(to, kind, body)` with no inbound envelope and workers hold
no routing tool, so **production `hop_count` cannot exceed 1**. `MAX_HOPS=3` and the hop
gate are built and tested, but only reachable in production via a synthetic construction —
acceptance test A4 is re-scoped accordingly (validator-level: construct an envelope with
`hop_count = MAX_HOPS+1`, assert rejection). Do not later "fix" the unreachable production
limit; the spec itself defers relay to "once >3 concurrent workers or multi-hop tasks
appear" (build-spec line 138).

**F7 — five pinned interfaces (T2 addendum, branch-independent unless noted):**
1. **`messages` DDL** (D2 owns): `message_id TEXT PK`, `from_agent TEXT NOT NULL REFERENCES
   agents(agent_id)`, `to_agent TEXT NOT NULL REFERENCES agents(agent_id)`, `task_id TEXT NOT
   NULL`, `hop_count INTEGER NOT NULL DEFAULT 0 CHECK (hop_count >= 0)`, `kind TEXT NOT NULL
   CHECK (kind IN ('task','result','escalate','status'))`, `body TEXT NOT NULL`, `created_at
   TEXT NOT NULL`, `read_at TEXT NULL`; index on `(to_agent, read_at)`.
2. **`read_messages`** (D7 owns): input `{ auth_token, filter?: { kind?, task_id?,
   unread_only? }, mark_read?: bool = true }`; returns only messages whose `to_agent` is the
   resolved caller (middleware-scoped), oldest-first; `read_at` set on return when
   `mark_read`; non-destructive — rows retained (TTL stays named future work, §10).
3. **`thread_ref` (amendment 7 — branch (iii) fixed shape):** opaque TEXT to the schema;
   JSON string `{"kind":"session","session_id":"<uuid>","last_pid":N|null}` —
   `session_id` is known **before** the process starts (minted by `spawn_agent`, passed as
   `--session-id` at first spawn); `last_pid` is the most recent invocation's pid, `null`
   between invocations.
4. **Worker working directory (amendment 7 — wired into D6):** the server creates
   `$DATA_DIR/workers/<agent_id>/` per agent, `provision.js` copies the worker skill there,
   and **every invocation** (`--session-id` at first spawn, `--resume <session_id>` on
   later routing) runs with that cwd — env-driven (P2) and collision-free
   (shared-scratchpad lesson: concurrent agents get unique subdirs).
5. **`auth_token` schema fragment** (D3 owns): one shared, exported schema fragment in
   `identity.js`; every handler composes it. D5's done condition extends: a check proves all
   10 registered tools' input schemas include `auth_token`.

## 5. Write asymmetry and identity resolution

`[SPEC]` "only the Router holds mutating tools (`spawn_agent`, `registry_write`). Workers
hold read + exit tools only. This makes each agent structurally incapable of acting as the
other role."

**A tension I am resolving, not papering over** `[MINE]`: "structurally incapable" implies
the mutating tools are *absent* from a worker's tool surface. But one MCP server publishes
one tool list to every client, and the spec's own acceptance test says a worker *calling*
`spawn_agent` gets `PERMISSION_DENIED` — i.e. the tool is present and rejected. I resolve
in favour of the acceptance test: **asymmetry is enforced by middleware rejection, not tool
absence.** The design record says so plainly rather than repeating the stronger claim. If
the owner wants true structural absence, that is a second MCP server (worker-only surface)
and a different deployment topology — flagged, not assumed.

**Identity resolution — OQ1 RATIFIED: capability token.** `[SPEC]` "Resolve caller identity
for `whoami`/permission checks from the session/thread ID mapping in the runtime — never
from a self-reported `agent_id` parameter." No such runtime identity channel exists: the
transport is stateless (`server.js` `sessionIdGenerator: undefined`), and the only working
local precedent — the swarm bus — does the forbidden thing (`send_message.js:26`
`from_agent: z.string(...)`, self-reported). The ratifier's mechanism, which this design
now builds:

- `spawn_agent` mints an unguessable **≥128-bit token** per agent at spawn time, stores a
  **hash** of it in the registry row (never the raw token), and injects the raw token into
  the Worker Preamble.
- Every subsequent tool call carries the token as `auth_token`; `middleware.js` resolves
  `auth_token` → row by hash lookup. The router's own token is **bootstrapped-or-adopted**
  at server init (F1, T2 addendum), not blindly inserted: in one transaction, SELECT the
  active router row; if none exists, INSERT it (server-minted `agent_id`), mint the token,
  and write the mode-600 file; if one already exists, **ADOPT** it — reuse the row, and if
  the token file exists with a hash matching the row, reuse the token, else **ROTATE** (mint
  a new token, update the row hash, rewrite the file). No blind INSERT ever occurs, so a
  restart never trips the Invariant-1 partial unique index (`idx_one_router`, §6), and a
  crashed server's leftover active row is adopted rather than duplicated. **Restart/policy:**
  a bootstrap-or-adopt on the same DB is idempotent — two consecutive server starts yield
  exactly one active router row with no uniqueness error, and after a restart `whoami` with
  the router's token (reused or rotated) resolves to that same row. Assignment (ADDENDUM 5): `identity.js`
  (D3) supplies the PURE primitives (`mintToken`/`hashToken` — no fs, no config imports);
  `registry.js`'s `bootstrapRouter()` (D4) owns the whole transaction INCLUDING the
  adopt-vs-rotate decision and all `ROUTER_TOKEN_FILE` I/O; `server.js` (D13) calls it at
  startup.
- **Tokens are never printed** — no tool logs, error message, or transcript may echo a raw
  token (the Maestro-echo lesson: a value that prints to stdout leaks through any
  transcript). Every brief that touches `identity.js`, `spawn_agent`, or a tool handler
  carries this redaction clause explicitly. **Scoped resolution (F4, T2 addendum):** this
  bans raw tokens from *server-side* surfaces — tool results, logs, error messages — and from
  any router-side or orchestrator transcript. It does not and cannot ban the token from the
  worker's own session context: the Worker Preamble's fourth slot, `{auth_token}`, is the
  delivery channel, and the worker session's local JSONL necessarily carries what the
  preamble carries. That local JSONL sits inside the same same-user trust boundary that
  already holds the mode-600 router token file. Threat model, stated plainly: the token
  defends against cross-agent leakage through shared and relayed surfaces (transcripts other
  agents or the orchestrator can read, logs, tool results) — not against a same-user process
  reading its own local files, an adversary that could read the router's token file too.
  This scoped form is what ADR 0035 §4 records; the ADR's "no transcript may echo a raw
  token" clause is amended to it.
- The spec's "never from a self-reported `agent_id`" clause is **amended**, plainly: identity
  is never self-**asserted**; a bearer token is caller-supplied but **unforgeable**. This is
  a downgrade from true runtime identity to unforgeability, and the record states it as
  such rather than overclaiming. Consequence if the token is ever mishandled: a leaked
  token enables impersonation, which is exactly why the redaction clause is non-negotiable.

Everything in this design that depends on knowing *who is calling* — `whoami`, every role
gate, `report_result`'s "sets own status", `heartbeat`'s "updates own `last_active_at`" — is
downstream of this module, and the mechanism above is what it now resolves against.

## 6. The six invariants and how each is enforced

| # | Invariant `[SPEC]` | Enforcement `[MINE]` | Strength |
|---|---|---|---|
| 1 | Exactly one active `router` row | SQLite **partial unique index**: `CREATE UNIQUE INDEX idx_one_router ON agents(role) WHERE role='router' AND status='active'` | Schema-level — cannot be bypassed by any code path |
| 2 | Only the router may call `spawn_agent`, `registry_write`, `route_message` | `middleware.js` role gate: resolve caller → read its row → require `role='router'` → else `PERMISSION_DENIED` | Server-side, single seam |
| 3 | Workers exit only via `report_result` / `escalate` | TWO layers (ADDENDUM 7): D5 seam role-gate (runtime — the only door for external callers) + capability-shaped registry primitives (`setWorkerStatus` worker-lane rejects all but `done`/`escalated`; `patchAgent` router-lane, banned from worker-reachable handlers by build-time grep) | Seam + primitives + build-time grep |
| 4 | Every live session ↔ exactly one registry row (no drift) | **Enforceable — branch (iii) (T2 addendum OQ4 re-ruling, owner-selected 2026-09-02).** Row→session: atomic spawn with rollback (§4 of spec), unchanged. Session→row: under branch (iii), "live session" = the registry row's stored `session_id` plus an optional currently-running pid — the durable half of the mapping is row↔session (`check_status`/`whoami` resolve the stored `session_id`), and true pid liveness only exists **during** an invocation (`claude -p --session-id`/`--resume`), not between them | **Server-side; pid-liveness component is invocation-scoped, not continuous — see the risk record below** |
| 5 | All messages carry envelopes; `hop_count ≤ MAX_HOPS` | **Two-part, reconciled — ADDENDUM 11.** `middleware.js` validates an envelope only when `args` already carries one (opt-in-by-presence): `route_message`'s ratified `(to, kind, body)` signature (OQ7) has no inbound envelope, so the seam runs BEFORE any envelope exists and cannot gate on its absence without making `route_message` uncallable. The actual guarantee for `route_message` — every outbound message it sends is a well-formed envelope — is D9's handler obligation: construct via `buildEnvelope` (server-resolved `from`, never caller-supplied) and `validateEnvelope` it before the single-transaction `messages` write. D7's `report_result`/`escalate` write path RULED (ADDENDUM 16 R3): direct `messages.js` `createMessage` write, NO envelope construction — every field is server-derived/tool-fixed, so the DDL's NOT NULL/CHECK/FK constraints are the well-formedness guarantee; D7 stays before D9 | Handler-level (D9, for `route_message`) is the real enforcement point; the seam is defense-in-depth for any future envelope-carrying call, not the primary guarantee |
| 6 | Worker prompt never contains Router Protocol; router's never contains the Worker Preamble | Provisioning-time property, not a runtime one. Enforced by (a) two separate skill directories now inside the portable root (`tools/agent-topology/skills/`, P1), (b) `preamble.js` being the only injector, (c) a **build-time test** that greps each SKILL.md for the other role's marker strings, (d) a check that no `agent-topology-*` symlink exists in `~/.claude/skills/` (OQ6) | Build-time assertion |

**OQ4 RE-RULED — branch (iii): session-persistent, process-ephemeral (T2 addendum,
owner-selected 2026-09-02).** The original OQ4(a) ruling above (detached one-shot
`claude -p` child) was **falsified** by an independent Opus verifier under ADR 0014 T2: a
one-shot `-p` process prints its response and exits, so it cannot receive `route_message`
dispatch to an existing agent (spec:114-115), cannot be usefully `check_status`-gated
before routing (spec:119), and has no plural "work cycles" for `heartbeat()` (spec:132) —
full falsification detail in the T2 ADDENDUM, `architecture/agent-topology-ratification.md`,
"The falsification, accepted." The orchestrator asked the owner to choose among three
branches, given `claude --help`'s `-r/--resume [value]` (help:191) and `--session-id <uuid>`
(help:205) flags; the owner selected **"Take Fable's recommendation,"** which was branch
(iii).

**The mechanism, as ruled:** the durable agent = registry row + a Claude **session**, not a
process. `spawn_agent` mints the session id itself and passes `--session-id <uuid>` at first
spawn, so `thread_ref`'s `session_id` (§4 F7 point 3) is known **before** the child process
starts. `route_message` to an existing agent = the server runs
`claude -p --resume <session_id>` — a fresh one-shot process against the SAME session,
preserving the agent's accumulated context (the actual value route-existing exists for).
`heartbeat` = per-invocation: one resumed invocation is a "work cycle," genuinely plural
across the agent's lifetime; `last_active_at` staleness is meaningful across invocations
rather than only within one process's lifetime. Any step failure at spawn still rolls the
row back, preserving atomicity for acceptance test A2 (re-scoped, §9).

> **RISK / ASSUMPTION — READ BEFORE BUILDING D6 OR D9 — EMPIRICALLY UNVERIFIED.**
> Branch (iii) is the owner's decision and Fable's design recommendation, but its core
> mechanism — a headless `claude -p --resume <session_id>` call actually resuming a prior
> session and returning output — **has never been executed successfully in this
> environment.** Three probes were attempted, in three different execution contexts, and
> **all three failed** — none by the mechanism succeeding and then breaking, all before the
> mechanism itself was ever reached:
> - **Probe 1 (sandboxed):** `claude -p --session-id ... --model haiku ...` → exit 1,
>   verbatim stdout `Not logged in · Please run /login`. A bare control call
>   `claude -p --model haiku "say hi"` hung silently 30s with zero stdout/stderr, killed
>   exit 137. A Keychain diagnostic was then refused by the auto-mode classifier. Raw
>   captures:
>   `<session-scratchpad>/probe-resume/`.
> - **Probe 2 (owner-authorized `dangerouslyDisableSandbox: true`):** `claude --version` →
>   `2.1.251 (Claude Code)` succeeded, but the baseline `claude -p` call was refused at the
>   permission layer before executing, verbatim: `Permission for this tool use was denied.`
>   Raw captures:
>   `<session-scratchpad>/probe-resume-2/`
>   (contains only the version output).
> - **Probe 3 (the owner's own unsandboxed shell, no subagent involved):**
>   `claude -p --model haiku "say hi"` → verbatim stderr `Not logged in · Please run
>   /login`. This removes both the sandbox and the permission layer as explanations for
>   that probe's failure — it ran as the owner, directly.
> - **This casts doubt on `spawn_agent` itself, not only on `--resume`.** Probe 1 already
>   invoked `-p --session-id`, the same first-spawn form `spawn_agent` uses, and failed the
>   same way (`Not logged in`) — the doubt is not confined to the `--resume` half of the
>   mechanism. **D6's smoke test may therefore fail for environment/auth reasons, not
>   design reasons** — a failure there does not by itself indict branch (iii) as a design.
> - **UNVERIFIED LEAD, not asserted as fact:** hq's own records show `<personal-project>` has
>   been broken since 2026-07-25, with a recorded root cause of "claude CLI logged out,
>   dual-account conflict" — the same symptom, on the same machine. Named as a lead only;
>   not confirmed here as the cause of the three failures above.
> - **OPEN LEAD, currently under separate investigation — do not assert as resolved:** the
>   owner states that other Claude Code chats on this machine CAN run `claude -p`
>   successfully, and that an OAuth-token environment variable exists which those sessions
>   pick up — implying the three failures above may be an environment-inheritance problem
>   (this execution context not inheriting that variable) rather than a machine-wide
>   logout. A separate probe is testing this concurrently; its result is **not yet known**
>   here and this lead must not be treated as resolving the risk.
> - The flags this branch depends on are **help-text-verified only, never
>   execution-verified**: `-p, --print` (help:152), `-r, --resume [value]` (help:191),
>   `--session-id <uuid>` ("must be a valid UUID", help:205), `-c, --continue` (help:59),
>   `--fork-session`, `--output-format` (print-only).
> - **This is neither "expected to work" nor "verified."** It is a design decision, ratified
>   and owner-selected, resting on an unexecuted mechanism. **D6's opening smoke test is the
>   gate** (expanded, amendment 7, below): it must actually invoke `-p --session-id` at a
>   first spawn AND `-p --resume <session_id>` at a subsequent routing call, not just a bare
>   `-p` call. **A smoke-test failure is STOP-THE-LINE**, not a signal to silently fall
>   back. **The fallback to branch (i)** (one-shot workers; `route_message` route-to-existing
>   and `heartbeat` redefined as documented NON-GOALS) **requires OWNER SIGN-OFF and may NOT
>   be taken unilaterally by any agent** — branch (i) being cheaper does not authorize taking
>   it; only the owner may give up on the branch the owner selected.

**D6 opens with an EXPANDED smoke test (amendment 7):** both `-p --session-id <uuid>`
(first spawn) and `-p --resume <session_id>` (route-to-existing) must be independently
proven to run from a Node `child_process` and return output before any handler code is
written against the mechanism. **STOP** on either failing — see the risk record above.

Invariant 6 is now the only one of the six that stays a build-time/provisioning-time
property rather than a runtime-enforceable one. Saying so plainly, and giving it its
checkable form (the two grep-based tests above), is deliberate — inventing a runtime
enforcement mechanism for a provisioning-time property would be exactly the kind of
un-flagged invention this record is meant to avoid.

## 7–8. Where things live; Settled design decisions

**Moved to part 2 (amendment 8, doc-consistency pass)** — `agent-topology-02.md` §7–§8 —
to keep this file under the 500-line cap after the risk-record additions above (T2
addendum amendment 1: probe 3, the `spawn_agent` doubt, the UNVERIFIED and OPEN leads).
§7 covers the registry DB file location, the ratified skill location (P1), and skill
provisioning (OQ6, no global symlink); §8 is the D1–D7 settled-decisions table.

## 9. OPEN QUESTIONS — ALL RESOLVED (T6 ratification, 2026-09-02)

All eight open questions below were blocking as originally drafted. Every one is now
**RESOLVED** by `architecture/agent-topology-ratification.md`; full reasoning and citations
live there and (for OQ1, OQ3, OQ4, OQ7) inline above in §4–§6, and (for OQ6) in part 2 §7.
This section keeps the original questions for record-keeping and states each ruling in one
line.

**OQ1 — RESOLVED: capability token (§5).** Identity is never self-asserted; a spawn-minted,
hashed-at-rest bearer token is caller-supplied but unforgeable. Not runtime identity —
unforgeability, and the record says so plainly.

**OQ2 — RESOLVED BY THE OWNER: inside hq, as an explicit STANDARDS §7 / ADR 0010 exception,
because the system will be ported to a separate work environment.** Root fixed at
`tools/agent-topology/`. This is the ruling that promoted portability to a first-class
requirement — see part 2 §12. Provenance and the exception itself are recorded in ADR 0035.

**OQ3 — RESOLVED, two parts (§4).** (i) The `done`/`escalated`/`dead` status values are
independently attested elsewhere in the fetched spec, not bare inference. (ii) ADR 0014
governs the escalation ladder inside hq; `tier` gains a fourth value, `fable`
(router-dispatch-only), reconciling the spec's 3-tier scheme with ADR 0014's apex tier.

**OQ4 — RE-OPENED then RE-RULED: branch (iii), session-persistent/process-ephemeral,
owner-selected 2026-09-02 (§6).** The original option-(a) ruling (detached one-shot
`claude -p`) was falsified by ADR 0014 T2 — a one-shot process cannot receive
route-existing dispatch or plural heartbeats. Given `-r/--resume` and `--session-id`, the
owner took Fable's recommendation: `spawn_agent` mints a session id and passes
`--session-id` at first spawn; `route_message` to an existing agent runs
`claude -p --resume <session_id>`. **This mechanism is empirically unverified in this
environment — see the risk record in §6.** D6's expanded smoke test is the gate; a failure
is STOP-THE-LINE and the branch-(i) fallback needs owner sign-off, not agent discretion.

**OQ5 — RESOLVED: spec defect, remedied in-system, not the bus.** The 9-tool surface had no
message-read path — `report_result`'s and `escalate`'s writes were unreadable by design.
Remedy: a 10th tool, `read_messages`, over the topology's **own** `messages` table (not the
bus), because `report_result` must write the result message and the `done` status in one
SQLite transaction — a bus hop would reopen exactly the drift bug the spec kills. The bus
stays untouched and complementary. Named, not built: this is a second unbounded message
table (see §10) — TTL/cleanup is deliberately future work.

**OQ6 — RESOLVED: neither skill is globally symlinked (part 2 §7).** Both install project-scoped
— the router skill in the router's own environment, the worker skill via `provision.js`
COPY into each worker's working directory — as a recorded per-role exception to ADR 0009.

**OQ7 — RESOLVED: forward-looking scaffolding, no relay path intended (§4).** Production
`hop_count` cannot exceed 1 in a pure star. `MAX_HOPS`/the hop gate are built and tested,
but acceptance test A4 is re-scoped to a synthetic validator-level test.

**OQ8 — RESOLVED: the build spec governs.** The companion page (Router Protocol) is the
pre-tooling manual protocol, explicitly superseded on the working-context point by the
build spec's own router SKILL.md: "Topology state lives in the registry, not your memory.
Never answer from memory" (build-spec lines 172–173). Router Protocol Rules 0, 2, and 5
(DECISION block, tier triggers, bounce-back) remain live — they are exactly the ones the
skill cites by number; Rule 3's working-context table is the one rule superseded.

---

**Continued in part 2 — `agent-topology-02.md`:** Where things live (§7) and settled design
decisions (§8), moved here at amendment 8 (T2 addendum, doc-consistency pass) to keep this
file under the 500-line cap after the risk-record additions in §6; Named, not acted on
(§10); Does this need an ADR (§11, answered — `decisions/0035-agent-topology-hq-exception.md`);
Portability and lift-and-port procedure (§12, P1–P5, including the branch-(iii) updates to
P4/P5 — the OQ4 mechanism's port-time preflight is the same D6 smoke test gated as
STOP-THE-LINE in §6 above, not a separate, lower-stakes porting quirk).
