# Task Spec — 28: `delivery-run` (sub-task lead conductor)

> Item 28 of design §7 (`part-06-build-plan-and-sources.md:28`), wave W2. Heavy item. Read `build-common.md` first; it is binding.
> Branch/worktree: `delivery-w0` (`wt/delivery-w0`); authors never add, commit or push (the integrator, Worker1, commits).
> Spec status: W2 spec. INTERFACES version read: `1.3.0` (FROZEN; AM-1..AM-3 applied; re-read at writing, §11). AM-4 queue (`SCRATCH/am4-queue.md`) encoded as RESOLVED lines in §11.

| Field | Value |
|---|---|
| Tier | `design` for both pieces and the integration step (§7 row 28-29 "design"); model per `tools/model-routing.md` |
| Review rung | `review-7-panel` (7 seats, up to 3 rounds, then the owner, D7); heavy item per `part-02` §2.4 and `part-06` item 31; G48 pre-round check first (part-03 §4) |
| Depends on | INTERFACES 1.3.0 frozen (done); item 9 `wave-execution` EXTEND, committed `6092662` on `ext/delivery-extends` (W' = `~/projects/agent-hq-worktrees/delivery-extends`; Rung 1 head `297a8dc` keeps the attach contract unchanged); soft (names fixed by INTERFACES, cite only): 17 dispatch-plan, 18 resource-catalog/port-claim, 19 cleanup, 20 pre-pr-gate, 23 shepherd, 24 ci-fix-loop, 27 template `decisions-fork.md`, 27b briefs; scripts 5-7 and `tools/port-check.sh` (agent-hq PR #9) at run time only |
| Parallel with | item 29 `delivery-pipeline` (disjoint directory) |
| Split | 2 pieces (Rule 7, disjoint paths), 1.5 h, then 1 integration step, 0.5 h (§3) |

## 1. Objective
Write `skills/delivery-run/` (SKILL.md plus top-level `references/*.md`): the per-sub-task lead that reads its dispatch plan, owns the sub-task bus (claim, start, `bus.endpoint`, restart), drives the extended `wave-execution` in DAG-frontier mode with `bus_endpoint` attach, runs the merged 10-minute tick (watchdog half), owns the slot ledger and spawn cap, the control channel and resume, handles every `UNIT-VERDICT`, sequences `RELEASE`/`INVALIDATE`, and hands off to `pre-pr-gate`, `ci-fix-loop`, `delivery-cleanup` and (indirectly) `ticket-clerk`, exactly as INTERFACES 1.3.0 freezes them.

## 2. Context Package
- Card: `part-02-skill-inventory.md:60` (card 6). Errata that override it: E9 (inbox canonical), E12, E15 (`max_concurrent` per invocation, `bus_endpoint`, non-release instead of `TaskStop` of dependents), E16 (depth), E20 (watchdog half), E24 (briefs root), E26 (constitution not a wave). Concurrency: `part-03` §3.1 (lead row), §4 (numbers, slot ledger, wave shape, merged tick prompt verbatim at `part-03-personas-and-concurrency.md:92`, rebase-before-verify, reboot). Launcher and backends: `part-05` §6.4. Learnings: `part-06` §7b rows "4 Build", "4 Watchdog tick", "5b Merge".
- Authority (cite by anchor, never restate differently): part A A.1 (paths, namespacing, atomic writes), A.2 (`state.md` readers; modes `build|plan-pr|post-merge`; `pm` host), A.3 (`substate.md`, seed, lock, `stop_reason`, row ids `S1`-`S8`, `bus.endpoint`), A.4 (slot rows, free-slot formula, machine row, security-audit agents), A.5 (catalog, leases), A.5.1, A.5.2 (port claim order, one +10 retry), A.5.3, A.6, A.7 (`GATE-PASS`); part B B1 (registration, host-sends rule, `.out` polling), B4 rows `push`, `pr-create`, `pr-attach`, `pr-comment`, `fetch`; part C C1, C1.1, C1.2, C2, C3, C4, C5.1-C5.3, C6, C7; part D D1, D1.1 (`PREPR:`, `INTEGRATED:`, `LANE:`, `CI:`), D2.2 row 6 (inputs and outputs), D4, D5; §Script interfaces (`catalog.sh`, `desk-req.sh`, `scope-check.sh`).
- Extended controller: W' `skills/wave-execution/SKILL.md` steps 2-8, `references/frontier-mode.md`, `references/spec-format.md` (read with `git -C W' show 6092662:<path>` or at the branch head).
- ADRs: `decisions/0054-*` (A0-A9, accepted), `decisions/0055-*` (desk verbs, accepted). Anatomy: `tools/skill-authoring.md` §2-§5; D16 model-invocable.

## 3. Scope
**Split plan (Rule 7; both pieces read only INTERFACES, the design and W', never each other's drafts):**

| Piece | Owner files (only these) | Content |
|---|---|---|
| P1 SKILL.md (design) | `skills/delivery-run/SKILL.md` | frontmatter; `## Trigger`; `## Steps` (below); `## Red flags`; `## Exit criteria`; `## Provenance`; links to the seven reference files by the exact names below |
| P2 references (design) | `skills/delivery-run/references/{bus-and-ports,ledger,verdicts,control-channel,resume,tick,handoffs-and-modes}.md` | depth per file (below), each at or under about 500 lines |
| Integration (design, 1 agent, after P1 and P2) | the eight files above only | link and term reconciliation, §9 run, hand-off note |

Steps P1 must carry, in order: Step 0 (D1 + D2.2 row 6, the `interfaces_version` compare, `MODE`/`PM_SHA` rule); ORCHESTRATOR-CHECK (Agent tool present, depth-0 session, env `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` >= 30 and `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` an integer, else print the check line and stop; RESOLVED PC-W2-2); lifetime `substate.lock` and seed copy (A.3); machine-ledger row (A.4, RESOLVED PC-W2-1); `REGISTER` line and the `register.consumed` wait before any `DESK` (C5.1, B1); `RELEASE` wait for a dependent sub-task (C6, dispatch-plan sub-task table); reconcile (C5.3 steps 1-5, also on a first start); Wave 0 in-lead (C1); bus claim, start, `bus.endpoint` (A.5.2, C1.1, D5); arm the merged tick (C7); invocation loop (lane leases, `invocation` bump, `max_concurrent`, background call, C2/C4 handling, `tier_override` re-dispatch); `02-integrate.md` and `INTEGRATED` entries; desk `fetch` of the PR base before the `02-integrate.md` invocation and before each `pre-pr-gate` call (RESOLVED Q5); `pre-pr-gate`; stage-5 desk requests; `ci-fix-loop` (and a `pre-pr-gate` re-run when CI fixes moved the head, RESOLVED PC-W2-3); `MERGED` -> `delivery-cleanup`; end of turn (write `substate.md`, print its path). Modes `plan-pr` and `post-merge` branch off after reconcile (A.2).

P2 file contents: `bus-and-ports.md` A.5.2 order, the one claimed +10 retry and pin, pm2 start with `PORT_RANGE_START=PORT_RANGE_END`, `$DATA_DIR/port` equality, catalog `port`/`pm2-app`/`bus` rows, atomic `bus.endpoint`, `pm2 restart` only, bus-down rule; `ledger.md` A.4 rows (lead-dispatched, the `wave-controller` row, dispatch-record agents), free-slot formula, reserved seats (PC-W2-6), `.freed` rules, `spawns`, `<cap>` and hand-over (Q2), machine row (PC-W2-1), lane and `gate-runner` leases, security-audit agents; `verdicts.md` C2 schema, lead filter, verdict-reason matrix, `PASS` head check plus one load-bearing command, two-mismatch stop, `ROLLED`, `ESCALATE`, `-escalation` drain, C4 relay, C3 `NEXT:`, the `step_complete` gate reading (spec 9 Q3); `control-channel.md` C5.1 layout, inbox naming and order, `REGISTER`, `MERGED`, C5.2 per-backend table, C6 `RELEASE`/`INVALIDATE`, desk send and `.out` polling (B1); `resume.md` C5.3 triggers, steps 1-6 incl. 3a/3b, hand-over, lock break (A.3); `tick.md` the design §4 prompt verbatim, C7 watchdog half, shepherd invocation rule, orphan sweep, "not a stall", `ticks.md` appends, `TaskStop` order; `handoffs-and-modes.md` Wave 0, `pre-pr-gate` inputs (D2.2 row 10), push/`pr-create`/`pr-attach`/`pr-comment` order (B4), `ci-fix-loop` inputs (row 11) and `CI:` copy, `MERGED` -> cleanup mode `subtask` with `MERGE_RECORD`, `pm` cleanup, ticket events via `substate.md`, modes `plan-pr` and `post-merge`, `.decisions` fork flow citing `references/templates/decisions-fork.md`.

**Out of scope:** `references/briefs/**` (item 27b) and `references/templates/**` (item 27) — never written (PC-3); `wave-execution` and every W1 directory (PC "28 and 29 must not edit the W1 directories"); `delivery-pipeline` (item 29: conductor, launcher spec, `--disallowedTools`); INTERFACES and ADRs (a gap is a `.decisions/28.md` fork or STUCK); scripts.
**Do NOT create:** scripts or tests under the skill; a second `bus.endpoint` writer or a bus restarter other than this skill; a port auto-pick or a second retry; a `disable-model-invocation` key; a reservation row; any `TaskStop` decided by the shepherd; cost metrics (B-4); symlinks; installs; web fetches.

## 4. Contracts
| Contract | Value | Authority |
|---|---|---|
| Inputs | `DELIVERY_ROOT` (env), `RUN_HOME`, `SUBTASK`, `MODE`, `BACKEND`, `PLANS_DIR`, `REPO_PROFILE` (@sha), `REPO`, `SESSION`, `PM_SHA` (post-merge), `SECURITY_AUDIT`; `NAME=value`; `INPUT-ERROR <field> <reason>` per field, then stop | D1, D2.2 row 6, R4-J16, R4-J23 |
| Bus | `session_id` `<run-id>-<subtask>`; topic `<run-id>-<subtask>-rendezvous`; `data_dir` `RUN_HOME/<subtask>/bus/`; port `ports.bus_base + 20·2N` (P8 row, AM-4 W2-3 spacing), claimed before start, pinned; one claimed retry at +10, second refusal or `port-check.sh` exit 3 = `stop_reason: port-refused` | C1.1 bus port, A.5.2 (AM-3 OQ-2), D4, D5, AM-4 W2-1, W2-3 |
| `bus.endpoint` | key=value `port data_dir pm2_app pid session_id topic`, atomic, before any dispatch; `session_id=`/`topic=` equal the bundle's, mismatch = stop row | A.3, D5 |
| Controller call | extended `wave-execution`, `bus_endpoint` = `<run-id>/<subtask>/bus.endpoint`; caller args `max_concurrent` = `30 - live_rows - sum(reserved)`, `invocation` (bumped in `substate.md` before each call), `tier_override` `<unit>=<tier>`; background Agent task, lead idles, cron handles C2/C4/C7 | C1.1, A.3, A.4, R4-J12, R4-J13, R4-J15 |
| Dispatch record | `RUN_HOME/<subtask>/dispatch/<invocation>.jsonl`; one slot row per recorded `agent_id`, `worktree` derived by the lead | C1.1, A.4 |
| Verdict | bare JSON `{unit, verdict, head, reason}`, registered `from_agent` only, `peek:true`, fresh `agent_id`, `limit 200` | C2, C4 |
| Tick | session cron every 10 min, armed by the lead for both backends; watchdog half every tick: `STALLED`, `PROMPT-OPEN`, bus-down, orphan sweep, `.verdict` relay, inbox read; shepherd half via `delivery-shepherd` at 3+ live agents (it also flags `STALLED`/`PROMPT-OPEN`, AM-3) | C7, part-03 §4 |
| Control | inbox canonical, `<seq>` order, `.consumed`; `SendMessage` only `INBOX <subtask>`; `RELEASE`/`INVALIDATE` from the conductor only | C5.1, C5.2, C6 |
| Resume | brief `resume <subtask>: re-read substate.md, inbox/ and gates/`; C5.3 steps; checkpoint is the sole authority | C5.3, O-Q6 |
| Hand-offs | `pre-pr-gate` (row 10) -> `prepr`, `head`, `review_record`; `push` then `pr-create` (`record_path`, `expect_head`) then `pr-attach` then `pr-comment`; `ci-fix-loop` (row 11) -> `ci`; inbox `MERGED` -> `delivery-cleanup` mode `subtask` | A.3, B4, D2.2 rows 9-11, C5.1 |

## 5. Inherited module API
`tools/delivery/catalog.sh` (`register|start|release|fail|keep|list --live|audit`, env `RUN_HOME`, `WORKTREE_BASE`), `desk-req.sh <run-id> <subtask|run> <verb> <fields-json-file>`, `scope-check.sh <tasks-file> <worktree> <base-sha>` (§Script interfaces); `port-claim` skill / `tools/port-check.sh --claim ...` (A.5.2); `swarm-communication` bus calls; W' `wave-execution` caller surface (step 4 attach, step 6.2 dispatch record, step 8 no `cleanup()` under attach); sibling skills by named inputs only (D2.2 rows 7, 9, 10, 11). Use them; do not reimplement.

## 6. What you inherit
COMMON block conventions (§3.0; briefs carry it, the lead copies nothing, R4-J14); tier names not models (M19); D10 (lead decides `TaskStop`); D7 (round 3 stop); D16; ADR 0014 T1; `tools/check-doc-length.sh`; version rule (NEW skill starts at `version: 0.1.0`, INTERFACES §Build branch and version rule).

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| `max_concurrent` | caller argument per invocation, free-slot formula | spec field, per wave, 30 | C1.1, E12 |
| gate/fix agents | count toward `max_concurrent`, get slot rows | reservation rows | A.4, O-Q3 |
| Port refusal | one claimed retry at +10 (P8 candidate + 10), then `stop_reason: port-refused`; exit 3 = no retry, same stop | auto-pick, second retry, "never retry", recomputing the candidate | A.5.2, AM-3 OQ-2, AM-4 W2-1, W2-3 |
| Bus restart | `pm2 restart` by the lead only; two failures `stop-the-line:S8` | `reload`, `pm2 start` twice, controller restarts | C1.1, C7 |
| Gate failure | dependents never released; lead `TaskStop`s only live agents | `TaskStop` of dependents | A5, E15, C1.2 |
| `ROLLED` | fresh invocation with `tier_override` one tier up; never a third top-tier attempt | one more budget | C2, C7 |
| `PASS` | `git rev-parse` equals `head` plus one load-bearing command, then `.freed` | trust the post | C2, M15 |
| Conductor channel | inbox file canonical; `SendMessage` = `INBOX <subtask>` | message body by `SendMessage` | C5.2, E9 |
| Briefs | dispatched agent reads its `Brief:` line; lead copies nothing | lead pastes briefs | C1.2, R4-J14 |
| `next_step` | `<unit>.<n>` | `step_id` | C3 |
| First push | stage 5, after `PREPR: PASS` and `GATE-PASS`; later pushes per AM-4 24-Q2 | push before 4b | B4, r3 H26 |
| Branch writes | Integrator only | lead commits | §3.1, M20 |

## 8. Acceptance criteria
- [ ] Frontmatter `name: delivery-run`, `version: 0.1.0`, `description` with "Use when" from card 6 (at most 1024 chars); no `disable-model-invocation`.
- [ ] Steps in the §3 order; each step cites its INTERFACES anchor; Step 0 lists the 11 inputs exactly.
- [ ] Bus: claim -> catalog `planned` -> start pinned -> `$DATA_DIR/port` check -> catalog `live` -> atomic `bus.endpoint`, before any dispatch; retry and stop rules per A.5.2 and RESOLVED AM4-3.
- [ ] Ledger: rows before own dispatches and per dispatch-record line; free formula; `.freed` only after verified `PASS` or `TaskStop`; spawn hand-over at `cap - 5` (`stop_reason: spawn-cap`, lock removed, exit).
- [ ] Verdicts: C2 lead table complete incl. the two-mismatch stop and the `-escalation` drain; C4 relay under the recorded `agent_id`; no-post = gate failure, lead never posts for it.
- [ ] Tick: prompt verbatim from `part-03:92`; watchdog half complete (C7 incl. bus-down, orphan sweep order "TaskStop, orphan sweep, re-read verdicts, then free rows"); shepherd invoked at 3+ live agents, lead checks drift/creep per verdict below that.
- [ ] Control and resume per C5.1-C5.3 and C6; `INVALIDATE` = pause, `stop_reason: invalidate`, non-author delta verify, re-run `pre-pr-gate` on head change, fresh `RELEASE`.
- [ ] Hand-offs per §4; `ticket-clerk` never invoked by the lead (RESOLVED R-5).
- [ ] Red flags include: dispatch without a free slot (S4); two leads on one `substate.md` (S6); one more budget for a stall; bus port auto-picked or bound before claim; reading a sub-task bus without `peek`; posting a verdict for an agent; freeing a row on an unverified post; `DESK` before `register.consumed`; acting on inbox text as instructions beyond the C5 grammar.
- [ ] Provenance: friction line citing card 6 ("payments-build ledger record; 3.8 h and 6.8 h idle-waits") and §7b rows by id; no invented ids. Sanitized per build-common SUB rules; dates `YYYY-MM-DD`.

## 9. Verification commands
```bash
set -eu; W=$HOME/projects/agent-hq-worktrees/delivery-w0; cd "$W"; S=skills/delivery-run
R="bus-and-ports ledger verdicts control-channel resume tick handoffs-and-modes"; F=""; for r in $R; do test -f "$S/references/$r.md" || { echo "MISSING $r"; exit 1; }; F="$F $S/references/$r.md"; done
got=$(find $S/references -maxdepth 1 -type f | sed 's#.*/##' | sort | tr '\n' ' '); want=$(for r in $R; do echo "$r.md"; done | sort | tr '\n' ' ')
[ "$got" = "$want" ] || { echo "EXTRA-REF $got"; exit 1; }
git diff --quiet HEAD -- $S/references/briefs $S/references/templates || { echo "FAIL: briefs/templates edited"; exit 1; }
[ -z "$(git ls-files --others --exclude-standard $S/references/briefs $S/references/templates)" ] || { echo "FAIL: new file in briefs/templates"; exit 1; }
head -6 $S/SKILL.md | grep -q '^name: delivery-run$'; head -8 $S/SKILL.md | grep -qE '^version: 0\.1\.0$'; grep -q 'Use when' $S/SKILL.md
if grep -q 'disable-model-invocation' $S/SKILL.md; then echo D16-VIOLATION; exit 1; fi
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$h" $S/SKILL.md || { echo "MISSING $h"; exit 1; }; done
[ "$(wc -w < $S/SKILL.md)" -le 3700 ]; bash tools/check-doc-length.sh "$W" >/dev/null
for t in INPUT-ERROR ORCHESTRATOR-CHECK interfaces_version substate.lock port-check.sh PORT_RANGE_START bus.endpoint 'pm2 restart' max_concurrent tier_override step_complete 'dispatch/' 'slots/' .freed spawn-cap STALLED PROMPT-OPEN stop-the-line:S8 port-refused RELEASE INVALIDATE MERGED register.consumed 'machine/' wave-controller CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION fetch UNIT-VERDICT pre-pr-gate ci-fix-loop delivery-cleanup delivery-shepherd TaskStop 'peek'; do
  grep -qF -- "$t" $S/SKILL.md $F || { echo "MISSING $t"; exit 1; }; done
python3 -I - architecture/delivery-workflow $S <<'PY'
import sys,pathlib
d=pathlib.Path(sys.argv[1]); s=pathlib.Path(sys.argv[2])
c=(d/'interfaces/part-c-waves-control.md').read_text(); p3=(d/'part-03-personas-and-concurrency.md').read_text()
body=''.join(f.read_text() for f in [s/'SKILL.md',*sorted((s/'references').glob('*.md'))])
need=[('C','^REGISTER ([a-z0-9-]+) (st[0-9]+|pm) ([^ ]+) ([a-z0-9-]+)$'),('C','^MERGED (st[0-9]+) ([0-9a-f]{40})$'),('C','^NEXT: (u[0-9]+)\\.([0-9]+) .+$'),
 ('C','NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>'),('C','resume <subtask>: re-read substate.md, inbox/ and gates/'),
 ('P','Stall watchdog and shepherd tick: for every subagent and background task, check state now'),('P','One line only if something changed; otherwise noop.')]
for src,n in need:
    assert n in (c if src=='C' else p3), ('not in source',n)
    assert n in body, ('missing verbatim',n)
print('VERBATIM-OK')
PY
if grep -nE '/Users/xavier|brainAlpha|Xavier|touri|Notion|runfrist|jetblue|\$[0-9]' $S/SKILL.md $F; then echo "FAIL: forbidden"; exit 1; fi
if grep -nE '(^|[^a-z])(ps -|pgrep)' $S/SKILL.md $F; then echo "FAIL: ps"; exit 1; fi
if find $S -type l | grep -q .; then echo "FAIL: symlink"; exit 1; fi
echo SKILL-28-OK
```
**Done condition (one, machine-checkable):** the block exits 0 and its last stdout line is `SKILL-28-OK`; then the `review-7-panel` record is 0 Blocking / 0 Medium, or a D7 stop is handed to the owner.

## 10. Branch and worktree
`~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`); read W' only. No git add/commit/branch/push/rebase. File scope dirs: `skills/delivery-run/SKILL.md` and `skills/delivery-run/references/` top-level files only (not `briefs/`, not `templates/`). Integrator commits P1, P2, then the integration once.

## 11. Decision Gate, resolutions and amendment note
Write `.decisions/28.md` (fork, options, recommendation, `Outcome: Blocked`) and stop on: a conflict between INTERFACES and W' `wave-execution`; any behaviour neither states; a need to write outside §10. Pre-flight six checks: inherit (§6), risky values (§7), module API (§5), do-not-create (§3), criteria checkable by §9, every risky value sourced (§7).
- RESOLVED R-1 (PC-3, spec 27b Q3, spec 27 Q3): no file under `references/briefs/` or `references/templates/`; §9 checks it.
- RESOLVED R-2 (plan-check §3 "28 owns the bus claim (PC-4), the watchdog half (PC-5) and the C2 wording for `step_complete` (spec 9 Q3)"; C1.2 verifier row): the `step_complete` gate reads the work_item's C2 record and the unit branch at its `head`; that wording lives in `verdicts.md`.
- RESOLVED R-3 (C7, D2.2 row 7, AM-3 OQ-3): both halves raise `STALLED`/`PROMPT-OPEN`; two flags for one agent collapse to one lead action; the watchdog half also runs below 3 live agents.
- RESOLVED R-4 (A.1 namespacing; W' step 4 name form): pm2 app `swarm-mcp-<session_id>`, `data_dir` `RUN_HOME/<subtask>/bus/` (never `/tmp`, D4); the bus is started per `swarm-communication` with the pinned range.
- RESOLVED R-5 (A.6 `ticket-clerk` host = conductor only; D3 event writer = conductor from `substate.md`): the lead's hand-off to `ticket-clerk` is its `substate.md` fields (`phase`, `prepr`, `ci`); it never invokes `ticket-clerk` or sends `jira-*`.
- RESOLVED AM4-1 (AM-4 queue 24-Q2): the lead's first push of a PR needs `PREPR: PASS` for that head; later pushes to the same PR (CI fix rounds) need the `GATE-PASS` record for the head plus `RUN_HOME/ci/<pr>.md` naming the head; no gate change.
- RESOLVED AM4-2 (AM-4 queue 11-Q11-R1): an `INPUT-ERROR` answer from a skill the lead invokes is no D7 round and no fix-verifier iteration; the lead fixes the input and re-invokes with the same iteration.
- RESOLVED AM4-3 (AM-4 queue 27b): after the one +10 retry is refused the lead writes `stop_reason: port-refused` in `substate.md` and stops; the conductor reports to the owner. The fixer one-MODEL-step rule (ADR 0014 T1, E25) is the review loops' and does not change C2 `ROLLED` handling; the Wave 0 Explorer is mechanical by default, execute for multi-step derivations.
- RESOLVED AM4-4 (AM-4 queue 27): the A.2 example's `interfaces_version: 1.1.0` is stale and not authoritative; Step 0 compares the live `state.md`, plan header and seed values. AM-4 queue 24-Q1, 11-Low and 12-OQ1..5 do not touch this item.
- RESOLVED Q1 (A.4 "the gate runner and every other agent get a row"; C1.1 call model; the session concurrency cap counts the controller as a live subagent; AM-4 W2-2): the controller background task takes one slot row, written before its Agent call: `persona` `wave-controller` (D2.1 token added by AM-4 W2-2; no brief file), `unit` `-`, `tier` the wave `agents` tier, `budget_min` = the sum of the invocation's work_item `budget_min` values (an upper bound; `STALLED` on it is `TaskStop`, never one more budget), `worktree` the sub-task worktree, `pid` `<lead-pid>/<agent-id>`. `max_concurrent` is computed after that row exists, so `30 - live_rows - sum(reserved)` already subtracts it. The row is renamed `.freed` when the task returns (TaskList) and its step 8 final result is noted, or after a `TaskStop`. It counts in `spawns`. At most one live invocation per sub-task (one checkpoint); a `ROLLED` re-dispatch waits for the live invocation to return.
- RESOLVED Q2 (A.3 `spawns`, C5.3 hand-over; PLAN-CHECK DEFAULT for the count; AM-4 W2-8): `spawns` = every Agent call made in the lead session, its own and those of the skills it hosts (`pre-pr-gate`, `ci-fix-loop`, `delivery-cleanup`, the shepherd and review seats), plus every dispatch-record line (nested spawns are counted because whether the session cap counts them is unmeasured). `<cap>` = env `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION`, read at ORCHESTRATOR-CHECK; unset or not an integer fails the check (fail closed). Before any own Agent call the lead requires `spawns + 1 <= cap - 5`; before each invocation also `spawns + 1 + (dispatch_budget - dispatch-record lines so far) <= cap - 5`. Otherwise it runs the C5.3 hand-over (`stop_reason: spawn-cap`, lock removed, exit) while no invocation is live.
- RESOLVED Q3 (A.5.2 "exit 3 (registry unusable) is stop-the-line"; AM-4 queue 27b; AM-4 W2-1): exit 3 on any lead-owned claim (the sub-task bus or its retry), and a review-bus stop that `pr-review` reports through `pre-pr-gate` (`PREPR: STOP` with the refusal line, C12), are written `stop_reason: port-refused`; there is no retry after exit 3. The conductor names the P8 candidate and its +10 retry from `dispatch-plan.md`; the lead writes no extra file.
- RESOLVED Q4 (AM-4 W2-3, port spacing): candidates are `<base> + 20·k` (`st<N>` bus `k = 2N`, review bus `k = 2N + 1`, lane binds by bind index), so every candidate sits on an even multiple of 10 from its base and its one +10 retry on an odd one that no candidate uses; one retry can never land on another candidate, and no cascade into `st<N+1>` exists. The lead claims the P8 `candidate` cell as written (it never recomputes the formula) and retries at that value + 10.
- RESOLVED Q5 (B1 "each runs inside a host session and its `DESK` line is sent by that host"; AM-4 W2-4): the lead sends `fetch {repo: REPO, ref: <PR base>}` and reads its `.out` before the invocation that runs `02-integrate.md` and before each `pre-pr-gate` call; the Integrator and `pre-pr-gate` rebase onto the fetched remote ref and never send `DESK`.
- RESOLVED PC-W2-1 (A.4 machine row; C5.2 "registers its machine-ledger row first"; AM-4 W2-9): every lead, both backends, writes `$DELIVERY_ROOT/machine/<SESSION>.row` after the seed copy and before `REGISTER`, under `machine/.lock`, after re-summing against 200 and rule 8 (`build=1` only in `MODE=build`); over either cap it writes `stop_reason: human`, prints the reason and stops. It rewrites `live_count` (= `.row` count + `sum(reserved)` + 1 for its own session) atomically on every tick. For a `claude -p` lead the conductor has already summed before launch; the lead's re-check under the lock closes the race.
- RESOLVED PC-W2-2 (§6.4 launcher assertion covers only `claude -p`; A.4 formula assumes 30): ORCHESTRATOR-CHECK also requires env `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` >= 30, since an `agent-tool` lead is started by the owner, not by the launcher.
- RESOLVED PC-W2-3 (B5 FROZEN: `pr-merge` re-derives the review record `record-<head>.md` on the landing head; AM-4 W2-7): when `ci-fix-loop` ends `CI: GREEN <sha>` with `<sha>` not equal to `head`, the lead re-runs `pre-pr-gate` with `HEAD=<sha>` (step 1 delta verify) so `prepr`, `head` and `review_record` name `<sha>` before the conductor can merge. A later push (AM4-1) also passes on `PREPR: PASS` for its head.
- RESOLVED PC-W2-4 (ci-fix-loop steps 6, 9, 12; A.3 `stop_reason`): the lead maps `ci/<pr>.md` line 1: `CI: HUMAN policy` -> `stop-the-line:D23`; a round-3 stop (open findings below line 1 and a round-3 `verify-*` that is not CLEAN) -> `d7-round3`; any other `CI: HUMAN` -> `human`.
- RESOLVED PC-W2-5 (AM-4 queue 23; C7): the watchdog half sends the one fixed-template `NUDGE` for a flag line it appends to `shepherd/ticks.md`; a line already present (either half) gets no second nudge.
- RESOLVED PC-W2-6 (A.3 `reserved`, A.4 reserved-seat rule): `ci-fix-loop`'s diagnoser, fixer, G48 checker and fix-verifier run one at a time under `ci: 1`; its gate runner gets a slot row. `pre-pr-gate`'s seats run under `review: 10`; its gate runner, G48 checker, fixer, fix-verifier, validator, Verified-By seat and security auditors get rows. The lead's `clerk: 1` stays reserved but unused (the clerk runs only in the conductor, A.6).
- RESOLVED PC-W2-7 (C1.1 call-model fallback): whether a session cron fires inside a `claude -p` lead is unmeasured; the move probes it, and if it does not fire the lead runs each invocation blocking and the watchdog half between invocations (C1.1).
- RESOLVED PC-W2-8 (C5.1, AM-4 W2-4 and W2-5): an `outbox/<id>.desk.refused` file is terminal `sender` for the lead at once (`.req.noreply`, escalation `human-step`, B1). At resume the new lead clears `stop_reason: spawn-cap`; it clears `invalidate` when the fresh `RELEASE` is consumed.
- AM re-check (1.3.0): AM-1 (bus and lane port claims, `SECURITY_AUDIT` passed on, security-audit agents in the ledger), AM-2 (rows 1, 3, 6, 8, 11, 14: `WORKTREE_BASE`, audit lines, port table, `PREPR: STOP C26`, `ticks.md` writer, abandoned run), AM-3 (one +10 retry, `lane-unavailable`, shepherd stall flags, `constitution.md`/`bundle.md`) are all reflected above. AM-4 rows W2-1..W2-10 (plan-check W2, `reviews/plan-check-w2-specs.md`) are treated as decided. Re-read INTERFACES `Amendments` before finishing; a later amendment touching parts A/C/D means update this spec and the skill, or mark STUCK.
