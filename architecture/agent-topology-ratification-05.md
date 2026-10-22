# agent-topology — ratification record, PART 5 (continues -04.md)

Split provenance: `agent-topology-ratification-04.md` measured 436 lines at ADDENDUM 15
time (`wc -l`, this dispatch); ADDENDUM 15 below would have pushed it over the 500-line
cap. Per ADR 0029 clause 3/4.1, carved into this new part rather than committing an
over-cap state.

---

# ADDENDUM 15 — D6 chain FINAL verdict: CLOSED. Narrow D6.5 fix accepted under R3 item
2's OR clause (R4), sync-path fault injection independently reproduced (R5), five-point
bar applied (R6) (2026-09-03)

Ratification authority dispatch (Fable), closing ADDENDUM 14's conditional bar. Ruled at
HEAD `dfebbf3` (`git log -1`, re-checked at dispatch start; working tree clean of `.js`
modifications). All load-bearing claims below cite a command run by THIS dispatch or a
file+line read directly at `dfebbf3` — no report's characterization is relied on where
the code or a rerun could be consulted instead. Docs only; nothing under
`tools/agent-topology/` is touched by this ADDENDUM or its commit.

## R4 — RULED: the narrow D6.5 fix SATISFIES R3 item 2; the fuller `fail()`
consolidation is NOT required to close the chain — it becomes a binding next-touch
obligation instead

R3 item 2's own ratified text reads: "Kill+reject logic is single-sited per R1, **OR the
sync-catch path (847fe6f L128-141) is demonstrably covered**." The OR clause was written
deliberately, and D6.5 lands squarely inside it: the sync catch now calls
`killChildGroup(child)` before settling (`worker_session.js:169-176`, read directly),
demonstrated under fault injection by D6.5's own 4-path regression AND independently
reproduced by this ruling (R5 below). A bar that names an escape clause is satisfied by
meeting it; re-litigating the fuller shape now would convert a ratified conditional into
a moving target.

That said, the substantive question — does the residual duplication itself risk a
"seventh" instance? — was examined on the code, not waved through:

**Complete settle-site enumeration at `dfebbf3`** (`cat -n
tools/agent-topology/worker_session.js`, 183 lines, all sites read):
1. Sync `spawn()` catch, L78-83 — plain reject, no kill, no settled/clearTimeout: CORRECT
   (spawn threw, `child` unassigned, no process exists; `timer` not yet created at L86).
2. Timeout, L86-93 — kills (`killChildGroup` L91). Correct.
3. `rejectFromStreamError`, L105-113 — kills (L109); shared by stdin (L145), stdout
   (L120), stderr (L121). Correct.
4. `child.once('error')`, L123-130 — settles, NO kill. See liveness analysis below.
5. Exit, L147-156 — child already dead, no kill needed. Correct.
6. Sync write/end catch, L158-177 — kills (L172, the D6.5 fix). Correct.

**The one remaining un-killed reject site (site 4) is provably not orphan-capable.**
Spawn options at L77 are exactly `{ cwd, detached: true, stdio: ['pipe', 'pipe',
'pipe'] }` — no `'ipc'` fd, no AbortSignal. Node emits `'error'` on a ChildProcess only
for: (a) spawn failure — no live process exists, nothing to kill; (b) kill failure —
reachable here only via `killChildGroup`, every caller of which sets `settled = true`
BEFORE calling it (L88/L107/L170), so site 4's guard (L124) exits without acting; (c)
IPC send failure — no IPC channel exists; (d) abort-signal failure — no signal passed.
No path reaches site 4 unsettled with a live child. This is precisely the per-path
liveness reasoning R1's `fail()` shape would have made unnecessary — it is still
required at exactly ONE site, it HOLDS, and it is now recorded here rather than living
only in a ruling's head (ADDENDUM 14's own sidebar flagged this soft edge).

**Risk class analysis.** R1's worry decomposes: missed-KILL defects (three found across
three rounds — D6.4 Issues 1/2 and the sync catch) versus missed-SETTLE boilerplate
(settled/clearTimeout/reject, now hand-repeated at 5 sites). Every defect actually found
in this chain was a missed kill; zero were missed settles — the settle boilerplate has
survived three adversarial rounds intact, and a missed settle fails LOUD (hung promise
or double-settle caught by the `settled` guard), unlike a missed kill which fails silent
(live orphan under a deleted row). The missed-kill class is now closed for the complete
enumerable path set: three stdio pipes + child 'error' + exit + timeout + the two sync
catches is the entire failure surface of this spawn configuration — nothing else in it
emits or throws. What remains is change-time risk only: a FUTURE edit adding a path
could forget the kill.

**Ruling.** (a) R3 item 2: SATISFIED by the OR clause — no further dispatch required;
the D6 chain does not wait on the consolidation. (b) **Binding next-touch obligation,
pinned:** the next dispatch that modifies `launchWorkerSession`'s failure paths — adds
one, reorders one, or touches any settle site — MUST adopt R1's `fail()` consolidation
(ADDENDUM 14 R1's brief, verbatim) as part of that dispatch, not add a hand-maintained
site. This is a brief-carry obligation in the ADDENDUM 13 D7-clearance pattern: the
fuller shape is a toll on the next entry to this file, not blocked work. D7 does not
touch `worker_session.js`, so it pays no toll.

**Consequence if wrong:** if the change-time risk materializes before any next touch,
the failure mode is the known one (orphan under rollback) and the standing obligation
plus this enumeration make it a one-dispatch fix; if the consolidation had been forced
now, cost would have been one more code dispatch plus a fourth verification round on a
file whose entire failure surface is already fault-injected green — re-walking a space
R2 already ruled collapsed.

## R5 — SPOT-CHECK: sync write-throw path independently reproduced at `dfebbf3`; D6.5's
evidence chain CORROBORATED, with a positive control proving the harness detects orphans

Path chosen: the sync write/end throw — the exact path D6.5 fixed, hence the most
load-bearing single check. Method (this dispatch's own harness, scratchpad only, real
module code): patched `child_process.spawn` in the require cache to substitute a real
detached group leader (`/bin/sh -c 'sleep 300 & wait'` — leader PLUS a grandchild),
sabotaged the first `child.stdin.write` to throw synchronously (`EFAULT`), then called
the REAL `require(...)/worker_session.js` at `dfebbf3`.

- **Fixed code (`dfebbf3`):** rejected with `spawn_agent: failed to write the preamble
  to the worker process` / `INTERNAL_ERROR` — the sync-catch's distinct message, proving
  WHICH path fired — and `process.kill(-pid, 0)` threw ESRCH on both the group and the
  leader (pid 83233). Clean rejection AND zero live processes: CONFIRMED.
- **Positive control (pre-fix `73b23a9` copy, same harness):** identical clean rejection
  — and the group survived (`kill -0` on -83237 succeeded; `ps` showed `sh` 83237 AND
  grandchild `sleep` 83238 alive, PGID 83237). This reproduces the verifier's exact
  finding (reject-but-orphan) and proves the harness can detect a live group — the
  DEAD result on the fixed code is a real measurement, not a harness blind spot.
  Control group killed and verified gone afterward.

## R6 — FIVE-POINT BAR APPLIED: **D6 CHAIN CLOSED**

1. **Fault-injection, zero live processes, all 4 paths — PASS.** Three independent
   evidence chains now: D6.4's stream-path injections (its commit message, verified by
   the non-author round that then found the sync gap), D6.5's own full 4-path re-run
   (all four reject cleanly, `ps`/`kill -0` dead, race-safety and ESRCH-tolerance
   confirmed), and this ruling's R5 reproduction of the sync path with positive
   control. Reproduced, not report-only — the bar's own requirement.
2. **Single-sited OR sync-catch demonstrably covered — PASS** via the OR clause (R4).
3. **Regressions green, line caps, gates — PASS**, gates re-run by THIS dispatch:
   `wc -l` → `worker_session.js` 183, `tools/spawn_agent.js` 298 (both ≤ 300);
   `tools/check-file-length.sh` → "0 file(s) over 300 lines"; `tools/check-invariants.sh
   --fast` → "8/8 OK (0 warn)". D6.5's broader regression list (rollback,
   compound-error, preamble-injection, deleteAgent idempotency, EPIPE at sizes, timeout
   group-kill reaping a real grandchild) is accepted on its report — internally
   consistent with the code as read, and its most failure-prone member (the sync path)
   is the one this ruling re-proved directly.
4. **Issues 3/4 comment-only, unchanged by D6.5 — PASS.** `git show --stat dfebbf3` →
   exactly one file, `worker_session.js`, +7/−1; the diff's only comment change is the
   sync-catch block itself. Issue 4's fail-closed note stands at
   `worker_session.js:141-144`; Issue 3's task-cap/defense-in-depth comment stands in
   `tools/spawn_agent.js` (L278-283, with the L119-126 enforcement it documents).
5. **Record hygiene — PASS, with the last item closed in this commit.** `9c97a5e`
   (ADDENDUMS 13+14) and `581a1fd` (D6.3/D6.4 plan rows) both on `wt/agent-topology`
   (`git branch --contains`, each). D6.5 itself had NO plan row (`command grep "D6.5"
   plans/agent-topology.md` → 0 hits; positive control `D6.4` → 1). Ruled: this is
   record hygiene squarely inside the ratifier's own docs lane, and ADDENDUM 13/14
   precedent is that consequent doc edits land in the ratification commit — so the D6.5
   row is ADDED IN THIS COMMIT rather than ruled a trailing item for a separate
   mechanical dispatch. It therefore neither blocks the verdict nor dangles after it.

**VERDICT: CLOSE. The D6 chain (D6 → D6.1 → D6.2 → D6.3 → D6.4 → D6.5) is closed.
D7 is clear to dispatch**, carrying ADDENDUM 13's three D7 brief-carry items unchanged
(G1's no-raw-SQL precedent verbatim; the D7 messages-write validation question; the A2 /
D10.3 awareness note). D7 touches no file governed by R4's next-touch obligation.

## Named, not acted on

- `fail()` consolidation — converted to the R4 next-touch obligation above; no dispatch
  now.
- D6.5's test environment stubbed `provisionWorkerSkill` because D11's `skills/` tree is
  not merged into this branch — pre-existing condition (the skill tree is D11's
  deliverable), not a new defect; the real-provision path is exercised when the branches
  meet, before the D1–D7 ship boundary's full acceptance gate.
- `scope` unbounded in `spawn_agent`'s schema — unchanged (ADDENDUM 14).
- `worker_preamble_overrides` — still deferred (ADDENDUM 12 G3b), unchanged.
- Stuck-`spawning` reaper — separately assigned, still open, explicitly NOT this
  ruling's concern (dispatch constraint), unchanged.
- `claude auth status` gate — unrelated, untouched (dispatch constraint).

---

# ADDENDUM 16 — D7 pre-dispatch stop: five never-ruled gaps (R1-R5) ruled; D7 stays
before D9; `messages.js` pinned into D7's scope (2026-09-03)

Ratification authority dispatch (Fable), fresh instance, ruling at HEAD `56f2fd9`
(`git rev-parse HEAD`; `git status` shows no `.js` modifications). D7 was dispatched
after ADDENDUM 15 and STOPPED correctly, code untouched, on gaps the record genuinely
never ruled. Every load-bearing claim below was re-verified by this dispatch's own
commands (`command grep` throughout — shell-wrapper lesson — each negative paired with a
positive control); D7's report was treated as allegation, not evidence, and every one of
its citations checked out exactly (schema.sql `messages` DDL; `registry.js:248-254`
exports; `bootstrap.js:144` `parent_id: null`; the 2-prose-hit `messages` grep vs. a
6-file `agents` positive control; ADDENDUM 11's "a D7-brief question" / ADDENDUM 12
clearance item (2) "not re-opened or resolved here" / plan D7 row "D7's brief decides
it" circle). Docs only; nothing under `tools/agent-topology/` is touched.

## R1 — RULED: new package-root module `messages.js`, built BY D7 (scope fold-in, no
new dispatch number)

Verified: zero code touches `messages` (grep above); §13 pins no messages primitive;
ADDENDUM 12 G1 forbids raw SQL against `agents`/`messages` from any tool module — so D7
as briefed was unimplementable. `registry.js` is pinned as "Pure row CRUD" over `agents`
(§13) and is agent-row-scoped by name and by every precedent; growing it cross-table
would blur the very capability-lane discipline Invariant 3 leans on. The record's own
split precedent (`bootstrap.js` out of `registry.js`, ADDENDUM 7; `worker_session.js`
out of `spawn_agent.js`, ADDENDUM 13 R1) already answers this shape of question:
separate concern, separate package-root module.

**Pinned (new §13 row, applied this commit): `messages.js` (D7), package root, exactly
three named exports, `db` first param per §13's convention, no own transactions (each
participates in the caller's — OQ5's one-transaction requirement, part 1 §9, is the
HANDLER's obligation via `db.transaction`):**
- `createMessage(db, { from_agent, to_agent, task_id, kind, body, hop_count? })` → row
  (mints `message_id` uuid + `created_at`; `read_at` NULL; `hop_count` defaults 0).
- `listMessages(db, toAgentId, filter?)` → rows addressed to `toAgentId` only,
  oldest-first; `filter`: `{ kind?, task_id?, unread_only? }` (F7 point 2's set).
- `markMessagesRead(db, toAgentId, messageIds)` → count; marks only rows whose
  `to_agent = toAgentId` — caller-scoping lives IN the primitive (capability-shaped,
  same discipline as `setWorkerStatus`'s worker lane), so a cross-agent read/mark is
  structurally unexpressible, not merely ungated.

**Owning dispatch: D7 itself.** D7 is the first consumer; a separate D7.0 adds a
rendezvous + independent verification for ~80 lines of CRUD, failing Rule 7's cost bar.
Precedent: D4 built `registry.js`, later dispatches consumed it — D9's `route_message`
consumes `createMessage` the same way. Consequence if wrong: the module is additive and
handler-independent; re-homing or re-owning it later breaks no shipped caller.

## R2 — RULED: `task_id` is a server-defaulted correlation label, NOT a minted
capability; D6's closed chain is NOT implicated

Verified: `agents` has no task column (schema.sql read in full); `spawn_agent`'s
ratified input is `{ auth_token, name, scope, tier, task, role? }` (`spawn_agent.js:189`)
— `task` is stdin text, no id minted, none persisted. NO pin anywhere assigns `task_id`
minting to anyone: F7 point 1 pins the column, the envelope `[SPEC]` shows a uuid, and
the trail ends there. So this is a record-level omission in F7, not a D6 execution
defect — D6 conformed to every pin it was given. **D6 stays closed; named only.**

**Ruling:** `task_id` is a correlation label, not an authority claim — OQ1's
self-assertion ban does not apply (asserting a `task_id` grants nothing; identity and
role are still seam-resolved from `auth_token`, and `from_agent` is still
server-resolved). In the pure star, one spawn = one task = one worker, so the worker
itself is the correlation key. Pinned: `report_result`/`escalate` accept OPTIONAL
`task_id?: string` (minLength 1, maxLength 256), defaulting server-side to the caller's
`agent_id`. A future multi-task router that mints real task ids passes them in the task
text and workers echo them back — `filter.task_id` stays meaningful, F7 point 2 intact.
Same-gap closure for D9 (prevents the identical stop): `route_message`'s ratified
`(to, kind, body)` signature carries no `task_id` either, so D9's handler mints a fresh
uuid per call — forward-looking scaffolding, exactly OQ7's hop-count posture. Plan D9
row amended accordingly. Consequence if wrong: `filter.task_id` degrades to
filter-by-sender in the star — harmless; re-pin when multi-task routing becomes real.

## R3 — RULED: NO envelope construction for `report_result`/`escalate`; direct
`createMessage` write; **D7 stays BEFORE D9 — the serial order does not change**

The cycle (§6 row 5 → ADDENDUM 11 "a D7-brief question" → ADDENDUM 12 item (2) → plan
D7 row "D7's brief decides it") is broken here, on the merits: for these two terminal
worker-exit writes, EVERY envelope field is server-derived or tool-fixed —
`from_agent` = seam-resolved caller; `to_agent` = the caller row's `parent_id`
(server-read, never caller-supplied — `spawn_agent.js:205` guarantees every worker has
one); `kind` = the tool's own constant (`result`/`escalate`); `hop_count` = 0;
`task_id` per R2. There is nothing caller-shaped left to validate: `validateEnvelope`
would be re-checking values the handler itself just derived from trusted sources. D9's
construct-then-validate obligation (ADDENDUM 11 R1) exists for `route_message`'s
GENERAL routing path — caller-directed `to`, caller-chosen `kind`, the hop machinery.
The real well-formedness guarantee for D7's writes is the `messages` DDL itself (five
NOT NULLs, the `kind` CHECK, both FKs — schema.sql, read directly) plus
`createMessage`'s fixed derivation. **Therefore D7 has no `envelope.js` dependency and
the ratified serial order (plan line 145: … D6 → D7 → D8 → D9 …) stands unchanged.**
Load-bearing corollary: the plan's ratified ship boundary "D1–D7 is a legitimate ship
boundary" (plan line 149) SURVIVES only under this ruling — moving D7 after D9 would
have silently destroyed it. Consequence if wrong: if a relay path ever needs worker
exits to carry real multi-hop envelopes, the fix is confined to two handlers swapping
`createMessage` args for `buildEnvelope` output — additive, not architectural.

## R4 — RULED: `report_result`/`escalate` are WORKER-ONLY; signatures pinned;
enforcement is a handler-level role check, not a seam change

The plan's "worker exits" phrasing governs; the brief's "any agent (worker or router)"
was drift, and the schema already votes: a router caller has `parent_id` NULL
(`bootstrap.js:144`) and `to_agent` is `NOT NULL REFERENCES agents(agent_id)` — no
valid addressee exists. A router escalates to the OWNER, outside the topology; there is
no agent above it to message. **Pinned input signatures (both tools, full field list):**
`{ auth_token (required, shared `authTokenShape` fragment — F7 pt 5), body (required
string, minLength 1, maxLength per R5), task_id? (optional string, 1..256 — R2) }`.
No `to`, no `kind`, no `hop_count`, no envelope — all server-side (R3). Each handler,
in ONE `db.transaction`: `createMessage(...)` + `setWorkerStatus(db, caller.agent_id,
'done'|'escalated')` (OQ5's one-transaction requirement, part 1 §9). **Enforcement:**
the handlers check `ctx.caller.role !== 'worker'` → `PERMISSION_DENIED`. Verified why
not the seam: `middleware.js:63-67` — the gate is a frozen `ROUTER_ONLY_TOOLS` list and
the module's own header declares any new wrapTool-surface property a pinned-surface
change (a stop-on-anomaly per §13); a handler check needs no pinned-surface deviation,
and the `to_agent` NOT NULL + the transaction are the structural backstop behind it.
`read_messages` stays any-agent, F7 point 2's signature verbatim, unchanged.

## R5 — RULED: `body` gets a LENGTH CAP (65,536 chars), NO content sanitization —
with the reason stated, not omitted

Cap: schema `maxLength: 65536` + the same in-handler double-check D6.3 established for
`task` (`spawn_agent.js:119-127` pattern). Why 64k not `task`'s 10k: a result/escalation
carries findings, not instructions — legitimately longer — while an unbounded TEXT
column in an already-named unbounded table (§10 TTL deferral) invites abuse the TTL
deferral can't absorb. Why NO control-character rejection, explicitly: `preamble.js`
rejects control chars (`preamble.js:69,93,124-128`) because its fields are INTERPOLATED
into a prompt template upstream of the token line — a newline there forges preamble
instructions. `body` never enters any prompt template: it lands in a DB column and
returns through `read_messages` as structured tool-result data. Multi-line bodies
(reports, code blocks) are the NORMAL case; rejecting control characters would break
legitimate use to defend a channel that does not exist. Named obligation on any FUTURE
consumer that interpolates a message `body` into another agent's prompt: sanitization
becomes THAT consumer's burden at the interpolation site, per the `task`-ordering
precedent (ADDENDUM 12 G3(a)) — recorded so the risk is owned, not forgotten.

## Consequent edits applied in this commit

1. Architecture part 1 §6 row 5: the "NOT ruled here — named, not acted on, ADDENDUM
   11" clause for D7's write path replaced in-cell with this ruling (R3). In-cell only
   — part 1 sits at 493/500 lines.
2. Architecture part 2 §13: new `messages.js` (D7) row pinning the three exports (R1).
3. Plan D7 row: brief-carry item (2) resolved in place (R3); scope gains `messages.js`;
   signatures + worker-only + body cap carried (R2/R4/R5).
4. Plan D9 row: `task_id` mint clause added (R2's same-gap closure).

## D7 re-clearance — the executable brief outline

**D7 is clear to re-dispatch** (Sonnet, non-author Sonnet verifier, unchanged). Build,
in order: (a) `messages.js` per the §13 pin (R1); (b) `tools/report_result.js` +
`tools/escalate.js` — worker-only handler role check, pinned 3-field signatures, one
transaction wrapping `createMessage` + `setWorkerStatus`, `body` cap 65,536 (R4/R5);
(c) `tools/read_messages.js` — F7 point 2 verbatim, via `listMessages` +
`markMessagesRead`. Still carried from ADDENDUM 12/15: G1's no-raw-SQL precedent
verbatim (a missing primitive is an additive-pin STOP); the A2/D10.3 awareness note.
No `envelope.js` import anywhere in D7 (R3) — its presence in D7 code is a
stop-on-anomaly. `claude auth status` gate: unrelated, untouched, unsoftened.

## Named, not acted on

- F7's `task_id` uuid example in the envelope `[SPEC]` reads as aspirational under R2
  (labels need not be uuids) — historical spec text left verbatim, not rewritten.
- `messages`-table TTL/cleanup — still deferred (§10), unchanged; R5's cap narrows but
  does not close the unbounded-growth note.
- Stuck-`spawning` reaper, `scope` unbounded, `worker_preamble_overrides` — all
  unchanged, not this ruling's concern.

---

# ADDENDUM 17 — D9's six self-flagged items (R1-R6) ruled: write-before-resume FINAL,
no `deleteMessage`; envelope flat shape pinned into §13; hop pass-through, verbatim
resume stdin, `last_pid` deferral, and the 296-line trim all ACCEPTED (2026-09-03)

Ratification authority dispatch (Fable), fresh instance, ruled at HEAD `2d81ee2`
(`git log --oneline -1`; branch `wt/agent-topology` confirmed via `git branch
--show-current`). Every load-bearing claim below cites a command run by THIS dispatch or
a file+line read directly at `2d81ee2`. `command grep` throughout, every negative paired
with a positive control (shell-wrapper lesson). Docs only; nothing under
`tools/agent-topology/` is touched. A separate independent verifier owns D9's other
claims (defect-class reproduction, write-ordering counters) — not re-verified here.

## R1 — RULED: write-before-resume is FINAL; NO `deleteMessage` primitive is added

**The clause D9 "failed" is a brief clause, not a record requirement.** `command grep -n
"orphan" plans/agent-topology.md architecture/agent-topology*.md` finds orphan language
only about processes and registry rows (plan D6.3/D6.4 rows, acceptance A2 at plan:159)
— zero hits pairing "orphan" with a message row (positive control: `command grep -c
"envelope" plans/agent-topology.md` → 4). No invariant is violated by the queued row:
Invariant 5 is satisfied (validated envelope before the write — route_message.js:255-271,
read directly), and OQ5's one-transaction requirement pairs a message write with a STATUS
write (part 1 §9; ADDENDUM 16 R4) — `route_message` changes no status, so its
single-`createMessage` transaction discharges it trivially.

**The ordering is forced by physics D9 read correctly:** `resumeSession` settles on the
child's `exit` (route_message.js:154-156), so a write-after-resume would land only after
the invocation it was meant to wake had already finished. Verified against the shipped
code, not the report.

**Rollback would be UNSAFE, not merely unnecessary — this is the decisive ground.** The
TIMEOUT failure path group-kills the child at 60s (route_message.js:137-139), but stdin
is written immediately after spawn (route_message.js:158-159): a "failed" resume can be
one whose target already received and acted on the message for up to a minute. Deleting
the row on that failure erases the only durable record of a possibly-delivered message,
leaving the target's session context holding content the `messages` table denies exists.
Write-ahead + at-least-once is strictly safer than a false exactly-once. The row is
exactly what F7 point 2 provides for: `read_messages` is non-destructive, rows retained,
`unread_only` filterable — the target picks it up on its next successful resume, and the
router (told the truth via the thrown error's `{message_id, message_written: true}`,
route_message.js:279) can retry or escalate with evidence. A router that retries writes a
second row: at-least-once duplication, visible and reconcilable via `task_id`/timestamps
— acceptable, and named.

**OQ5 paraphrase corrected, conclusion upheld:** OQ5's actual text
(agent-topology-ratification.md:109-118; part 1 §9 "OQ5 — RESOLVED") never says "the
`messages` table is the transport" — it rules a `read_messages` tool over the topology's
OWN table so `report_result` can write message + status in one transaction. D9's
paraphrase overstates OQ5; the load-bearing property ("the row is a durably queued,
readable unread message") stands on **F7 point 2**, which should have been the citation.

**`deleteAgent` precedent DISTINGUISHED, not followed:** ADDENDUM 12 G1 added
`deleteAgent` because a pinned acceptance criterion required rollback ("no orphan
registry row", A2, plan:159) and a half-created agent row is unusable state. No pinned
criterion requires message rollback (grep above), and an unread message row is
FUNCTIONAL state with a pinned read path. The precedent authorizes additive pins where
the record requires the capability; here the record does not.

**Consequence if wrong:** if at-least-once duplication ever proves harmful in practice,
the fix is additive and small — pin `deleteMessage(db, messageId)` → boolean into
`messages.js` (§13 amendment, G1's exact pattern) via a one-lane D9.1. Nothing shipped
breaks. Ruled against today because it trades a visible duplicate for a silent
false-history deletion under the timeout ambiguity above.

## R2 — RULED: pass-through (`hop_count` defaults 0, never incremented) is CORRECT

D9's precedent citations CHECK OUT verbatim: §13's `messages.js` row and ADDENDUM 16 R1
pin `createMessage`'s "`hop_count` defaults 0" (this file, lines 192-193), and ADDENDUM
16 R3 pins D7's writes at "`hop_count` = 0" (this file, line 239). **Semantics pinned
here so no future dispatch re-derives them: `hop_count` counts COMPLETED prior hops at
write time.** An origin write — D7's worker exits AND D9's router-originated
`route_message`, which accepts no inbound envelope (OQ7) — is 0. Increment-at-relay
becomes the obligation of whichever future dispatch adds an inbound-envelope relay path
(the spec's own deferred S5, build-spec line 138); it is NOT `buildEnvelope`'s job.
**Low-stakes now, and saying so:** with every production write at 0 and MAX_HOPS=3, the
hop gate cannot fire in production under either reading (OQ7's "cannot exceed 1" is an
upper bound; shipped maximum is 0, within it). The exact semantics matter only for the
multi-hop extension, which is why the one-line pin above exists.

## R3 — RULED: the flat-shape derivation is SOUND; shape now PINNED in §13

All three of D9's forcing constraints verified directly: (1) §13's `envelope.js` row
makes `body` an input to `buildEnvelope`; (2) plan D9 (plans/agent-topology.md:138) and
ADDENDUM 11 R1 run `validateEnvelope` on `buildEnvelope`'s result — one shape serves
both; (3) shipped `middleware.js:286` runs `hopGate(envelopeGate(args))` and
`hopGate` reads `envelope.hop_count` off the SAME object `envelopeGate` validated
(middleware.js:208-216) — a nested `{envelope:{...}, body}` supplied at the seam would
also fail `validateEnvelope`'s `body` check, so flat is forced there too. **§13's
`envelope.js` row is amended this commit to pin the shape as fact:** flat
`{ from, to, task_id, hop_count, kind, body }`, `Object.freeze`d. §4's nested `[SPEC]`
JSON stays verbatim as the historical wire sketch (ADDENDUM 16's
historical-text precedent); the §13 pin governs.

## R4 — RULED: VERBATIM resume stdin is CORRECT; no framing

G3a's `## Your task` framing (spawn_agent.js:241) solves a SEPARATION problem: first-spawn
stdin mixes the trusted preamble (including the auth-token line) with caller text, and
the ordering/framing keeps caller text downstream of trusted text. A resume stdin has no
such mix — the payload is 100% message body (route_message.js:276), nothing trusted to
separate. Adding fixed framing would CREATE a spoofable boundary (a body containing the
framing string forges a second message) where none exists. Provenance is structural, not
textual: `route_message` is in the frozen `ROUTER_ONLY_TOOLS` (middleware.js:67), so in
the pure star EVERY resume wake-up is, by construction, a routed message from the router.
The metadata verbatim delivery drops (`kind`, `task_id`, `message_id`) has a pinned
durable read path — F7 point 2's `read_messages`, which also collects any queued rows
from prior failed resumes (R1). **Consequent edit (this commit): plan D11's worker-skill
done condition gains clause (e):** the worker SKILL.md must state that a resume wake-up
IS a routed message and that structured metadata (kind/task_id, plus any queued unread
rows) is retrieved via `read_messages` with `unread_only`. **Consequence if wrong:**
framing is a one-line handler change plus a schema-description tweak — no pinned-surface
change (`stdinPayload` composition is not pinned) — addable later at trivial cost.

## R5 — RULED: `last_pid` deferral is FINE; nothing ships that reads it

Verified: `command grep -rn "last_pid" tools/agent-topology --include="*.js"` (excluding
node_modules) → exactly 3 hits: spawn_agent.js:255 (comment), spawn_agent.js:258 (writes
`null` at creation), route_message.js:217 (comment). No reader exists (positive control:
`session_id` in spawn_agent.js → 2 hits). D12's staleness mechanism uses
`last_active_at`, not pid (plan:142). Named for the future implementer: because both
`launchWorkerSession` and `resumeSession` settle on child EXIT, F7 point 3's "most
recent invocation's pid, `null` between invocations" can only be maintained by a
mid-invocation write PAIR (pid at spawn, null at exit) — a new write path with its own
crash-window failure mode. That cost belongs to the dispatch that first READS the field
(D12 if `check_status` wants pid-liveness; possibly never). Until then a permanent
`null` is indistinguishable from "between invocations" — F7's defined meaning — so no
current or future reader is misled by the deferral.

## R6 — RULED: the 296-line trim is LEGITIMATE; no split required

Read in full at `2d81ee2`. Header is 60 lines (`'use strict'` at route_message.js:61) —
MID-RANGE among shipped peers, not anomalously stripped: report_result.js:69,
escalate.js:71, spawn_agent.js:80, worker_session.js:38 (all via `command grep -n
"^'use strict'"`). Every load-bearing comment class survives: the `settle()` semantics
block (route_message.js:119-125), all four D6-chain defect-class citations
(D6.1/D6.3/D6.4/D6.5 at :86-88, :141-149, :162-163), redaction notes (:94-97, :110),
and the write-before-resume rationale (:35-47, :263-264). The densest constructs (the
one-line try/catch `killChildGroup`, :90-91) are byte-shaped copies of the VERIFIED
peer (worker_session.js:61-64) — house style, not cramping. **Fallback named so a
future touch never strips comments to stay under 300:** if `route_message.js` must
grow, the ruled split is `resumeSession` out to package-root `resume_session.js`
(ADDENDUM 13 R1's exact pattern), one pinned export
`resumeSession({ sessionId, cwd, stdinPayload })` → `Promise<void>`. Not needed today.

## Closure

R1-R6 require ZERO code changes: no D9.1 is dispatched. Following the D6-chain
precedent (ADDENDUM 15), the FINAL "D9 CLOSED" verdict issues only after the concurrent
independent verifier reports; on the six self-flagged items, D9's judgment is ratified
as shipped. `claude auth status` gate: unrelated, untouched, unsoftened.

## Named, not acted on

- At-least-once duplication on router retry after a failed resume (R1) — visible,
  reconcilable, accepted; `deleteMessage(db, messageId)` is the pre-named additive
  remedy if it ever bites.
- `hop_count` increment-at-relay — pinned as the future inbound-envelope dispatch's
  obligation (R2), not built.
- `last_pid` mid-invocation write pair — the reading dispatch's cost (R5).
- §4's nested envelope `[SPEC]` JSON — historical text left verbatim; §13's flat pin
  governs (R3).
