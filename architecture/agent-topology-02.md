# agent-topology — architecture PART 2 of 2 (Where things live, Settled decisions, Named/not-acted-on, ADR question, Portability)

> **Superseded 2026-09-07 by native primitives — see decisions/0037. Retained as design
> record.**

Part 1 = `agent-topology.md` (status header, evidence base, prior-art analysis, design
principle, components/module decomposition, data model, write asymmetry & identity
resolution, the six invariants and the OQ4 branch-(iii) re-ruling with its
empirical-unverification risk record, and the OPEN QUESTIONS section with every OQ1–OQ8
ruling). This part carries: Where things live (§7), Settled design decisions (§8),
Named-not-acted-on items (§10), whether an ADR is needed (§11, answered), and the
portability / lift-and-port procedure (§12, P1–P5). Headings, numbering, and content are
unchanged from the original single-file document except where T2-addendum amendments 1/7/8
required updates (P4/P5 for the OQ4 branch-(iii) mechanism; §7/§8 relocated here) — those
are applied in place here, not summarized away.

**Split provenance (2026-09-02):** this file was one document at 546 lines in this
worktree after T2-addendum amendments 1 (owner's OQ4 branch decision + the
empirical-unverification risk record) and 7 (branch-dependent rewrite of §6/§9) were
applied to `agent-topology.md`, 9% over the ADR 0021/0029 ~500-line soft cap. Per ADR
0029 Clause 3/Clause 4.1 (split into cross-referenced parts is the default, no-approval
remedy for crossing the cap) and the `projects/<project>.md` / `projects/<project>-02.md`
precedent, the tail (§10 Named-not-acted-on through §12 Portability) was carved out
verbatim into this file in the same pass, rather than committing an over-cap state or
requesting a cap exemption. No content was reworded, compressed, or dropped by the split
— this is a relocation, not a trim, apart from the branch-(iii) updates to P4/P5 named
above (those are content amendments required by amendment 7, not split artifacts).

**Second split pass (2026-09-03, amendment 8, doc-consistency sweep):** part 1 grew again
after the risk record gained probe 3, the explicit `spawn_agent`-doubt sentence, and the
UNVERIFIED/OPEN leads (still amendment 1's scope — the risk record itself). To keep part 1
under the cap with margin, §7 (Where things live) and §8 (Settled design decisions) were
relocated here verbatim in the same pass, immediately below. Cross-references in part 1
(`§7` → `part 2 §7`) and in `decisions/0035-agent-topology-hq-exception.md` were updated to
match; no content was reworded or dropped.

---

## 7. Where things live

- **Registry DB file:** `$DATA_DIR/topology.db`, default `~/.agent-topology/data/`
  **outside hq** `[MINE — non-negotiable]`. hq's `.gitignore` blocks `*.sqlite`, `*.db`,
  `*.db-wal`, `*.db-shm` repo-wide, and the pre-commit hook blocks staged `data/` and
  `*.db` outright. A DB inside hq is unshippable by construction.
- **Skills — RATIFIED location (P1):** authored **inside the portable root**, at
  `tools/agent-topology/skills/agent-topology-router/SKILL.md` and
  `tools/agent-topology/skills/agent-topology-worker/SKILL.md`, content **verbatim from
  spec §10**. This deviates from ADR 0009's authorship location (hq top-level `skills/`);
  the deviation is recorded in ADR 0035. Both are still blanket-exempt from the doc cap —
  both checkers exclude `skills` as ANY path segment (`check-file-length.sh:22`;
  `check-doc-length.sh:71,141` `-not -path "*/skills/*"`), so the move does not lose the
  exemption.
- **Skill provisioning — OQ6 RATIFIED: neither skill is globally symlinked.** `[SPEC]`
  "Install the router skill only in the router's environment and the worker skill only in
  spawned worker environments." ADR 0009 installs every *other* hq skill by symlink into
  the shared, global `~/.claude/skills/`, where the 22 pre-existing skills live. A global
  install here would leak both procedures to every session, violating Invariant 6. ADR 0035
  records a per-role exception to ADR 0009 on both steps: the router skill installs
  **project-scoped** in the router's own environment; `provision.js` installs the worker
  skill **project-scoped** into each worker's working directory, by **COPY** from the
  package root rather than symlink, so installs survive relocation of the source tree
  (portability, P1/P4). Enforceable form of Invariant 6: (a) the build-time marker grep
  above (test A7), (b) a check that no `agent-topology-*` symlink exists in
  `~/.claude/skills/`. Invariant 6 stays defense-in-depth — the middleware role gate, not
  skill visibility, is the hard authority boundary.

## 8. Settled design decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | SQLite, single-writer | `[SPEC]` "single-writer semantics match the write-asymmetry rule" |
| D2 | One middleware seam, thin handlers | `[SPEC]` implementation note, verbatim |
| D3 | Invariant 1 as a partial unique index, not a code check | `[MINE]` a code check races; the index cannot |
| D4 | Per-request MCP tool factory + 3-arg `registerTool` | `[MINE]` two already-paid-for bugs from the bus record |
| D5 | Asymmetry via rejection, not tool absence | `[MINE]` follows the spec's own acceptance test over its prose |
| D6 | DB file outside hq | `[MINE]` hq gitignore + pre-commit make the alternative impossible |
| D7 | Build-time grep test for Invariant 6 | `[MINE]` the only checkable form of a provisioning-time property |

## 10. Named, not acted on

- `architecture/swarm-communication-layer.md` records Issue 5 (unbounded message
  accumulation — no TTL, no cleanup job) as **still true**. OQ5 is now ratified to "own
  store" (part 1 §9), so this design's `messages` table inherits the same unbounded-growth
  pattern as a second table. Named only — TTL/cleanup is deliberately future work, not
  this build.
- The bus's `pm2 reload` crash-loop (discrepancy #9) is still unfixed in the bus repo.
- hq `CLAUDE.md`'s Folder map (lines 20–31) is **stale**: it omits `skills/` and `plans/`,
  both of which exist and are load-bearing. Not fixed here.
- `tools/model-routing.md`'s "Pipeline-specific (current)" table still lists Phase 0/2/3
  rows as `queued`/`this batch` from the original buildout. Stale, untouched.

## 11. Does this need an ADR?

**Yes — one, written: `decisions/0035-agent-topology-hq-exception.md`** (0035 allocated by
the orchestrator; verified free across hq main, all live worktrees, and every branch
before use). It settles: the OQ2 exception to STANDARDS §7 + ADR 0010, with the
portability rationale and the owner-ruling provenance line; the `fable` tier addition
reconciling the spec's ladder with ADR 0014 (OQ3); the ADR 0009 per-role
authorship+install exception (P1/OQ6); and the identity-token deviation from the spec's
"never self-reported" wording (OQ1). The ADR does not cover OQ4 — the T2-addendum
branch-(iii) re-ruling changes no ADR 0035 ruling (identity, tier, skill-install, and
portability all stand as recorded); see part 1 §6 for the OQ4 record itself.

## 12. Portability and lift-and-port procedure (P1–P5, RATIFIED)

The owner's stated reason for keeping this build inside hq — it will be **ported to a
separate work environment** — is load-bearing, not decorative: the ratification record
treats it as promoting portability to a first-class requirement, and rules P1–P5 all
follow from it. The target environment must be assumed to have **no hq, no swarm bus, no
ADR machinery** — only Claude Code and the ported directory.

- **P1 — the portable unit is `tools/agent-topology/` in its entirety**, including both
  SKILL.md files, which live inside this root (`tools/agent-topology/skills/
  agent-topology-{router,worker}/SKILL.md`) rather than hq's top-level `skills/`. Cap
  exemptions survive the move — both checkers exclude `skills` as ANY path segment.
- **P2 — no hardcoded paths.** All paths are env-driven with machine-neutral defaults in
  `config.js` only: `DATA_DIR` (default `~/.agent-topology/data/`), `CLAUDE_BIN` (default
  `claude` on PATH), skills source resolved relative to the package root. Enforced by a
  grep-based portability check: `command grep -rn '/Users/\|projects/hq'
  tools/agent-topology --exclude-dir=node_modules` → 0 hits, with a positive control
  (`require` present) proving the grep itself works. **Widened form (T2 addendum,
  mechanical correction 3):** the `--include='*.js'` filter is dropped so `schema.sql`,
  `package.json`, and both SKILL.md files are inside the gate too.
- **P3 — no runtime dependence on hq tooling.** hq's checkers and gates are
  authoring-time only; nothing under `~/projects/agent-hq` may be read at runtime. The OQ5
  ruling (own message store, not the bus) is retroactively load-bearing here: a bus
  dependency would have made the system unportable to an environment where the bus does
  not exist.
- **P4 — OQ1 and OQ4 rulings survive relocation as made (updated, amendment 7: branch
  (iii)).** The capability token lives in the DB + a `$DATA_DIR` file (no
  machine-specific identity source), unchanged. The OQ4 spawn/route mechanism now needs
  only the CLI on PATH plus its `--session-id`/`--resume` flags (both help-text-verified,
  §5 of part 1), not any machine-specific process-management facility; `session_id`
  itself is stored in the portable DB, not derived from anything host-specific. D6's
  expanded smoke test (`-p --session-id` at first spawn, `-p --resume` at route-to-
  existing) doubles as the port-time preflight — and, per the risk record in part 1 §6,
  that smoke test is where the mechanism gets its **first actual execution**, in whatever
  environment runs it first; the port-time run is not exempt from that gate.
- **P5 — lift-and-port procedure** (documentation only; no porting tooling is built):
  1. Copy the `tools/agent-topology/` directory to the target environment.
  2. `npm install` inside the copied directory.
  3. Set `DATA_DIR` and `CLAUDE_BIN` (only if the target's Claude CLI isn't on PATH as
     `claude`) in the target environment.
  4. Project-scope-install the router skill in the router's own environment (copy, not
     symlink — no ADR 0009 machinery exists in the target).
  5. Run D6's expanded smoke test (`claude -p --session-id <uuid>` then
     `claude -p --resume <session_id>`, both from `child_process`) as the port-time
     preflight — **treat a failure here exactly as STOP-THE-LINE**, per part 1 §6's risk
     record, not as a porting quirk — then run the full acceptance gate before treating
     the port as live.

## 13. Internal export surface — PINNED (ratification ADDENDUM 4, 2026-09-02)

D10 proved this gap concrete: the behavioral contract was pinned, module export names were
not, so every later dispatch would have invented its own. Pinned here; **every D3+ brief
cites this section**; deviation is a stop-on-anomaly, not an implementer's choice.

**Module system: CommonJS, as already shipped and verified** (`package.json` has no
`"type": "module"`; D1's `errors.js`/`config.js` and D2's `db.js` all use
`module.exports = {...}` — verified CLEAN before this pin). Named exports only, **no
default exports**. ESM test files reach CJS modules via dynamic `import()`, where Node
exposes `module.exports` as `default` and synthesizes named exports from object-literal
properties — D10's loader must therefore also search `mod.default`'s properties when
`default` is a non-function object (test-worktree amendment, below).

**Error discipline (pinned):** internal modules THROW `Error`s built by
`makeError(code, message, details?)` (D1's shipped shape: an `Error` with `.code` and
`.details`); `middleware.js` is the ONLY place a thrown error becomes a transport-level
structured error result. Handlers never build transport responses. This deviates
deliberately from the bus's return-not-throw style (`swarm-communication-layer/src/
errors.js:23-24`) because we have the single middleware seam the bus lacks.

**Pinned exports per module** (functions touching the DB take the better-sqlite3 handle as
their FIRST parameter — no module-level DB singletons; the per-request-factory lesson):

| Module | Pinned named exports |
|---|---|
| `config.js` (shipped; **D1.1 amends to LIVE GETTERS — ratification ADDENDUM 6**) | same names: `DATA_DIR`, `CLAUDE_BIN`, `MAX_HOPS`, `STALE_THRESHOLD_MS`, `SPAWN_REAP_THRESHOLD_MS` (live getter, env-overridable, default 600000 — spawn-completion staleness anchored on `created_at`, DISTINCT from `STALE_THRESHOLD_MS`'s heartbeat semantics; ratification ADDENDUM 20, built by D15), `PORT_RANGE_START`, `PORT_RANGE_END`, `TOPOLOGY_DB`, `ROUTER_TOKEN_FILE`, … — every value a live property getter, env read at ACCESS time, derived paths computed from the current `DATA_DIR`. **Convention (widened, ADDENDUM 7): access `config.X` at use time; NEVER destructure config at module top and NEVER spread/copy it (`{...config}`, `Object.assign`) — any copy re-freezes. ESM consumers MUST default-import (`import config from …`); ESM NAMED imports of config are BANNED — `cjs-module-lexer` cannot see getters, so they silently yield `undefined`** |
| `errors.js` (shipped) | `ERROR_CODES`, `makeError(code, message, details?)` |
| `db.js` (shipped; **D4.2 amends — ratification ADDENDUM 8**) | `openDb`, `initSchema`, `readSchemaSQL`, `requireDb`, `isRetryableBusy`, `sleepSync` — the last three added by D4.2 (`requireDb` de-dup + shared retry predicates), ratified post-hoc (ADDENDUM 8 R1). **Containment clause: contention handling lives ONLY at the two ruled seams — `openDb`'s open-time retry here and `bootstrapRouter`'s transaction re-run in `bootstrap.js` (§14); no other module adds busy retries; no further db.js export without a stop** |
| `identity.js` (D3) | `mintToken()` → `{ token, tokenHash }`; `hashToken(token)` → 64-char lowercase hex; `resolveCaller(db, authToken)` → row or `null`; `authTokenShape` (shared input-schema fragment, F7 pt 5, **plain frozen JSON-Schema property fragment — ADDENDUM 5**). **PURE module: no fs and no config imports; exactly these four exports** — the router token FILE belongs to `bootstrapRouter` |
| `registry.js` (D4) | Pure row CRUD + transition primitives: `createAgent(db, fields)` → row; `getAgent(db, agentId)` → row or `null`; `patchAgent(db, agentId, patch)` — **router-lane, unrestricted; NEVER referenced from a worker-reachable handler** (build-time grep, D5 done condition; check re-pinned by ratification ADDENDUM 18 R3 — scope DERIVED as every `tools/*.js` not in `middleware.js`’s `ROUTER_ONLY_TOOLS`, comment-excluding pattern with positive control, superseding the named-three-file wording); `setWorkerStatus(db, agentId, status)` — worker-lane, rejects all but `done`/`escalated`; **`deleteAgent(db, agentId)` — additive, ADDENDUM 12 G1 (D6.1): hard-delete one row, for spawn-rollback use only (no soft-delete status exists in the schema); router-lane, unrestricted, same shape discipline as `patchAgent`.** **`touchAgent(db, agentId)` — additive, ratification ADDENDUM 18 R1 (built by the re-dispatched D12): sets exactly `last_active_at` to `new Date().toISOString()`, writes nothing else; worker-lane; one-statement delegation to `patchAgent` (the `setWorkerStatus` pattern — an in-registry delegation is not a worker-handler reference); returns the patched row; missing row throws `patchAgent`’s NOT_FOUND; “own row” is the seam’s guarantee — `heartbeat`’s handler passes `ctx.caller.agent_id`, never a caller-supplied id.** **Invariant 3 = D5 seam role-gate (runtime, external callers) + this primitive split + the build-time grep** — ADDENDUM 7. **Raw `ctx.db.prepare(...)` SQL against `agents`/`messages` from any tool module is FORBIDDEN generally (ADDENDUM 12 G1) — it is invisible to the Invariant-3 build-time grep; a missing primitive is an additive-pin request, never a raw-SQL workaround** **`listAgents(db, filter?)` — additive, ratification ADDENDUM 19 R1 (built by D14): filter keys exactly `role`/`status`/`scope_query` (unknown key → `INVALID_REQUEST`, loud), `scope_query` = literal substring on `scope` (`LIKE`+`ESCAPE`, wildcards escaped); returns matching rows ordered `created_at` ASC; SQL errors via `rethrowSqlError`; any-agent-lane (spec:91). Cap pre-ruling: if a conforming `listAgents` cannot land at ≤300 lines (file is 279/300 at pin time), the pre-authorized remedy is a package-root sibling `registry_query.js` with sole export `listAgents` — no stop needed (ADDENDUM 19 R1)** |
| `messages.js` (**NEW — ratification ADDENDUM 16 R1, built by D7**; package root, sibling to `registry.js`/`bootstrap.js` per the ADDENDUM 7/13 split precedent) | Pure `messages`-table CRUD — the pinned primitive ADDENDUM 12 G1's raw-SQL ban requires; exactly three named exports, no own transactions (each participates in the caller's `db.transaction` — OQ5's one-transaction requirement is the handler's obligation): `createMessage(db, { from_agent, to_agent, task_id, kind, body, hop_count? })` → row (mints `message_id` uuid + `created_at`, `read_at` NULL, `hop_count` defaults 0); `listMessages(db, toAgentId, filter?)` → rows addressed to `toAgentId` only, oldest-first, `filter: { kind?, task_id?, unread_only? }` (F7 pt 2's set); `markMessagesRead(db, toAgentId, messageIds)` → count, marks only rows whose `to_agent = toAgentId` — caller-scoping lives IN the primitives (capability-shaped, `setWorkerStatus` discipline), so cross-agent read/mark is structurally unexpressible. Consumers: D7's three tools; D9's `route_message` (via `createMessage`, after its ADDENDUM-11 `buildEnvelope`/`validateEnvelope` obligation) |
| `registry_reap.js` (**NEW — ratification ADDENDUM 20 R4, built by D15**; package root, sole-export sibling of `registry_query.js` — the write-side twin; `registry.js` at 279/300 cannot absorb it) | Exactly one named export: `reapStuckSpawning(db, thresholdMs)` → array of patched rows (full rows, `patchAgent` return convention — callers log only `agent_id`s, redaction discipline). `thresholdMs` positive finite number else `INVALID_REQUEST`. Mechanism pinned: one `db.transaction` — `listAgents(db, { status: 'spawning' })`, JS-filter `created_at < new Date(Date.now() - thresholdMs).toISOString()` (ISO lexicographic), per-row `patchAgent(db, agent_id, { status: 'dead' })`; zero new SQL, writes exactly `{status:'dead'}`, `thread_ref` stays NULL (the reaped-stuck-spawn signature). Sole production caller: `server.js` init, one call after `bootstrapRouter` (the `bootstrapRouter` init-caller precedent — outside the request path, outside Invariant 3's derived grep scope); the grep's banned-name set gains `reapStuckSpawning` alongside `patchAgent`/`deleteAgent`. In-server strands (`rollbackSpawn` compound failure) are remediated by the router via `registry_write` `{status:'dead'}` per the loud `strandedAgentId` error — the sweep is the cross-restart backstop |
| `provision.js` (D6.1 — ADDENDUM 12 G2; originally pinned to D6, not built there) | `provisionWorkerSkill(workerDir)` → installed path. Copies the worker SKILL.md into `$DATA_DIR/workers/<agent_id>/` (F7 point 4, OQ6 COPY-not-symlink). **Destination subpath PINNED (ADDENDUM 13 R2): `<workerDir>/.claude/skills/agent-topology-worker/`** — `.claude/skills/<name>/` is the layout a Claude Code session actually discovers a project-scoped skill from (independently confirmed: `~/projects/<project>/.claude/skills/<skill>/SKILL.md` is a live, working project-scoped install using exactly this layout); a bare file at `workerDir`'s root would satisfy §13's older literal text while being functionally inert. D6.1's shipped code already matches this pin exactly (`provision.js`'s `PROJECT_SKILLS_SUBPATH = path.join('.claude', 'skills')`) |
| `bootstrap.js` (D4 lane, split from registry.js at 298/300 — ADDENDUM 7) | `bootstrapRouter(db)` → `{ row, token, rotated, created }` — owns the whole F1 bootstrap-or-adopt transaction INCLUDING the mode-600 `ROUTER_TOKEN_FILE` read → SHA-256 compare vs the row's `token_hash` → reuse-or-ROTATE → rewrite (via `identity.mintToken`/`hashToken` and registry primitives; `created`=first creation, `rotated`=rotation, never both; path from `config.ROUTER_TOKEN_FILE`) — ADDENDUM 5 as amended by ADDENDUM 7 |
| `worker_session.js` (**NEW — ADDENDUM 13 R1, assigned to D6.2**, split from `tools/spawn_agent.js` at 358/300 lines, same pattern as `bootstrap.js`'s split from `registry.js`) | Exactly one named export: `launchWorkerSession({ sessionId, cwd, stdinPayload })` → `Promise<void>`, resolves on the child's exit 0, rejects with a `makeError` shape (`INTERNAL_ERROR` on spawn/write/emitted-error failure, `TIMEOUT` on `SPAWN_TIMEOUT_MS` expiry). Owns: `child_process.spawn(config.CLAUDE_BIN, ['-p','--session-id', sessionId], { cwd, detached: true, stdio: [...] })`, the stdin write of `stdinPayload`, stdout/stderr draining (never captured — REDACTION), the exit/error event handlers, and the timeout's process-**group** `SIGKILL` (`process.kill(-child.pid, 'SIGKILL')`, falling back to `child.kill`) — `detached:true` makes the child a group leader, so a bare `child.kill` on timeout would orphan its descendants (D6.1 minor item 2). `SPAWN_TIMEOUT_MS` (60,000 — a local convention default, NOT a pinned contract value) moves into this module as a private constant; `spawn_agent.js` no longer needs `require('child_process')` once this module owns the only `spawn()` call. Package root (sibling to `registry.js`/`bootstrap.js`/`preamble.js`/`provision.js`), **not** under `tools/` — that directory is reserved by the `tools/*.js` row below for the uniform tool-export shape a future `mcp-server.js` loops over; a non-tool helper placed there would be indistinguishable by location from one of the 10 anticipated tool files |
| `single_instance.js` (**NEW — ratification ADDENDUM 21 R1, built by D15.1**; package root, split from `server.js` at 291/300 when D15's reap wiring could not land ≤300 — the pre-authorized STOP in D15's plan row, resolved per the `worker_session.js`/ADDENDUM 13 precedent: SPLIT, never compress) | The §14-clause-4 single-instance + port-file concern, lifted verbatim from `server.js`. Five named exports: `SERVICE` (the identity string `'agent-topology'` — owned here because this module asserts identity via `/health`'s `service` field; `server.js` re-imports it); `BIND_HOST` (`'127.0.0.1'` — probe target and bind host share one constant by construction); `assertSingleInstance()` → `Promise<void>`, throws `Error` with `.alreadyRunning = true` and `.port` when a live same-`DATA_DIR` instance answers (the exact contract `server.js`'s `EXIT_ALREADY_RUNNING` branch keys on), cleans a stale port file and returns otherwise; `writePortFile(port)` → void (mkdir `config.DATA_DIR` recursive + write); `releasePortFile(port)` → void (unlink ONLY if the file still records `port`; best-effort). `PORT_FILE_NAME` and `HEALTH_PROBE_TIMEOUT_MS` are module-PRIVATE — the port-file name stays deliberately unpinned (`server.js`'s original recorded choice). Carries no token, no SQL; sole consumer `server.js`. `server.js`/`mcp-server.js` themselves still have no §13 rows (entry-point class) |
| `preamble.js` (D6) | `buildPreamble({ parent_id, scope, tier, auth_token })` → string |
| `envelope.js` (D9; **shape pinned — ratification ADDENDUM 17 R3**) | `buildEnvelope({ from, to, task_id, kind, body, hop_count? })` → envelope; `validateEnvelope(obj)` — throws per the error discipline. **The envelope IS the pinned FLAT object `{ from, to, task_id, hop_count, kind, body }`, `Object.freeze`d — `body` INSIDE it, `hop_count` at top level** (forced jointly by this row's `body` input, ADDENDUM 11 R1's validate-the-built-result, and shipped `middleware.js:286`/`hopGate` reading `hop_count` off the validated object); part 1 §4's nested `[SPEC]` JSON is the historical wire sketch, left verbatim — this pin governs. `hop_count` counts COMPLETED prior hops: origin writes are 0 (pass-through, never incremented here); increment-at-relay belongs to the future inbound-envelope dispatch (ADDENDUM 17 R2) |
| `middleware.js` (D5) | `wrapTool(toolDef)` → transport-ready handler running identity → role gate → envelope gate → hop gate; only `mcp-server.js` may call it |
| `tools/*.js` (10 files) | one uniform named export `tool` = `{ name, description, inputSchema, handler }`; `handler(args, ctx)` with `ctx = { db, caller }` injected by middleware. Object shape follows the bus precedent (`send_message.js:87-100`); the uniform export name deviates from the bus's `<camelName>Tool` deliberately so `mcp-server.js` loops files and D5's "no handler reaches the server directly" grep stays one-line. `spawn_agent.js` additionally requires `worker_session.js` (package root, see its row above) — that require does not add an 11th tool file. **The 10-file inventory, enumerated (ADDENDUM 19 — a plan-authoring gap left `registry_read.js`/`registry_write.js` in no dispatch row until D14):** `spawn_agent`, `report_result`, `escalate`, `read_messages`, `whoami`, `route_message`, `heartbeat`, `check_status` (shipped, D6–D12) + `registry_read.js` and `registry_write.js` (D14; full input/output pins in `agent-topology-ratification-06.md` ADDENDUM 19 R1/R2 — flat input shapes, `registry_write` mutates ONLY `{status, scope, tier, last_active_at}` per spec:96 over `patchAgent`, seam-gated router-only with no handler role check; `registry_read` is any-agent over `listAgents`) |

**D10's guesses: ADOPTED as the pin where they led** — `mintToken` + `{ token, tokenHash }`,
`createAgent` + row-with-`agent_id`, `buildPreamble`, `token_hash` column name (all
first-choice guesses in `test/helpers/fixtures.mjs`, derived from the verified bus
precedent). **OVERRIDDEN in three places:** (a) no default exports (CJS named only);
(b) DB-touching functions take the explicit `db` first parameter — fixtures currently call
`createAgent(fields)` bare; (c) the loader's default-export preference must handle the CJS
default-object interop case. These, plus the A3 amendment (ADDENDUM 4), form ONE
test-worktree amendment dispatch; D10's tests are otherwise untouched.

**Named, not acted on:** D10's `fixtures.mjs` seeds the ROUTER row with `tier: 'fable'` —
but Fable never holds a main seat (ADR 0014), and OQ3 makes `fable` dispatch-only; the
fixture router tier should be `default` or `strong`. For the same amendment dispatch.

## 14. Concurrency model — STATED (ratification ADDENDUM 8, 2026-09-03)

Three dispatches (D4 → D4.1 → D4.2) accumulated SQLite contention defenses discovered
defect-by-defect from a 6-process test harness no record document mandates. This section
is the stated model those defenses answer to; every future concurrency defect is judged
against it FIRST ("is this scenario in contract at all?"), never against whatever a test
harness happens to spawn.

1. **One-writer-process model.** Exactly ONE server process per `$DATA_DIR/topology.db`
   opens the SQLite database in production: `server.js` (D13), which calls
   `bootstrapRouter` once at init (F1). Workers and router-client sessions reach registry
   state only through that server's MCP tools; no worker process ever opens the DB file
   (part 1 §3, §5). Grounds: the spec chose SQLite because "single-writer semantics match
   the write-asymmetry rule" (spec:148); in the shipped tree the only production `openDb`
   caller is db.js itself.
2. **Bootstrap is serial by design.** F1's contract is CONSECUTIVE server starts, not
   concurrent ones (plan D4 done condition). Concurrent bootstrap — two or more processes
   racing `bootstrapRouter`/first-open on one DB — is **OUT OF CONTRACT**: unsupported,
   surfaced loudly, never converged through silently. The record already encodes this: a
   bootstrap uniqueness error is a per-row STOP fragment on D4 and D13, and the shipped
   code conforms (`SQLITE_CONSTRAINT_UNIQUE` is not retryable — `isRetryableBusy`).
3. **Named hazard if violated (out-of-contract, deliberately undefended):** two
   concurrent bootstrappers can fight over adopt-vs-rotate — the token-file write is a
   non-transactional side effect inside the transaction callback, so a second server can
   rotate the token out from under the first. The defense is clause 4, not more retries.
4. **Single-instance discipline.** D13's server startup treats an already-live instance
   on the same `DATA_DIR` (the port file §3 already gives server.js names the check) as a
   **startup STOP**, not a peer. A double-start is an operator error, reported loudly.
5. **What the retries ARE.** The bounded retries at the two seams (`openDb` open-time;
   `bootstrapRouter` transaction re-run) are HARDENING against transient lock/snapshot
   contention from legitimate secondary openers — the test harness, the port-time
   preflight, a diagnostic open — and are inert on the supported single-opener path
   (first attempt succeeds). They are NOT support for concurrent bootstrap and are not
   extended defect-by-defect. A committed multi-process hardening BENCH
   (`tools/agent-topology/test/bench/`, D10.2 — ADDENDUM 10 H1) is the standing
   instrument: separately invoked, never part of the A1–A7 gate, asserting only bounded
   behavior (clean shaped errors, one active router row, attempts within bound) with
   timings printed, not asserted. **Provenance of every figure in this clause and in the
   seam comments (ADDENDUM 10 H2):** the 17/48, 30-run, 34-run, 8.5–12.7s and ~110s
   numbers are single-source RELAYED measurements from ad hoc instruments that were
   never committed — not reproducible from the repo today, environment-specific,
   re-measurable only once the bench lands, and never retroactively validated by it.
   Empirical bounded worst case when a write lock is genuinely held against first-open:
   ~110s of blocking at `openDb` before a clean shaped error (that provenance class) —
   tolerated and documented, NOT tuned; at port time, a startup that blocks ~2 minutes
   then errors cleanly is THIS path, not the `claude -p` hang class.
6. **Port invariants (extends P5).** What survives the port is this model's INVARIANTS,
   never its tuned numbers: (a) one server process per `DATA_DIR`; (b) `DATA_DIR` on a
   LOCAL filesystem — the port-time preflight checks this; WAL/locking assumptions do not
   hold on network filesystems; (c) `DATA_DIR` user-private (ADDENDUM 7's symlink-scoping
   premise, P5 step 3). If the target environment needs multiple concurrent writer
   processes, the SQLite choice itself reopens — the spec names its own successor path
   (spec:148, "swap for a Notion database later") — a ratification-level design change,
   never a retry-tuning exercise.
