---
name: panel-consultation
description: >
  Real 9-agent review panel with RACI attribution for bigger docs and doc-bearing PRs: nine
  independent Sonnet seats read the artifact blind, Accountable seats close each finding topic,
  a synthesizer compiles the findings table, then a different agent fixes and another runs
  fix-verifier, looping until a full round reads 0 Blocking / 0 Medium — all under one Opus
  orchestrator sub-agent, no swarm bus. MODE=reconcile instead merges two diverged versions of
  one artifact: the same nine seats classify every delta, a fixer writes only the merge target.
  Use when asked to 'consult the panel', 'panel consultation', 'review this design/plan/spec/skill',
  to review a PR whose changes are bigger docs, or to reconcile two diverged versions. This is
  Rung 2 on the review ladder (tools/review-ladder.md) and supersedes
  review-7-panel (Rung 2b). For a PR with small doc changes use doc-reviewer (Rung 1). For code
  changes use pr-review (Rung 3). For a one-way-door or high-blast-radius decision escalate to
  panel-review (Rung 4).
---

Labels: **owner** = the owner's quoted words (the only standing rules, Rule 9); **fact** =
measured, cited; **(default)** = this skill's choice, the owner may change it; **question** =
open owner item. A sentence that is neither a quote with its source nor a cited fact is a
default. What rests on a default or question: `## Defaults and open questions`.

## Trigger

A review mechanism, not a thinking tool: nine separate agent instances read the artifact blind,
a synthesizer compiles a RACI table, a different agent fixes, another verifies, to the owner's bar.

Artifacts in scope (default, from the owner's routing words of 2026-10-28):

- bigger docs: architecture and design records, plans and dispatch plans, specs, ADR drafts,
  skills (SKILL.md plus references), standards; a single file or a companion set;
- doc-bearing PRs: a PR whose diff is prose or markdown of that kind (any repo the caller names; default, Q12);
  the panel reads the changed files at the PR head in full, plus the diff.

Not in scope:

- code diffs: `pr-review` (Rung 3; hq Rule 10 for hq executable code);
- small doc changes: `doc-reviewer` (Rung 1). Owner, Q-SMALL (2026-10-28, chat): "And for the
  question about small doc to bigger one b" = option 2, by size; the coordinator's statement (not
  owner words; default): roughly 50 changed lines or fewer across one or two files;
- one-way-door decisions: `panel-review` (Rung 4);
- thinking before any artifact exists: `superpowers:brainstorming` or a direct Rung 0 look.

A PR that mixes executable code with bigger docs gets one rung per artifact (ADR 0022 item 4,
`hq:decisions/0022-operating-model-cost-efficiency-audit.md:172-174@c057d0cf`): `pr-review` on the
code, this skill on the docs (default, Q7).

Ladder placement (default): Rung 2, keeping the number. Rung 2b (`review-7-panel`) is superseded
by this skill and kept as a stub until the owner decides (Q1). The frontmatter names one rung
up and one down per `tools/review-ladder.md:65-72@28e7e358`.

## Inputs

Caller inputs, in the dispatch prompt; the skill does not prompt for missing ones:

| Input | Meaning |
|---|---|
| `MODE` | `review` (default; unchanged behaviour, every row below) or `reconcile` (new: `## Reconcile mode`) |
| `ARTIFACT_PATHS` | one or more absolute paths inside a worktree, never on a default branch (global Rule 6) |
| `REPO` + `PR_NUMBER`, or `REPO_DIR` + `BASE_REF` + `HEAD_REF` | the PR forms, instead of `ARTIFACT_PATHS` |
| `KIND` | design, plan, spec, skill or pr-docs; selects the fitted-surface examples; `pr-docs` adds the diff, PR title and commits to every brief; changes no seat, row, tier or bar |
| `RECORD_DIR` | absolute, outside the reviewed tree; default the caller's scratchpad `panel-consultation/<artifact-slug>/` |
| `OWNER_DECISIONS` | binding quotes, each with date and channel |
| `HISTORY` | prior records; goes to the orchestrator and the synthesizer only, never to a seat |
| `BAR` | default 0 Blocking / 0 Medium (`MODE=review` only; reconcile's own bar is in `## Reconcile mode`) |
| `SOURCES` | paths seats may read, including any decisions or live docs the caller names (seats re-measure, they do not recall) |
| `PUSH` | `REPO`+`PR_NUMBER` form only, `yes` or `no`, default `no` |
| `VERSION_A_PATH`, `VERSION_B_PATH` | `MODE=reconcile` only; already-materialised plain files, both read-only — nothing in this process ever writes to either. When the two versions live on git refs, not disk, the caller (not this skill) materialises them first, e.g. `git show <refA>:<path> > <scratch-path>`, into a scratch location outside any worktree (default); this skill performs no checkout of its own |
| `COMMON_ANCESTOR_PATH` | `MODE=reconcile` only; optional; a shared git ancestor, same materialisation rule as above, enabling a real 3-way diff |
| `MERGE_TARGET_PATH` | `MODE=reconcile` only; where the Fixer writes the reconciled result. Need not pre-exist (the Fixer creates it fresh) and is not required to sit inside a worktree — but MUST NOT resolve to the same file as `VERSION_A_PATH` or `VERSION_B_PATH` (checked at Prepare, `## Reconcile mode`) (default) |

`ARTIFACT_PATHS` does not apply under `MODE=reconcile` (default); the four rows above replace it.
`BAR`, `PUSH` and the PR forms are `MODE=review` only.

`HEAD_SHA` is the one name for "head" everywhere (briefs, `git show`, `git diff`, pre-round C7,
the fix-verifier `diff`): the orchestrator worktree's HEAD after the latest fix commit, in every
input form and `PUSH` mode. Pushing never redefines it. PR forms: `gh repo clone <REPO>` into the
orchestrator's scratchpad (or the caller's `REPO_DIR`); the worktree is added on the PR head
branch; a fork head, or a branch already checked out elsewhere, is stop-and-report; the worktree
is removed at hand-back (default; literal full path) after the records are written.

| Input form | What seats read | Where a fix lands | Commit / push |
|---|---|---|---|
| `ARTIFACT_PATHS` | the files as committed at `HEAD_SHA` | the same files, same worktree | one fixer commit per fix point; this skill never pushes |
| PR (`REPO`+`PR_NUMBER`, or `REPO_DIR`+refs) | the changed doc files materialised with `git show HEAD_SHA:<path>` into `RECORD_DIR/materialised/r<N>/<repo-relative path>`, plus `git diff <base>...HEAD_SHA`; never the working tree; re-materialised each round (design-specified; the read-through-git-only rule is the one in `skills/pr-review/SKILL.md:92-105@28e7e358`) | `<repo>-worktrees/pc-<slug>` on the PR head branch | one commit per fix point; pushed only per `PUSH` (Steps, step 12) |
| `MODE=reconcile` | `VERSION_A_PATH`, `VERSION_B_PATH`, `COMMON_ANCESTOR_PATH` (if given) as given, read-only | `MERGE_TARGET_PATH` only, written fresh | the Fixer writes the file directly, no git commit; this skill never pushes in this mode; `PUSH` does not apply |

## Roles and model pins (Rules 3 and 4)

| Role | Count / round | Model (source) |
|---|---|---|
| Orchestrator | 1 per artifact (sub-agent, owner S9) | Opus (owner 06:27:40Z) |
| Pre-round checker | per the timing rule in Steps | Haiku (default; trial default of `references/preround-check.md`) |
| Seats | 9 (Full) or 3-9 (Focused) | Sonnet (owner 06:27:40Z) |
| A-close agents | 0-9, one per topic that the close rule sends to A-close | Sonnet (owner R-ck) |
| Synthesizer | 1 | Sonnet (owner R-ck) |
| Fixer | 1 per fix point | Opus (default); Fable once ADR 0014 T1 fires for the artifact |
| Fix-verifier | 1 per `a`/`b`/`l`/`m` fix commit | Sonnet (owner R-ck) |
| Low pass + verifier | 1 + 1 after the bar | Sonnet, Sonnet (default) |

`MODE=reconcile` variant of the Fixer row above (same role, same model pin): writes the merged
content to `MERGE_TARGET_PATH` only, never to `VERSION_A_PATH` or `VERSION_B_PATH`; the existing
`fix-verifier` skill then confirms the merge against the verdict, unchanged (`references/reconcile-brief.md` section 7).

Owner words behind the pins and the loop (verbatim): 06:27:40Z, "The panel review can be
orchestrated by opus but the work can be done by Sonnet"; S9, 2026-10-24 14:13:43Z, "Spawn a sub
agent to be the orchestrator so that it handles all of the context coming in"; R-ck, 2026-10-12
(`hq:tools/brain/templates/router-CLAUDE.md:72-73@c057d0cf`): "Continue foward with the review no
blocking or medium issues and run sonnet for the review gates".

Dispatch counts and concurrency: `references/scaling.md` section 7. Seats, matrix and checks:
`references/seats-raci.md`; brief templates: `references/briefs.md`.

## Steps (orchestrator runbook)

This is the `MODE=review` runbook (default, unchanged by this pass). `MODE=reconcile` reuses the
same roles and the same per-dispatch discipline below, with a classification brief instead of a
defect-hunt brief and a verdict instead of a bar — its own runbook is `## Reconcile mode`.

Run in order each round. Every dispatch pins its model (Rule 3), carries the common block of
`references/briefs.md`, and states a done condition and a stop clause.

1. **Prepare.** Confirm (default) the artifact is committed and clean in a worktree on a non-default branch (PR forms: build
   the clone and worktree per Inputs). Create `RECORD_DIR`, start the ledger, set `HEAD_SHA`.
2. **Choose the tier.** Measure the ledger inputs and write them with the tier (Full or Focused,
   `references/scaling.md`). Round 1 is always Full. (default, Q6)
3. **Pre-round check.** One fresh Haiku checker (`references/preround-check.md`) before every seat
   round and after every fix commit. On FAIL: a fresh
   fixer with only the FAIL lines, one re-run; FAILs still open go to the synthesizer as data,
   never to seats. (default, Q10: prose checklist, not a script)
4. **Fit the surfaces.** Write each seat's 2-4 line risk surface in the ledger before dispatch
   (`references/seats-raci.md` section 3); re-fit to the residual finding class in later rounds,
   the matrix never changes. Add the reading rules that bind the loop.
5. **Phase 1.** Dispatch the nine seats (nine by default, Q13; no bus, default, Q9; Focused: the core trio plus R and A seats of in-scope
   topics) in ONE message using the seat brief. Seats are Sonnet. A seat reads no peer record and
   no prior findings. In a Focused round write the `NOT-REVIEWED` ledger lines first.
6. **Screen and validate each record** as it lands (record-identity grep; shape per
   `references/severity-and-records.md` section 5). No FINDING/PASS/SKIPPED line for the R topic,
   or more than one kind, is malformed; no record or an API error is a transport failure.
   Re-dispatch once, fresh, one tier up; a second failure writes `UNRESOLVED | <topic> | r<N> |
   malformed` or `transport`, and the round cannot meet the bar. A block is never re-dispatched.
7. **Topic files and A-close.** Per in-scope topic extract R's lines and every C-NOTE into the
   topic file. A topic with a FINDING or a `risk-seen` C-NOTE gets a fresh Sonnet A-close; any
   other topic with an R PASS line gets the orchestrator's `CLOSED ... PASS` line (seats-raci.md
   section 2). Screen each topic file.
8. **Synthesize.** One fresh Sonnet synthesizer reads every topic file, the ledger lines, the
   pre-round record and `HISTORY`, and writes the table and line 1. Screen its record.
9. **Bar check.** A Full round (default, Q6) at 0 Blocking / 0 Medium with no UNRESOLVED topic meets the bar
   (go to step 13). A Focused round never does (line 1 `FOCUSED`); the next tier follows
   `references/scaling.md`. Otherwise the bar is not met.
10. **Fix, verify, cap (bar not met).** Fixer `a`, pre-round `post-a<k>`, fix-verifier at
    iteration 1. ISSUES_FOUND: fresh fixer `b`, pre-round `post-b<k>`, fix-verifier at iteration
    2. CLEAN: next round. A second ISSUES_FOUND is the fix-cycle cap (Loop). With no Blocking or
    Medium to fix (Focused round at 0/0, or only an UNRESOLVED topic open), no fixer runs.
11. **Scope check after every fix commit:** `git diff --name-only <pre-fix sha>..<HEAD_SHA>` in
    the worktree must name only `ARTIFACT_PATHS` (PR forms: the materialised paths); any other
    path is stop-the-line before a verifier is dispatched. Run the record-identity grep on `git
    show <fix sha>`; a flagged commit is reverted with `git revert`.
12. **Push (`REPO`+`PR_NUMBER` form, `PUSH=yes`).** After each CLEAN verdict and at hand-back, push the fix commits to
    the PR head branch when `PUSH=yes`; every other form pushes nothing. A rejected push is
    stop-the-line. (default)
13. **Low cycle (bar met).** With 0 Advisories skip it: `lows: applied 0 / open 0 / reverted no`. Low pass `l` (Sonnet), pre-round `post-l<k>`, fix-verifier at
    iteration 1; ISSUES_FOUND: one narrow fix `m1` (fresh Sonnet), pre-round, re-verify at
    iteration 2. If that re-verify is not CLEAN, a pre-round FAIL stays open after the Low
    fixer's FAIL fix, or a transport stop ends the cycle, `git revert` the Low commits and hand
    back the Lows as open. (default)
14. **Hand back** at most 10 lines (`references/severity-and-records.md` section 7). The panel
    presents; the caller or owner decides anything beyond the artifact's own text. PR forms:
    remove the worktree (literal full path).

## Reconcile mode

`MODE=reconcile` (new; `review` above, including every Step, is unchanged — verify with `git
diff` against this skill's pre-reconcile state before trusting that claim, never assume it).
Produces a merged best-of-both result from two independently-diverged versions of one artifact,
never a blind pick-one-side overwrite. Full mechanics — each seat's reading rule, the
classification taxonomy, the `DELTA` line shape, all five briefs, record names — are in
`references/reconcile-brief.md`; this section states only what differs from `review` mode's
flow. Every bullet below is this skill's own choice (default), carrying no owner ruling yet.

- **Prepare (default):** before any seat reads, resolve the real path of `VERSION_A_PATH`,
  `VERSION_B_PATH`, `COMMON_ANCESTOR_PATH` (if given) and `MERGE_TARGET_PATH`; confirm each of
  the first three exists and is readable; stop-the-line if `MERGE_TARGET_PATH` resolves to the
  same file as `VERSION_A_PATH` or `VERSION_B_PATH` (a caller typo would otherwise let the Fixer
  overwrite a source version while faithfully following its own brief). Snapshot `VERSION_A_PATH`
  and `VERSION_B_PATH` (sha256 or byte-for-byte copy) for the post-write check below. No worktree
  or `HEAD_SHA` is required — reconcile mode's inputs are already-materialised plain files, not a
  tracked artifact (`## Inputs`).
- **Read-only on both versions.** The nine seats, A-close and synthesizer all read
  `VERSION_A_PATH` and `VERSION_B_PATH` (plus a real 3-way diff when `COMMON_ANCESTOR_PATH` is
  given); only the Fixer writes, and only to `MERGE_TARGET_PATH`.
- **Classification, not defect-hunting.** Each seat runs its own topic's check
  (`references/seats-raci.md` section 4) against both versions and classifies every delta in its
  domain into exactly one of the five classes `references/reconcile-brief.md` section 2 defines.
  A-close adjudicates each from source, the same close rule as `review` mode (one `CLOSED` line
  per topic).
- **One fix point, escalating only per the existing cap.** No Scaling tier, no `review` mode's
  bar-chasing Loop below: nine seats, A-close, synthesizer, then the Fixer writes
  `MERGE_TARGET_PATH`. The post-write check (next bullet) runs, then the existing `fix-verifier`
  skill confirms the write against the verdict; the existing fix-cycle and cap (Loop, below)
  apply unchanged — a narrow fix `b`, or a cap-escalated new cycle, is still reachable and uses
  the fix-letter/iteration record-name suffix `references/reconcile-brief.md` section 9 defines.
- **Post-write check (default; mirrors `review` mode's Step 11 — a brief-text promise alone is
  not a check):** after the Fixer writes, before `fix-verifier` is dispatched, the orchestrator
  re-hashes `VERSION_A_PATH` and `VERSION_B_PATH` against the Prepare-time snapshot. A mismatch is
  stop-the-line: revert (restore from the snapshot) and hand back `BAR NOT MET —
  write-scope-violation`, naming the path and the fix record.
- **Output: a reconciliation verdict**, not a findings table. The synthesizer writes one
  disposition per delta (the winning version, or the specific merge instruction) plus an
  explicitly named list of residual `CONFLICT` items that need the human owner's call — the panel
  never invents authorial intent nobody stated. `MISSING-FROM-BOTH` items are a separate bonus
  list, non-blocking.
- **Done bar** (replaces 0 Blocking/0 Medium for this mode): every identified delta has a
  disposition, and every residual `CONFLICT` is named in the hand-back. This mode never loops
  trying to resolve a `CONFLICT` itself — an unresolved one is escalated by name.
- **Hand-back:** same at-most-10-line form as `review` mode (`references/severity-and-records.md`
  section 7), line 1 replaced by this mode's bar line above.

## Scaling

`MODE=review` only (`MODE=reconcile` is always one Full round; see above). Defaults, never below
what the risk needs (Q6; full text and tests in `references/scaling.md`):

| Round | Tier | Seats | Condition |
|---|---|---|---|
| any | Full | 9 | round 1, and every case that is not Focused; the only tier that can meet the bar (default) |
| 2 and later | Focused | 3-9 | ALL of F1-F6: previous synthesizer 0 Blocking, at least one Medium in 1-3 topics; last fix-verifier CLEAN; no new surface; fix touched at most 1/3 of the lines; `OWNER_DECISIONS` count unchanged (default) |

Focused seats: the core trio (cold-reader, fact-checker, integration-architect) plus the R and A
seats of in-scope topics (a Blocking or Medium last round, plus UNRESOLVED). Inputs and the chosen
tier go in the ledger. Smaller than Focused does not exist (default; owner, 2026-10-28 chat: "Pr's with small doc
changes always go through a doc reviewer."): a small doc is doc-reviewer's.

## Loop

`MODE=review`'s bar-chasing loop (unchanged). `MODE=reconcile` reuses only the fix-cycle, cap and
harness-outcome mechanics below for its one fix point; it has no round cap and no Scaling tier
because it never iterates past one Full round (`## Reconcile mode`).

- **Bar** (owner S1, 2026-10-24: "... another agent has fixed the issues and then another agent
  runs the fix validator and that loops runs till there's no blocking or medium issues then the
  plan is approved to go"; `skills/review-7-panel/SKILL.md:23-27@c057d0cf`; R-ck above): 0
  Blocking / 0 Medium. That the round showing it must be Full-tier is a default (G39; Q6).
- **No round cap** (S1). Default D44 (Q5): at 4 rounds without the bar the orchestrator REPORTS
  (rounds, residual finding classes) and CONTINUES; the caller reads it as an ADR 0014 T2 signal.
  Hermes G57/D79: stop clauses tighter than 0B/0M stopped three loops early on 2026-10-27; a
  brief cites the bar and the ADR 0014 ladder, not a round count. Only an owner stop or a
  stop-the-line anomaly ends a loop short: a block, a second transport failure of a non-seat
  role, a second fix-verifier timeout, the fix-cycle cap on a Fable cycle.
- **ADR 0014.** T1 (second Opus fix followed by new Mediums, `skills/review-7-panel/SKILL.md:45@c057d0cf`):
  Fable fixer from then on; T2 (a frozen fact contradicted by re-measurement): pause, report,
  assessor (`skills/review-7-panel/SKILL.md:113-116@c057d0cf`). A pre-round FAIL fix does not count to T1.
- **Harness outcomes** are two events (default). (a) Transport failure (no record, or an API
  error such as HTTP 429; not a fix-verifier timeout): re-dispatch ONCE, fresh, one tier up; a
  second one for a seat or A-close writes `UNRESOLVED | <topic> | r<N> | transport`; for a
  non-seat role it ends the loop with hand-back `BAR NOT MET — transport`; in the Low cycle it
  reverts the Low commits and hands back `BAR MET — lows: transport`. (b) A classifier or
  permission block anywhere in the tree is stop-the-line: quote verbatim, never reword,
  reroute or retry (global Rule 4).
- **Fix-verifier timeout** (90 s; its own outcome is ISSUES_FOUND with one check-0 Advisory,
  `skills/fix-verifier/SKILL.md:235-249@c057d0cf`) is not a verdict: re-dispatch ONCE, fresh, same tier
  and SAME iteration number; F3 and the next fixer read only a completed verdict; a second timeout is a transport stop-the-line.
- **Fix cycle and cap** (`skills/fix-verifier/SKILL.md:251-291@c057d0cf`; the one statement): a cycle is
  main fix `a`, verify at iteration 1, if ISSUES_FOUND narrow fix `b`, verify at iteration 2. A
  second ISSUES_FOUND means the cap has fired, logged `iteration-cap` (distinct from T1; the
  verifier's iteration-3 Blocking is never dispatched): escalate the fixer one tier per the Rule 4
  ladder (Opus, one Opus retry with an upgraded brief, then Fable) and open a NEW cycle with
  iteration back at 1, a new `session_id` suffix and the next `<k>` in the record names. A
  Fable-tier cycle whose iteration-2 verify is ISSUES_FOUND ends the loop with `BAR NOT MET —
  fix-cycle cap` and the open findings.
- **Reading rules, frozen facts, fix discipline** (defaults carried; text in
  `references/briefs.md` section 9): a "(fact)" names its command and count; a reading rule binds
  seats and synthesizer for the loop; a fixer closes the whole class and writes property, never a
  timing mechanism (S14); the byte bar applies only to a class that returned twice.
- **Nearest-wrong-variant walk** (Hermes D58) is not in the fix-verify step (default, Q14).

## Independence and secrets

- Nine separate dispatches in ONE message, each pinned and given only its own brief (artifact,
  sources, owner decisions, seat row, fitted surface, reading rules, its record path). A seat
  reads no other seat's record and no prior findings (the A-close topic file is the one
  exception). Briefs carry no expected result. Focused rounds name topics, never findings.
- Records are files, nothing is consumed, so an "absence" claim is trustworthy here, unlike on a
  consuming bus.
- No swarm bus (default, Q9): it needs a process manager, Node and a sibling repository present
  on one host only; `read_messages` consumes per agent unless `peek:true`, and measured lossy
  reads (a gate saw `found:0` with all 7 signals present); 4 Haiku dispatches a round, the file
  shape none. Lost: live deliberation; replaced by blind C-NOTEs and the A-close re-verification.
- Every brief carries "never read `.env*`, `*hermesAuth*`, credential or token files" and the
  owner's removal sentence (`references/briefs.md`, common block). The orchestrator screens every
  record, hand-back text and fix commit with the record-identity grep; any count other than 0 is
  stop-the-line (`references/severity-and-records.md` section 8).
- The A-close, synthesizer, fixer and fix-verifier are different instances from each other and
  from any seat (Rule 4; S1). Evidence (facts): a first real 7-seat round found 10-12 Mediums per
  design after a simulated round had passed each (n=3, G14 extension); simulated round 1 found
  Blocking in 5 of 9 designs (G10).

Never-list (defaults carried from `skills/review-7-panel/SKILL.md:136-149@c057d0cf`): every role writes
only the artifact under review (the fixer) or its own record; no agent decides an owner-only item
(rules, money, external publication, deletion: Rules 9 and 11); no `--no-verify`, no
`core.hooksPath` override, no force-push; a fixer that refuses a finding says so with the reason.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "Small doc, run nine seats to be safe." | Rung 1: `doc-reviewer` covers it; pick the lowest rung (`tools/review-ladder.md` section 4). |
| "Two clean rounds, call it approved." | Owner S1 (`skills/review-7-panel/SKILL.md:155@c057d0cf`): loop to no Blocking/Medium. (default, Q6) The bar round is Full-tier; (default) then the Low cycle. |
| "Stop at 4 rounds." | D44 (default, Q5): report and continue. |
| "The verifier's count is good enough to freeze." | Re-measure; name the command and the count. |
| "Let a finished seat peek at a peer record." | Independence is the point of nine instances; only the A-close sees a topic file. |
| "The fix-verifier was CLEAN, skip the next full round." | Only a Full round at 0B/0M meets the bar (Hermes G39; Q6); CLEAN only decides the next round's tier. |
| (`MODE=reconcile`) "This CONFLICT has an obvious right answer, just pick one and merge it." | A genuine two-way CONFLICT escalates by name to the human owner; the panel never invents authorial intent nobody stated (`## Reconcile mode`). |

Rows 2-4 are carried from `skills/review-7-panel/SKILL.md:155-157@c057d0cf`; rows 1, 5, 6 and 7 are
design-specified (row 6: Hermes G39; row 7: `## Reconcile mode`).

## Exit criteria

`MODE=review` (default):
- [ ] The last round is Full-tier (default, Q6) and its synthesizer line 1 is `BAR MET 0/0/<A>`, with no
      UNRESOLVED topic in the ledger.
- [ ] Every in-scope topic of every round has exactly one CLOSED line (UNRESOLVED has none).
- [ ] (default) The last fix-verifier record before the bar round reads CLEAN (or no fix preceded it).
- [ ] The Low cycle ran, had 0 Advisories, or was reverted and the Lows are listed open.
- [ ] (default) No fix commit touched a path outside `ARTIFACT_PATHS`; every record screened (count 0).
- [ ] The hand-back is at most 10 lines in the form of `references/severity-and-records.md` section 7.

`MODE=reconcile`:
- [ ] Every delta any seat or A-close surfaced has exactly one disposition row in the
      synthesizer's reconciliation verdict; none silently dropped.
- [ ] Every residual `CONFLICT` is named in the hand-back, none left unresolved-and-unlisted.
- [ ] The Fixer wrote only `MERGE_TARGET_PATH`; `VERSION_A_PATH` and `VERSION_B_PATH` are
      byte-identical to before the run; the `fix-verifier` record reads CLEAN.

## Defaults and open questions

Behaviours that rest on a design default or an open owner question; each is marked `(default)`
where it applies (Rule 9).

| Q | Behaviour | Default in force | Owner decides |
|---|---|---|---|
| Q1 | what becomes of `review-7-panel` | kept as a superseded stub | delete, keep stub, or keep as its own rung |
| Q2 | small vs bigger | ANSWERED 2026-10-28, by size (Trigger) | nothing open |
| Q5 | stop clause | no cap; report at 4 and continue (D44) | a cap, or confirm |
| Q6 | tiers and the Full-tier bar round | logged defaults until measured on two loops | adopt as a standing rule, or keep |
| Q7 | PR mixing code and bigger docs | one rung per artifact | one rung for the whole PR |
| Q9 | live deliberation | no bus; blind C-NOTEs plus A-close | a bus-backed Phase 2 now |
| Q10 | pre-round check form | Haiku-run prose checklist | script it as Rule 10 code with tests |
| Q12 | doc rung for an app repo's PRs with bigger docs | any repo the caller names (Trigger) | whether this skill is that rung |
| Q13 | nine seats vs S3's seven | the 2026-10-28 "9 agents" set the seat count; S3 kept as the fitting rule | confirm or correct |
| Q14 | D58 nearest-wrong-variant walk | left out of fix-verify (the verifier contract has no slot) | add it with a second verifier brief |
| Q15 | `MODE=reconcile`, new 2026-10-29 | every rule in `## Reconcile mode` and `references/reconcile-brief.md` is tagged `(default)`; no owner ruling yet | ratify as a standing rule, or correct |

Also defaults: pins beyond the owner's quoted ones, cap logic, byte bar, Low cycle, matrix, budgets.

## Provenance

Design record: `hq:architecture/panel-consultation.md` and its `-02` companion. Owner words: 2026-10-28 chat, "IT should
be 9 agents using the RACI model to better review pr's."; S1, S9, R-ck, 06:27:40Z as above, S3 in `references/seats-raci.md`; S14, 2026-10-26, question
Q-PREROUND-C8, answer "Yes" (`references/preround-check.md` C8); pre-round trial, 2026-10-26,
"Do you want that added to the review skills? yes". Hermes `brain/review-loop-mechanics` items
G10, G11, G14, G17, G25, G39, G51, G57, S1, S3, S9, S14, D44, D54, D58, D60, D65, D66, D79.
`MODE=reconcile` (2026-10-29): no prior panel-consultation or review-7-panel capability reconciles
two diverged artifact versions; added per a dispatch brief naming this exact gap, with no Hermes
or owner-quote trace yet — recorded here as a design default (Q15) pending one.
Lineage: `references/seats-raci.md`, section Lineage; reconcile mode's own lineage:
`references/reconcile-brief.md`, section Lineage.
