# 0054. Amendment to ADR 0023: wave-execution extensions for the delivery workflow (Graft 5 promoted, persona, lane, `step_complete`, DAG-frontier, caller `session_id`/`output_topic`, preflight rules 13-15)

- **Status:** accepted 2026-10-26 (owner ratified conditional on fix-verify; record: reviews/adr-0054-rung1.md)
- **Date:** 2026-10-26
- **Amends:** ADR 0023 (`decisions/0023-wave-execution-workflow-grafts.md`). ADR 0023's
  decisions D1-D4 stand unchanged except where this ADR names a change; D5 is partly promoted.
- **Context of:** the delivery workflow design v2 (§2.3 `wave-execution` EXTEND row; §7 items 2,
  3 and 9; `architecture/delivery-workflow/changelog.md` round-2 rows B1, line 180, and M17,
  line 199). The owner approved extending `wave-execution` in principle ("ADR 0023: YES, extend
  wave-execution (max_concurrent, persona, lane, gate_type step_complete, DAG-frontier mode);
  record an amendment to ADR 0023", owner decisions, 2026-10-26). The text of this amendment
  still needs ratification (design §7, owner wait (b)); the `wave-execution` EXTEND (§7 item 9)
  may not merge before it.
- **Citation key:** "design §N" = design v2, `architecture/delivery-workflow/part-02..06-*.md`
  (§2 part-02, §3-4 part-03, §5 part-04, §7 part-06). "`INTERFACES.md` part C" = the draft
  `architecture/delivery-workflow/interfaces/part-c-waves-control.md`, assembled into
  `INTERFACES.md` by W0 item 2. Line numbers in ADR 0023, `architecture/wave-execution.md`,
  `skills/wave-execution/SKILL.md` and its `references/spec-format.md` are at agent-hq `c1ba30e`.

## Context

`delivery-run` (design §2.2 card 6) runs one sub-task's units at full width (D20, up to 30
agents) on top of `wave-execution`. Today's skill cannot carry that load:

- Waves are strict barriers, so a unit waits for every unit of the previous wave, not only for
  its own blockers. ADR 0023 rejected barrier-free waves but named the opt-in path: per-`work_item`
  `depends_on` edges with real cancellation semantics (0023 lines 153-157).
- An N-item wave fans out unbounded; `max_concurrent` was deferred as Tier B (0023 lines 141-144).
- `SESSION_ID` is minted per invocation and a resumed run starts a brand-new bus session
  (0023 lines 92-110; `SKILL.md` step 3), so a caller cannot name the one canonical topic that
  its agents and its fallback files point at. Round-2 panel finding B1 (completion signal) is
  closed only if `session_id = <run-id>-<subtask>` is pinned by the caller and stable across
  resume, with one literal topic `<run-id>-<subtask>-rendezvous` (design §5.0).
- The dispatch plan's unit table (scope globs, blocked-by, persona, lane, budget, done token,
  verifier) has no field to map onto (M17); the mapping lives in `INTERFACES.md` (§7 item 2).

## Decision

Every new field is optional, and a bundle that declares none of them validates and runs exactly
as today (ADR 0023's behavior-preserving rule, 0023 lines 184-187). Text citing "owner
2026-10-26, Q<n>" records the owner's answer to that question (Owner decisions below). A
**barrier wave** is a wave whose work_items declare no `depends_on` edges: it runs as today,
and the next wave starts only after its wave gate passes; a wave with edges is a frontier wave
(A5).

**A0 — Where the new values live.** `session_id`, `output_topic` and `bus_endpoint` (A9) are bundle-level spec fields,
declared beside `dispatch_budget`, so they are inside `spec_root` and covered by its content hash
(the checkpoint key). `max_concurrent` is an invocation argument, not a spec field (owner 2026-10-26, Q9):
it carries the caller's free slot count, which changes between invocations, and outside
`spec_root` it never changes the hash, so a resume still finds its checkpoint. `persona`, `lane`
and `depends_on` are per-`work_item` spec fields (owner 2026-10-26, Q10 for `persona` and
`lane`), as is the done-condition field (A4; owner 2026-10-26, Q2).

**A1 — Graft 5 promoted: `max_concurrent`.** Moves from Tier B to built. Integer >= 1, validated
inline (0023 lines 143-144); absent = unbounded (today). It applies to every wave of the
invocation (A0), not as the per-wave field 0023 D5 sketched (lines 141-142). The controller never
has more than `max_concurrent` agents live at once, and gate and fix agents count toward it
beside work_item agents (owner 2026-10-26, Q3); a gate or fix agent with no free slot waits for
one. So `max_concurrent` = the caller's free slots enforces D4's 30-agent ceiling without
further caller arithmetic (owner decisions D4; design §2.2 card 6, "Stop: spawn without slot").
`spec_ref` nesting
and preflight rule 12 stay deferred.

**A2 — `persona` (per-`work_item`, owner 2026-10-26, Q10).** A non-empty token naming the persona brief the
dispatched agent runs under (design §3.2-3.3; briefs are `references/briefs/<persona>.md` in the
owning skill, which design part-06 item 27b does not yet name). Passed verbatim in the brief, never interpreted; it does not override the `agents`
field's model tier. Absent = today's dispatch brief.

**A3 — `lane` (per-`work_item`, owner 2026-10-26, Q10).** A token naming an exclusive-writer resource lane
(design §4 rule 6). Within one run, at most one work_item per lane is live at a time; the others
wait. Leasing the lane's real resources (ports, browsers, devices) stays the caller's job through
the catalog; `wave-execution` only serializes by lane name. Absent = no lane constraint.

**A4 — `gate_type: step_complete`.** A fourth enum value next to `exit_criteria`,
`adversarial_verify`, `judge_panel`. One gate agent per work_item walks that work_item's done
condition plus the wave's `exit_criteria`, both verbatim as the rubric. The done condition is
one optional per-`work_item` field holding it verbatim (in `delivery-run`: the unit's done token
and verifier command, `INTERFACES.md` part C, C1.2), required under `step_complete` and checked
by rule 9 (owner 2026-10-26, Q2); its name is per `INTERFACES.md` part C, C1.2.
This amends the rubric invariant ("never replaced, reworded, or supplemented", `spec-format.md`
lines 58-59; `SKILL.md` step 6.4, lines 95-97) for `step_complete` only: the done condition sits
beside `exit_criteria`, and neither is reworded. Rule 9's `gate_agents` for `step_complete` is
`work_items_count` in a barrier wave and 1 per work_item in a frontier wave (A5). The verdict
payload `{agent_id, verdict: pass | fail, rationale}` is unchanged. A barrier wave with
`gate_type: step_complete` passes only when every work_item's gate agent returns pass, as A5's
frontier rule (owner 2026-10-26, Q11); unlike `judge_panel`'s majority (0023 lines 69-71;
`wave-execution.md` lines 179-181), each verdict judges a different work_item's done condition.
Which output each gate agent reads is not an owner question and is not decided here
(`INTERFACES.md` part C, C1.2). Every work_item must state a verifiable done condition; rule 9
checks it (A8).

**A5 — DAG-frontier mode (`depends_on`, per-`work_item`).** A wave in which any work_item
declares `depends_on: [<work_item>, ...]` runs in DAG-frontier mode; a wave without edges runs as
today. Declared waves stay barriers to each other; frontiers are computed inside one wave
(owner 2026-10-26, Q4). Such a wave enumerates its work_items, since edges cannot name items generated at
runtime (`spec-format.md` line 36).
- **Release:** a work_item is dispatched when every blocker's gate has passed, its lane (A3) is
  free, and fewer than `max_concurrent` agents are live, gate and fix agents included (A1).
  Units with no edges start at once.
- **Gate (owner 2026-10-26, Q5):** each work_item is gated on its own completion with the wave's
  `gate_type`, the wave's `exit_criteria` read against that work_item's output only, so a
  criterion over the wave's collective output is not checked inside a frontier wave (a caller
  that needs one puts it in a following barrier wave). The wave gate passes when every
  work_item's gate has passed. The checkpoint records per-work_item gate passes.
- **Fix loop and escalation (owner 2026-10-26, Q5):** `fix_loop_cap` applies per work_item in a frontier
  wave (per wave in a barrier wave, as today). On exhaustion the controller posts
  `{SESSION_ID}-escalation` with `{ halt_reason: "fix-loop-cap-exhausted", wave: N, work_item:
  <id>, iterations: <cap> }` and never releases that work_item's transitive dependents; the
  others run on to their own gate pass or escalation. Once no work_item is live or releasable,
  the controller writes the checkpoint, runs step 8 and stops; a later invocation resumes at
  the unpassed work_items.
- **Cancellation:** a dependent is released only after every blocker's gate passes, and no
  passed gate is reopened within an invocation, so a failed or escalated work_item never has a
  live dependent; non-release is the cancellation. This is how A5 meets 0023's "real
  cancellation / invalidation-on-gate-failure" condition (lines 155-157); the design's "`TaskStop`
  of dependents on gate failure" (part-02 line 84) has no case inside `wave-execution`.
  Invalidation from outside the run (`INVALIDATE`, `INTERFACES.md` part C, C6) is the caller's.
- **Dispatch budget (owner 2026-10-26, Q5):** rule 11's term for a frontier wave is
  `work_items_count x (1 + (fix_loop_cap + 1) x g)`, `g` = gate agents per work_item (1 for
  `exit_criteria` and `step_complete`, else `skeptics` or `judges`). Barrier waves keep the 0023
  formula with rule 9's mapping (`step_complete` = `work_items_count`, A4).
- **Scope against the design (owner 2026-10-26, Q4):** rule 15's same-wave restriction is stricter than design
  §2.3 ("every edge names a `work_item`", part-02 line 84). Design §4 (part-03 line 80, "Waves
  1..N are DAG frontiers") can be read as each numbered wave being a frontier; this ADR reads it
  as frontiers inside one wave, declared waves staying barriers to each other. `INTERFACES.md`
  part C, C1 builds its one-frontier-wave layout on that reading.
- This takes up ADR 0023's opt-in `depends_on` path; the rejection of a global barrier-free flag
  (0023 lines 153-157) stands, and its collective-gate rationale holds for barrier waves.

**A6 — caller-pinned `session_id` (bundle-level).** When declared, it replaces the minted
`wave-exec-<date>-<uuid>` and is the same value on every invocation, including resume, so every
`{SESSION_ID}-*` topic is stable. This reverses 0023 D3's "brand-new bus session" rule for pinned
runs only; an unpinned run still mints a fresh `SESSION_ID` per invocation.
- **Resume authority (owner 2026-10-26, Q6):** the checkpoint is the only authority for passed
  work_items; a completion post for a work_item it does not record is re-gated, never taken as
  passed. Gate verdicts and escalations of an earlier invocation never count (A7).
- **Bootstrap** (when `bus_endpoint` is absent, A9): step 4 that finds
  `swarm-mcp-<session_id>` left by a crashed invocation recovers it with `pm2 restart` (never a
  second `pm2 start`, never `reload`), then runs the identity preflight as today; a leftover
  `DATA_DIR` without its app is reused by `pm2 start`.
- **Checkpoint key:** `session_id` is in the `spec_root` content (A0), so two bundles that
  differ only in `session_id` hash differently and keep two checkpoints.

**A7 — bundle-level literal `output_topic`.** One literal topic for the whole spec (completions
and gate verdicts of every wave). It overrides the per-wave `output_topic`; a differing per-wave
value is `VALIDATION_FAILED` (rule 14; owner 2026-10-26, Q8). With no bundle-level value declared, the
per-wave `output_topic` works as today, including the documented `{SESSION_ID}-wave-{N}-output`
(`spec-format.md` line 46; `SKILL.md` Topic Naming, line 208). `{SESSION_ID}-fix-loop-output` and
`{SESSION_ID}-escalation` are unchanged.
- **Discriminator:** the controller gives every agent it dispatches a `from_agent` id and
  records its role (work_item, gate or fix), wave and work_item. Each id carries a nonce minted
  per invocation, so no id is ever reissued under one pinned `session_id`, even when the rest of
  the id is deterministic (for example `<work_item>-gate`). A post counts only when its
  `from_agent` (the bus send field, `skills/swarm-communication/SKILL.md` step 4) was assigned in
  this invocation; the role says whether it is a completion for that work_item (checked against
  its `output_schema`) or a gate verdict. Posts of other waves, work_items or earlier invocations
  never match; the checkpoint stays the authority for what has passed (A6).
- **Fallback file (owner 2026-10-26, Q7):** `wave-execution` never reads `status/<agent-id>.verdict`
  (design §5.0). The caller reads it and posts its record under that agent's id once the bus is
  reachable again (`INTERFACES.md` part C, C4). If the dispatch returns with no post first, that
  is a gate failure, and the fix loop's existing stalled-dispatch exception (`SKILL.md` lines
  199-202) lets the fix agent verify ground truth and post the completion.

**A8 — preflight rules 13-15.** Numbered after the deferred rule 12. They run after rules 9-10
and before rule 11, which stays the last check executed (it needs the A5 mode of each wave).
13. `session_id`, when declared, matches `^[a-z0-9-]+$`; as a bundle field it is in the
    `spec_root` content the checkpoint key hashes (A0, A6).
14. A bundle-level `output_topic` is a literal: no `{SESSION_ID}` or other placeholder. When one
    is declared, no per-wave value differs from it (owner 2026-10-26, Q8). With none declared, per-wave
    values are checked as today, `{SESSION_ID}-wave-{N}-output` included.
15. `depends_on` is acyclic, every edge names a work_item declared in the same wave (owner
    2026-10-26, Q4), and a wave that declares edges enumerates its work_items (A5).
Rule 9 also gains `step_complete` in its enum and its `gate_agents` mapping (A4), and checks
that every work_item of a `step_complete` wave declares its done-condition field (owner
2026-10-26, Q2). `persona` and `lane` are validated inline, as
0023 did for `max_concurrent`; `max_concurrent` is validated where it is passed.

**A9 — caller-owned bus: `bus_endpoint` (bundle-level; owner 2026-10-26).** The owner answered
open item 1: "Q2 YES: add an optional bus_endpoint to wave-execution; caller-owned bus attach and
skip-teardown (ratify with 0054)" (owner decisions, INTERFACES owner questions; that list's Q2
is this ADR's Q1). Optional. When
set, `wave-execution` attaches to the caller-owned bus it names and skips its own bootstrap
(step 4) and teardown (step 8); the bus lifecycle stays the caller's. When absent, behaviour is
unchanged from today. The value's form and the `bus.endpoint` file's content are per
`INTERFACES.md` (part C, C1.1 and C5.1), not decided here. No new preflight rule.
Consequences of attach under today's skill text:
- **Identity preflight** (§ Bus Rules, `SKILL.md` lines 136-142) still runs before the first
  dispatch; `APP_NAME`/`DATA_DIR`, which step 4 sets today (lines 59-61), are the values read
  from the endpoint, and the port is still read only from `$DATA_DIR/port`. Which endpoint keys
  map to them is per `INTERFACES.md`.
- **Step 5** still runs: `start_session` is idempotent (`SKILL.md` lines 75-78) and follows the
  preflight.
- **Step 8** still posts the final result but does not run `cleanup()`, which is defined in step 4
  and holds `end_session`, `pm2 delete` and the `DATA_DIR` removal; session close and teardown
  are the caller's (owner line above). Who recovers an attached bus is per `INTERFACES.md`, not
  decided here.

## What changes in `architecture/wave-execution.md`

- Lines 9-14 (banner): add an ADR 0054 line. The banner and § Proposed capabilities (lines
  154-164) say Tier A is "not yet implemented"; `SKILL.md` and `spec-format.md` at `c1ba30e`
  already carry `gate_type`, `output_schema`, `dispatch_budget`, rules 9-11 and Resume /
  Checkpoint. Item 9 records Tier A's real state there; this ADR does not decide it.
- Lines 60-63 (spec contract summary): the A0-A9 fields, the invocation argument, rules 13-15.
- Lines 67-72 (one PM2 instance per run): unless `bus_endpoint` attaches a caller-owned bus (A9).
- Line 72 and the topic table (lines 74-79): pinned `SESSION_ID` (A6); bundle `output_topic` (A7).
- Lines 94-101 (constraints): a pinned resume reuses `SESSION_ID`; concurrent runs stay
  uncoordinated; `fix_loop_cap` is per work_item in frontier waves (A5).
- Lines 166-176 (field table): `max_concurrent` loses *(deferred)* and becomes an invocation
  argument (A0) that counts gate and fix agents (A1); rows for `persona`, `lane`, `depends_on`,
  the done-condition field, bundle `session_id`, `output_topic` and `bus_endpoint`; `gate_type`
  gains `step_complete`.
- Lines 178-187: the `step_complete` rubric exception and all-must-pass barrier verdict (A4);
  the barrier-wave definition; the frontier release, gate, fix,
  escalation and non-release rules (A5); the discriminator (A7).
- Lines 189-208 (rules 9-12): rule 9 (A4, A8), rule 11's frontier term (A5), rules 13-15.
- Lines 210-228 (resume): the pinned-`session_id` exception (A6), per-work_item entries (A5).
- Lines 230-236 (priority): `max_concurrent` moves to built; `spec_ref` stays Tier B.
- Lines 242-244 (rejected list): opt-in `depends_on` is now built (A5); the global flag stays out.

## What changes in `skills/wave-execution` (W1 item 9, a separate reviewed branch)

- `SKILL.md` step 3 (lines 53-57): use the pinned `session_id` when declared, else mint as today.
- Steps 4 and 8 (lines 59-73, 123-129): step 4 and step 8's `cleanup()` skipped when
  `bus_endpoint` is set, the skill attaching to the caller-owned bus (A9); unchanged when it is
  absent, plus step 4's pinned-name recovery (A6). Step 5 (lines 75-78): runs on the attached bus.
- § Bus Rules (lines 131-151): under attach, the identity preflight compares against the endpoint
  values (A9); who recovers an attached bus is per `INTERFACES.md`, not decided here.
- Step 6 (lines 80-113): `max_concurrent` (counting gate and fix agents, A1), `lane`,
  `persona`, `from_agent` ids; the frontier
  release loop; rendezvous on the bundle topic with the A7 discriminator; the `step_complete`
  gate and its rubric exception (lines 95-97).
- Step 7 (lines 115-121): per-work_item fix loop, `work_item` in the escalation payload,
  non-release of dependents, the frontier halt rule (A5).
- § Resume / Checkpoint (lines 153-177), § Topic Naming (lines 204-211), § Exit criteria
  (lines 236-273): matching edits; one new Red flags row ("a blocker passed, so release its
  dependents before their lane is free").
- `references/spec-format.md`: `work_items` (line 36), optional fields (lines 41-46, including
  `fix_loop_cap` at line 45), gate fields (from line 48, including the rubric sentence at lines
  58-59), rules (lines 94-136) per A0-A8. `references/example-spec/`: a frontier wave with tests.

## What does not change

The bus model; the one-PM2-per-run idiom when `bus_endpoint` is absent (A9); the identity
preflight check (its comparison values come from the endpoint under attach, A9); `pm2 restart` as the only recovery verb when `bus_endpoint` is absent (under attach, recovery
is per `INTERFACES.md`, A9); explicit `session_id` on every call; port read
only from `$DATA_DIR/port`; Prohibited Side Channels; the bus post as the sole completion signal;
the checkpoint location; the three existing gate types and their verbatim, never-supplemented
rubric; `output_schema`, `dispatch_budget` and rules 1-11 for barrier waves, except rule 9's
`step_complete` additions; `fix_loop_cap` default 3; `spec_ref` and rule 12 (deferred); the
loop-system disambiguation; ADR 0023's other rejected items; the global rules. Two gate
invariants do change: the `step_complete` rubric adds the done condition (A4), and a frontier
wave's gate is per work_item, not over the collective output (A5). `delivery-run`'s ledger, slot
rows, `bus.endpoint` and the fallback file are caller concerns (design, `INTERFACES.md`).

## Consequences

- Easier: `delivery-run` maps the unit table onto `waves/` without hand-rolled barriers (M17);
  one canonical topic survives resume (B1); width is bounded by free slots, not unbounded fan-out.
- Harder / accepted: 7 more fields, 1 invocation argument and 3 more rules; frontier waves dispatch
  one gate agent per work_item, which rule 11 now counts; a pinned resume re-gates unrecorded
  posts; collective criteria move to a barrier wave.
- Revisit if: the pilot (P1a) shows per-work_item gates cost more than they catch, or a
  cross-wave edge is needed (rule 15 forbids it today).

## Owner decisions (owner 2026-10-26; `owner-decisions.md`, ADR 0054 questions)

Numbered within this ADR (`INTERFACES.md` numbers its own). Each answer is the Recommended
answer in `architecture/delivery-workflow/reviews/adr-0054-rung1.md`.

1. **Q1** — caller-owned bus (`INTERFACES.md` part C, its Q2): yes, now A9.
2. **Q2** — yes: one optional per-work_item done-condition field, required under
   `step_complete` and checked by rule 9 (A4, A8).
3. **Q3** — gate and fix agents count toward `max_concurrent` (A1, A5).
4. **Q4** — yes: `depends_on` edges stay inside one wave; declared waves stay barriers (A5,
   rule 15).
5. **Q5** — yes: per-work_item gate, fix loop and budget term in a frontier wave (A5).
6. **Q6** — yes: the checkpoint is the sole resume authority; unrecorded posts are re-gated (A6).
7. **Q7** — yes: the caller consumes the fallback file (A7).
8. **Q8** — yes: a differing per-wave `output_topic` is `VALIDATION_FAILED` (rule 14).
9. **Q9** — yes: `max_concurrent` is an invocation argument (A0, A1).
10. **Q10** — yes: `persona` and `lane` are per work_item (A2, A3).
11. **Q11** — yes: a barrier-wave `step_complete` gate passes only when every gate passes (A4).

## Alternatives considered

- **Leave `wave-execution` alone and build barrier-free dispatch inside `delivery-run`** —
  superseded by the owner's ADR 0023 YES (changelog M8).
- **Global barrier-free flag** — still rejected (0023 lines 153-157); edges are per-work_item.
- **Keep minting `SESSION_ID` and pass the topic through a side file** — rejected: it breaks
  resume and adds a channel that Prohibited Side Channels forbids (B1).

**Links:** ADR 0023; `architecture/wave-execution.md`; `skills/wave-execution/SKILL.md` and
`references/spec-format.md`; design v2 (landing page `architecture/delivery-workflow.md`, parts
`architecture/delivery-workflow/part-02..06-*.md`; card 6 at part-02 line 60, §2.3 at line 84);
`architecture/delivery-workflow/changelog.md`; `architecture/delivery-workflow/interfaces/`.
