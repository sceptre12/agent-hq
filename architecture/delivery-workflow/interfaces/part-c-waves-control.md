# INTERFACES.md, part C: waves and control

- **Status:** draft, pending 2b review (design §7 item 2). Integrated 2026-10-26; every former `OPEN` is resolved with a one-line rationale; `DEFAULT (integrator)` marks a choice the design does not imply (logged in `INTERFACES.md`). Consistent with ADR 0054 (`decisions/0054-adr-0023-amendment-delivery-workflow.md:38-197`, Decision A0-A9); its caller-owned bus (A9, `:179-197`) is settled by the owner, 2026-10-26, Q2 YES (`architecture/delivery-workflow-sources/owner-decisions.md:59`), and its questions Q2-Q11 are settled by the owner, 2026-10-26 (`architecture/delivery-workflow-sources/owner-decisions.md:74`; answers listed at `decisions/0054-adr-0023-amendment-delivery-workflow.md:267-284`). ADR 0054 is accepted 2026-10-26 (`decisions/0054-adr-0023-amendment-delivery-workflow.md:3`).
- **Source:** design v2 §5.0, §3.0, §3.1, §4, §2.2 cards 1, 6, 7, §2.3, §6.4. Where the changelog and the design text disagree, the design text governs; each case is noted.
- **Path keys:** `RUN_HOME = $DELIVERY_ROOT/<run-id>`; `<subtask>`, `<agent-id>` as in part A.

## C1. Unit table to `wave-execution` `waves/` (M17)

`delivery-dispatch-plan` writes one `waves/` spec_root per sub-task at `plans/<epic>/subtasks/<subtask>/waves/` (plan plane, committed by sub-task 0; part D6), layout Option B of `skills/wave-execution/references/spec-format.md`; the bundle-level header (`session_id`, `output_topic`, `bus_endpoint`, `dispatch_budget`) lives in `bundle.md` at the bundle root, next to `waves/` (AM-3 errata (c), item 9c's choice; spec-format's bundle-field section cross-references it). `delivery-run` invokes the extended `wave-execution` (ADR 0054) in DAG-frontier mode.

**Wave files per sub-task (`DEFAULT (integrator)` file set, on ADR 0054 A5: frontiers are computed inside one wave and declared waves stay barriers to each other, owner 2026-10-26, Q4, `decisions/0054-adr-0023-amendment-delivery-workflow.md:93-96`, `owner-decisions.md:74`):** `constitution.md` (not a wave file: spec-format rule 4 numbers waves from 1; the lead runs it serially before `01-build.md`, AM-3 errata (d)) only when the repo has no profile yet (the serial contracts wave, §4 Wave shape), then `01-build.md` holding every unit of the sub-task with `depends_on` edges, then `02-integrate.md` (Integrator, `pre-pr-gate` hand-off). A sub-task's frontier is therefore one DAG wave, not N numbered files; the §4 phrase "lane-waves 1..N" names successive frontiers inside `01-build.md`. **Wave 0 setup (`DEFAULT (integrator)`; design §4 Wave shape, `architecture/delivery-workflow/part-03-personas-and-concurrency.md:80`):** it is not a wave file; `delivery-run` performs it in-lead before its first `wave-execution` call (the worktree adds serial, the other steps in parallel, design §4): catalog check (`RUN_HOME/catalog.tsv` exists, part A.5), unit worktrees added serially with `git worktree add --detach` by the lead (each registered as catalog `worktree`), baseline gates on `origin/main` by the gate runner (A.7 lease; result in its `status/` file, no `GATE-PASS`), facts re-measure by an Explorer (rows in its `status/` file), then the lane leases (C1.1). Only the constitution-and-contracts agent of a repo with no profile is a wave (`constitution.md`).

### C1.1 Invocation-level values (bundle fields written by `delivery-dispatch-plan`, caller values set by the lead `delivery-run`, card 6; ADR 0054 A0, A1, A6, A7)

| Value | Setting | Rule |
|---|---|---|
| `session_id` | bundle field, `<run-id>-<subtask>` | pinned, stable across resume; rule 13 |
| `output_topic` | bundle field, `<run-id>-<subtask>-rendezvous` | the one literal completion topic; rule 14 |
| `max_concurrent` | **caller argument on each invocation**, not a spec field, because it is the free slot count at dispatch time (owner 2026-10-26, ADR 0054 Q9, `owner-decisions.md:74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:47-51`) | `30 - live_rows - sum(reserved)` (part A.4; formula `DEFAULT (integrator)`); worker, gate and fix agents all count toward it and a gate or fix agent with no free slot waits (owner 2026-10-26, ADR 0054 Q3, `owner-decisions.md:74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:55-61`) |
| `dispatch_budget` | bundle field, written by `delivery-dispatch-plan` | rule 11's sum over every wave of the bundle (`skills/wave-execution/references/spec-format.md:120-128`): for the frontier wave `01-build.md` the term `work_items x (1 + (fix_loop_cap + 1) x g)` per ADR 0054 A5 (`g` = gate agents per work_item), for each barrier wave (`constitution.md`, `02-integrate.md`) the 0023 term `work_items_count + (fix_loop_cap + 1) x gate_agents` with rule 9's mapping (`decisions/0054-adr-0023-amendment-delivery-workflow.md:118-121`); never `budget`, `budget_min` or `spawns`, which are lead-side (A.3, A.4); the restatement of the rule-11 sum and the lead-side exclusion are `DEFAULT (integrator)`. Per-work_item budget term in a frontier wave: owner 2026-10-26, ADR 0054 Q5 (`owner-decisions.md:74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:119-122`) |
| `agent_id` and dispatch record | controller-minted `from_agent` (nonce-bearing, ADR 0054 A7) | `wave-execution` appends one JSON line per agent **before** it dispatches that agent, to `dirname(bus_endpoint)/dispatch/<invocation>.jsonl` (= `RUN_HOME/<subtask>/dispatch/`), only when `bus_endpoint` is declared: `{"agent_id":"^[a-z0-9-]+$","role":"worker\|gate\|fix","unit":"^[ui][0-9]+$","persona":"<D2.1 token>","tier":"<wave agents tier>","backend":"agent-tool\|claude-p","utc":"<ISO>"}`; a worker takes its work_item `persona`, a gate agent `gate-checker`, a fix agent `fixer`, all the wave `agents` tier, and `backend` is the controller's dispatch mode; `<invocation>` is the caller input `invocation` (`^[0-9]+$`, `substate.md` `invocation`, part A.3). The lead writes a slot row for each `agent_id` in it (part A.4), deriving `worktree` itself (the controller holds no domain knowledge): the unit worktree `<worktree_base>/<run-id>-<subtask>-<unit>` for `u<N>`, the sub-task worktree for `i<N>` (part A.6), the served work_item's worktree for gate and fix agents. It accepts bus posts only from ids registered there (C2). `DEFAULT (integrator)` (record fields, path and order: row R4-J12) |
| `invocation`, `tier_override` | caller inputs on each invocation (`DEFAULT (integrator)`, rows R4-J12, R4-J15) | `invocation` as above; `tier_override` `<unit>=<tier>` (repeatable, `tier` per D2.1) raises one work_item's tier for that invocation; the re-dispatch after a `ROLLED` (C2) is a fresh invocation with it, resuming at the unpassed items from the checkpoint |
| call model | `delivery-run` runs each `wave-execution` invocation as a background Agent task (`run_in_background`) and idles between turns; its C2 handling, C4 relay and C7 ticks run from its cron while the invocation is live (`DEFAULT (integrator)`, row R4-J13). The controller is then depth 1 and the agents it dispatches depth 2, none of which dispatches (design §3.1; measured depth limit 3, the 3rd level has no Agent tool, `architecture/delivery-workflow/measurements-2026-10-26.md:115-118`); design errata E16 | if a move probe shows depth 2 failing, the lead runs `wave-execution` in its own turn (blocking) and the C7 watchdog half runs only between invocations |
| lane lease | the lead, per lane name per invocation, before it calls `wave-execution` | the lead does not touch the controller's dispatch order, so it leases every `lane/<name>` named by any work_item of the invocation (catalog compare-and-append, part A.5) before the call, and releases each lease after the last work_item of that lane has its C2 record accepted; a lane that binds a port claims it per part A.5.2 before its launch, never auto-picking on a collision (amendment AM-1); one live work_item per lane inside the invocation is the controller's `lane` rule (ADR 0054 A3) (`DEFAULT (integrator)`) |
| `bus_endpoint` | bundle field (written by `delivery-dispatch-plan`, kept bundle-level per ADR 0054 A0), value the `$DELIVERY_ROOT`-relative path `<run-id>/<subtask>/bus.endpoint`, resolved by `wave-execution` against `$DELIVERY_ROOT` (the bundle is committed and hashed, so no absolute path) | **Owner ruling 2026-10-26, Q2 YES (ADR 0054 open item 1):** "add an optional bus_endpoint to wave-execution; caller-owned bus attach and skip-teardown (ratify with 0054)" (`architecture/delivery-workflow-sources/owner-decisions.md:59`). When declared (ADR 0054 A9, `:179-197`), `wave-execution` reads `data_dir` and `pm2_app` from the file and `port` from `$data_dir/port`; it skips its own bootstrap (step 4); it still runs the identity preflight and step 5 (`start_session`); step 8 still posts the final result but skips `cleanup()`. `session_id=` and `topic=` in the file must equal the bundle `session_id` and `output_topic`. `delivery-run` starts the pm2 app (C5.3 step 4) and is the only restarter (`pm2 restart`, also mid-run) (`DEFAULT (integrator)`; ADR 0054 A9 leaves who recovers an attached bus to this part, `:194-197`). Absent = today's bootstrap and teardown. Ratified with ADR 0054 (accepted 2026-10-26) |

**Bus port (PC-4, AM-2, AM-4 W2-3):** the sub-task bus port is the dispatch-plan candidate `ports.bus_base + 20·2N` for `st<N>`, claimed by `delivery-run` per part A.5.2 before the bus starts and pinned with `PORT_RANGE_START=<port> PORT_RANGE_END=<port>` (`$DATA_DIR/port` must equal the claim); `wave-execution` adds no claim. The per-review bus uses `k = 2N + 1` (`ports.bus_base + 20·(2N+1)`) and is claimed in `pr-review` Step 1 from its `BUS_PORT` input (part D2.3). On a claim refusal the launcher makes exactly one retry at candidate + 10, claimed before bind, and pins the bus to that retry port (`PORT_RANGE_START=<port+10> PORT_RANGE_END=<port+10>`); a second refusal stops the line and the lead writes `stop_reason: port-refused` (AM-3, owner OQ-2; AM-4 W2-1).

**Engine details fixed by the item 9 loop (AM-4 9):** a wave-level gate agent's dispatch-record `unit` is `wave-<N>`; `persona` is `none` when the work_item declares none; a declared `bus_endpoint` with a missing `session_id`, `output_topic` or invocation value halts before any dispatch with one error token `BUNDLE-ERROR <field>`; runtime-generated work_items (fix agents) may carry `persona` and `lane`; in a barrier wave a `lane` is released when the holder's gate passes or escalates.

### C1.2 Unit-table column to `waves/` field

| Unit-table column (§5.3) | `waves/` field | Level | Rule |
|---|---|---|---|
| id | `work_item` id | work_item | equals `unit` in the `UNIT-VERDICT` record (C2); a build unit is `u<N>`; the Integrator work_item in `02-integrate.md` that merges `u<N>` is `i<N>` (part A.1) (`DEFAULT (integrator)`) |
| ticket | brief text (the work_item's instruction cites `.tasks/<unit>-<slug>.md`, part A.6) | work_item | branch `<JIRA-KEY>-<slug>` created only after the key is read back from the desk (§3.0) |
| scope globs | **not a spec field**; they live in `.tasks/<unit>-<slug>.md` §3 (heading `## 3`, one glob per line as `- <glob>` until the next `## `) and the dispatch-plan unit table; `scope-check.sh` reads the `.tasks` file only and matches with git pathspec `:(glob)` semantics (`*` within one segment, `**` across segments), against `git diff --name-only <base-sha>...HEAD` in the worktree (`DEFAULT (integrator)`) | work_item | §4 rule 2 (`DEFAULT`: no duplicate home for the globs, D22-style) |
| blocked-by | `depends_on` | work_item | released when every blocker's gate passes; on gate failure dependents are never released (ADR 0054 A5, `:98-117`); edges name work_items of the same wave only (rule 15; owner 2026-10-26, ADR 0054 Q4, `owner-decisions.md:74`); each work_item has its own gate, fix loop and budget term in a frontier wave (owner 2026-10-26, ADR 0054 Q5, `owner-decisions.md:74`); the lead `TaskStop`s only already-live agents, and on `INVALIDATE` (C6) (`DEFAULT (integrator)`) |
| persona | `persona` | work_item (ADR 0054 A2; owner 2026-10-26, Q10, `owner-decisions.md:74`) | a persona token of part D2.1; `delivery-dispatch-plan` writes a `Brief: skills/delivery-run/references/briefs/<persona>.md` line into the work_item instruction (that directory is the one briefs root); `wave-execution` passes the instruction verbatim (ADR 0054 A2) and the dispatched agent reads the `Brief:` file as its first step (COMMON block); `delivery-run` copies nothing (`DEFAULT (integrator)`, row R4-J14) |
| lane | `lane` | work_item (ADR 0054 A3; owner 2026-10-26, Q10, `owner-decisions.md:74`) | one live work_item per lane; the lease itself is a catalog `lane-lease` row (part A.5) |
| budget | brief text; the lead copies it into the slot row `budget_min` | work_item | feeds STALLED (C7) (`DEFAULT`: no spec field) |
| completion record | `output_schema` (the C2 record) | work_item | every work_item posts the C2 record (`DEFAULT (integrator)`) |
| done condition | `done_condition` | work_item | the done condition is one optional per-work_item field, required under `gate_type: step_complete` and checked by rule 9 (owner 2026-10-26, ADR 0054 Q2, `owner-decisions.md:74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:75-80`, `:174-176`). Its name is `done_condition` (`DEFAULT (integrator)`; ADR 0054 A4 leaves the name to this part); value: a two-key object `{"token": "<verbatim done token>", "command": "<verifier command>"}`, both non-empty one-line strings, no other key (`DEFAULT (integrator)`), written by `delivery-dispatch-plan`, read by the `step_complete` gate agent; `token` is the string `command` prints as its last stdout line on success, and the gate agent passes the work_item only when `command` exits 0 and that line equals `token` exactly (`DEFAULT (integrator)`) |
| verifier | gate, `gate_type: step_complete` | wave | one gate agent per work_item walks its `done_condition` plus the wave `exit_criteria` (ADR 0054 A4); it reads that work_item's C2 unit record and the unit branch at the record's `head`, and runs the `done_condition` verifier command there (`DEFAULT (integrator)`; ADR 0054 A4 leaves which output each gate agent reads to this part, `decisions/0054-adr-0023-amendment-delivery-workflow.md:88-89`); in a barrier wave (`02-integrate.md`) the `step_complete` gate passes only when every gate agent passes (owner 2026-10-26, ADR 0054 Q11, `owner-decisions.md:74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:85-87`) |
| review path, e2e `new\|updated\|none` | brief text | work_item | |
| tier (§5.3 roster) | `agents` | wave | tier names only (M19) |

Required wave fields (`goal`, `inputs`, `work_items`, `agents`, `exit_criteria`, `outputs`) stay mandatory (spec-format rule 5).

### C1.3 Preflight rules 13-15 (ADR 0054 A8)

13. `session_id` matches `^[a-z0-9-]+$`, and the checkpoint hash covers it.
14. `output_topic` (bundle and any per-wave value) is a literal; no placeholder; a per-wave value that differs from the bundle value fails validation (`VALIDATION_FAILED`; owner 2026-10-26, ADR 0054 Q8, `owner-decisions.md:74`).
15. `depends_on` is acyclic, and every edge names a work_item declared in the same wave (owner 2026-10-26, ADR 0054 Q4, `owner-decisions.md:74`).

Rule 9 also checks that every work_item of a `step_complete` wave declares `done_condition` (owner 2026-10-26, ADR 0054 Q2).

Rule 12 is the deferred `spec_ref` rule of ADR 0023 (`decisions/0023-wave-execution-workflow-grafts.md:137-138`); the gap in the numbering is intended. The design places the Plan-checker as one that "runs before round 1 (D55)" (`architecture/delivery-workflow/part-03-personas-and-concurrency.md:35`; D55 per the owner's "ADOPT as skill rules: D35, D55, D57, D59, D60, D62", `architecture/delivery-workflow-sources/owner-decisions.md:7`; M17, `architecture/delivery-workflow/changelog.md:199`), and the rule set it runs then, rules 1-11 and 13-15, is the `DEFAULT (integrator)` of this part. **Invocation (`DEFAULT (integrator)`):** `delivery-dispatch-plan` dispatches it (depth 1, persona `plan-checker`, brief `skills/delivery-run/references/briefs/plan-checker.md`) after it writes `waves/`, with the inputs `PLANS_DIR` and `RUN_HOME`; the Plan-checker writes `RUN_HOME/plan-check.md` (`PLAN-CHECK:` line 1, part D1.1); on `n findings` `delivery-dispatch-plan` fixes the plan files and dispatches a fresh Plan-checker, until `PLAN-CHECK: clean` or round 3 (D7, `architecture/delivery-workflow-sources/owner-decisions.md:8`), when it stops for the owner.

## C2. `UNIT-VERDICT` record (B1, M15)

The sole completion signal of a unit: one JSON `output_schema` record posted on `<run-id>-<subtask>-rendezvous`, on the sub-task's bus (`session_id = <run-id>-<subtask>`).

**Records on the topic (ADR 0054 A7):** (a) the unit record below (posted by the worker); (b) gate verdicts `{"agent_id","verdict","rationale"}` (gate agents); (c) the step 8 final result (controller). **Lead rule (`DEFAULT (integrator)`):** act only on bare JSON that matches the unit record schema and whose `from_agent` is registered in this invocation's dispatch record (C1.1); log and ignore (b) and (c) apart from noting the final result. **The post is the bare JSON object**; "`UNIT-VERDICT:`" is the prose name used in the design and the briefs, not a text prefix on the bus (`DEFAULT (integrator)`: `output_schema` validates JSON).

```json
{"unit": "<id>", "verdict": "PASS|ROLLED|ESCALATE", "head": "<sha>", "reason": "<code>"}
```

| Field | Rule |
|---|---|
| `unit` | equals the C1 `work_item` id |
| `verdict` | closed enum; verdict -> allowed `reason` (`DEFAULT (integrator)`): `PASS` -> `none`; `ROLLED` -> `budget`, `lane-unavailable`, `env-bug`, `merge-conflict`; `ESCALATE` -> every other non-`none` code below. The record has exactly the four keys (`additionalProperties: false`) |
| `head` | the unit worktree's head at posting |
| `reason` | required; closed set: `none` (the only value allowed with `PASS`), `gherkin-checkpoint` (§3.6 step 3), `decision-gate` (a `.decisions/<unit>.md` was written, §5.10), `spec-gap`, `contract-gap` (§1 failure classes Structural, Systemic), `tier-exhausted` (never a third attempt at the top tier), `lane-unavailable` (the lane's candidate port and its single +10 retry were both refused, part A.5.2, AM-3), `budget`, `fix-loop-cap-exhausted` (from `{SESSION_ID}-escalation`), `arch` (architecture contradiction), `source-bug` and `env-bug` (e2e writer), `merge-conflict` (Integrator real conflict), `human-step` (e.g. a production migration apply) (`DEFAULT` set beyond the two the design names; every non-`none` code with `ESCALATE` takes the ESCALATE action below) |

**Controller side (`DEFAULT (integrator)`, row R4-J15):** the `step_complete` gate agent fails every work_item whose C2 record is not `PASS`, so a `ROLLED` or `ESCALATE` unit is a failed gate: dependents stay unreleased (ADR 0054 A5) and the unit is not counted done.

**Lead handling (§5.0, card 6, §4):**

| Verdict | Lead action |
|---|---|
| `PASS` | `git rev-parse HEAD` in the unit worktree (for an Integrator record `i<N>`, the sub-task worktree) must equal `head`; re-run one load-bearing command (M15); only then rename the slot row `.freed`. **A `head` mismatch is an incomplete post**: the unit is re-gated under its fix loop, never accepted, and two consecutive mismatches on one unit are a stop row for that unit (`DEFAULT`, from ADR 0054 A6, `:135-137`: an unrecorded completion post is re-gated, never taken as passed; owner 2026-10-26, Q6, `owner-decisions.md:74`) |
| `ROLLED` | re-dispatch one tier up (a fresh invocation with `tier_override`, C1.1), or mark the unit blocked; never a third attempt at the top tier |
| `{SESSION_ID}-escalation` post | the lead drains it into `escalations/<unit>.md` as `ESCALATE` with reason `fix-loop-cap-exhausted`; dependents stay unreleased (ADR 0054 A5, `:106-112`; owner 2026-10-26, Q5, `owner-decisions.md:74`) |
| `ESCALATE` | pause the unit; write `RUN_HOME/<subtask>/escalations/<unit>.md` (the record plus the `.decisions/<unit>.md` path if any); the conductor's next status post lists open escalations for the human; the human's answer arrives as an inbox `ANSWER` line (C5) (`DEFAULT` location); run-level (non-sub-task) work writes `RUN_HOME/escalations/<unit>.md` instead (AM-4 22) |

Readers: the sub-task lead, with `peek:true`, a fresh `agent_id` per read and `limit 200`, as `pr-review` readers do (`DEFAULT`, same bus idiom), and the shepherd, peek-only, to see terminal records for `FREE-CANDIDATE` (AM-4 23). The conductor never reads a sub-task bus (§5.0). Round-1 M8 ("status files are heartbeat only") is superseded by the C4 fallback.

## C3. `NEXT:` status line

```
NEXT: <unit>.<n> <one line>          ^NEXT: (u[0-9]+)\.([0-9]+) .+$
```

`<unit>.<n>` is called `next_step` (never `step_id`, which is the release step, part A.1).

- `RUN_HOME/<subtask>/status/<agent-id>.md`; each agent writes only its own file (A2, §3.0). **One current line, overwritten** (`DEFAULT`; history is the agent's transcript).
- `<n>` is the step number in the unit's `.tasks/<unit>-<slug>.md` §9 verification commands, or `0` before the first step (`DEFAULT`).
- Readers: the shepherd tick compares it with the plan (card 7). Writers: build personas via the COMMON block; `feature-change` `UNIT_MODE=team` emits it (§2.3).

## C4. Status-file fallback (B1)

- **Trigger:** the bus named in `bus.endpoint` is unreachable at posting time.
- **Action:** the agent writes the exact C2 record to `RUN_HOME/<subtask>/status/<agent-id>.verdict` and stops (§3.0).
- **Pickup:** the lead's tick reads `status/*.verdict`, handles each as C2 (including head verification), relays the record to the topic itself, posting under the dispatching agent's recorded `agent_id` (the `.verdict` file stem, which must appear in `dispatch/*.jsonl`, else the file is logged and ignored) as `from_agent` (ADR 0054 A7 discriminator) (the caller consumes the fallback file and `wave-execution` never reads it: owner 2026-10-26, ADR 0054 Q7, `owner-decisions.md:74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:159-163`), then renames it `.verdict.consumed` (`DEFAULT`). **No post:** a dispatch that returns with neither a bus post nor a `.verdict` is a gate failure, and the fix loop's stalled-dispatch exception verifies ground truth and posts the completion (ADR 0054, `decisions/0054-adr-0023-amendment-delivery-workflow.md:159-162`); the lead never posts for it.
- **Precedence:** a bus post for the same unit and head wins; a `.verdict` whose record differs from a bus post is logged and ignored (`DEFAULT`).

## C5. Lead control channel and resume (M21)

### C5.1 Layout beside `substate.md`

```
RUN_HOME/<subtask>/substate.md        lead only (header under mkdir substate.lock)
RUN_HOME/<subtask>/bus.endpoint       port, data_dir, pm2_app, pid, session_id, topic
RUN_HOME/<subtask>/inbox/             conductor messages and human answers, one per file
RUN_HOME/<subtask>/outbox/<id>.desk   claude -p lead: DESK lines for the conductor to relay (part B1); .desk.relayed after relay; .desk.refused when the conductor refuses to relay it (wrong <subtask> or a conductor-only verb, B1); the lead treats it as terminal `sender` (AM-4 W2-4)
RUN_HOME/<subtask>/outbox/register    lead: REGISTER line for the conductor (relayed to the desk as REGISTER-SENDER, part B1)
RUN_HOME/pm/outbox/<seq>.conductor-request   pm lead: CONDUCTOR-REQUEST line for a conductor-only verb; .sending-<id>, then .sent-<id> after send, or .refused
RUN_HOME/<subtask>/dispatch/          wave-execution: dispatch records (C1.1)
RUN_HOME/<subtask>/escalations/       lead: ESCALATE records for the human
RUN_HOME/<subtask>/gates/             H-e2e.<subtask>.ok (desk)
```

**Inbox file (`DEFAULT (integrator)`):** name `<seq>-<yyyymmddThhmmssZ>-<type>.md`, `<seq>` a 4-digit per-subtask counter `^[0-9]{4}$` allocated by an `O_EXCL` create (`set -C`) of the marker `inbox/.seq/<seq>` for the next free number (a failed create tries the next number), shared by both writers, then the file is written; `type` in `release|invalidate|answer|merged`; the lead processes files in `<seq>` order; an `INVALIDATE` supersedes any earlier unconsumed `RELEASE`; crash replay = reprocess every file not yet renamed; the first line is the message verbatim (`RELEASE <subtask>`, `INVALIDATE <subtask> <reason>`, `ANSWER <run-id> <subtask> <unit> <text>`, the part B8 line as typed); further lines are notes. `merged` carries `MERGED <subtask> <merge_sha>` (`^MERGED (st[0-9]+) ([0-9a-f]{40})$`), written by the conductor right after it records `merge_sha` from the `pr-merge` `.out`; on it the lead runs `delivery-cleanup` mode `subtask` (the cleanup trigger) (`DEFAULT (integrator)`). **`pm` and `final` cleanup (`DEFAULT (integrator)`):** the `pm` lead runs mode `subtask` for `pm` (approver the `pm` lead, evidence `postmerge-<pm_sha>.md` and `release-<pm_sha>.md`) once `release-<pm_sha>.md` line 1 holds a terminal token (`RELEASE: LIVE` or `RELEASE: ROLLED-BACK`, part D1.1); the conductor runs mode `final` (approver the conductor, evidence every `cleanup-<run-id>-<subtask>.md` with `CLEANUP DONE`, no `SUBTASK` input) once every `subtasks[]` entry is `cleaned`, before it writes `stage: done` (CYCLE DONE). Writers: the conductor for `RELEASE`, `INVALIDATE` and `MERGED`; the desk for `ANSWER`, after the human types it in the desk session (part B8), so no agent can author a human answer (M30). The lead renames a consumed file `<name>.consumed`.

**Lead to conductor lines (`DEFAULT (integrator)`):** `outbox/register` holds one line `REGISTER <run-id> <subtask> <identity> <session>` (`^REGISTER ([a-z0-9-]+) (st[0-9]+|pm) ([^ ]+) ([a-z0-9-]+)$`, `<identity>` the `SendMessage` id or `-` for `claude -p`), written by the lead at start, after it renames any earlier `outbox/register`, `register.consumed` or `register.refused` to `<name>.<yyyymmddThhmmssZ>` (`DEFAULT (integrator)`), so the `register.consumed` gate below keys on this start's line; the conductor consumes it into `subtasks[].lead_id` and `.session`, sends the desk `REGISTER-SENDER <run-id> | <subtask> | <identity>` when `<identity>` is not `-` (part B1; the desk holds the sender registry, owner 2026-10-26, OP3 B, `owner-decisions.md:65`), and renames it `register.consumed` only after the desk's `REGISTERED ... ok` (for `-`, at once); on `refused` it renames it `register.refused` and stops that lead (stop row). The lead sends no `DESK` line before `register.consumed` exists (part B1). `outbox/<id>.desk` is renamed `<id>.desk.relayed` by the conductor after relay (part B1). **Conductor request from the `pm` lead (`DEFAULT (integrator)`):** `release-track` in the `pm` lead never sends a conductor-only verb itself; it writes `RUN_HOME/pm/outbox/<seq>.conductor-request` (`<seq>` the 4-digit counter allocated as for the inbox, marker `pm/outbox/.seq/<seq>`) holding one line `CONDUCTOR-REQUEST <run-id> pm <seq> <verb> <fields-json>` (`^CONDUCTOR-REQUEST ([a-z0-9-]+) pm ([0-9]{4}) (tag-push|publish|test-report-push) (\{.*\})$`, `<fields-json>` one-line JSON with exactly the part B4 fields of that verb). On its tick the conductor reads it, refuses a file outside `pm/outbox/` or a line not matching the regex (renamed `.refused`, logged in the run log), else runs `desk-req.sh` with `<subtask>` `run` and those fields, renames the file `<seq>.conductor-request.sending-<id>` **before** sending (the minted id is persisted), sends the `DESK` line itself and renames it `<seq>.conductor-request.sent-<id>`; on resume a `.sending-<id>` file is re-sent with the same `<id>` (B2 idempotency), never re-minted (`DEFAULT (integrator)`); the `pm` lead reads the result at `RUN_HOME/desk/<id>.out`. `pr-merge` and the epic `jira-create` stay the conductor's own requests (no carrier).

**Abandoned run (AM-2 row 14; the plan-check cites a C5.1 "`pm` and `final` cleanup" paragraph that this part does not have, so the rule is stated here):** after `stage: stopped` the conductor runs `delivery-cleanup` in mode `final` with evidence `state.md` `stage: stopped` and no `MERGE_RECORD`; D8 and D9 keep unmerged branches and their worktrees, flagged.

### C5.2 Channel per backend

| | `BACKEND=agent-tool` lead | `BACKEND=claude-p` lead |
|---|---|---|
| Launch | own session, depth 0, started by the owner; registers its machine-ledger row first (§3.1, §4) | spawned by the conductor through the §6.4 launcher spec |
| Conductor to lead | **the inbox file is canonical**; a `SendMessage` may be sent as well but carries only `INBOX <subtask>` (a wake-up), never the message body (`DEFAULT`, resolving card 6 vs §5.0 in favour of §5.0) | inbox file, read on every tick |
| Lead to conductor | `substate.md` (`phase`, `prepr`, `head`, `pr`, `review_record`, `integrated`, `ci`, part A.3), `escalations/`, `outbox/` | same |
| Lead to desk | `DESK` line by `SendMessage` | `.req` plus `outbox/<id>.desk`, relayed by the conductor (part B1; owner Q1, `owner-decisions.md:58`) |
| Desk to lead | `DONE`/`REJECTED` line plus `.out` | `.out` polling authoritative |
| Worker completion | Agent return plus bus post | bus post only; the exit code is not a signal (§6.4) |

### C5.3 Resume

Brief (both backends): `resume <subtask>: re-read substate.md, inbox/ and gates/`. For `claude -p` the conductor launches a fresh child through the launcher spec with the brief on stdin; for `agent-tool` the owner restarts the session and types the same brief (`DEFAULT`).

Triggers: reboot (M15); the spawn cap (`cap - 5`); dead lead state found by the conductor at its own resume (card 1); a dead lead found on the conductor's 1-minute tick: the `owner` pid of a sub-task's `substate.lock` fails `kill -0` while `subtasks[].state` is `released|building|pr-open` (`DEFAULT (integrator)`).

Steps, in order (§4, card 6): (1) rename every slot `.row` to `.stale` and run `catalog.sh audit` (no catalog row is marked stale; `state` has no such value, part A.5); (2) re-verify by `kill -0`, `lsof`, `git worktree list`, git refs and the audit lines; `agent-tool` rows are dead on lead restart (A3); (3) free the dead, restore the live, and for each `GHOST` row write `catalog.sh release` or `fail` (only those two); (3a) lease reclaim: the new lead writes `released` (`catalog.sh release lane-lease <handle>`) for every `live` `lane-lease` row of its sub-task (`lane/<name>` and `gate-runner/<n>`) whose `owner_agent` has no live `.row` after (3) or is the old lead, then re-leases per C1.1 before dispatch (`DEFAULT (integrator)`); (3b) reconcile `dispatch/*.jsonl` against `slots/`: every recorded `agent_id` with no `.row`, `.stale` or `.freed` file gets a row written and verified as in (2) (`DEFAULT (integrator)`); (4) re-check the pm2 app against `bus.endpoint`, restart it with `pm2 restart` only (never `reload`); (5) read `inbox/` and `gates/`; (6) only then dispatch. `wave-execution` resumes from its checkpoint because `session_id` is unchanged; the checkpoint is the sole resume authority (owner 2026-10-26, ADR 0054 Q6, `owner-decisions.md:74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:135-137`).

**Hand-over on the spawn-cap path:** the old lead writes `stop_reason: spawn-cap`, removes its lifetime `substate.lock` (part A.3) and exits; the new lead refuses to start while the lock exists and is not stale, so the two-leads stop row cannot be hit (`DEFAULT`). **Order after a `TaskStop` or at resume:** TaskStop, orphan sweep, re-read verdicts (bus and `status/*.verdict`), then free rows. **Bus reads past `limit 200`:** a fresh read repeats with the last seen message id as cursor until a page returns fewer than 200.

## C6. Cross-sub-task sequencing: `RELEASE` and `INVALIDATE` (M19)

```
RELEASE <subtask>
INVALIDATE <subtask> <reason>
```

`<subtask>` is always the **receiver's** id (`DEFAULT`, resolving the card 1 / rule 8b ambiguity). `<reason>` is a closed set: `predecessor-reentered` (a stage 5, 5a or 6 failure re-entered stage 4), `predecessor-rebased`, `contract-changed`, `plan-changed` (`DEFAULT`).

| Message | Sender | Precondition | Receiver action |
|---|---|---|---|
| `RELEASE` | conductor only | the predecessor's `merge_sha` is in `state.md` (for `pm`: every sub-task merged, part A.2) | the successor starts; the conductor sets `released_utc` and `state: released` |
| `INVALIDATE` | conductor only; it clears the re-entered predecessor's `merge_sha` when it sends `predecessor-reentered` | a predecessor re-entered or changed | pause (stop row for `delivery-run`); non-author delta verify of reviewed-head..new-head; a successor past `pre-pr-gate` re-runs `pre-pr-gate` if its head changes and waits for a fresh `RELEASE` once the predecessor re-merges (`DEFAULT`) |

Independent sub-tasks need no `RELEASE`.

## C7. Shepherd and watchdog flags (D10, M11)

**Flag line:** `<FLAG> <agent-id>` appended to `RUN_HOME/<subtask>/shepherd/ticks.md` only when something changed (card 7). Authority: flags and redirects only; the lead decides `TaskStop` and re-dispatch (D10). **Stall flags (AM-3, owner OQ-3, `architecture/delivery-workflow-sources/owner-decisions.md` "Plan-check owner questions"):** the shepherd flags `STALLED` and `PROMPT-OPEN` on its own tick as well, alongside the `delivery-run` watchdog half; two flags for one agent collapse to one lead action.

**Nudge template (`DEFAULT (integrator)`, A2):** `NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>`; sent by `SendMessage`; no free text. **Flag discipline (AM-4 23):** Integrator rows (`unit` `i<N>`) and `wave-controller` rows (`unit` `-`) get no `DRIFT` or `CREEP` check; a cleared flag that returns is not re-flagged; exactly one nudge per flag, sent by whichever side (watchdog or shepherd) writes the flag line.

| Flag | Raised by | Condition | Lead action |
|---|---|---|---|
| `STALLED` | tick (watchdog half) and the shepherd (AM-3, OQ-3) | past `budget_min` with no result | `TaskStop`, re-dispatch one tier up or escalate; never one more budget (`DEFAULT (integrator)`) |
| `PROMPT-OPEN` | tick (watchdog half) and the shepherd (AM-3, OQ-3) | a pending tool call with no result | answer it or stop the agent |
| `DRIFT` | shepherd half | `NEXT:` does not match the plan | spec check first; redirect |
| `CREEP` | shepherd half | `scope-check.sh` hit outside the unit's globs (tasks file `<primary_repo>/.tasks/<unit>-<slug>.md`, `primary_repo` = the parent of `PLANS_DIR`'s `plans/`; `base-sha` = `git -C <worktree> merge-base HEAD <sub-task branch>`, never stored; row R4-J21) | a named defect, never a fix; adjacent defects ticketed |
| `FREE-CANDIDATE` | shepherd half | a terminal record exists for the agent (bus post or `.verdict`) but its slot row is not yet `.freed` | the lead alone frees, after C2 verification (`DEFAULT` condition, from the design's "terminal status the lead has not yet processed") |

**Not a stall:** a `claude -p` lead's result followed by a still-running background task (turn-close rule, card 7).
**After every `TaskStop`:** orphan sweep under the agent's worktree by cwd and pid, kill by pid, catalog each (§4).
**Bus down (`DEFAULT (integrator)`):** on every tick the watchdog half checks `kill -0` on the `bus.endpoint` pid and `lsof` on its `port`; on failure the lead runs `pm2 restart <pm2_app>` (C1.1, the only restarter); two failed restarts in a row write `stop_reason: stop-the-line:S8` (A.3 row ids) and agents fall back to C4 meanwhile.
**Observation means:** catalog, `TaskList`, files, `git -C`, `kill -0`; no `ps`.
**Merged tick:** fires while a `wave-execution` invocation runs in the background (C1.1 call model); one session cron every 10 minutes, `run_in_background`, prompt verbatim from design §4, **armed by the lead in its own session** (`DEFAULT (integrator)`) for both backends (TaskList and slot rows are lead-session state; the conductor arms only its own 1-minute relay tick, part B1). The watchdog half (STALLED, PROMPT-OPEN) belongs to `delivery-run` and runs every tick; the shepherd half (DRIFT, CREEP, FREE-CANDIDATE) belongs to `delivery-shepherd` and runs when the sub-task has 3 or more live agents (card 7); below that the lead performs the drift and creep check itself on each verdict (`DEFAULT`). The shepherd reads `FREE-CANDIDATE` evidence from the files and the bus with the C2 reader idiom.
