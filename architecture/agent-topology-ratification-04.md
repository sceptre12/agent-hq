# agent-topology — ratification record, PART 4 (continues -03.md)

Split provenance: `agent-topology-ratification-03.md` was at 405 lines; ADDENDUM 12 below
(ruling on D6's four self-reported gaps) would have pushed it over the 500-line cap. Per
ADR 0029 clause 3/4.1, carved into this new part rather than committing an over-cap state.

---

# ADDENDUM 12 — D6 self-reported gaps G1-G4: ratified (2026-09-03)

Ratification authority dispatch (Sonnet — status.claude.com showed an active
Fable/Opus-tier incident at dispatch time; same rigor applied as the rest of this
record). D6 landed at `724cb7b` (`spawn_agent.js` + `preamble.js`, OQ4 branch iii) and
self-reported four gaps in its own commit message and file headers. Ruled on all four.
D6's already-verified evidence (rollback proofs, token-argv-visibility) is untouched here
— a separate, independent verifier owns that.

## G1 — RULED: rollback delete needs a pinned primitive; raw SQL NOT blessed as a general pattern

Confirmed directly: `registry.js`'s shipped exports are exactly `createAgent`,
`getAgent`, `patchAgent`, `setWorkerStatus` (`command grep -n 'module.exports\|^function '
tools/agent-topology/registry.js` → no `delete*`), matching §13's ADDENDUM-7-settled pin.
`spawn_agent.js:129-135` issues `ctx.db.prepare('DELETE FROM agents WHERE agent_id = ?')`
directly, flagged `[MINE]` in its own header.

**Ruling: add `deleteAgent(db, agentId)` to `registry.js`, additively — the same pattern
as ADDENDUM 7's `rotated`/`created` field addition** ("Additive (no shipped caller
breaks)"). `registry.js` being frozen-and-verified is not a reason to bypass it; it is a
reason to extend it narrowly rather than route around it. Assigned: **D6.1** (below).

**Precedent — FORBIDDEN generally, for a concrete mechanism, not a style preference.**
Invariant 3's enforcement (ADDENDUM 7) is "seam gate + capability-shaped primitives +
build-time grep" — the grep checks that worker-reachable handlers (`report_result`,
`escalate`, `heartbeat`) never reference `patchAgent` by name. **That grep is blind to raw
`ctx.db.prepare(...)` SQL.** If raw SQL against `agents`/`messages` becomes an accepted
pattern, a future worker-reachable handler (D7, D12) could flip status to anything via raw
SQL and Invariant 3's build-time check would see nothing wrong — a silent authority-bypass
hole, not a style issue. D7/D9/D12 must use pinned primitives; a missing primitive is an
additive-pin request (this ruling's own precedent), never a raw-SQL workaround.

**Consequence if this ruling is wrong:** minimal — `deleteAgent` is a strict superset of
the raw SQL, functionally identical, costing one small additive dispatch. **Consequence of
NOT ruling this way:** D7/D9/D12 could each reach for raw SQL, and a worker-reachable one
doing so would defeat Invariant 3's grep-based enforcement invisibly.

## G2 — RULED: D6 is NOT done as landed; `provision.js` was pinned to D6, not legitimately narrowed

Confirmed: `architecture/agent-topology-02.md:182` §13 pins `provision.js (D6)`; the
plan's F7 point 4 (`plans/agent-topology.md:332-335`) states "Worker working directory (D6
owns)... `provision.js` copies the worker skill there"; ADDENDUM 11's R2
(`agent-topology-ratification-03.md:342-343`), written and ratified **immediately before
D6 was dispatched**, reaffirms: "architecture §3's module table assigns `spawn_agent` +
`preamble.js` + `provision.js` to D6." `provision.js` does not exist
(`ls tools/agent-topology/provision.js` → no such file); `spawn_agent.js:45-49` names the
gap in a comment rather than stopping.

**This is a pin deviation, not a legitimate narrow scope.** Per ADDENDUM 7's calibration
("a pin contradiction is ALWAYS a stop, even when your resolution looks obviously right —
deviations are authorized in the record, never in comments"), D6 should have stopped when
its own brief narrowed away from a three-times-pinned deliverable — the same category of
procedural lapse ADDENDUM 7 called "substantively CORRECT, procedurally UNACCEPTABLE" for
D4. D6's actual work (atomicity, rollback, four-slot preamble) is not in question here —
only the completeness claim.

**Ruling: D6 is INCOMPLETE, not "done, narrowly scoped."** `provision.js` is assigned to
**D6.1** (below) — it is the same pinned D6 deliverable, not new scope. **Interim state is
acceptable and blocks nothing currently in flight:** the branch-(iii) mechanism itself
remains empirically unverified (`claude auth status` → `loggedIn:false`) in this
environment, so no real worker is being spawned yet; a worker with a cwd but no copied
skill is a real gap that must close before the D1–D7 ship boundary is declared complete,
but it blocks no dispatch in the current chain.

## G3 — RULED: genuine spec gap predating D6; F4 never addressed it; `task` ships in D6.1, overrides deferred

Confirmed directly against the spec on disk (`topology-tooling-build-spec.md:100,103`):
`spawn_agent(spec)`'s input is `{ name, tier, scope, task, worker_preamble_overrides? }`;
step 2 is "Create the agent session with the Worker Preamble (below) + task injected as
system context" — `task` is injected ALONGSIDE the preamble, not necessarily as a preamble
template placeholder. F4 (`agent-topology-ratification.md:300-315`) ruled only the fourth
`{auth_token}` slot into `preamble.js`'s template; it never mentions `task` or
`worker_preamble_overrides` (0 hits for `worker_preamble_overrides` across every
architecture/plan doc; control: `task_id` — a different concept — present 3/1/1 times in
the same docs, proving the grep pattern itself works). **This predates D6: F4 pinned
preamble.js's four-slot signature before D6 was dispatched, and D6 correctly built to that
pin.** D6's header names the gap accurately ("NAMED, NOT BUILT... outside this dispatch's
four-slot pin (§13) and outside D6's scope as briefed") — D6 is correctly reporting a gap
in an EARLIER ruling (F4/architecture), not a D6 defect.

**Functional consequence, stated plainly:** `spawn_agent.js`'s shipped `inputSchema` has
no `task` field at all (verified: `properties` lists only `auth_token`/`name`/`scope`/
`tier`/`role`) — a spawned worker today receives ONLY the Worker Preamble (role/scope/tier
instructions), with no task content. A real spawn right now would produce a worker with
nothing to do.

**Ruling, split:** (a) `task` (required string) — add to `spawn_agent`'s input schema,
appended as separate stdin content AFTER the preamble text (not a `preamble.js` slot —
preserves F4's already-pinned, already-verified four-slot interpolation contract).
Low-ambiguity, assigned to **D6.1**. (b) `worker_preamble_overrides?` — **NOT ruled here,
deliberately deferred.** It raises a real design question (replace vs. append vs.
slot-override; interacts with the redaction-critical preamble content, including the
`{auth_token}` line) that needs its own ratification pass, not a mechanical fix. Named,
not acted on. Does not block D1–D7's ship boundary — the spec's own build order marks step
3 (worker exits) as "stopping here yields a working system," and overrides are an
optional-input refinement, not a step-3 precondition.

## G4 — RULED: confirmed pre-existing, not a D6 defect; D10.3 owns the fix; blocks nothing in flight

Confirmed directly: `wt/agent-topology-tests` commit `e9c4095` (D10.2, landed 09:36:48,
**before** D6's `724cb7b` at 10:52:22) — its own commit message and
`test/acceptance/a2-spawn-atomicity.test.mjs:105-141` state steps 1–2 call
`spawnAgent(input)` (bare single-argument, pre-D5 convention) and were **confirmed, not
predicted**, to throw `ExportShapeError` against a real §13-shaped export, via D10.2's own
verification harness — the same defect D5 flagged and fixed for A1. Step 3 (the new
fault-injection test, added by D10.2 item 4) uses the correct `loadExportedTool` +
`wrapTool` call shape and is unaffected. The file's own header already names the fix
owner: "the next dispatch that touches A2's calling convention (D6's verifier, or a future
D10.3)."

**Ruling: D10.3, not D6's verifier.** Rewriting A2's calling convention is test-authoring
work in the D10-lineage pattern (D10 → D10.1 → D10.2, all tests-worktree, all
non-author-verified); D6's verifier's job is to verify D6's deliverable, not patch the test
suite it is grading against — assigning the fix to the verifier would make it author part
of its own gate.

**Blocks nothing currently in flight.** D7 (report_result/escalate/read_messages) has no
dependency on `spawn_agent`'s calling convention. A2 is checked at the full acceptance
gate (after the D1–D13 chain, or at minimum before the D1–D7 ship boundary is declared
closed) — not a precondition for any individual dispatch's start. It DOES need to land
before that gate can run cleanly.

---

# ADDENDUM 13 — D6.1 verified, blocked on the 300-line gate: split ruled (R1), provision
subpath pinned (R2), rollback self-correction assessed sound (R3) (2026-09-03)

Ratification authority dispatch (Sonnet — status.claude.com showed an active Fable/Opus
incident at dispatch time; same rigor applied). D6.1 (ADDENDUM 12's G1/G2/G3(a) fix)
completed all four functional items with cited evidence, caught and fixed its own
mid-dispatch regression (item 5, R3 below), and correctly refused to split, allowlist, or
`--no-verify` past `tools/check-file-length.sh`'s 300-line gate when its finished
`spawn_agent.js` measured **358 lines** (confirmed: `wc -l
tools/agent-topology/tools/spawn_agent.js` → 358; `LIMIT=300` at
`tools/check-file-length.sh:15`). The changes are UNSTAGED in
`hq-worktrees/agent-topology`'s working tree (confirmed via `git status --porcelain` /
`git diff --stat`, this dispatch's own commands): modified `preamble.js`, `registry.js`,
`tools/spawn_agent.js`; new `provision.js`. Nothing in `tools/agent-topology/` is touched
by this ADDENDUM — docs only.

## R1 — RULED: extract `launchWorkerSession` into a new package-root module `worker_session.js`

Read the live diff directly (`git diff -- tools/agent-topology/tools/spawn_agent.js`) and
the resulting file (`Read tools/agent-topology/tools/spawn_agent.js`, all 358 lines).
Confirmed both candidates are real, cohesive units, not an arbitrary line-count split:

- **`launchWorkerSession`** — doc comment + function, lines 180–252 inclusive (73 lines,
  matching the dispatch's own measurement). Pure child-process concern: `spawn()` argv
  construction, stdin write, stdout/stderr draining, exit/error handlers, and the
  timeout/process-group-kill path (D6.1 minor item 2). Nothing in it reads `agentId`,
  `workerDir`-as-registry-concept, or calls `registry.js` — it only takes
  `{ sessionId, cwd, stdinPayload }`.
- **`rollbackSpawn`** — doc comment + function, lines 131–178 inclusive (48 lines, matching
  the dispatch's own measurement). This is spawn_agent's OWN compensating-transaction logic
  (calls `deleteAgent`, removes `workerDir`, builds the compound stranded-row error) — it is
  not a generic utility, it is "the atomic register-and-create flow"'s own rollback step,
  the thing the file's header says this module IS.

**Ruling: extract `launchWorkerSession` only.** Simulated the removal (this dispatch's own
Python line-accounting against a scratch copy, not the live file): removing the
`launchWorkerSession` block (180–252), the `SPAWN_TIMEOUT_MS` block it alone uses (91–98,
8 lines — a local, explicitly non-pinned convention constant, moves with it), and the
now-unused `require('child_process')` (line 79) removes 82 lines; adding back one
`require('./../worker_session')` line and a short header pointer (bootstrap.js/registry.js
precedent, ADDENDUM 7) lands `spawn_agent.js` at roughly 280 lines — comfortably under 300
with margin for the header edit's exact wording. Extracting `rollbackSpawn` too was
considered and rejected: `launchWorkerSession` alone clears the gate with margin, and
`rollbackSpawn` is spawn_agent's own orchestration logic, not a second reusable seam —
extracting it would add a file without reducing real coupling (Rule 7: don't split finer
than the gate requires).

**Module name and export, PINNED into §13 (`agent-topology-02.md`, new row, applied in
this commit):** `worker_session.js`, package root (sibling to `registry.js`/`bootstrap.js`/
`preamble.js`/`provision.js`) — **not** under `tools/`, because that directory is reserved
by the already-pinned `tools/*.js` row for the uniform `tool = {name, description,
inputSchema, handler}` shape a future `mcp-server.js` (D13) loops over; a non-tool helper
file placed there would be indistinguishable by location from one of the 10 anticipated
tool files and risks a naive "loop everything in `tools/`" implementation trying to
register it as an 11th tool. Exactly one named export: `launchWorkerSession({ sessionId,
cwd, stdinPayload })` → `Promise<void>`. `SPAWN_TIMEOUT_MS` moves in as a module-private
constant (not exported — nothing outside the module needs it).

**Consequence if this ruling is wrong:** low — `worker_session.js` is a pure lift-and-shift
of already-shipped, already-evidenced logic; a wrong module name or location is a rename,
not a rewrite. **Consequence of not ruling now:** D6.1's verified, working code sits
uncommitted indefinitely, or a future implementer improvises a different split under time
pressure, reopening exactly the kind of undocumented-seam drift D10 already cost this build
once (§13's own opening line).

## R2 — RULED: `.claude/skills/agent-topology-worker/` is the correct pinned subpath

D6.1's `provision.js` header (`tools/agent-topology/provision.js:24-33`, read directly)
already names this exact reasoning and flags it "for the ratifier." Verified independently,
not taken on the file's own word: grepped `architecture/` and `plans/` for a destination
subpath — OQ6's ruling (`agent-topology-02.md:50-58`, `agent-topology-ratification.md:
120-128`) states the worker skill installs "project-scoped... by COPY" but never spells out
a subpath; §13's pre-ADDENDUM-13 text said only "into `$DATA_DIR/workers/<agent_id>/`."
D6.1's claim — that `.claude/skills/<name>/` is the layout a Claude Code session actually
discovers a *project*-scoped skill from — is corroborated by a live, independent example
outside this repo: `find $HOME/projects -maxdepth 4 -type d -name skills -path
"*.claude*"` → `$HOME/projects/<project>/.claude/skills`, containing
`sprout-cli/SKILL.md` and `desktop-screenshot/SKILL.md` — a real, working project-scoped
install using exactly this layout, not merely this build's own assertion about itself
(positive control: the search also confirmed six other unrelated `.claude/` dirs exist
under `~/projects/`, so the hit is not a fluke of an overly narrow glob).

**Ruling: `.claude/skills/agent-topology-worker/` (relative to `workerDir`) is PINNED.**
Added to §13's `provision.js` row in this commit (`agent-topology-02.md`). D6.1's shipped
`provision.js` already matches it exactly (`PROJECT_SKILLS_SUBPATH = path.join('.claude',
'skills')`, `installed = path.join(workerDir, PROJECT_SKILLS_SUBPATH,
WORKER_SKILL_NAME)`) — **no code change needed for R2**, only the doc pin.

## R3 — ASSESSED: the compound-error rollback fix (item 5) is sound

Read `rollbackSpawn` (lines 131–178) and all four of its call sites in `handler` (lines
280–330) directly, not taken on the report's word. Every step that can fail after the row
is inserted (`mkdirSync`, `provisionWorkerSkill`, `buildPreamble`, `launchWorkerSession`,
`patchAgent`) now routes through `rollbackSpawn` — zero remaining bare `deleteAgentRow`-style
call sites (confirmed: `command grep -n "deleteAgentRow\|catch (err)" tools/agent-topology/
tools/spawn_agent.js` shows only `rollbackSpawn` after the five `catch` blocks). The new
path — `deleteAgent` itself throwing during an already-failing operation — is handled by
returning a COMPOUND `INTERNAL_ERROR` naming both failures plus the stranded `agent_id`,
never swallowed; cleanup ordering is correct (row confirmed gone before `workerDir` is
`rmSync`'d, so a stranded row keeps a diagnosable cwd); every field in the compound error's
`details` is either the server-minted `agentId` (already non-secret, registry.js
precedent) or a static/derived `code`/`message` from a `makeError` shape — no caller string
and no token reaches it, consistent with the file's own REDACTION discipline. **Sound.**
This is the same self-correction pattern this record has already praised elsewhere (D4.3's
HEAD-move stop, D6's honest gap-naming) — a positive calibration instance for the record,
not something requiring re-implementation.

## D6.2 — NEW DISPATCH: execute R1 (the split) and R2's doc-only confirmation on the preserved D6.1 code

**Scope:** on the CURRENT uncommitted working tree in `hq-worktrees/agent-topology`
(`wt/agent-topology`, HEAD `3c33ba1` at ADDENDUM 13 time) — do not re-derive D6.1's work
from the backup patch or from scratch. (1) Create `tools/agent-topology/worker_session.js`
per R1's pinned shape; move `launchWorkerSession` (lines 180–252) and the
`SPAWN_TIMEOUT_MS` block (lines 91–98) into it verbatim; remove the now-unused
`require('child_process')` from `spawn_agent.js`; add `const { launchWorkerSession } =
require('./../worker_session');` to `spawn_agent.js`; add a short header pointer in
`spawn_agent.js` naming the split (bootstrap.js/registry.js precedent). (2) R2 needs no
code change — confirm `provision.js`'s `PROJECT_SKILLS_SUBPATH` already matches the pin and
note that in the commit message. **Sonnet** — mechanical lift-and-shift of already-ratified,
already-evidenced logic, no new design judgment. Non-author verifier. **Done condition:**
`wc -l tools/agent-topology/tools/spawn_agent.js` ≤ 300 (positive control: confirm it was
358 before, and that `check-file-length.sh` failed before and passes after); `git diff`
shows `launchWorkerSession`'s behavior byte-identical (same spawn args, same timeout/kill
logic, same event handlers) — a pure move, not a rewrite; D6.1's existing test evidence
(`verify.js`, `leaktest.js`, `killtest.js` in the scratchpad, or their committed
equivalents) still passes against the split code; `tools/check-file-length.sh` and the
pre-commit hook both pass; commit lands (this is a normal worktree commit, not blocked by
any gate named in this ADDENDUM).

## Item 6 (D6.1's stuck-`spawning` gap) — noted, not ruled

D6.1 named a real gap: a crash between `launchWorkerSession` succeeding and `patchAgent`
flipping the row to `active` strands that row at `spawning` forever (no reaper); the row's
name still blocks reuse (`idx_active_name` covers `spawning`) and its token stays live
(middleware's `LIVE_STATUSES` covers `spawning`) indefinitely. **Not ruled here** — assigned
a future home (D13 init or a dedicated sweep dispatch) when that work is actually
dispatched. Named, not acted on.

## Consequent doc edits applied in this commit

- §13 (`agent-topology-02.md`): new `worker_session.js` row (R1); `provision.js` row gains
  the pinned destination subpath (R2); `tools/*.js` row gains a one-clause note that
  `spawn_agent.js`'s require of `worker_session.js` is not an 11th tool file.
- Plan (`plans/agent-topology.md`): new dispatch-table row for **D6.2**.

## D6.1 — NEW DISPATCH: closes G1 + G2 + G3(a), one lane, sequential (not parallel)

`registry.js` (+1 additive export) + `provision.js` (new file, per the already-pinned
§13/F7-pt-4 signature `provisionWorkerSkill(workerDir) → installed path`) +
`spawn_agent.js` (three call-site changes: `deleteAgentRow` → `deleteAgent`; wire
`provisionWorkerSkill` into the cwd-creation step; accept + append `task` to stdin).
**Sonnet** — three additive, low-ambiguity, already-pinned-shape fixes, no new design
judgment. Bundled into ONE sequential dispatch, not three parallel ones, because all three
touch `spawn_agent.js` — Rule 7's same-file-edit safety bar rules out parallelizing them
(assessed against the ~30-agent ceiling as a stress test: 0 of 3 safe to parallelize
against each other; rejected on the safety bar, not the cost bar). Non-author verifier.
Done condition: `registry.js`'s `deleteAgent` used at all rollback sites (0 raw `DELETE`
`ctx.db.prepare` calls remain in `spawn_agent.js`, positive control: `prepare` calls
present); `provision.js` exports exactly `provisionWorkerSkill`; a spawned worker's dir
contains the copied worker SKILL.md; `task` is required in `spawn_agent`'s input schema
and appears in the child's stdin after the preamble text, never inside it. **STOP:** any
of the three fixes requires touching `preamble.js`'s pinned four-slot signature (out of
scope — see G3(b)).

## Consequent doc edits applied in this commit

- §13 (`agent-topology-02.md`): `registry.js` row gains `deleteAgent(db, agentId)`
  (additive, D6.1); the four existing exports are unchanged.
- Plan (`plans/agent-topology.md`): new dispatch-table rows for **D6.1** and **D10.3**;
  D7's row gains a brief-carry note (below).

## D7 clearance

**D7 is clear to dispatch.** None of G1–G4 blocks it. D7's brief must carry: (1) G1's
precedent ruling verbatim — `report_result`/`escalate` status-flips use `setWorkerStatus`
(already pinned, worker-lane); if a needed mutation has no primitive, STOP and request an
additive pin extension, never raw SQL; (2) the pre-existing, already-named (ADDENDUM 11)
open question of whether D7's `messages`-table write needs the same "construct-then-
validate before write" obligation D9 got — a D7-brief question, not re-opened or resolved
here; (3) awareness that A2 steps 1–2 carry a known, tracked, unrelated defect (fixed by
D10.3) — no action needed by D7 itself.

---

# ADDENDUM 14 — D6 chain shape ruled: consolidate the failure path (R1), no third
adversarial pass (R2), conditional close bar for D6.4 (R3) (2026-09-03)

Ratification authority dispatch (Fable). Ruled with D6.4 IN FLIGHT and NOT landed: HEAD
`847fe6f` at ruling time (`git log -1`, re-checked immediately before writing), no `.js`
modifications in the working tree (`git status --porcelain` → only three staged `.md`s).
All verifier claims re-verified against `847fe6f`'s actual code, not taken on the record's
word. Docs only; nothing under `tools/agent-topology/` touched by this ADDENDUM.

## R1 — RULED: the recurrence is STRUCTURAL; the fix is a single in-file settle helper,
not another per-site patch — and not a redesign either

Evidence, all from `git show 847fe6f:tools/agent-topology/worker_session.js` (147 lines):
the invariant this file must uphold — "a rejection never leaves the child alive, and no
stdio emitter is left without an 'error' listener" — currently has SIX enforcement sites,
each hand-maintained: timeout (L74-84, group-kills — correct), `child.once('error')`
(L90-97, no kill), `child.stdin.once('error')` (L108-116, no kill — verifier Issue 1,
confirmed: `rollbackSpawn` at `tools/spawn_agent.js:163/169` then deletes the row and
`rmSync`s the workerDir under a live session, against `spawn_agent.js:18`'s "A2 sees zero
orphan rows/sessions"), `child.stdout`/`child.stderr` (L87-88, NO 'error' listener at all —
verifier Issue 2, confirmed), exit (L117-127, child dead — correct), and the sync
write/end catch (L128-141, rejects with NO kill — **a THIRD instance of Issue 1's exact
shape, found by this ruling, named by no verifier round**). Two consecutive closing
verifications each found one more instance of the same one-line shape; this pass found
another still unclaimed. That is not three streams and bad luck — it is an invariant with
no single home. Sidebar: `child.once('error')` is not strictly a "never-spawned" path
(Node also emits it on kill failure post-spawn), so even the verifier's safe-list had a
soft edge; a unified path subsumes it without needing the per-path liveness reasoning.

**Ruling:** `worker_session.js` adopts ONE internal failure-settle helper — `fail(err)`:
settle-once guard, clear timer, **unconditional best-effort process-group SIGKILL** (the
existing L81-82 try/catch pattern; killing an already-reaped group throws ESRCH and is
caught, so no path needs to prove the child dead first), then reject — and ONE shared
'error' listener attached in a loop over `[child.stdin, child.stdout, child.stderr]`.
The resolve path (exit 0) stays as-is. Net: fewer lines than three patched sites, and a
fourth stream- or path-shaped defect CANNOT recur because no per-site kill logic remains
to forget. §13's pinned export surface (`agent-topology-02.md:182`) is unchanged — this
is internal restructure of a 147-line file with a 300 cap; fully proportionate.

**Disposition vs the in-flight D6.4:** judge its LANDED diff, do not interrupt it.
- If D6.4 landed the kill+reject logic single-sited (a `fail()`-equivalent) covering all
  paths including the sync catch → R1 is satisfied, **no D6.5**.
- If D6.4 landed as point patches on Issues 1 and 2 only → **D6.5 is required** before the
  chain closes. Brief: "In `tools/agent-topology/worker_session.js` only: introduce a
  module-private `fail(err)` (settle-once, clearTimeout, best-effort group-SIGKILL per the
  existing timeout pattern, reject); route the timeout, `child` 'error', all three stream
  'error' handlers (attach via one loop), and the sync write/end catch through it; no
  export or behavior-contract change; done when fault-injection on each of the four
  failure paths shows reject + `process.kill(-pid, 0)` → ESRCH, regression set green,
  ≤300 lines." Sonnet — mechanical, design settled here. Non-author verification per R2.
- Either way, the sync-catch instance (L128-141) is a CONCRETE defect of Issue 1's class
  and MUST be closed; it is not a refactor nicety.

**Consequence if wrong:** if the consolidation was unnecessary, cost is one small Sonnet
dispatch plus a scoped check on a <150-line file. If patch-in-place had been blessed and
the structural read is right, the next defect ships as a live orphaned worker whose row is
deleted and cwd `rm -rf`'d underneath it — the exact promise `spawn_agent.js:18` makes to
A2 — after three verification rounds already spent on this class.

## R2 — RULED: no third full adversarial pass; scoped fault-injection close-out instead

The two ISSUES_FOUND verdicts were both CORRECT and each strictly smaller and adjacent to
the prior fix (host-crash → orphan-on-reject + missing sibling listener): the verifier
converged the search space to one file's failure paths. Healthy convergence — but what
remains is now enumerable, not open-ended: a child process has exactly three stdio pipes
and a fixed event set, and once R1's shape lands there is exactly ONE invariant with ONE
home. A third open-ended adversarial pass would re-search a space the record has already
collapsed. **Ruling: the close-out verification is a scoped, scripted check (non-author,
Sonnet):** (1) fault-inject 'error' on stdin, stdout, stderr, and force the sync-throw
path — assert reject AND process group dead (ESRCH) for each; (2) re-run the existing
regression evidence set (D6.1/D6.3's verify/leak/kill tests or committed equivalents);
(3) line caps + pre-commit. Ladder note: no Fable T1 fires — Opus never failed here (the
Opus verifier succeeded twice at its actual job); the repeated-same-tier pattern was
Sonnet fixes each leaving a same-shape defect, and per "escalate, don't retry" the correct
escalation was a fix-SHAPE change, which is this ruling — this dispatch is the escalation.
**Stop-the-line clause:** if the scoped check on the unified shape still finds a live
process on any reject path, the structural thesis is falsified — that is a fired trigger
(falsified working hypothesis), not a fourth patch; stop and escalate.

**Consequence if wrong:** an over-light close misses a defect — mitigated because R3's bar
names every remaining path explicitly rather than trusting a summary; an over-heavy close
would have cost one more Opus adversarial dispatch re-walking a closed space.

## R3 — CONDITIONAL close bar (D6.4 not landed at ruling time)

The D6 chain closes with NO further ratification round iff D6.4's landed state shows ALL:
1. All three stdio streams carry 'error' handlers; fault-injection on stdin-error,
   stdout-error, stderr-error, AND the sync write/end catch shows zero live processes
   (group ESRCH) at/by rejection, per path — claimed by the dispatch AND reproduced by the
   R2 close-out check, not report-only.
2. Kill+reject logic is single-sited per R1, OR the sync-catch path (847fe6f L128-141) is
   demonstrably covered — else D6.5 runs first (brief above) and the bar re-applies to it.
3. Regression set green; `worker_session.js` and `tools/spawn_agent.js` each ≤300 lines;
   `check-file-length.sh` + pre-commit pass.
4. Issues 3/4 documented as comments per D6.4's brief — comment-only, zero behavior change
   in that documentation.
5. Record hygiene closed: D6.3 and D6.4 get dispatch-table rows in `plans/agent-topology.md`
   (verified this ruling: `command grep -n "D6.3\|D6.4"` → 0 hits in plan + ratification
   docs; positive control `D6.2` → 1), and ADDENDUM 13 — found STAGED but never committed
   (`git diff --cached` = the full ADDENDUM 13 text; D6.2's code landed at `6b1e719`
   without it) — is committed. Two fix rounds and two verification verdicts currently
   exist only in commit messages and dispatch briefs; rulings live in the record.

**Issue 4 semantic — SIGNED OFF (design authority, closure item, not a re-litigation of
its already-judged non-blocking status):** fail-closed is CORRECT. The stdin payload
carries the minted token and the task; a child that provably did not consume it is not a
successfully spawned worker even on exit 0 — resolving would register an `active` row for
a session that never received its credentials or work. The semantic change stands ratified.

## Named, not acted on

- `scope` unbounded in `spawn_agent`'s schema (Issue 3; confirmed `spawn_agent.js:275` has
  `minLength` only vs `task`'s `maxLength: 10000` at L281) — future home: the next
  dispatch touching spawn_agent's schema, or the D13 preflight. Not this chain.
- `worker_preamble_overrides` — still deferred (ADDENDUM 12 G3b), unchanged.
- Stuck-`spawning` reaper — still with D13/sweep (ADDENDUM 13 item 6), unchanged.
- `child.once('error')` post-spawn (kill-failure) edge — subsumed by R1's unified shape;
  no separate action if R1 executes.
- ADDENDUM numbering: 13 is staged-uncommitted and 14 (this) is working-tree only while
  D6.4 holds the code lane; whoever commits next takes both in one docs commit.
