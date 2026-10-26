# Task Spec: 09 wave-execution EXTEND (ADR 0054 A0-A9, owner Q1-Q11)

> Item: design §7 item 9 (`part-06-build-plan-and-sources.md:22`), wave W1. Branch: `ext/wave-execution` (a separate reviewed branch, M29).
> Tier: SKILL.md piece = design (strong); spec-format piece and example/tests piece = execute (default); integration = design. Review rung: Rung 1 trio (prose; not one of the four heavy items). The branch is not used to review the family (M29).
> Depends on: INTERFACES frozen (parts C1.1-C1.3, C2, A.5, D2.3); ADR 0054 accepted 2026-10-26 (clears owner wait (b), `part-06:49`); 2b plan-check of this spec. Blocks: items 28 and 29 (`delivery-run`, `delivery-pipeline`, W2).
> Done condition (machine-checkable): `bash skills/wave-execution/references/example-spec/tests/run.sh` prints `WAVE-EXEC-TESTS: PASS <n>/<n>` with exit 0, AND every command in section 9 exits 0.

## 1. Objective
Extend `skills/wave-execution` (SKILL.md, `references/spec-format.md`, `references/example-spec/` with tests) and `architecture/wave-execution.md` so they implement every ADR 0054 decision A0-A9 and owner answers Q1-Q11, with all new fields optional and a bundle that declares none validating and running exactly as today.

## 2. Context package
- Authority: `decisions/0054-adr-0023-amendment-delivery-workflow.md` (A0-A9; "What changes in `skills/wave-execution`" lists the edit sites by line at `c1ba30e`); INTERFACES part C1.1 (values), C1.2 (`done_condition`, `persona`, `lane`, `depends_on`), C1.3 (rules 13-15), C2 (record, controller side R4-J15), part A `bus.endpoint` and `dispatch/<invocation>.jsonl`, part D2.3 (input names, transport rule R4-J22: `wave-execution` keeps snake_case), D topic table.
- Existing: `skills/wave-execution/SKILL.md` (294 lines, 2623 words, `c1ba30e`), `references/spec-format.md` (141 lines), `references/example-spec/` (waves 01-03 plus README), `architecture/wave-execution.md` (261 lines), `decisions/0023-*`.
- Standards: `tools/skill-authoring.md` §2-§5 (SKILL.md body at or under 5k tokens; depth in `references/`), `tools/check-doc-length.sh`.
- Dependencies: none beyond the frozen files. Port guard (INTERFACES 1.1.0 amendment, landing): see SPEC-QUESTION 1.

## 3. Scope
**Split plan (Rule 7: three directory-disjoint pieces in parallel, 1.5 h; then one integration step, 0.5 h).**

| Piece | Owner files (only these) | Reads, never writes |
|---|---|---|
| P1 SKILL.md (design tier) | `skills/wave-execution/SKILL.md`; new `skills/wave-execution/references/frontier-mode.md` if the body would exceed budget (SPEC-QUESTION 2) | ADR 0054, INTERFACES |
| P2 spec-format (execute) | `skills/wave-execution/references/spec-format.md` | ADR 0054, INTERFACES |
| P3 example spec and tests (execute) | `skills/wave-execution/references/example-spec/**` (waves, README, `tests/`) | ADR 0054, INTERFACES |
| Integration (design, 1 agent, after P1-P3) | `architecture/wave-execution.md`; cross-file fixes in P1-P3 files | all |

P2 and P3 take the field names, enum values, regexes and rule numbers from ADR 0054 and INTERFACES only, never from each other's in-progress output; the integrator reconciles them.

**In scope (what the pieces must contain):**
- P1, steps and rules: step 3 pinned `session_id` else mint (A6); step 4 skipped and step 8 `cleanup()` skipped when `bus_endpoint` is set, with the identity preflight (comparing against `data_dir`/`pm2_app`, port only from `$data_dir/port`) and step 5 still run (A9, C1.1); unattached step 4 recovers a leftover `swarm-mcp-<session_id>` with `pm2 restart` only (A6); `max_concurrent` as an invocation argument counting work_item, gate and fix agents, a gate or fix agent waiting for a free slot (A0, A1, Q3, Q9); `persona` passed verbatim, `lane` serialization (A2, A3); `step_complete` gate with the `done_condition` rubric exception, all-must-pass in a barrier wave (A4, Q2, Q11); frontier release loop, per-work_item gate, per-work_item `fix_loop_cap`, escalation payload with `work_item`, non-release of transitive dependents, halt rule, no gate reopened (A5, Q5); nonce-bearing `from_agent` ids and the A7 discriminator on the bundle `output_topic`; the dispatch record appended before each dispatch when `bus_endpoint` is declared, and posts accepted only from registered ids (C1.1 row `agent_id`); caller inputs `invocation` and `tier_override` (C1.1, R4-J12, R4-J15); resume authority = checkpoint only, per-work_item entries (A6, Q6); fallback file never read by the skill (A7, Q7); Topic Naming, Resume/Checkpoint, Exit criteria and Constraints edits; one Red flags row: "a blocker passed, so release its dependents before their lane is free".
- P2, format: bundle-level `session_id`, `output_topic`, `bus_endpoint` beside `dispatch_budget`; per-work_item `persona`, `lane`, `depends_on`, `done_condition`; `gate_type: step_complete`; `fix_loop_cap` per work_item in a frontier wave; `max_concurrent`/`invocation`/`tier_override` marked as invocation arguments, not spec fields; rule 9 (enum plus `gate_agents` mapping plus `done_condition` presence and two-key shape), rules 13-15, rule 11 frontier term `work_items_count x (1 + (fix_loop_cap + 1) x g)` still last; the rule-12 gap noted; the changed rubric sentence (lines 58-59) for `step_complete`.
- P3, example: one added wave file with a frontier wave (edges, lane, persona, `done_condition`, `step_complete`), bundle fields in the bundle header, README table updated; `tests/run.sh` plus fixtures.
- Integration: `architecture/wave-execution.md` per ADR 0054 "What changes in `architecture/wave-execution.md`" (every bullet), including the banner at lines 9-14 and § Proposed capabilities at lines 154-164 corrected to Tier A's real state (`gate_type`, `output_schema`, `dispatch_budget`, rules 9-11, Resume/Checkpoint are already in `SKILL.md`/`spec-format.md` at `c1ba30e`), then a read-through for contradictions between P1, P2, P3 and the architecture doc.

**Out of scope:** ADR 0023/0054 text (accepted, no edit); `spec_ref` and rule 12 (deferred); `delivery-run`/`delivery-dispatch-plan` (items 28/29, 15-17); INTERFACES (frozen; a defect is a change-control amendment, not an edit here); any other skill; any commit (the integrator commits).
**Do NOT create:** a preflight executable for the skill itself; command-token registries; a global barrier-free flag; per-wave `max_concurrent`; cross-wave edges; a cost metric; symlinks; a second `bus.endpoint` reader or writer; cleanup of an attached bus.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| ADR 0054 A0 | bundle fields: `session_id`, `output_topic`, `bus_endpoint`; per-work_item: `persona`, `lane`, `depends_on`, `done_condition`; invocation args: `max_concurrent`, `invocation`, `tier_override` | ADR 0054 A0; C1.1; D2.3 |
| `session_id` | `^[a-z0-9-]+$`, in `spec_root` hash, stable on resume (rule 13) | A6, A8, C1.3 |
| `output_topic` | literal, no placeholder; differing per-wave value is `VALIDATION_FAILED` (rule 14) | A7, A8, Q8 |
| `bus_endpoint` | `$DELIVERY_ROOT`-relative `<run-id>/<subtask>/bus.endpoint`; keys `port, data_dir, pm2_app, pid, session_id, topic`; port only from `$data_dir/port`; `session_id=`/`topic=` equal the bundle's | C1.1, part A `bus.endpoint` |
| `done_condition` | `{"token": <str>, "command": <str>}`, both non-empty one-line, no other key; gate passes only if `command` exits 0 and its last stdout line equals `token`; required under `step_complete` (rule 9) | C1.2, Q2 |
| `gate_type` enum | `exit_criteria, adversarial_verify, judge_panel, step_complete`; `step_complete` `gate_agents` = `work_items_count` (barrier), 1 per work_item (frontier) | A4, D2.1 |
| rule 15 | `depends_on` acyclic; edges name work_items of the same wave; a wave with edges enumerates its work_items | A5, A8, Q4 |
| rule order | 1-10, then 13-15, rule 11 last | A8 |
| `max_concurrent` | integer >= 1, validated where passed; absent = unbounded | A1 |
| dispatch record | `dirname(bus_endpoint)/dispatch/<invocation>.jsonl`, one JSON line per agent before dispatch, fields `agent_id, role, unit, persona, tier, backend, utc`; only with `bus_endpoint` | C1.1 (R4-J12) |
| escalation payload | `{halt_reason: "fix-loop-cap-exhausted", wave, work_item, iterations}` on `{SESSION_ID}-escalation` | A5 |

## 5. Inherited module API
`skills/swarm-communication` (bus calls, `from_agent`, `peek`, `start_session`/`end_session`) and the existing wave-execution steps 1-8, Bus Rules, Prohibited Side Channels, Topic Naming. Reuse; do not restate swarm-communication.

## 6. What you inherit
| Thing | Source | Notes |
|---|---|---|
| Edit sites by line | ADR 0054 "What changes in `skills/wave-execution`" | lines are at `c1ba30e`; re-locate by heading |
| Rubric sentence | `spec-format.md:58-59`, `SKILL.md:95-97` | amended for `step_complete` only |
| Stalled-dispatch exception | `SKILL.md:199-202` | used by A7 fallback rule |
| Doc checker | `tools/check-doc-length.sh` | non-skill docs at or under about 500 lines |

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| `max_concurrent` home | invocation argument | spec field / per-wave field | A0, Q9 |
| `session_id` on resume | same pinned value | new mint | A6 (unpinned runs still mint) |
| Passed work_items on resume | checkpoint only; unrecorded post is re-gated | trust a completion post | A6, Q6 |
| Cancellation | non-release of dependents | `TaskStop` of dependents | A5 |
| Frontier gate | per work_item, own output only | collective wave output | A5, Q5 |
| Edges | same wave only | cross-wave edge | A8 rule 15, Q4 |
| Attached bus | skip step 4 and `cleanup()`; keep identity preflight and step 5 | skip the preflight | A9 |
| Fallback file | never read by the skill | read `status/<agent>.verdict` | A7, Q7 |
| Recovery verb | `pm2 restart` (unattached); caller restarts when attached | `pm2 start` twice / `reload` | A6, C1.1 |
| `fix_loop_cap` | per work_item (frontier), per wave (barrier), default 3 | one scope for both | A5 |

## 8. Acceptance criteria
- [ ] A bundle declaring none of the new fields validates and runs as at `c1ba30e` (tested by the unchanged 3-wave example).
- [ ] Every A0-A9 decision and Q1-Q11 answer maps to a located sentence in SKILL.md or `spec-format.md` (traceability table in P1's hand-off note, not a file).
- [ ] Rules 13-15 and the amended rule 9 and rule 11 are in `spec-format.md`; rule 11 stays last.
- [ ] `invocation`, `tier_override`, the dispatch record and registered-id acceptance are documented (INTERFACES C1.1 rows R4-J12, R4-J15).
- [ ] The example frontier wave validates under rules 1-15 (tests); each negative fixture fails with its named rule.
- [ ] `architecture/wave-execution.md` has no "not yet implemented" for Tier A, carries the ADR 0054 banner line, and covers every bullet of the ADR's architecture-doc list.
- [ ] SKILL.md body within the token budget; overflow in `references/`; `Provenance` section updated (ADR 0054, this port).
- [ ] No cost metric; no hq-internal text beyond what the SUB rules allow.

## 9. Verification commands
```bash
W=~/projects/agent-hq-worktrees/delivery-w0; cd "$W"
bash skills/wave-execution/references/example-spec/tests/run.sh          # WAVE-EXEC-TESTS: PASS n/n
bash tools/check-doc-length.sh "$W"                                      # exit 0
test "$(wc -w < skills/wave-execution/SKILL.md)" -le 3700                # token proxy (SPEC-QUESTION 2)
for f in session_id output_topic bus_endpoint max_concurrent persona lane depends_on done_condition step_complete invocation tier_override; do
  grep -q "$f" skills/wave-execution/SKILL.md && grep -q "$f" skills/wave-execution/references/spec-format.md || echo "MISSING $f"; done   # no output
grep -c "^1[345]\. " skills/wave-execution/references/spec-format.md     # 3
! grep -rn "not yet implemented" architecture/wave-execution.md
grep -q "ADR 0054" architecture/wave-execution.md
! grep -rnE "/Users/xavier|brainAlpha|Xavier|touri|Notion" skills/wave-execution architecture/wave-execution.md
git status --short | grep -vE '^( M|\?\?) (skills/wave-execution/|architecture/wave-execution.md|architecture/delivery-workflow/tasks/09-)' # no output (integrator only reads status; no add/commit)
```
`tests/run.sh` (P3) is hermetic bash in the style of `tools/test_check-doc-length.sh`: a static checker of the bundle rules over `example-spec/` and `tests/fixtures/{valid,invalid-<rule>}/`. It must cover: valid frontier bundle passes; invalid per rule 9 (`step_complete` without `done_condition`, extra key in it), 13 (uppercase `session_id`), 14 (placeholder topic; differing per-wave topic), 15 (cycle; cross-wave edge; edges without enumerated work_items), 11 (frontier budget overrun); the no-new-field 3-wave bundle still passes.

## 10. Branch
`ext/wave-execution`, from agent-hq `main` after the W0 branch lands. Pieces write into one worktree on directory-disjoint paths; the integrator commits once per piece plus once for integration. The branch is reviewed separately and not used to review other W1 items (M29).

## 11. Decision Gate reminder
Write `.decisions/09-wave-execution.md` and stop on: a conflict between ADR 0054 and INTERFACES; any behaviour neither states (mark `SPEC-QUESTION:`, do not invent); a need to edit a file outside section 3; a rule that tests cannot check with the commands above.

**Pre-flight (six checks):** inherit present (section 6); risky values present (7); module API present (5); do-not-create present (3); criteria verifiable with the given commands (8, 9); every risky value sourced (7).

## SPEC-QUESTIONS (for the plan-checker)
1. SPEC-QUESTION: the port-guard amendment (INTERFACES 1.1.0: `tools/port-check.sh` claims before any bind; catalog `port` rows; PreToolUse hook) is not yet in the frozen files and `tools/port-check.sh` is absent from the tree. Step 4 binds a pm2 bus port when `bus_endpoint` is absent; whether P1 must call the claim there (and how an attached bus is claimed, presumably by the caller) is undecided. Default until the amendment lands: P1 adds no claim step and the integrator re-reads INTERFACES before finishing and adds it if the amendment specifies it. The `security-audit` amendment adds no wave-execution change (its agents are counted by the caller's slot ledger).
2. SPEC-QUESTION: SKILL.md is 2623 words today; the added A0-A9 behaviour may break the 5k-token body budget. Default: P1 may add `references/frontier-mode.md` (frontier release loop, discriminator, dispatch record) and link it; the word-count proxy 3700 is a stand-in for a tokenizer.
3. SPEC-QUESTION: C1.2 states the `step_complete` gate agent reads the work_item's C2 record and its `head` and fails a non-`PASS` record, which is `delivery-run` vocabulary; ADR 0054 A4 keeps `wave-execution` domain-agnostic. Default: SKILL.md states it generically (the gate agent runs `done_condition.command` where the work_item's output says to, and fails a work_item whose completion record is not a pass), with the C2 wording left to `delivery-run`.
4. SPEC-QUESTION: whether the tests piece is wanted as an executable checker (default above) or fixtures only; a script implies the code gate (`pr-review`, 7 seats, item 32 rung). Default: executable, reviewed at Rung 1 as a test fixture, not as shipped tooling.
