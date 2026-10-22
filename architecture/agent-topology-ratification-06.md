# agent-topology — ratification record, PART 6 (continues -05.md)

Split provenance: `agent-topology-ratification-05.md` measured 483 lines at ADDENDUM 18
time (`wc -l`, this dispatch); ADDENDUM 18 below cannot fit under the 500-line cap.
Per ADR 0029 clause 3/4.1, carved into this new part rather than committing an
over-cap state — the same split -05 made from -04 at ADDENDUM 15.

---

# ADDENDUM 18 — D12 pre-code stop ruled: `touchAgent` pinned (R1), folded into ONE
re-dispatched D12 (R2), Invariant-3 check re-pinned derived-scope + comment-safe (R3)
(2026-09-03)

Ratification authority dispatch (fresh instance), ruling on D12's correct stop. Ruled at
HEAD `dd92319`, branch `wt/agent-topology`, working tree clean (`git status --porcelain`
→ empty, this dispatch). Docs only; nothing under `tools/agent-topology/` is touched by
this ADDENDUM or its commit. Every load-bearing claim cites a command run by THIS
dispatch or a file+line read directly at `dd92319`.

**D12's stop was CORRECT.** `heartbeat` is worker-reachable (not in
`ROUTER_ONLY_TOOLS`, `middleware.js:67`), must write its own `last_active_at`, and no
permitted path exists: `patchAgent` is banned from worker-reachable handlers by name
(`agent-topology-ratification-02.md:196-199`; §13:179; D5 done condition,
`plans/agent-topology.md:129`), `setWorkerStatus` writes only `status`
(`registry.js:204-213`), and raw SQL is forbidden generally (ADDENDUM 12 G1,
`agent-topology-ratification-04.md:33-39`, which names D12 as the anticipated hazard).
A missing primitive is an additive-pin request — this is that request, granted.

## R1 — RULED: `touchAgent(db, agentId)` → row. Accepted as proposed, shape pinned

Pinned signature and behavior — an implementer needs no further interpretation:

- **`touchAgent(db, agentId)`** — sets exactly `last_active_at` to
  `new Date().toISOString()` (the module's timestamp convention, `registry.js:117`);
  writes nothing else. Returns the patched row (`SELECT *` — carries `token_hash`;
  stripping is D5's job, `registry.js:59-63` advisory, same as every row-returning
  sibling).
- **Implementation is the `setWorkerStatus` delegation pattern** (`registry.js:204-213`):
  one statement, `return patchAgent(db, agentId, { last_active_at: new
  Date().toISOString() })`. `last_active_at` is already in `ALLOWED_PATCH_FIELDS`
  (`registry.js:79`). No own `requireDb`, no own existence check — both inherited from
  `patchAgent` (`registry.js:168-171`), exactly as `setWorkerStatus` inherits them. An
  in-registry delegation to `patchAgent` is NOT a worker-handler reference — the
  Invariant-3 grep scopes to `tools/` handler files, and `setWorkerStatus`'s identical
  delegation is already ratified (ADDENDUM 7; `registry.js:32`).
- **Missing row → `patchAgent`'s `NOT_FOUND` throw** (echoing `agentId` — the
  D4.2-ruled exception, `registry.js:51-57`). Correct for heartbeat: a beat from an
  unknown/deleted row must fail loud, never silently no-op.
- **No caller-role parameter, no liveness/terminal-status inspection.** A role param is
  the banned self-reported-role anti-pattern (`agent-topology-ratification-02.md`,
  ADDENDUM 7 region); state inspection is not the primitive's job — `setWorkerStatus`
  likewise writes without reading current status. "Own row" is the seam's guarantee:
  the `heartbeat` handler passes `ctx.caller.agent_id`, never a caller-supplied id
  (`registry.js:36-38` discipline, verbatim the D7 rule).

**Consequence if wrong:** minimal — `touchAgent` is a strict narrowing of the already-
pinned `patchAgent`; no shipped caller consumes it yet, so any later reshape is one
additive amendment. Consequence of NOT ruling: D12 stays blocked, or reaches for raw
SQL — the exact Invariant-3 bypass ADDENDUM 12 G1 exists to prevent.

## R2 — RULED: added to `registry.js` directly; ONE re-dispatched D12 builds all three

- **Headroom confirmed:** `registry.js` is 254 lines (`wc -l`, this dispatch); cap 300.
  `setWorkerStatus`'s block (doc comment + function, `registry.js:195-213`) is 19
  lines; `touchAgent`'s will match it, plus one `module.exports` line — landing ≈275,
  under the cap. (`deleteAgent`'s 32-line block, `:215-246`, is the ceiling case; even
  that fits.)
- **Location:** `registry.js`, additive — the ADDENDUM 12 G1 / `deleteAgent` precedent
  verbatim: an `agents`-table write primitive belongs in the agents-table CRUD module;
  routing around a frozen-and-verified module is what the precedent forbids.
- **Dispatch: ONE re-dispatched D12, no D12.0.** The re-dispatch builds, in order:
  (1) `touchAgent` in `registry.js` + its header EXPORT-SURFACE note + export line;
  (2) `tools/heartbeat.js`; (3) `tools/check_status.js` — one pass. `deleteAgent` got
  its own slice (D6.1) because D6 had ALREADY shipped with gaps — a remediation
  dispatch; D12 stopped cleanly before writing code, so there is nothing to remediate
  and a separate slice buys only coordination overhead (ADDENDUM 14's chain-shape
  lesson: no unnecessary narrow slices). Model stays the plan's pinned Haiku
  (`plans/agent-topology.md:142`) — this ruling removes the interpretation that made
  D12 stop; what remains is mechanical. Non-author verify per the plan row, done
  condition now including R3's corrected check. **STOP guard carried into the brief:**
  if `registry.js` would cross 300, stop — ADDENDUM 13's split pattern, never a
  comment-trim (ADDENDUM 15's `route_message` lesson).

**Consequence if wrong:** one Haiku dispatch redone; the failure mode of the cap math
being off is a loud stop at the 300 gate, not a silent overrun.

## R3 — RULED: the check as SHIPPED does not false-positive today, but is
under-inclusive; re-pinned with DERIVED scope and a comment-excluding pattern

Verified facts (this dispatch):

- `tools/read_messages.js:125` contains `patchAgent` inside a `//` comment ("the
  patchAgent precedent") — read directly. Positive control for the grep itself: the
  same `command grep -rn patchAgent tools/` finds real code refs at
  `spawn_agent.js:88` (require destructure) and `:261` (call).
- The shipped check names THREE files — `report_result`/`escalate`/`heartbeat`
  (`plans/agent-topology.md:129`; `agent-topology-ratification-02.md:196-199`).
  `command grep -c patchAgent` on `report_result.js`/`escalate.js` → 0 and 0;
  `heartbeat.js` does not exist. **So the check as written passes today —
  `read_messages.js` is not in its file list and no false positive currently fires.**
- BUT the runtime worker-reachable set is "everything not in `ROUTER_ONLY_TOOLS`"
  (`middleware.js:67,156`): today `read_messages` ("any agent" by ratified design,
  `plans/agent-topology.md:136`), `whoami`, `report_result`, `escalate` — plus
  `heartbeat`/`check_status` when D12 lands. The named-three list predates D7 and is
  UNDER-inclusive — a silent enforcement gap, strictly worse than D12's flagged false
  positive. D12's flag is right in substance: the moment the scope is correctly
  widened, `read_messages.js:125` trips a naive grep.
- No committed check script exists to fix (`find . -name '*.sh'` under
  `tools/agent-topology` → none; `package.json` scripts are `start`/`test`/`lint`
  only) — the check is a done-condition PROCEDURE, so this re-pin IS the fix. No code
  dispatch needed; docs-only compatible.

**The re-pinned check (supersedes the three-file wording wherever cited):**

- **Scope, derived not enumerated:** every `tools/*.js` whose tool name is NOT in
  `middleware.js`'s `ROUTER_ONLY_TOOLS` — future worker-reachable tools are captured
  automatically.
- **Pattern:** `command grep -n 'patchAgent' <files> | command grep -vE
  ':[[:space:]]*(//|\*)'` → must emit 0 lines. Pure `//` and `*` block-comment lines
  are excluded; code-with-trailing-comment still counts (fails loud — the right error
  direction).
- **Positive control (mandatory, unchanged in spirit):** the same pipeline on
  `tools/spawn_agent.js` must emit ≥2 lines (today `:88` and `:261`; its `:16`
  block-comment line correctly filtered out).
- **Proven by this ruling:** corrected pipeline over the four current worker-reachable
  files → 0 lines (the raw grep first emits exactly the `read_messages.js:125` comment
  hit, demonstrating the filter earns its place); positive control → 2 lines.

Folded into the same D12 re-dispatch's done condition. **Consequence if wrong:** a
mis-derived scope either false-positives (loud, safe) or reverts to the named-list gap
(silent) — the derived form makes the loud failure the default.

## Named, not acted on

- `registry.js`'s header EXPORT-SURFACE comment must gain the `touchAgent` line — a
  code-file edit, done by the D12 re-dispatch, not by this docs-only ruling.
- Post-terminal heartbeat: a worker whose row is already `done`/`escalated` can still
  call `heartbeat` and refresh `last_active_at`. The primitive stays unconditional
  (matching `setWorkerStatus`); whether the handler no-ops on terminal status is D12's
  handler-level call, named for its brief, not pinned here.
- `plans/agent-topology.md:129` (D5 row) keeps its historical three-file wording
  verbatim; this ADDENDUM governs — same convention as §4's envelope sketch under
  ADDENDUM 17 R3.
- Stale cross-reference: `agent-topology-ratification-04.md:29` cites
  `plans/agent-topology.md:332-335`, but the plan is 209 lines (`wc -l`); the cited F7
  point-4 content now lives at `plans/agent-topology.md:130`. Historical text, left
  verbatim; does not bear on R1-R3.

---

# ADDENDUM 19 — plan-origin gap ruled: `registry_read.js` + `registry_write.js` never
dispatched; both BUILT (R1/R2 pins), one new dispatch D14 before D13 (R3), A1 re-run
named (R4) (2026-09-03)

Ratification authority dispatch (fresh instance), ruling on the two missing tool files.
Ruled at HEAD `1325658`, branch `wt/agent-topology`. Docs only; nothing under
`tools/agent-topology/` is touched by this ADDENDUM or its commit. Every load-bearing
claim cites a command run by THIS dispatch or a file+line read at `1325658`.

**The gap, confirmed at origin.** `ls tools/agent-topology/tools/` → 8 files; §13's own
row says `tools/*.js (10 files)` (agent-topology-02.md:187). The full dispatch table
(D0–D13 + every D6.x/D10.x row, plans/agent-topology.md:126-143, read in full) assigns
`registry_read`/`registry_write` to NO row — the spec's build-order step 1 names both
(spec:134, "Registry (data model + `registry_read`/`registry_write` + role enforcement)")
but the plan's S1 rows (D1–D5) built the store, schema, identity, primitives, and seam
without the two tools. A plan-authoring omission, not an implementer's: D7's own row even
calls `read_messages` "the 10th tool" — the count always included these two. Meanwhile
`middleware.js:67` hardcodes `'registry_write'` in `ROUTER_ONLY_TOOLS` (direct read), and
the committed A1 test loads the REAL file (`a1-role-gate.test.mjs:146`,
`loadExportedTool(new URL('tools/registry_write.js', ROOT).href)`) — both reference a
file that has never existed. D13 cannot register 10 tools from 8 files.

## R1 — `registry_read` is BUILT AS SPECIFIED, not struck. The count stays 10.

Not superseded, on four cited grounds: (a) `whoami` returns ONLY the caller's own row
(`tools/whoami.js` handler: fields off `ctx.caller`, no query); (b) `check_status`
requires a known `target_agent_id` and returns ONE row's computed liveness
(`check_status.js:60-71`) — neither can LIST agents; (c) the D11-SHIPPED router skill's
per-message step 2 is `registry_read({ auth_token, status: "active" })`
(`wt/agent-topology-skills` tree, `skills/agent-topology-router/SKILL.md:14`) — striking
the tool orphans a ratified, F3-verified skill line; (d) the spec makes it load-bearing
for BOTH roles: "Workers use it to learn their parent and topology position; Router uses
it for route-existing matching" (spec:91-94). **Consequence if struck:** the router skill
instructs a nonexistent tool; route-existing matching has no mechanism, so "Never spawn a
duplicate for a scope an active agent owns" (SKILL.md rule) becomes unsatisfiable.

**Pinned shape — `tools/registry_read.js` (all agents, S1):**

- **Input schema:** `{ auth_token (authTokenShape, F7 pt 5), role?, status?, scope_query? }`,
  `required: ['auth_token']`. Filter fields FLAT at top level — the spec's own skill text
  calls it flat (`registry_read({ status: "active" })`, spec:177) and the shipped D11
  skill matches; spec:92's `filter?` object IS the argument object. `role`/`status` carry
  the ratified enum arrays in the inputSchema (defense in depth; schema CHECKs are the
  authority). `scope_query` (string, minLength 1): literal substring match on `scope` —
  SQL `LIKE '%'||?||'%' ESCAPE`, with `%`/`_`/escape char escaped in the input so
  wildcards are treated literally.
- **Output:** the array of matching registry rows directly (spec:93 "Output: array of
  registry rows"), ordered `created_at` ASC (deterministic), each row enumerated via the
  `whoami` `RETURNED_FIELDS` convention — every column EXCEPT `token_hash`, explicit
  allow-list, never `SELECT *` spread (whoami.js's shipped defense-in-depth pattern; the
  seam's `sanitize` remains the second layer).
- **No role restriction** (spec:91 "all agents"): absent from `ROUTER_ONLY_TOOLS`, no
  handler role check, no middleware change.
- **Primitive (additive §13 pin):** `listAgents(db, filter?)` in `registry.js` — filter
  keys exactly `role`/`status`/`scope_query`; an unknown filter key throws
  `INVALID_REQUEST` (loud, never silently ignored); returns rows; SQL errors rewrapped by
  `rethrowSqlError`. Raw SQL in the tool file stays forbidden (ADDENDUM 12 G1).
  **Cap pre-ruling:** `registry.js` is 279/300 (`wc -l`, this dispatch); if a conforming
  `listAgents` cannot land at ≤300, the pre-authorized remedy — no stop needed — is a new
  package-root sibling `registry_query.js` with sole export `listAgents` (the
  `messages.js`/`bootstrap.js` split precedent), recorded in the commit message and given
  a §13 row citing this ADDENDUM.

## R2 — `registry_write` pinned: thin allow-list layer over `patchAgent`, seam-gated.

Cannot be struck: `ROUTER_ONLY_TOOLS` (middleware.js:67), A1 (plan:158 + the committed
real-file test), Invariant 2 (spec:122, architecture §6 row 2), and the shipped router
skill (SKILL.md:21,32) all depend on it as a distinct tool.

**Pinned shape — `tools/registry_write.js` (ROUTER ONLY, S1):**

- **Input schema:** `{ auth_token (authTokenShape), agent_id (string, minLength 1),
  status?, scope?, tier?, last_active_at? }`, `required: ['auth_token','agent_id']`. FLAT
  patch fields — forced by two shipped artifacts: A1 passes
  `{ auth_token, agent_id, status: 'dead' }` (`a1-role-gate.test.mjs:155-160`) and the D11
  skill calls `registry_write({ auth_token, agent_id, status: "dead" })` (SKILL.md:21).
  `status`/`tier` carry the ratified enum arrays in the inputSchema; `last_active_at` is
  an ISO-8601 string (no schema CHECK exists on it — router-trusted, named below).
- **Handler validation (the tool's whole job beyond delegation):** (1) at least ONE of the
  four patch fields present, else `INVALID_REQUEST`; (2) any arg key outside the six named
  above → `INVALID_REQUEST` (loud-reject, the D6.3 defense-in-depth pattern — a typo'd
  field must never silently not-patch); (3) build `patch` from exactly the present
  allow-listed fields.
- **Mutation scope: exactly `{status, scope, tier, last_active_at}`** — spec:96 verbatim
  ("partial row (status, scope, tier, last_active_at)"). NOT `name`/`role`/`parent_id`/
  `thread_ref`/`token_hash`: `patchAgent`'s broader `ALLOWED_PATCH_FIELDS`
  (registry.js:81-84) is the INTERNAL router-lane surface (`bootstrapRouter`,
  `spawn_agent`); the tool exposes only the spec's subset. **Consequence if
  unrestricted:** a router tool call could rewrite `role` or `token_hash` — role forgery
  and token-hash manipulation through the public tool surface, breaking the write-
  asymmetry field discipline and the §5 token threat model.
- **Behavior:** one `patchAgent(db, agent_id, patch)` call; missing row surfaces
  `patchAgent`'s `NOT_FOUND`; enum-value violations surface as schema CHECK errors via
  `rethrowSqlError`. **Output:** the patched row, enumerated via the `whoami`
  `RETURNED_FIELDS` convention (all columns except `token_hash`).
- **Role gate: seam-only, definitionally correct.** Already in the frozen
  `ROUTER_ONLY_TOOLS` (middleware.js:67); NO handler-level role check — identical to
  `spawn_agent`/`route_message`. ADDENDUM 16 R4's handler-level checks exist only for
  WORKER-only tools, which the seam's router-only list cannot express; this tool is the
  case the seam was built for.
- **Named, not acted on:** the router may patch its OWN row (e.g. `status: 'dead'`) —
  router-only foot-gun, deliberately ungated; `last_active_at` has no format CHECK in the
  schema — router-trusted, not validated beyond type.

## R3 — one new dispatch, **D14**, after D12, BEFORE D13.

(a) selected: a single fresh dispatch building `listAgents` + both tool files — they are
the spec's S1 remnant, one coherent unit of the same shape (thin tools over primitives,
`whoami`/`check_status` precedent), and ADDENDUM 14's no-unnecessary-slices lesson says
don't split small pinned work. NOT folded into D13: D13 carries distinct concerns and its
own STOP triggers (server plumbing, F1 bootstrap-at-init, the §14 port-file startup STOP)
— a tool-shape defect surfacing as a D13 stop would entangle two unrelated failure
surfaces, and D13's done condition ("registers all 10") is only satisfiable AFTER these
files exist. "D14" not a renumbered D8.x: the D6.x/D10.x convention numbers follow-ups of
an existing row; no row ever owned this work. **Model: Sonnet** (all judgment pinned
here; matches D7's tier for the same shape), Sonnet non-author verifier. Serial order
amended: … D9 → D12 → **D14** → D13.

## R4 — A1 needs a RE-RUN, not a rewrite. Named, not acted on.

D5's A1 evidence used a synthetic tool object named `registry_write` passed to `wrapTool`
— VALID as a seam role-gate proof (the gate keys on `toolDef.name`, middleware.js:63-67,
so any object bearing the name exercises the same path) but never proof of the file. The
COMMITTED A1 test already loads the real `tools/registry_write.js`
(`a1-role-gate.test.mjs:146`) with an input conforming to R2's flat pin — so no D10.x
amendment dispatch is needed; the test would currently fail module-not-found and will
bind to the real file the moment D14 lands. **Follow-up, named only:** the acceptance-
gate run (post-D13, non-author, fresh DB) must include A1 executed against the real
files, and its report must cite that run — D5's synthetic-name evidence is hereby marked
INTERIM, superseded for A1 purposes by that run. No registry_read acceptance test exists
or is required (the spec's gate list, spec:140-146, never names one).

---

# ADDENDUM 20 — stuck-`spawning` reaper RULED (the build's last open item): threshold
sweep at server init, `dead` terminal, `registry_reap.js` primitive pinned, D15 named
(2026-09-03)

Ratification authority dispatch (fresh instance), ruling on the gap deferred at
ADDENDUM 13 item 6 (`agent-topology-ratification-04.md:262-268`) and carried unchanged
through ADDENDUMs 14/15 (`-04.md:432`, `-05.md:155,320`). Ruled at HEAD `aa22def`,
branch `wt/agent-topology`, tree clean (`git status --porcelain` → empty, this
dispatch). Docs only. Every load-bearing claim below cites a file+line read at
`aa22def` or a command this dispatch ran (`command grep` throughout, positive controls
on every negative).

D13's stop was CORRECT and all four of its cited facts re-verified here, not relayed:
`detached: true` (`worker_session.js:77`); the compound-failure strand-while-running
path (`rollbackSpawn`, `spawn_agent.js:160-186` — deleteAgent rollback fails →
INTERNAL_ERROR naming `strandedAgentId`, row left at `spawning`); `LIVE_STATUSES`
includes `spawning` (`middleware.js:76`, gate at `:142`); `idx_active_name` predicate
`status IN ('spawning','active')` (`schema.sql:69-71`).

## R1 — RULED: threshold heuristic. A liveness probe is IMPOSSIBLE, not just costly.

A stuck-`spawning` row carries NOTHING to probe: `thread_ref` is written only at the
step-3 flip (`spawn_agent.js:258-262`), which is exactly the step the strand never
reached; `createAgent` defaults it NULL (`registry.js:104,136`); the minted
`sessionId` (`spawn_agent.js:211`) lived only in the dead server's memory; `last_pid`
is `null` by design even when written ("null between invocations", `:256-258`). So the
row cannot prove liveness — the question "orphan or failure?" is unanswerable from
state, and the design does not need to answer it (see the self-exclusion property
under R2).

**Pinned threshold:** new config export `SPAWN_REAP_THRESHOLD_MS` — live getter,
env-overridable, default `600000` (10 min), same pattern as `staleThresholdMs`
(`config.js:52-56`). It is a DISTINCT constant from `STALE_THRESHOLD_MS`, whose
semantics are heartbeat staleness of `last_active_at` on live workers
(`config.js:46-48`); this one is spawn-completion staleness anchored on **`created_at`**
(ISO-8601 TEXT, `new Date().toISOString()` — lexicographic compare is valid; cutoff =
`new Date(Date.now() - thresholdMs).toISOString()`). Rationale for 10 min: a policed
spawn completes or is group-SIGKILLed within `SPAWN_TIMEOUT_MS` = 60s
(`worker_session.js` header + §13 row); 10× headroom covers the unpoliced orphan case
(server died before its own timeout timer could fire), and matches the system's
existing presumed-dead order of magnitude without conflating the two knobs.

**Consequence if wrong:** too short → a live orphan mid-invocation at reap time loses
its credential and its eventual `report_result` fails LOUD (`LIVE_STATUSES` gate,
`middleware.js:142`) — one lost first result from an agent that was already
permanently unreachable (NULL `thread_ref` → un-routable, un-`check_status`-able);
recovery is a re-spawn. Too long → name blocked + token live for up to the threshold —
bounded, where today it is unbounded. Both failure modes are strictly better than the
status quo (permanently stuck rows with permanently live tokens).

## R2 — RULED: startup sweep, no timer, no reap-on-conflict.

**Trigger = `server.js` `start()`, one call, immediately after `bootstrapRouter`
(`server.js:250`), before serving.** No background timer: none exists anywhere in this
system, and introducing the first mechanism class of its kind for one edge case fails
proportionality. Reap-on-conflict inside `spawn_agent` is REJECTED: `spawn_agent.js`
is 298/300 (`command grep -c ""`, this dispatch) — no room without a split — and the
case it would serve is already twice-covered (below).

**Why startup-only automation is sufficient against D13's point 2:** the in-server
strand path is not silent — `rollbackSpawn` returns a LOUD `INTERNAL_ERROR` carrying
`strandedAgentId` to the router (`spawn_agent.js:174-186`), and a SHIPPED remediation
exists: `registry_write` (router-only, `middleware.js:67`) patches `status` and its
`STATUS_VALUES` includes `'dead'` (`registry_write.js:69`; §13 row, spec:96 subset).
D15 adds one line to the Router Protocol SKILL.md instructing exactly that. The
startup sweep is the automated backstop for anything the router misses.

**The self-exclusion property (why the threshold is safe at startup):** at startup,
§14 clause 4 guarantees no other server is running, so no `spawning` row can still be
flipped to `active` — every one is stranded. But a detached orphan child may still be
live and can complete its OWN lifecycle: `LIVE_STATUSES` admits `spawning` callers
(`middleware.js:76,142`) and `setWorkerStatus` checks only the TARGET status
(`registry.js:208-217`), so an orphan's `report_result` flips it `spawning`→`done` —
and the sweep's `status='spawning'` predicate then skips it automatically. The
threshold exists purely to hold that window open; rows that outlive it are reaped.

## R3 — RULED: terminal status is `dead`.

Evidence: `dead` is in the CHECK enum (`schema.sql:33`); `dead` exits BOTH harm
surfaces at once — `idx_active_name`'s predicate (`schema.sql:69-71`, name freed) and
`LIVE_STATUSES` (`middleware.js:76`, token dies at `:142`); `config.js:48`'s own
words for an over-threshold worker are "considered dead"; `check_status` already
verdicts staleness as `dead` (`check_status.js:59` `STALE_VERDICT`); `registry.js`'s
header names "marking a stale worker `dead`" as the anticipated router-lane patch
(`registry.js:26-31`). `deleteAgent` is REJECTED: pinned "for spawn-rollback use only"
(§13) and deletion destroys the forensic row. **The reap writes exactly
`{ status: 'dead' }` — nothing else.** `thread_ref` stays NULL, which becomes the
distinguishing signature of a reaped stuck-spawn (every ordinary terminal row passed
through the step-3 flip and carries a `thread_ref`).

## R4 — RULED: additive primitive `reapStuckSpawning(db, thresholdMs)`, granted here.

D13 was right that a dedicated primitive is a §13 additive pin requiring a stop — this
ADDENDUM is that stop, granted (the `touchAgent`/`listAgents`/`deleteAgent` precedent:
ADDENDUMs 18/19/12). Raw SQL in a tool or server module stays FORBIDDEN (ADDENDUM 12
G1; `server.js:149`'s own comment confines SQL to `db.js`/`registry*.js`/
`messages.js`/`bootstrap.js`).

**Home:** package-root sibling **`registry_reap.js`**, sole export
`reapStuckSpawning` — `registry.js` is 279/300 and cannot absorb a primitive plus its
mandatory header; the sole-export sibling mirrors `registry_query.js` (ADDENDUM 19
R1's pre-authorized pattern, now the write-side twin). NOT `bootstrap.js`:
`bootstrapRouter`'s `{row, token, rotated, created}` contract is pinned and F1-only.

**Pinned shape:** `reapStuckSpawning(db, thresholdMs)` → array of the patched rows
(full rows, `patchAgent` return convention — they carry `token_hash`, so callers log
only `agent_id`s, per the redaction discipline). `thresholdMs` must be a positive
finite number, else `INVALID_REQUEST` via `makeError`. Mechanism pinned: inside one
`db.transaction`, `listAgents(db, { status: 'spawning' })` (require from
`registry_query.js`), JS-filter `created_at < cutoff`, then per-row
`patchAgent(db, agent_id, { status: 'dead' })` (require from `registry.js`) — zero
new SQL, all transitions through the pinned primitives; in-registry-family delegation
is not a worker-handler reference (the `touchAgent` clause).

**Caller class RULED LEGITIMATE:** `server.js` init calling a package-root
registry-writing module outside any request path is not new — `bootstrapRouter` at
`server.js:250` is exactly that today. Invariant 3's build-time grep governs
worker-REACHABLE TOOL files (derived scope: `tools/*.js` not in `ROUTER_ONLY_TOOLS`,
ADDENDUM 18 R3); `server.js` is outside that scope by construction. The grep's
banned-name set gains `reapStuckSpawning` alongside `patchAgent`/`deleteAgent` — one
clause. `server.js` logs a reap loudly (count + `agent_id`s, non-secret) via its
existing startup reporting; at 291/300 the ~6-line integration fits — if a conforming
integration cannot land ≤300, that is a STOP, not a silent split.

## D15 — NEW DISPATCH (the build's last): stuck-`spawning` reaper

Scope, exact: (1) `config.js` — add live getter `SPAWN_REAP_THRESHOLD_MS` (env
override, default 600000; §13 config row gains the name); (2) NEW `registry_reap.js`
per the R4 pin; (3) `server.js` — init step after `bootstrapRouter`:
`reapStuckSpawning(db, config.SPAWN_REAP_THRESHOLD_MS)` + loud log; (4) update
`spawn_agent.js:250-253`'s KNOWN GAP comment to point here (comment-only edit); (5)
Router Protocol SKILL.md gains one line: on a `spawn_agent` INTERNAL_ERROR naming a
`strandedAgentId`, `registry_write` that row to `status: 'dead'`; (6) Invariant-3
grep gains `reapStuckSpawning`. Tier: Sonnet (all judgment pinned here). Done
condition: a seeded over-threshold `spawning` row is `dead` after `start()` with its
name re-spawnable and its token rejected (`PERMISSION_DENIED` path); an
under-threshold `spawning` row survives the sweep; a `done` row is untouched;
`check-file-length.sh` clean; non-author verification. STOP: any fix requiring a
`middleware.js`, schema, or pinned-surface change. Single dispatch — Rule 7 exempt
(1-2 tasks). **Ship gate: D15 blocks the final acceptance declaration** — the record
deferred this gap TO this build three times; ruling it a known-limitation now would
silently shrink committed scope. It does NOT block or reopen D13's own acceptance.

## Named, not acted on

- The idle-window residual: a stranded row on a server that never restarts and whose
  router never remediates keeps its token until the next boot. Bounded, documented,
  accepted — the alternative is the rejected timer.
- `scope` unbounded, `worker_preamble_overrides`, `messages` TTL — unchanged.
- `claude auth status` gate — unrelated, untouched (dispatch constraint).
