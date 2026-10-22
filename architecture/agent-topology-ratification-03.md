# agent-topology — T6 ratification record, PART 3 (addenda continuation)

Part 1: `architecture/agent-topology-ratification.md` (verdict, OQ rulings, T2 addendum,
Addendum 3). Part 2: `architecture/agent-topology-ratification-02.md` (Addenda 4–8).
Part 2 reached 459/500 lines at Addendum 8; later addenda continue here (split, not
butchered — same convention as the earlier splits).

---

# ADDENDUM 9 — D4.2 verification returned ISSUES_FOUND: gate ruling (G1), the ~110s worst case (G2), non-disclosure confirmed (G3) (2026-09-03)

Context: ADDENDUM 8 gated D5 on "D4.2's independent verification returns CLEAN." The
verdict is ISSUES_FOUND — characterized by the verifier as process/documentation only,
with concurrency and correctness independently reproduced sound within the §14 contract
(34 runs at 6/12/20 processes, zero failures; retry bounded at exactly 11 attempts then a
clean `makeError`; token redaction holds; `patchAgent` byte-identical). Those results and
the four issue items are treated as the VERIFIER'S CLAIMS relayed by the coordinator;
what this ratifier re-verified directly before ruling: pragma order and its true line
numbers (db.js:125-127 at `baff0ec` — `busy_timeout` → `journal_mode` → `foreign_keys`;
the verifier's citation "117-119" is off by 8, order claim confirmed, line numbers not),
the six-export surface (db.js:156-163), the false-comment triple (db.js:58-63 vs
bootstrap.js:74), the retry arithmetic (sleep sum 15×(1+…+10) = 825ms, matching the
verifier's 55.8s nominal), and the plan's gate text (plans/agent-topology.md:23-24). At
ruling time D4.3 had NOT yet landed (`git log -1` → `92a3a16`; `git status` clean).

## G1 — RULED: D5 WAITS. It dispatches after D4.3 lands AND is non-author-verified — stated explicitly, both halves.

**The wait is lane discipline, not issue severity.** Stated plainly so the two reasons
cannot be conflated later:

- **Substantively, nothing in the ISSUES list blocks D5.** All four items are
  documentation-truth or process findings; none touches a surface D5 consumes — the
  export set D5 imports against is the one ADDENDUM 8 already ratified into §13, the
  behavior D5 builds on was independently reproduced sound, and item 1's pin breach was
  ratified post-hoc BEFORE the verdict arrived. Had D4.3 not been in flight, this
  ratifier would have opened the gate on this verdict as-is.
- **Operationally, D5 must still wait, twice over.** (i) D4.3 is actively mutating
  db.js/bootstrap.js — D5's two dependency files — in the SAME worktree; dispatching D5
  against a moving base in a shared serial lane violates the build's own structure.
  (ii) The build's unbroken precedent gates every dependent dispatch on its
  predecessor's non-author verification (ADDENDUM 3: D3 after D2.1 verified; ADDENDUM 4:
  D3 after D2.1 non-author-verified; ADDENDUM 5: D4 after D3 CLEAN; the plan's D1.1
  gate: "D4 lands+verifies → D1.1 → D5"). D4.3 gets the same treatment — a cheap,
  fix-verifier-class check, so the asymmetry favors waiting.
- **If D4.3 stops** (its brief correctly makes stopping a sanctioned outcome given the
  hard stop on export surfaces), the stop routes back to ratification and D5 still does
  not jump the queue.

The plan's ADDENDUM 8 GATE bullet is rewritten accordingly (consequent edit below): the
"D4.2 … CLEAN" condition, which as written could never open on this verdict, is replaced
by the two-step condition actually ruled here.

**Consequence if wrong:** waiting costs one small verification cycle on a tiny fix
dispatch; opening early risks D5 authored against files that shift under it mid-dispatch
in the same worktree — rework and merge noise at minimum, a middleware built on
unverified churn at worst. Asymmetric; wait.

## G2 — RULED: documenting is SUFFICIENT. No lower bound, no retuned timeout, no fail-fast — and the reason is §14 itself.

The measurement (verifier's claim, arithmetic re-checked here): real-lock exhaustion at
`openDb` took ~109.9s against a nominal 11×5000ms + 825ms ≈ 55.8s, because each
`journal_mode=WAL` attempt blocked 8.5–12.7s — beyond the configured 5000ms per-statement
budget (a single pragma can make multiple internal lock acquisitions, each drawing its
own busy_timeout budget; named as the plausible mechanism, not asserted as verified).

**Why no tuning ruling:** the path requires something to HOLD a write lock against server
first-open. Under §14 that is out of contract (concurrent bootstrap) or an anomaly (a
wedged writer) — and §14 clause 5's whole point is that retry behavior is not tuned
defect-by-defect for scenarios outside the stated model. The observed behavior is exactly
what was ruled: bounded, terminating, a clean shaped error, no hang. A fail-fast or lower
bound tuned now would be calibrated against a harness-manufactured scenario — the precise
accretion pattern R2 stopped — and risks flaking legitimate slow first-opens (port-target
disk, preflight) that ARE in contract.

**What documentation must carry (consequent edits below):** the empirical figure goes
where operators and porters will actually look — (a) §14 clause 5 gains one sentence
(~110s bounded worst case, tolerated not tuned); (b) D4.3's brief already records it at
the code seam; (c) the port-relevant reading is named: a port-time preflight or startup
that blocks ~2 minutes before erroring is THIS bounded path, not the known
`claude -p` hang class — the two must not be conflated in a port-day diagnosis. If the
ported environment shows startup lock contention in PRACTICE, that is §14 clause 6
firing (the model's assumptions failing there) and returns to ratification as a design
question, never as timeout tuning.

**Consequence if wrong:** worst case under this ruling is a wedged-DB startup wasting ~2
bounded minutes before a clean error — an annoyance, fully recoverable. The inverse
error (tuning for the unsupported path) reopens retry churn and can break in-contract
slow opens. Asymmetric; document only.

## G3 — RULED: ADDENDUM 8 STANDS UNAMENDED; the harsher R3 branch is now FACT; one mechanical guard is added so the next undisclosed surface change cannot rely on verifier thoroughness.

- **The post-hoc ratification stands.** It was made on substantive merits (real de-dup,
  cycle-free seam, containment clause) explicitly WITHOUT assuming disclosure — ADDENDUM
  8 pre-stated both branches and ruled "unchanged either way." The verifier resolves the
  branch: the commit framed `requireDb` as mechanical de-dup and never named
  `isRetryableBusy`/`sleepSync` as new exports at all. The criticism does NOT soften;
  this is a confirmed second pinned-surface breach in the same lane (D4's Invariant-3
  build-through was the first), one dispatch after the calibration line was written.
- **The containment clause stands as written** ("no further db.js export without a
  stop") — nothing in the confirmation changes its text.
- **New mechanical guard (consequent edit below), because two breaches in one lane is a
  pattern, not luck:** the plan's standing clauses gain an export-surface diff duty —
  EVERY verifier diffs each touched module's `module.exports` against its §13 row; any
  delta not pre-authorized in the record is ISSUES_FOUND on its own, regardless of
  merit. D4.2's verifier caught this one by thoroughness; the guard makes catching it
  mandatory rather than fortunate.
- **D4.3's narrowed brief is RATIFIED.** ADDENDUM 8 pre-authorized two fix forms for the
  false comment: (a) correct the comment, or (b) export the constants and amend §13. The
  coordinator's D4.3 brief forbids (b) outright (hard stop on any export/signature/schema
  change). That narrowing is ratified as the RIGHT call and (b) is WITHDRAWN: a
  pinned-surface change executed inside the recovery from an undisclosed pinned-surface
  change is exactly the move R3's calibration line exists to prevent. Form (a) is now
  the only authorized form.

**Consequence if wrong:** if the export-diff duty proves noisy (false ISSUES on
pre-authorized deltas), the cost is a verifier citing the record row that authorizes the
delta — one line of evidence, not a stop. If this guard is NOT added and a third
undisclosed surface change slips through, §13 stops being a pin at all.

## D5 brief — one ADDITIONAL line beyond ADDENDUM 8's

- D5's verifier performs the G3 export-surface diff on every file D5 touches
  (`middleware.js` §13 row: `wrapTool` only) and on its imports' surfaces as consumed —
  any unpinned export D5 ADDS or DEPENDS ON is ISSUES_FOUND by itself.

Everything ADDENDUM 8 required D5's brief to carry stands unchanged.

## Consequent edits applied by this addendum

1. Plan, ADDENDUM 8 GATE bullet: gate condition rewritten to G1's two-step form (D4.2
   ISSUES ruled non-blocking for D5; D5 dispatches after D4.3 lands + non-author-verifies).
2. Plan, standing clauses: the G3 export-surface diff duty, all future dispatches.
3. Part 2 §14 clause 5: one sentence recording the ~110s bounded empirical worst case
   (G2), tolerated not tuned, with the port-day don't-conflate note.
4. Ratification part 2 gains a tail pointer to this file (mirroring part 1's).

## Named, not acted on

- The verifier's line-number drift (pragmas cited at 117-119; actually 125-127 at
  `baff0ec`) — order claim verified true; the drift is named for the verifier's own
  calibration, cost nothing here.
- D4.3 remains in flight; nothing in this addendum pre-judges its outcome. Its landing
  + non-author verification is now the LAST gate before D5.
- STILL TRUE, unsoftened: `claude auth status` → `{"loggedIn": false}`; D6 onward stays
  gated on the empirically unverified `claude -p --resume` mechanism (part 1 §6 risk
  record).

---

# ADDENDUM 10 — the instrument gap: every concurrency figure is repo-unreproducible (H1 commit-the-bench, H2 provenance hedge, H3 instrument clause) (2026-09-03)

D4.3 landed at `ee88950` (comments-only — re-verified here: 0 non-comment changed lines
across the diff, control 68 total +/- lines; export surfaces untouched) and surfaced
that NO concurrency harness exists anywhere: this ratifier's own sweep confirms the
negative independently — 0 harness/stress/bench files in `tools/agent-topology` (control:
db.js `require` count 10), 0 `child_process` hits outside node_modules,
`git log --all --name-only` shows no agent-topology concurrency harness on any branch
(control: `registry.js` appears 7 times; every harness hit is other projects), and
the sibling tests worktree holds only `acceptance/ fixtures/ helpers/`. So D4.1's 17/48,
D4.2's 30-run claim, the verifier's 34-run/109.9s/8.5–12.7s figures, and D4.3's own 36/36
all came from ad hoc, never-committed scripts. The figures now recorded in db.js,
bootstrap.js, and §14 clause 5 are RELAYED SINGLE-SOURCE MEASUREMENTS with no in-repo
instrument — including one this ratifier wrote into §14 ("The 6-process tests are
retained as hardening regression tests"), which presupposed an instrument that does not
exist. **That sentence was this ratifier's own defect: it ratified retention of tests
nobody had ever committed.** Owned and corrected below.

## H1 — RULED: the instrument IS committed — as a bench, in the tests lane, framed by §14; and it is a RECONSTRUCTION, not a validation

- **Why commit:** §14 clause 5 already commits the record to these tests existing; the
  workspace's archive-raw lesson is exactly this failure (a bespoke instrument discarded,
  its conclusions later uncheckable — and here a defective figure could sit in three
  places with nothing to re-measure it). Without an instrument there is no regression
  baseline if the contention hardening ever breaks, and no answer to a future reader who
  doubts a number.
- **The legitimization worry is answered by framing, not by omission:** the harness
  header MUST carry §14's line — concurrent bootstrap is OUT OF CONTRACT; this bench
  measures the HARDENING's bounded behavior under an out-of-contract scenario; a pass
  asserts bounded, clean, single-router outcomes, never mode support. Leaving the
  instrument uncommitted does not un-legitimize the mode; it only makes the recorded
  claims unfalsifiable — the worse outcome.
- **Where and what:** `tools/agent-topology/test/bench/` (inside the portable unit, P1 —
  so the port-time preflight can re-measure on the target; cap-exempt as a test dir),
  authored in `wt/agent-topology-tests` (that lane's mandate; disjoint files, Rule 7
  safe). NOT part of the A1–A7 acceptance gate — separately invoked. Assertions limited
  to BOUNDED-BEHAVIOR properties (no raw error escapes; `activeRouterRows=1`; attempts
  ≤ bound); timings are PRINTED as measurements, never asserted (D4.3's 36/36-clean
  runs show this environment no longer even exhibits BUSY — timing assertions would
  flake or silently vacuously pass).
- **Ownership: folded into D10.2**, which already exists in the record and already
  carries ADDENDUM 8's "6-process harness relabeling" named item — this is that item,
  now concrete. No new dispatch number.
- **Stated plainly:** a reconstructed bench re-measures GOING FORWARD. It does not and
  cannot retroactively validate the recorded figures — those keep their provenance class
  (H2) forever.

**Consequence if wrong:** if committing it tempts someone to treat multi-process
bootstrap as supported, the header framing plus §14 is the defense, and misuse is
visible in review; if it stays uncommitted and the hardening regresses, the regression
is invisible until a port-day incident — invisible failure is the worse branch.

## H2 — RULED: G2's substance STANDS and is STRENGTHENED; the figure's RECORDING gains a mandatory provenance hedge

Documenting remains sufficient, a fortiori: a figure that cannot be reproduced is the
last thing to TUNE against — retuning timeouts on an unreproducible single-source
number would be accretion on hearsay. But recording it as bare fact is no longer
acceptable: §14 clause 5 is amended (consequent edit below) to carry the evidence
class — single-run, single-verifier, relayed, produced by an uncommitted ad hoc
instrument, environment-specific, not reproducible from the repo today, re-measurable
once D10.2's bench lands. **Code comments need NO re-edit:** db.js's and bootstrap.js's
figure passages cite §14 clause 5 and ADDENDUM 9 G2 (verified in the `ee88950` diff),
so the hedge propagates by citation; a re-edit for a disclaimer alone would be churn.
Pre-authorized, not dispatched: the next dispatch that touches either file for its own
reasons may append "(single-source relayed measurement — see §14 clause 5)" where the
figures appear. Owner: that future touch, whichever lane makes it.

**Consequence if wrong:** if the hedge is too weak and someone later treats ~110s as a
calibrated constant, the §14 provenance line is the audit trail showing it never was
one; if too strong, the cost is a reader double-checking a number that happens to be
right — trivially cheap.

## H3 — RULED: yes, a standing clause, scoped to THIS build; hq-wide promotion NAMED, not acted on

Three occurrences in one lane of a failure the workspace has already paid to learn
(archive-raw lesson) is a pattern. The plan's standing clauses gain (consequent edit
below): **any dispatch or verification whose done condition, verdict, or recorded
figure rests on a measurement must commit the instrument that produced it — in its
lane's tree or the plan's evidence dir — in the same commit/report; a figure whose
instrument is not committed is recorded as a CLAIM with its provenance class, never as
settled fact.** Promotion beyond this build (STANDARDS/ADR or a compound lesson) is an
owner-scope question — NAMED for the orchestrator to route, deliberately not folded in
(no ADR number is allocated from here).

**Consequence if wrong:** if the clause proves heavy for trivial measurements, the cost
is committing small scripts that would otherwise be discarded — near-zero; without it,
the fourth unreproducible figure enters the record the same way the first three did.

## D5 gate — CONFIRMED EXPLICITLY

**D5's gate opens when D4.3's in-flight verification returns CLEAN** — or ISSUES ruled
non-blocking by ratification, the ADDENDUM 9 G1 pattern. Nothing in H1–H3 adds a gate:
the bench is tests-lane work, parallel by the plan's own Rule 7 assessment, and does
NOT gate D5. If D4.3's verifier flags the figure passages for provenance, the H2 ruling
above IS the disposition (record-side hedge, no code re-edit) — pre-answered so it need
not bounce back here.

## Process note, for the calibration record

D4.3 stopped mid-dispatch when HEAD moved rather than waive its own stop condition —
even though the moving commit validated its work — and self-caught its 10-attempt/50–56s
arithmetic error against the ratified 11-attempt/55.8s figures. Both are exactly the
R3 calibration line holding under temptation. Noted so the lesson's positive case is on
the record alongside its violations.

## Consequent edits applied by this addendum

1. Part 2 §14 clause 5: the false "are retained" sentence replaced (tests exist only
   once D10.2 lands them) + the provenance class of every recorded figure stated.
2. Plan: standing clause "Instrument-with-measurement" (H3); D10.2 scope extension
   bullet (H1: the bench, its location, its framing).

## Named, not acted on

- hq-wide promotion of the instrument clause (H3) — owner/orchestrator scope.
- The original failing scenario (pre-fix SQLITE_BUSY at the WAL switch) is now
  UNDEMONSTRABLE — the fix is in place and this environment showed 36/36 clean; the
  bench guards the hardening's bounded behavior, not the historical defect.
- STILL TRUE, unsoftened: `claude auth status` → `{"loggedIn": false}`; D6 onward
  stays gated on the empirically unverified `claude -p --resume` mechanism.

---

# ADDENDUM 11 — D5 verifier finding on the envelope gate: opt-in-by-presence RULED
CORRECT; §6 row 5 was the defect, not the code (2026-09-03, fresh ratifier instance,
dispatched on Sonnet — Fable/Opus unavailable, `status.claude.com` "Elevated errors for
multiple models" incident naming Fable 5/5.1 and Opus 5/4.8/4.6, fix in progress)

Continuity note: read fresh — architecture parts 1/2, all ten prior addenda, the plan, and
`tools/agent-topology/middleware.js` at `32b232834d92068ac3c0a26871829a694ca1c8f6` (`git log
-1`; `git status` clean) — before ruling. `claude auth status` re-checked: still
`{"loggedIn": false}`; unrelated, untouched.

D5's independent verifier found, verbatim: a caller can omit `args.envelope` on a call and
the envelope/hop gates never fire (`sawEnvelope:false`); D5's author flagged this as a
judgment call, resolving the tension between §6 row 5's "before any message-bearing
handler" and OQ7's `route_message(to, kind, body)` signature (no inbound envelope) by
gating on presence rather than an invented tool list.

## R1 — RULED: opt-in-by-presence is CORRECT; §6 row 5's text, not the gate, was wrong

**Verified directly, not restated from the brief:** `middleware.js:184-199` (`envelopeGate`)
returns `null` — no validation attempt — when `args` lacks an `envelope` key, and this is
called uniformly for every wrapped tool via `hopGate(envelopeGate(args))` at
`middleware.js:286`, with no per-tool-name branch. `middleware.js:164-178`'s own comment
already states the OQ7 reasoning D5's author gave. Architecture §4 OQ7 (RATIFIED, this
file's ancestor `agent-topology.md` §4/§9): `route_message` takes `(to, kind, body)` with
**no inbound envelope**; §13 (architecture-02) pins `envelope.js`'s exports as
`buildEnvelope({from, to, task_id, kind, body, hop_count?}) → envelope` and
`validateEnvelope(obj)` — construction is a named, separate step from validation, owned by
D9, not by the seam.

**Where would an envelope be built for `route_message`?** Inside D9's `route_message`
handler, which `wrapTool` calls only AFTER the four gates run (`middleware.js:271-292`:
`assertWrappable` → returned `wrappedHandler` runs `identityGate` → `roleGate` →
`hopGate(envelopeGate(args))` → `handler(args, {db, caller})`). The seam therefore runs
**before** any envelope exists for this call — it is not that D5 chose to skip validating
it, it is that there is nothing to validate yet. Rejecting envelope-less calls at the seam,
per §6 row 5's literal text, would make `route_message` uncallable in production, exactly
as D5's author reasoned.

**Ruled out, and why — a fixed message-bearing-tool list (§6 row 5's alternative literal
reading):** this is not just impractical, it is actively the wrong shape. If the seam
instead REQUIRED `route_message` callers to supply a pre-built `envelope` object
(containing `from`), that reopens the exact vulnerability OQ1 closed: a caller asserting
its OWN identity in a payload field, rather than the seam resolving it from the
unforgeable `auth_token` (architecture §5, "identity is never self-asserted"). The
`from` field of every real envelope MUST be server-resolved from `ctx.caller.agent_id`,
never caller-supplied — which is only possible if envelope construction happens inside the
handler, downstream of `identityGate`, not upstream of it at the seam.

**Ruled out — constructing the envelope AT the seam:** would require `wrapTool` (pinned
arity-1, single export, §13) to become tool-shape-aware (know `route_message` takes
`to`/`kind`/`body` specifically, mint a `task_id`), which is a scope and signature change
to the one pinned seam function — itself a stop-on-anomaly under §13's "deviation is a
stop-on-anomaly, not an implementer's choice," not a fix to freelance into this ruling.

**Ruling: opt-in-by-presence stands, unchanged in code.** The seam is defense-in-depth for
any future call that DOES carry an inbound envelope (OQ7's named forward-looking
scaffolding, and the A4 synthetic hop-limit test); the real, structural guarantee that
`route_message` never writes an unvalidated message is D9's handler obligation — see the
consequent plan edit below. **The defect was §6 row 5's prose**, not `middleware.js`.

**Consequence if this ruling is wrong** (i.e., seam-level enforcement is genuinely
required): the fix is D9-scoped either way — either D9's handler is found NOT to call
`buildEnvelope`/`validateEnvelope` before its `messages` write (a D9 defect, caught by the
done-condition check added below, not a middleware defect), or the design itself needs a
second MCP surface / signature change for `route_message` to accept a trusted envelope
(a ratification-level design change, not a doc fix) — named, not invented here.

## R2 — RULED: does NOT block D6. D9-only (and this doc-consistency fix)

**Evidence D6 has no coupling:** architecture §3's module table assigns `spawn_agent` +
`preamble.js` + `provision.js` to D6, writing only to the `agents` table via
`registry.js`'s `createAgent` (registry primitives, ADDENDUM 7) and to the filesystem
(`$DATA_DIR/workers/<agent_id>/`, F7 point 4) — no `messages`-table write anywhere in D6's
scope. The `messages` DDL (F7 point 1) is D2-owned; only `route_message` (D9) and
`report_result`/`escalate` (D7) write to it per the OQ5 ruling. Branch (iii)'s
session-persistent mechanism (`--session-id` at first spawn, `--resume` at
route-to-existing, part 1 §6) is process/session bookkeeping only — it neither reads nor
writes an envelope. Checked directly against `git show HEAD:plans/agent-topology.md`
(pre-this-addendum): `command grep -n '^| D6'` isolates D6's row, and
`command grep -c 'envelope'` on that isolated line → **0 hits** — D6's row carried no
envelope text to begin with (positive control: the same grep on the whole file →
**4 hits**, in the S5 build-order label and the D5/D7/D9 rows, confirming the grep pattern
itself works and D6's zero is not a tooling artifact).

**Ruling: R2 = No.** D9 is the only dispatch this finding touches; D6 is clear to proceed
on this finding alone (D6's separate, unrelated `claude auth status` gate is unaffected
either way — untouched here, per the brief's explicit instruction).

**Consequence if wrong:** if D6's implementer discovers spawn_agent's own bookkeeping
does touch a message/envelope concept not visible in the current record, that is a NEW
pin contradiction under ADDENDUM 7's calibration ("a pin contradiction is ALWAYS a stop,
even when your resolution looks obviously right") — it stops and returns to
ratification; this ruling does not pre-authorize working around such a discovery.

## R3 — consequent edits applied

1. **Architecture §6 row 5** (`architecture/agent-topology.md`): reworded from
   "`envelope.js` validate, called from `middleware.js` before any message-bearing
   handler" (which the shipped seam cannot literally do — see R1) to state the two-part
   reconciled model: seam validates only when `args` already carries an envelope; D9's
   `route_message` handler is the real enforcement point. D7's `report_result`/`escalate`
   write path is explicitly named, NOT ruled here (D7 is dispatched before D9 in the
   serial order and has no stated dependency on `envelope.js`; extending this ruling to D7
   would be new scope, not R1-R3).
2. **Plan D9 row** (`plans/agent-topology.md`): done condition gains an explicit clause —
   `route_message`'s handler must call `buildEnvelope` (server-resolved `from`) then
   `validateEnvelope` before the single-transaction `messages` write, with a check that no
   code path reaches that write without both calls. This is the checkable form of R1's
   ruling; D9's non-author verifier enforces it the same way every other done-condition
   clause is enforced.
3. **`middleware.js` itself: NOT edited** — DOCS ONLY per this dispatch's constraints, and
   R1 found no code defect to fix. The shipped gate and its inline comment
   (`middleware.js:164-178`) already state the correct reasoning; only the architecture
   doc's summary table cell was out of sync with what was actually built.

## Named, not acted on

- **D7's `report_result`/`escalate` envelope-construction path** — not ruled here. If the
  same "construct before write" obligation applies there, that is a D7-brief question for
  whoever dispatches D7, informed by this addendum's R1 reasoning, not a retroactive
  extension of R1's scope from this ratifier.
- STILL TRUE, unsoftened: `claude auth status` → `{"loggedIn": false}`; D6 onward stays
  gated on the empirically unverified `claude -p --resume` mechanism — unchanged,
  untouched by this addendum, per the dispatch brief's explicit instruction.

## D6 clearance

**D6 is clear to dispatch, design-wise, on this finding.** R2 found zero coupling between
D5's envelope-gate finding and D6's scope. D6's separate, pre-existing gate — `claude auth
status` returning `{"loggedIn": false}` on this machine, empirically unverified
`-p --resume` mechanism (architecture part 1 §6 risk record) — is UNCHANGED and UNRELATED;
this addendum does not touch it, does not soften it, and does not re-assert it as
resolved.

---

**Continued in `agent-topology-ratification-04.md`** (2026-09-03, doc-cap split — this
file was already at 405 lines; ADDENDUM 12, ruling on D6's four self-reported gaps
(G1–G4), would have pushed it well over the 500-line cap): ADDENDUM 12 rules on the
rollback-delete raw-SQL finding (G1), the un-built `provision.js` (G2), the `task`/
`worker_preamble_overrides` spec gap (G3), and A2's stale pre-D5 calling convention (G4),
assigns dispatch D6.1 and D10.3, and clears D7 to dispatch.
