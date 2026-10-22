# agent-topology — T6 ratification record, PART 2 (addenda continuation)

Part 1: `architecture/agent-topology-ratification.md` (verdict, OQ rulings,
T2 addendum, Addendum 3). This file continues the addenda past the 500-line cap.

---

# ADDENDUM 4 — D10 stop: A3 contradiction + export-surface pin (2026-09-02)

**A3 vs D6 — RULED: the contradiction is real and it is the SOURCE SPEC's.** The spec's
own Worker Preamble opens "You are a **worker agent** spawned by the Router (parent:
`{parent_id}`)" (spec:128) while its own acceptance test requires the worker's prompt to
state NEITHER role nor parent_id (spec:143). The spec's preamble design defeats its own
test — a source-spec defect, stated plainly; not D10's error, and D10 was right to refuse
to choose. **Preamble contents stand as ruled:** `{parent_id}/{scope}/{tier}/{auth_token}`
— the values are server-interpolated FROM the registry at spawn (registry-sourced at t0,
injected only by `preamble.js`), the token cannot move (it is the delivery channel), and
stripping the rest buys nothing: `whoami` resolves `auth_token` → row server-side and
structurally cannot read the prompt. **A3 is re-scoped to prove provenance by
DISAGREEMENT, not absence** (mirroring A4's synthetic re-scope): keep D10's spoofed-input
test (stands as written); REMOVE the "no declarative role statement" hard assertion (it
fails against the spec's own conformant preamble) and the `t.skip` parent_id-absence half;
ADD a staleness test — spawn-fixture a worker (preamble interpolated at t0), router
`registry_write` patches `scope` (spec:96 allows it) at t1, `whoami` must return the t1
registry value that now DISAGREES with the preamble text. Registry wins over prompt =
identity is registry-sourced, proven positively. The plan's A3 row loses its
"grep the preamble to prove it says neither" clause accordingly.

**Export surface — RULED: pinned NOW, in part 2 §13** (architecture/agent-topology-02.md),
recorded by this ratifier; every D3+ brief cites it; deviation is stop-on-anomaly.
CommonJS as shipped (D1/D2 verified CLEAN — the pin follows committed code); named
exports only; throw-`makeError`, middleware converts; per-module names adopt D10's
first-choice guesses (bus precedent verified: `send_message.js:87`, `errors.js:8,23-24`)
with three overrides listed in §13. **One test-worktree amendment dispatch** (orchestrator
dispatches; tests not edited from here) carries: the A3 changes above, the loader's
CJS-default-object interop, fixtures' explicit `db` first argument, and the fixture
router-row `tier: 'fable'` fix (Fable never holds a main seat, ADR 0014).

**D3 safety: safe to dispatch once D2.1 is non-author-verified** (D2.1 landed at
`867e22a`; verification was in flight at ruling time). D3's brief adds: cite §13 for
`identity.js`'s four pinned exports. D6 gating unchanged — `claude` remains logged out on
this machine; nothing here softens that risk record.

---

# ADDENDUM 5 — D3 stop: token-file ownership + `authTokenShape` encoding (2026-09-02)

**The two-way reading was this ratifier's own drafting error, named:** ADDENDUM 3's F1
assignment line said "D3 owns token mint/**rotate**" while §13 pinned `identity.js` to
four exports, none touching `ROUTER_TOKEN_FILE`. The word "rotate" belonged to D4. D3 was
right to stop rather than invent a fifth export.

## Token-file / rotate ownership — RULED: no fifth export; `bootstrapRouter` owns it

`identity.js` is pinned **PURE**: exactly the four shipped exports (`mintToken`,
`hashToken`, `resolveCaller`, `authTokenShape`), no fs and no config imports — which is
precisely what D3 shipped (its verifier evidence shows no I/O, no stdout). The F1
bootstrap-or-adopt transaction — SELECT-or-INSERT the router row, read the mode-600
`ROUTER_TOKEN_FILE` (path from `config.ROUTER_TOKEN_FILE`, already shipped by D1),
SHA-256-compare against the row's `token_hash`, decide reuse-vs-ROTATE, rewrite file and
row — lives WHOLE inside `registry.js`'s `bootstrapRouter(db)`, which calls identity's
pure `mintToken`/`hashToken` and whose already-pinned return `{ row, token, rotated }`
was in fact announcing where the decision lives. Rationale: the adopt/rotate choice spans
a DB row and a file inside one transaction — splitting it across modules would strand
half a transaction in a "pure" module and force D4's brief to call a name no authority
doc pins. Consequence if wrong: `registry.js` carries an fs dependency — contained, and
the `rotated` flag makes the behaviour directly testable. §13's identity/registry rows,
architecture §5's assignment sentence, the plan's D3 row, and ratification part 1:282 are
all corrected to this single reading.

## `authTokenShape` encoding — RULED NOW, not deferred

Pinned: a **frozen plain JSON-Schema property fragment**, exactly as D3 shipped — and
plain JSON Schema is the pinned interchange encoding for EVERY `inputSchema` in §13's
tool objects (bus precedent verified: `send_message.js:89-100` carries plain JSON Schema
in its tool object). If D13's chosen MCP-SDK registration path requires zod raw shapes,
the conversion happens in EXACTLY ONE place — `mcp-server.js`, at registration time —
never per handler and never by re-encoding the ten schemas or the shared fragment.
`package.json` stays dependency-light until D13 actually introduces the SDK. D13's brief
must carry this note. Consequence if wrong (the SDK cannot accept JSON Schema and an
adapter proves burdensome): only `mcp-server.js` changes — quarantining that flip is the
point of the ruling.

## Standing consequences

- **D3's four shipped exports stand unchanged** (D3 itself proved them identical under
  either resolution; nothing re-opens).
- **D4 is safe to dispatch once D3's in-flight verification returns CLEAN.** Its brief
  cites §13's amended `registry.js` row (the file-I/O ownership now has a pinned home)
  plus ADDENDUM 3's F1 done conditions; nothing in this ruling blocks it further.
- Named, not acted on: no ESLint config exists anywhere in the repo or its ancestors
  (pre-existing; D1/D2 shipped the same way) — a lint story is future work, not this
  build. D6 gating unchanged: `claude` remains logged out; the spawn mechanism is still
  empirically unverified and nothing here softens that.

---

# ADDENDUM 6 — D10.1 stop: config freezing + A2 step-3 inducibility (2026-09-02)

## config.js eager env reads — RULED: go LAZY via live getters; D1.1 amendment

Verified: `config.js:15` (`DATA_DIR`) and `:23` (`CLAUDE_BIN`) freeze `process.env` at
first import; `TOPOLOGY_DB` (`:52`) and `ROUTER_TOKEN_FILE` (`:58`) are frozen
derivations of the frozen `DATA_DIR` — so the hazard D10.1 proved for `CLAUDE_BIN` holds
for every path value, and `DATA_DIR`'s case is WORSE (it breaks per-test DB isolation for
every DB-opening test). `MAX_HOPS` (`:30`) and `STALE_THRESHOLD_MS` (`:37`) do NOT share
the freeze hazard — they are hard literals with no env read at all — but that is its own
gap: architecture §3 pins `config.js` as their "env surface" and the spec calls them
defaults, so D1 under-shipped them.

**Ruling:** `config.js` converts every value to a **live property getter** on
`module.exports` (`get CLAUDE_BIN() { return process.env.CLAUDE_BIN || 'claude'; }`,
derived paths computed inside their getters from the current `DATA_DIR`; `MAX_HOPS` and
`STALE_THRESHOLD_MS` gain their architecture-§3-mandated env overrides in the same
pattern, with numeric parse + fallback). Export NAMES are unchanged, so §13's pin holds;
§13 gains the convention line: **consumers access `config.X` at use time and never
destructure config at module top — destructuring re-freezes.** Blast radius verified, not
assumed: `db.js:11` `const { TOPOLOGY_DB } = require('./config')` destructures and must
be fixed in the same amendment; `identity.js` imports no config (pure, per ADDENDUM 5);
D4's in-flight `registry.js` must follow the convention for `ROUTER_TOKEN_FILE` — relay
to its lane now, and its verifier checks it.

**Ownership:** **D1.1**, Sonnet (getter subtleties + a consumer call-site fix — above
Haiku-mechanical), scheduled AFTER D4 commits (same worktree, serial), before D5. Done
conditions: in one Node process, two accesses under different `process.env.DATA_DIR`
yield different `config.TOPOLOGY_DB`; `CLAUDE_BIN=x` reflected at access time; db.js
opens at the CURRENT env path (two opens, two dirs, one process); no consumer
destructures config at module top (`command grep` with positive control on the require
count); `check-file-length.sh` and P2 grep clean.

**D10.1's module-scope workaround: KEEP now, REVERT in D10.2 after D1.1 verifies** —
restoring per-test env overrides and the secondary real-CLI scenario as an
**auth-gated test**: it skips with an explicit printed reason while `claude auth status`
is logged out and runs the day the machine is logged in. Coverage becomes explicitly
conditional instead of silently gone.

## Fixture-only A2/A5 — RULED: ACCEPTABLE, two conditions

The acceptance gate's job is proving the SERVER's atomicity and staleness logic;
integration with the real binary is D6's expanded smoke test, which remains the
designated HARD gate before any live use and doubles as the port-time preflight (P4/P5).
Conditions: (a) that smoke gate stands unchanged — the spawn mechanism stays empirically
unverified until it actually executes, and nothing here softens that; (b) the auth-gated
real-CLI secondary above is restored by D10.2 so the lost coverage is conditional, not
gone.

## A2 step 3 — RULED: partly this ratifier's own doing, and still inducible

Stated plainly: the unique-collision route to a step-3-only failure is unreachable
BECAUSE ADDENDUM 3 widened `idx_active_name` to `('spawning','active')` — the collision
now fires at INSERT (step 1) by design. Its unreachability at step 3 is that ruling
working as intended, not a coverage hole to apologize for. But D10.1's "no override
exists" overlooks a seam the design already pins: §13's `handler(args, ctx)` with
`ctx = { db, caller }` makes the db handle INJECTABLE. A test wraps the better-sqlite3
handle in a proxy that throws on the step-3 status-flip UPDATE, inducing a step-3 failure
in-process with zero production-code contortion — and with the fake-claude session
already running, which is exactly the distinct step-3 obligation (delete row AND kill
session) that steps 1–2 never exercise. **D6's done condition therefore STANDS as
written (all three steps induced), with the step-3 method now pinned: ctx.db
fault-injection proxy.** The `t.skip` is replaced in D10.2. If D6's implementation
somehow forecloses the proxy route, that is a stop-on-anomaly back to ratification, not
a silent skip.

## D5

Nothing here blocks D5 (`middleware.js`). Sequence: D4 lands + verifies → D1.1 → D5,
serial in the one worktree. D5's brief already cites §13; it gains the no-destructure
convention line like every later brief.

---

# ADDENDUM 7 — D4 verification: Invariant 3 enforcement + three pins (2026-09-02)

## Invariant 3 — RULED: enforced at TWO cooperating layers; §13:179 was this ratifier's pin defect

**The pin was unsatisfiable as written, and that is mine:** §13 pinned
`patchAgent(db, agentId, patch)` — a signature carrying no caller identity — and in the
same row said "status-transition table enforced here." A function that cannot see the
caller cannot enforce a caller-conditional rule. This is the second pin contradiction of
mine surfaced by an implementer (ADDENDUM 5 was the first); implementer stops are how
ratifier errors surface, which is the system working.

**Ruling — where Invariant 3 lives:**
1. **Runtime authority boundary: the D5 middleware seam.** Workers are separate
   processes; they cannot import `registry.js`; their entire capability surface is the
   MCP tool list, and every tool passes through the seam, which resolves the caller from
   its token and role-gates. For the threat Invariant 3 names — a worker exiting by any
   path other than `report_result`/`escalate` — seam enforcement IS real enforcement,
   structurally, because the process boundary makes the seam the only door.
2. **In-process discipline: capability-shaped primitives in the registry layer.**
   `patchAgent(db, agentId, patch)` stays EXACTLY as pinned — unrestricted, router-lane;
   adding a caller/role parameter would be a self-reported role, the precise anti-pattern
   the spec bans (role truth exists only after token resolution, i.e. at the seam).
   **`setWorkerStatus(db, agentId, status)` STAYS** (D4's addition is the right shape,
   and the registry row carries no exactly-N clause): worker-lane, rejects everything but
   `done`/`escalated`; handlers pass the RESOLVED caller's own `agent_id`, so "own row"
   is the seam's guarantee. **Worker-reachable handlers (`report_result`, `escalate`,
   `heartbeat`) may reference ONLY worker-lane primitives — never `patchAgent`** —
   enforced by a build-time grep added to D5's done condition (`command grep` for
   `patchAgent` across worker-reachable handlers → 0 hits with a positive control), in
   the same family as A7.

**Is middleware-only enforcement genuine?** Split answer, stated plainly: for EXTERNAL
callers, yes — structurally, via the process boundary and tool-only surface. For
IN-PROCESS callers (our own future code, the only thing that can import `registry.js`),
no single seam can be genuine on its own — which is why the ruling is layered: seam gate
+ capability-shaped primitives + build-time assertion together are enforcement; a code
comment is not. §13:179 and architecture §6 row 3 are reworded to this single reading.

**Process verdict — substantively CORRECT, procedurally UNACCEPTABLE.** D4's resolution
is the one this ruling adopts, and it still should have stopped. §13:153 makes deviation
from a pin a stop-on-anomaly; a pin CONTRADICTION is the strongest possible trigger, and
D4 built through it on private judgment, leaving Invariant 3 advisory with only a comment
to say so. D2, D3, D10 and D10.1 each stopped on thinner grounds, and every one of those
stops produced a better ruling than the silent guess would have been. Calibration for
every future implementer: **a pin contradiction is ALWAYS a stop, even when your
resolution looks obviously right — deviations are authorized in the record, never in
comments.** Had this guess been wrong, the registry would carry silent authority drift.

## `rotated: false` on first creation — RULED: add a third field, additively

`bootstrapRouter(db)` returns **`{ row, token, rotated, created }`**: first creation =
`created: true, rotated: false`; reuse = `false/false`; rotate = `false/true`;
`created && rotated` never both true. Additive (no shipped caller breaks), restores the
lost distinction. Fold into D4.1 if its lane can take the relay (it is inside
`bootstrapRouter`'s file I/O right now), else the next registry-lane touch.

## §13 gaps from D1.1's verification — both RULED into the record

- **(a) Spread re-freezes — convention WIDENED:** never destructure config at module
  top, and never spread or copy it (`{...config}`, `Object.assign({}, config)`) — any
  copy re-freezes at copy time. Access `config.X` at use time, always. Latent, not
  exploited (verifier: 0 spreads across all 5 consumers, control 1); the rule is fixed
  before the first exploit, not after.
- **(b) ESM named-export synthesis — recorded; no code change:** `cjs-module-lexer`
  cannot recognize `get X(){}`, so an ESM **named** import of `config.js` silently
  yields `undefined`. Ruling: ESM consumers MUST use the default import
  (`import config from '…/config.js'`) and property-access; named ESM imports of config
  are BANNED, recorded in §13. The getter design stands — the lexer limitation is
  inherent and the default-import path preserves live getters. D13's brief carries this
  line; D10.2 normalizes the tests to default-import-only (dropping the `??` fallback)
  and also fixes `fixtures.mjs`'s now-stale frozen-`DATA_DIR` header (lines 32–51) —
  confirmed, folded into D10.2.

## `registry.js` at 298/300 — RULED: split, and the seam is named

**`bootstrapRouter` and ALL its file I/O move to a new module `bootstrap.js`** (the F1
transaction: token-file read, chmod, symlink refusal, rewrite — precisely the code D4.1
is hardening), importing registry's row primitives and identity's pure functions.
`registry.js` keeps pure row CRUD + transition primitives (`createAgent`, `getAgent`,
`patchAgent`, `setWorkerStatus`). That is a real seam — file-I/O-laden init transaction
vs pure row CRUD — per ADR 0016's "split, don't butcher." ADDENDUM 5's "lives WHOLE
inside `registry.js`'s `bootstrapRouter`" is superseded on FILE LOCATION ONLY: the
transaction still lives whole, in `bootstrap.js`; ownership stays the D4 lane. §13 gains
a `bootstrap.js` row; `server.js` (D13) calls `bootstrapRouter` from its new home. Owner:
D4.1 if relayable, else a D4.2 immediately after — an implementer does not choose the
seam, and now does not have to.

## ADDENDUM 7 note — defect-5 (symlink) scoping CONFIRMED (post-D4.1)

D4.1 left the token-file symlink-follow unfixed, scoping it out on the grounds that
exploitation requires local write access to `DATA_DIR`. Confirmed, not overruled: that is
the same same-user trust boundary the F4 redaction ruling already excludes — an attacker
who can write `DATA_DIR` is the same user and can simply read the mode-600 token file
directly; the symlink adds no capability the boundary doesn't already concede. One caveat
recorded so the scoping cannot silently outlive its premise: it holds only while
`DATA_DIR` is user-private. The ported environment must keep it so — P5's lift-and-port
step 3 (set `DATA_DIR`) inherits this as a requirement, not a suggestion.

---

# ADDENDUM 8 — D4.2 ruled: retry ownership (R1), concurrency model (R2), flag-and-proceed calibration (R3) (2026-09-03, fresh ratifier instance)

Continuity note: the prior ratifier instance was stopped; this addendum is by a FRESH
instance that read the full record (both ratification parts, both architecture parts, the
plan, ADR 0035, the shipped code at `baff0ec`) rather than relying on continuity. D4.2's
runtime evidence (30 clean 6-process runs, 18 no-regression checks, line counts) is
treated as CLAIMS pending the independent verification in flight at ruling time; nothing
below depends on those claims — every load-bearing fact cites a file/line this instance
read or a command it ran.

## R1 — RULED: openDb placement CORRECT; double-seam CORRECT, not redundant; §13's db.js row amended

**Placement.** If open-time contention is to be retried at all (see R2 for whether), the
connection-opening module is the only correct owner: the diagnostic evidence D4.2 cites
places the failure AT the `journal_mode=WAL` pragma inside `openDb` (db.js:118-152) —
before `bootstrapRouter` ever runs — and a downstream module cannot retry a failure that
occurs while the handle it needs is being created. `db.js` creating handles is also why it
is the right home for the shared helpers: neither `registry.js` nor `bootstrap.js` may
require the other, and both sit downstream of db.js cycle-free (db.js:36-42 states this
and the import graph confirms it).

**Double seam — CORRECT.** The two seams fail differently and need different remedies:
open-time `SQLITE_BUSY` at the one-time WAL journal-format switch is a lock wait that can
outlive `busy_timeout`'s per-statement budget, remedied by re-attempting the whole
idempotent open (db.js:118-152, schema all IF-NOT-EXISTS); an in-transaction
`SQLITE_BUSY_SNAPSHOT` is not a lock wait at all and is remedied only by re-running the
transaction from a fresh read (bootstrap.js:143-173). Neither seam's retry can cover the
other's failure shape. Not redundant; both stand.

**Is db.js doing too much?** No, with one amendment. 163 lines sits under the 300 cap,
and `registry.js` stays retry-free (`command grep -n 'retry\|BUSY\|sleep'` → 0 hits,
control: 10 `function` hits), so contention handling is confined to exactly two seams.
BUT db.js now exports SIX names (db.js:156-163) against §13's pinned THREE (part 2
§13, db.js row) — a pinned-surface change no record authorized. Substantively right
(`requireDb` de-dup kills a real duplication the D4.2 verifier named;
`isRetryableBusy`/`sleepSync` shared so bootstrap.js does not redefine the FUNCTIONS) —
ratified POST-HOC here. §13's db.js row is amended to the six names and gains the
containment clause: **contention handling lives ONLY at these two seams (openDb's open
retry, bootstrapRouter's transaction re-run); no other module adds busy retries; no
further db.js export without a stop.**

**Defect NAMED, not fixed (this is a docs-only dispatch):** db.js:58-59's comment is
false three ways — it claims the retry bound is "same bound … exported below so
bootstrap.js does not redefine its own copy," yet `MAX_BUSY_RETRIES` is absent from
db.js's exports (db.js:156-163), bootstrap.js:74 redefines it, and the values DIFFER
(10 at db.js:62 vs 8 at bootstrap.js:74). Owner of the fix: fold into the dispatch that
answers the in-flight D4.2 verification (D4.3 on ISSUES, else the next registry-lane
touch). Two forms are pre-authorized so no new stop is needed: (a) correct the comment —
each seam owns its own bound — or (b) export the constants and amend §13's row again.

**Consequence if wrong:** if openDb was the wrong owner, the cost is ~100 contained lines
in one under-cap module plus a wider pinned surface — reversible by a later slim-down.
The inverse error (ordering removal now) would put raw first-open crashes back in front
of the test harness and the port-time preflight, and would reopen a dispatch line that is
mid-verification. Asymmetric; keep.

## R2 — RULED: concurrent bootstrap is NOT a supported operating mode; the concurrency model is now STATED (part 2 §14)

**The finding that forced the question:** three dispatches (D4 → D4.1 → D4.2) accumulated
contention defenses discovered defect-by-defect from a 6-process harness that NO record
document mandates. Checked: `command grep -rn -iE '6.process|six.process|concurrent
(bootstrap|open|start|init|server)|concurrenc'` across both architecture parts, the plan,
and ADR 0035 → the only hits are the plan's Rule 7 dispatch-lane text (plan:57,158),
nothing about concurrent DB access (control: 9 `bootstrap` hits in this file alone). The
harness was testing a mode the architecture never declared.

**Ruling.** The record, read as a whole, already answers the question — it had just never
been stated in one place:

- **One production DB-opener exists.** `server.js` is the sole entry (`architecture/
  agent-topology.md` §3 module table: "HTTP entry, /health, port file"); it calls
  `bootstrapRouter` once at init (D13 row); workers are `claude -p` processes that reach
  registry state ONLY through the server's MCP tools and never open the SQLite file
  (§3, §5). In the shipped tree the only `openDb` caller is db.js itself — no second
  production opener exists (`command grep -rn 'openDb' tools/agent-topology
  --include='*.js'` excl. node_modules → definitions/comments only).
- **F1's contract is serial.** Its done condition is "two CONSECUTIVE server starts"
  (plan D4 row); the spec chose SQLite BECAUSE "single-writer semantics match the
  write-asymmetry rule" (spec:148).
- **The record already classifies the concurrent-create race as an anomaly, not a mode:**
  "STOP: bootstrap uniqueness error" is a per-row stop fragment on D4 AND D13 (plan
  dispatch table), and the shipped code conforms — `SQLITE_CONSTRAINT_UNIQUE` is not
  retryable (bootstrap.js:160 `isRetryableBusy` gate).

So: **concurrent bootstrap — two or more processes racing `bootstrapRouter`/first-open on
one DB — is OUT OF CONTRACT.** It cannot happen in the production star; where it appears
(a double-started server) it is an operator error to be surfaced loudly, never converged
through silently.

**What is REMOVED: nothing — and why that is not a contradiction.** The retries are
RECLASSIFIED, not endorsed as mode-support: they are bounded HARDENING against transient
lock/snapshot contention from legitimate secondary openers (the test harness, the
port-time preflight, a diagnostic open), inert on the supported single-opener path (first
attempt succeeds, loop exits). Removal would cost a fresh dispatch plus re-verification
against a line that is mid-verification, and most of db.js's growth is §13 error
discipline (no raw error escapes) that stays regardless. The accretion is stopped at the
source instead: **part 2 §14 is the stated model, and every future concurrency defect is
judged against §14 first — "is this scenario in contract at all?" — never against
whatever a harness happens to spawn.** The 6-process tests are kept as hardening
regression tests with their scope so labeled.

**Named hazard the retries do NOT cover (proof the reverse-engineered defenses missed the
real question):** two concurrent bootstrappers can fight over adopt-vs-rotate — the token
file write is a non-transactional side effect inside the transaction callback
(bootstrap.js `writeRouterTokenFile` called within `txn`), so an out-of-contract second
server can rotate the token out from under the first. Deliberately NOT defended with more
retry code; the defense is single-instancing (§14 clause 4: D13's startup treats an
already-live instance on the same DATA_DIR as a STOP, using the port file §3 already
gives it).

**Port survival.** §14 states INVARIANTS, not tuned numbers, so the model travels: one
server process per DATA_DIR; DATA_DIR on a local filesystem (the port-time preflight
checks this — WAL/locking assumptions do not hold on network filesystems); DATA_DIR
user-private (ADDENDUM 7's symlink-scoping premise, carried into P5 step 3). If the
ported environment needs multiple concurrent writer processes, the SQLite choice itself
reopens — the spec names its own successor path (spec:148 "swap for a Notion database
later") — a ratification-level design change, never a retry-tuning exercise.

**Consequence if wrong:** if concurrent multi-server operation turns out to be genuinely
needed, §14 makes that need surface as an explicit STOP + ratification question instead
of a half-working mode held up by retries that do not cover the adopt/rotate race — it
fails loud in the correct direction. The residual cost of this ruling is carrying ~40
lines of hardening code whose production reachability is near zero; bounded and accepted.

## R3 — calibration: D4.2's flag-and-proceed was RIGHT on the retry scope; the pin rule stands untouched; one half went unflagged

**The two cases are different in kind, and implementers must carry the distinction:**

- **D4 (ADDENDUM 7's verdict, reaffirmed):** a contradiction BETWEEN RECORD AUTHORITIES
  (§13's pinned signature vs the same row's enforcement claim) with NO authorizing clause
  — built through on private judgment, resolution recorded only in comments.
  "A pin contradiction is ALWAYS a stop" governs that case, unchanged.
- **D4.2 (this case):** the brief's ANTICIPATED LOCATION ("inside createAgent's
  transaction") was falsified by diagnostic evidence, and the brief itself carried an
  explicit delegation clause ("implement it where it correctly belongs"). A brief's
  anticipation is not a pin; the authorization D4.2 acted on was IN THE RECORD (the
  brief's own clause), and the deviation was surfaced explicitly in the report with the
  evidence that forced it. That is the system working: **flag-and-proceed is correct when
  (a) an explicit clause in the brief pre-authorizes the judgment being exercised AND
  (b) the deviation is surfaced in the report with its evidence. Absent either, stop.**

**The unflagged half:** the db.js export-surface change (three pinned names → six) is a
§13 pinned-surface deviation (ADDENDUM 4: "deviation is a stop-on-anomaly, not an
implementer's choice") that the brief's placement clause did NOT cover, and the report as
relayed flags only the retry-scope expansion. That half warranted its own stop or, at
minimum, its own explicit flag. Ratified post-hoc under R1 because it is substantively
right — but the calibration line extends: **a pinned-surface change (exports, signatures,
schemas) is never covered by a general "where it belongs" clause; it stops, every time,
even inside an otherwise-authorized deviation.** The in-flight verifier should confirm
whether D4.2's full report flagged the export additions; if it did, this paragraph's
process criticism softens to "flagged but wrongly self-authorized" — the ruling above is
unchanged either way.

**Consequence if wrong:** too-lenient calibration teaches implementers to stretch
delegation clauses into scope licenses; the guard is exactly the two-part test plus the
pinned-surface carve-out. Too-strict calibration (requiring a stop even under an explicit
clause with explicit surfacing) would re-create the stop-storm this build has already
paid for five times over — D2, D3, D10, D10.1, D3-again all stopped correctly, but a
system where EVERY judgment stops is a system where briefs cannot delegate at all.

## D5 clearance

**D5 is CLEAR to dispatch once (and only once) D4.2's independent verification returns
CLEAN.** Nothing in R1–R3 blocks the middleware seam. D5's brief MUST carry, beyond what
ADDENDUM 6/7 already added (no-destructure convention; the `patchAgent` build-time grep):

- The §14 concurrency model line: middleware and handlers run inside the single server
  process and add NO busy retries — contention handling lives only at the two ruled
  seams (db.js `openDb`, bootstrap.js transaction re-run).
- §13's db.js row as amended (six exports); any new export or pinned-surface change is a
  stop-on-anomaly BY NAME, per R3's calibration line — not covered by any general clause.

## Consequent edits applied by this addendum

1. Part 2 §13 db.js row: amended to the six shipped exports + containment clause (R1).
2. Part 2 gains **§14 — Concurrency model** (R2's six clauses).
3. Plan: D13 row gains the §14 single-instance STOP; the D1.1-gate block gains the D5
   brief-carry lines above.

## Named, not acted on

- db.js:58-63 false comment (bound "shared/exported/not redefined" — none true; 10 vs 8)
  — owner assigned above, not fixed here (docs-only dispatch).
- The 6-process harness's own scope label ("hardening regression, not mode conformance")
  lives in the test worktree — D10.2's existing amendment list is the natural carrier;
  not edited from here (sibling-worktree constraint).
- Whether D4.2's FULL report flagged the export additions — left to the in-flight
  verifier; both outcomes leave R1/R3 unchanged.

---

# ADDENDUM 9 lives in `architecture/agent-topology-ratification-03.md`

This file reached 459/500 lines at Addendum 8; later addenda continue in the `-03` file
(split, not butchered — same convention as the part 1 → part 2 split).
