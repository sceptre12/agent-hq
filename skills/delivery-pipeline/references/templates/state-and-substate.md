# Template: `state.md` and `substate.md` (design 5.0; INTERFACES A.2, A.3, A.4)

Fill-in skeletons for the two run-state files and the two single-line records that sit beside them (slot row, machine ledger row). Every field name, enum and regex below is copied from `INTERFACES.md` 1.9.0 (AM-6 to AM-9 applied); if this file and INTERFACES differ, INTERFACES wins and this file is the defect. Regex dialect: POSIX ERE.

- **Writer / Reader (`state.md`):** writer the conductor (`delivery-pipeline`) only. Readers: conductor at resume, `delivery-run` Step 0 (`interfaces_version` only), `delivery-desk` (gate pointers, `plans_dir`, `repo_profile` pinned `@<sha>`), the human.
- **Writer / Reader (`substate.md`):** writer the sub-task lead only, except that the desk clears `stop_reason` when it writes `RESUME.<subtask>.<run-id>.ok` (the S6 carve-out, INTERFACES 1.9.0 AM-9 G1/42). Readers: conductor (never the bus), shepherd tick, lead at resume. Two writers on one `substate.md` is otherwise stop-the-line `S6`.
- **Writer / Reader (slot row):** the lead writes, renames `.row` to `.stale` or `.freed`; the shepherd never writes rows (it flags `FREE-CANDIDATE <agent>`).
- **Plane:** all of these are RUN (`RUN_HOME` = `$DELIVERY_ROOT/<run-id>`, never `/tmp` or `$TMPDIR`; INTERFACES A.1, D6).
- **Atomic write (A.1):** write a temp file in the same directory, then `mv` into place. One YAML document per file, no front matter.
- **Date and time:** timestamps inside file bodies are `YYYY-MM-DDTHH:MM:SSZ`; the compact `yyyymmddThhmmssZ` appears only in identifiers and file names.

## Part 0. Token shapes used below (A.1)

| Token | Shape |
|---|---|
| `<run-id>` | `^[a-z0-9-]+$`; `<epic-key-lowercased>-<yyyymmdd>`, or provisional `run-<n>-<yyyymmdd>`; never renamed |
| `<epic>` | `^[A-Z][A-Z0-9]+-[0-9]+$`, original case |
| `<subtask>` | `^(st[0-9]+\|pm)$`; `st0` is the plan PR; `pm` hosts stages 6-7; `run` only in a desk id or catalog row |
| sha | 40-hex `^[0-9a-f]{40}$`, never abbreviated |
| unit id | `^u[0-9]+$`; Integrator work_item `^i[0-9]+$`; where either may appear `^[ui][0-9]+$` |
| `agent_id` | `^[a-z0-9-]+$` |
| `session` (launcher name) | `^[a-z0-9-]+$`, distinct from the bus `session_id`; a lead's is `<run-id>-<subtask>-l<n>` (`n` the launch count for that sub-task, from 1), the conductor's `<run-id>-c<n>` (A.8, 29-1) |

## Part 1. `state.md` (conductor; A.2)

Path: `RUN_HOME/state.md`. A gate field holds a pointer, never a verdict (M30): a verdict is a gate file the desk writes after the human types the confirmation, or external evidence the desk reads back. An agent never writes under `gates/`.

```yaml
orchestrator_tier: design             # design|execute|verify|mechanical; the conductor's own tier, written at stage 1 (AM-3 errata (g))
run_id: <run-id>                      # last path segment of RUN_HOME
epic: <epic>                          # original-case key; the run-id cannot be reversed to it
plans_dir: <abs path>                 # primary repo plans/<epic>/ (plans/<run-id>/ when the run-id is provisional)
primary_repo: <abs path>              # clone root from the PRIMARY_REPO input at stage 1
repo_profile: <abs path>@<sha>        # link plus sha, never a copy (D22); from the intake PROFILE: token
delivery_root: <abs path>             # equals $DELIVERY_ROOT at write time
stage: 1                              # 1|2|3|4|4b|5|5a|5b|5c|6|7|8|done|stopped
gates:
  H0: <abs path to RUN_HOME/gates/H0.ok, or empty>
  H1: <abs path to RUN_HOME/gates/H1.ok, or empty>
  H-e2e: []                           # list of RUN_HOME/<subtask>/gates/H-e2e.<subtask>.ok paths
  H-pr: []                            # list of gh:<owner>/<repo>#<pr>@<commit_id> pointers (desk read-back)
  H-prod: []                          # list of RUN_HOME/gates/H-prod.<step_id>.ok paths
subtasks:
  - id: st0                           # <subtask>
    session: <session>                # <run-id>-<subtask>-l<n>; names its machine/<session>.row; never launched again under this token
    lead_id: <identity or ->          # from the lead's REGISTER line; - for claude-p
    backend: agent-tool               # agent-tool|claude-p
    state: planned                    # planned|released|building|pr-open|merged|stopped|cleaned
    pr:                               # int once the pr-create .out exists, else empty
    merge_sha:                        # 40-hex from the pr-merge .out; empty until merged
    released_utc:                     # ISO UTC when RELEASE was written, else empty
    launched_utc:                     # ISO UTC, set in the one launch-intent write (A.8, 29-13)
    relaunch_phase:                   # substate.md phase at a relaunch; empty at first launch
    reentered: false                  # true|false; set with reentered_utc at a back-edge, kept
    reentered_utc:                    # ISO UTC of the back-edge, else empty
    pm_sha:                           # post-merge re-entry st<N> only: the pm_sha it was added for, in the same write (A.8, 29-36)
    stop_reason:                      # conductor-detected stops only (stale-session, ledger refusal, relay refusal), A.3 enum; else empty (INTERFACES 1.9.0 AM-9)
h1_handled:                           # <H1 file name> <utc>: the H1.* file already handled (A.8, 29-17)
skill_versions:
  delivery-pipeline: <version>@<sha256 of installed SKILL.md>
  # one entry per skill the run uses: name: <version>@<sha256>
interfaces_version: <version>@<sha256 of INTERFACES.md>   # e.g. 1.5.0@<64-hex>
security_audit: guidance              # guidance|full (AM-1); default guidance
machine_ledger_row: <abs path>        # $DELIVERY_ROOT/machine/<session>.row of the conductor session
```

### 1.1 Field rules

| Field | Rule (INTERFACES) |
|---|---|
| `orchestrator_tier` | `design\|execute\|verify\|mechanical`; written at stage 1 from `tools/model-routing.md`; when it is not `design`, `review-tailor` applies the review ladder's +1 rung modifier (`tools/review-ladder.md`); AM-3 errata (g) |
| `stage` | closed enum; `done` after CYCLE DONE, `stopped` after a run-level stop |
| `gates` | `H0`, `H1` scalar; `H-e2e`, `H-pr`, `H-prod` lists; values are paths or external-evidence pointers (A.2.1) |
| `subtasks[].state` | transitions in 1.2; `released` only after `RELEASE` (part C6) |
| `skill_versions` | value encodes version plus hash: `<version>@<sha256 of SKILL.md>` (`ls -L`, `shasum -a 256`) |
| `interfaces_version` | consumers re-check after an amendment; `delivery-run` Step 0 compares it with the dispatch-plan header |
| `security_audit` | the conductor sets `full` only on an explicit operator request or when `architecture.md` carries the header line `security_sensitive: yes`; it is passed on as the input `SECURITY_AUDIT` (D2.2, D2.3). Guidance mode writes no file and launches no agent. AM-1 |
| `subtasks[].launched_utc`, `relaunch_phase` | written with `session` (and `state: released` when released at launch) in one `state.md` write, after every fail-closed check and the worktree add, before the exec (A.8, 29-13); a lead with no `substate.lock` newer than `launched_utc` and no `register.consumed` 10 minutes after it, and no live `homes/<session>/pid`, is a startup failure (one-relaunch rule) |
| `subtasks[].reentered`, `reentered_utc` | set together at a back-edge, which also clears `merge_sha` in the same write, before any `INVALIDATE` file (C8) |
| `subtasks[].stop_reason` | written by the conductor for the stops it detects (`stale-session` from a `RUN_HOME/pm/outbox/stop-<utc>.md` file, a ledger refusal, a relay refusal), A.3 enum; the lead's own stops stay in `substate.md`; emptied in the same write that moves the sub-task out of `stopped` on `RESUME.<subtask>.<run-id>.ok` (INTERFACES 1.9.0 AM-9 G1/6, G1/42) |
| `h1_handled` | an `H1.*` file is handled once, keyed on its `utc=` (A.8, 29-17) |
| `primary_repo` | recorded before `plans_dir` is created; in a multi-repo epic the primary profile governs and links the others (`linked_profiles[]`, A.2.2) |

### 1.2 `subtasks[].state` transitions (conductor writes)

| Event | New state | Source of truth |
|---|---|---|
| stage 3 plan accepted | `planned` | dispatch plan |
| `RELEASE` written (or launch of an independent sub-task) | `released` | conductor |
| `phase: building` read in the lead's `substate.md` | `building` | `substate.md` |
| `pr-create` `.out` | `pr-open` (`pr` set) | desk result |
| `pr-merge` `.out` | `merged` (`merge_sha` set) | desk result |
| `stop_reason` in `stop-the-line:*\|d7-round3\|human\|port-refused\|stale-session` (`stale-session` is recorded by the conductor in `state.md` `subtasks[].stop_reason` from a `pm/outbox/stop-<utc>.md` file and is also a human step, INTERFACES 1.9.0 AM-9 G1/6; `spawn-cap` keeps the state and triggers a C5.3 relaunch; `invalidate` keeps it until the fresh `RELEASE`) | `stopped` | `substate.md`, or `state.md` `subtasks[].stop_reason` for a conductor-detected stop |
| `RUN_HOME/gates/RESUME.<subtask>.<run-id>.ok` (desk-written, owner action) | leaves `stopped`: the only exit | A.8, B9 |
| `CLEANUP DONE <subtask>` | `cleaned` (for `pm` only once `release_record` line 1 is terminal and `cleanup-<run-id>-pm.md` is newer than the current `pm` `launched_utc`) | cleanup record |
| back-edge: sub-task re-enters stage 4 | `pr-open` or `merged` to `building`; `merge_sha` cleared in the same write when `INVALIDATE ... predecessor-reentered` goes to successors | part C6 |
| `POSTMERGE: FAIL` | new entry `st<N>` (next free integer), state `planned`, then stage 4 for it | A.2 post-merge re-entry |
| after the last sub-task merges | add entry `id: pm`, start its lead with inbox `RELEASE pm` | A.2 stages 6-7 host |

The mapping is forward only along `planned -> released -> building -> pr-open -> merged -> cleaned` (`stopped` from any state); the back-edge is the one backward write (A.8, 29-37).

### 1.3 Gate files the pointers name (A.2.1; the desk is the only writer)

Every gate-file name carries the run id, `<gate>.<run-id>.ok` (AM-5 26): read each file name below with that suffix, e.g. `H0.<run-id>.ok`, `H-e2e.<subtask>.<run-id>.ok`.

| Gate | File or pointer | Content |
|---|---|---|
| H0 | `RUN_HOME/gates/H0.ok` | key=value lines `utc=`, `by=`, `ref=` (sha256 of `plans_dir/brief.md`), `text=` |
| H1 | `RUN_HOME/gates/H1.ok`, `H1.changes` or `H1.reject` (with `notes=RUN_HOME/gates/H1.notes.md`) | same form; `ref=` sha256 of `h1-packet.md` or `jira:<KEY>@<comment-id>`; only `.ok` unlocks `jira-create` |
| H-e2e | `RUN_HOME/<subtask>/gates/H-e2e.<subtask>.ok` | same form; `ref=` sha256 of the batched `.feature` list in `test-plan.md` |
| H-pr | pointer only `gh:<owner>/<repo>#<pr>@<commit_id>` | no file |
| H-prod | `RUN_HOME/gates/H-prod.<step_id>.ok`, one per human release step | same form; `ref=` the release-plan `step_id` |
| grant | `RUN_HOME/gates/grant.<subtask>.<n>.ok` | same form; `ref=` names the sensitive path (`pre-pr-gate`, AM-4 20) |
| H-destructive | `RUN_HOME/gates/H-destructive.<row-id>.ok` | same form; `post-merge-verify` refuses a destructive row without it (AM-5 21) |
| RESUME | `RUN_HOME/gates/RESUME.<subtask>.ok` | written on `GATE <run-id> RESUME.<subtask> ok <text>` (B9); the only exit from `stopped` (A.8) |

`state.md` holds no separate Jira pointer; a Jira-side H1 approval lives in the `ref=` of `H1.ok`.

### 1.4 Example (shapes only; replace every value)

```yaml
orchestrator_tier: design
run_id: found-1234-20261102
epic: <JIRA-KEY>-1234
plans_dir: /abs/repo/plans/<JIRA-KEY>-1234
primary_repo: /abs/repo
repo_profile: /abs/repo/plans/repo-profile.md@<40-hex sha>
delivery_root: /abs/delivery
stage: 4
gates: {H0: /abs/delivery/found-1234-20261102/gates/H0.found-1234-20261102.ok, H1: /abs/delivery/found-1234-20261102/gates/H1.found-1234-20261102.ok, H-e2e: [], H-pr: [], H-prod: []}
subtasks: [{id: st0, session: found-1234-20261102-st0-l1, lead_id: lead-st0, backend: agent-tool, state: merged, pr: 812, merge_sha: <40-hex sha>, released_utc: 2026-11-02T10:14:00Z, launched_utc: 2026-11-02T10:13:30Z, relaunch_phase: , reentered: false, reentered_utc: }]
h1_handled: H1.found-1234-20261102.changes 2026-11-02T09:40:00Z
skill_versions: {delivery-pipeline: 0.1.0@<sha256>}
interfaces_version: 1.5.0@<sha256>
security_audit: guidance
machine_ledger_row: /abs/delivery/machine/found-1234-20261102-c1.row
```

## Part 2. `substate.md` (lead; A.3)

Path: `RUN_HOME/<subtask>/substate.md`. Created by the lead from `substate.seed.md` (copied verbatim into `RUN_HOME/<subtask>/` at lead start, never edited). The seed holds exactly: `subtask_id`, `session_id`, `reserved`, `frontier`, `interfaces_version`, `phase: seeded`. In modes `plan-pr` and `post-merge` the lead initializes from `subtask_id`, `session_id` and `phase: seeded` only.

```yaml
subtask_id: <subtask>
session_id: <run-id>-<subtask>        # bus session_id, pinned, stable across resume
live: <n>/30 (derived)                # derived from the count of slots/*.row; never hand-set
reserved: {shepherd: 1, ci: 1, review: 10}   # review: 10 per concurrent pr-review; no clerk seat (AM-8 V8)
spawns: <n>/<cap>                     # cap measured at P0 (unmeasured: verify at move); lead stops at cap - 5
frontier: []                          # current DAG frontier, unit ids
interfaces_version: <version>@<sha256> # kept from the seed unchanged (A.3; same value as state.md, A.2)
tick_utc:                             # ISO UTC, rewritten by the lead on every tick (A.8, 28-CV8)
waves_done: 0                         # completed lane-waves (count)
stop_reason:                          # empty, or one value below
invocation: 0                         # wave-execution counter: incremented and written BEFORE each call
lock_breaks: []                       # ISO UTC per stale-lock break
phase: seeded                         # seeded|building|integrating|prepr|pr-open|ci|merged|post-merge|release|done
prepr:                                # PASS|STOP or empty (pre-pr-gate verdict for head)
head:                                 # 40-hex sub-task branch head the prepr verdict and review record cover
pr:                                   # int or empty, from the lead's pr-create .out
review_record:                        # RUN_HOME/review/<subtask>/record-<head>.md or empty
integrated: []                        # entries "<unit> <sha>", each ^u[0-9]+ [0-9a-f]{40}$
ci:                                   # GREEN <sha> | HUMAN <reason> | empty (last ci-fix-loop token)
postmerge:                            # PASS|FAIL, pm lead only
pm_sha:                               # pm lead only: merge_sha of the last sub-task merge
postmerge_record:                     # pm lead only: abs path of postmerge-<sha>.md
release_record:                       # pm lead only: abs path of release-<sha>.md
e2e_gherkin_utc:                      # ISO UTC or empty; e2e-writer after H-e2e (AM-9 G2/53)
e2e_spec_path:                        # abs path or empty; e2e-writer after H-e2e
e2e_run_result:                       # PASS|FAIL or empty; lane-runner after nl-run-e2e
e2e_heal_review:                      # reviewed|none or empty; lane-runner after nl-run-e2e
```

### 2.1 Field rules

| Field | Rule |
|---|---|
| `live` | always `<n>/30` and always derived; the literal `(derived)` marks that nobody types the number |
| `stop_reason` | `stop-the-line:<row>` (regex `^stop-the-line:[A-Z]+[0-9]+[a-z]?$`) \| `d7-round3` \| `invalidate` \| `spawn-cap` \| `human` \| `port-refused` \| `stale-session`. `port-refused`: a lead-owned port claim refused after its one +10 retry, or `port-check.sh` exit 3 (AM-4). `stale-session`: a second `pm` lead finds a fresh `substate.lock` and writes `STOP stale-session` to `pm/outbox/stop-<utc>.md`; the conductor records this value in `state.md` `subtasks[]` (not here) and maps `pm` to `stopped` (INTERFACES 1.9.0 AM-9 G1/6). Writer: the lead for the stops it detects; the conductor for conductor-detected stops (`stale-session`, ledger refusal, relay refusal), in `state.md` (G1/42); the desk clears it when it writes `RESUME.<subtask>.<run-id>.ok` (AM-8 V2). `ci-fix-loop`'s `CI: HUMAN d7-round3` maps to `d7-round3`; an unnamed stop is `human` (A.8, 28-CV2) |
| `tick_utc` | rewritten on every tick; no move within 12 minutes of a `claude -p` lead's first invocation reads as "the cron does not fire" (C1.1 fallback) |
| stop-the-line row ids | closed: `S1` classifier or harness block; `S2` failed gate; `S3` authoring on main; `S4` spawn without a free slot; `S5` verifier authored the code; `S6` two writers on one `substate.md`; `S7` unrecorded production write; `G1` build or publish from the main checkout; `G3` release step before its simulation; `G4` hooks skipped without a recorded pass; `G5` fix commits left unpushed; `D23` pipeline-definition edit by an agent; `S8` sub-task bus down after two failed restarts |
| `phase` | the conductor maps it to `subtasks[].state` (Part 1.2); the lead sets `building` before its first `wave-execution` invocation (A.8, 28-CV18) |
| `prepr`, `integrated`, `ci`, `postmerge` | lead-to-conductor transport of the `PREPR`, `INTEGRATED`, `CI`, `POSTMERGE` tokens (D1); `pr-create` only after `prepr: PASS` for `head`; the conductor sends `pr-merge` only after it reads `pr` set and `ci: GREEN <head>` |
| `e2e_gherkin_utc`, `e2e_spec_path`, `e2e_run_result`, `e2e_heal_review` | written by the e2e-writer (the first two, after `H-e2e.<subtask>.<run-id>.ok`) and the lane-runner (the last two, after `nl-run-e2e`), A.3 writer carve-out (INTERFACES 1.9.0 AM-9 G2/53) |
| `integrated` | one entry per accepted Integrator C2 record: `u<N> <head>` where the record `unit` is `i<N>` |
| `invocation` | passed as the caller input `invocation` of `wave-execution` (C1.1) |

### 2.2 Lock (`substate.lock/`)

Lifetime lock: the lead runs `mkdir RUN_HOME/<subtask>/substate.lock` at start. `owner` file content `<pid> <ISO UTC>`, regex `^[0-9]+ [0-9TZ:-]+$`, written to a temp file in the lock directory then `mv`d. Stale when the pid fails `kill -0`, or `owner` is missing or unparsable and the directory is older than 120 s. A break is logged as `lock_breaks: [<utc>]`. Break and waiter rules are the single statement in INTERFACES A.3 (link only; do not restate them in a skill). Hand-over on the spawn-cap path: the old lead writes `stop_reason: spawn-cap`, removes its lock and exits.

### 2.3 Companion files in `RUN_HOME/<subtask>/`

| File | Writer | Format |
|---|---|---|
| `bus.endpoint` | lead (`delivery-run`), atomic, after the bus starts and before any dispatch | key=value lines `port=`, `data_dir=` (absolute), `pm2_app=`, `pid=`, `session_id=` (equals the bundle `session_id`), `topic=` (equals the bundle `output_topic`) |
| `inbox/*.md` | conductor and desk; for `pm/inbox/` also the `post-merge-verify` verdict agent | conductor messages `RELEASE`, `INVALIDATE`, `MERGED`, desk `ANSWER` lines; in `pm/inbox/` the `verdict` type: the verdict agent's `POSTMERGE:` line or the desk-written `VERDICT pm <row-id> <text>` (part C5.1, C8; AM-7 touch-up 7) |
| `status/<agent-id>.md`, `.verdict`, `.verdict.consumed` | each agent, own file | `NEXT: <unit>.<n> <one line>`, regex `^NEXT: (u[0-9]+)\.([0-9]+) .+$` (part C3) |
| `gates/H-e2e.<subtask>.ok` | desk | Part 1.3 |
| `gate-runs/<sha>.md` | gate runner | `GATE-PASS` record, A.7 (link only) |

Completion signal: the single topic `<run-id>-<subtask>-rendezvous` on the sub-task bus; the payload is the bare JSON `{"unit": "<id>", "verdict": "PASS|ROLLED|ESCALATE", "head": "<sha>", "reason": "<code>"}` (part C2). Fallback when the bus is unreachable: the same record in `status/<agent-id>.verdict` (part C4). The conductor never reads a sub-task bus; it reads `state.md`, `substate.md` and inbox files.

## Part 3. Slot row (A.4)

Path: `RUN_HOME/<subtask>/slots/<agent-id>.row`. One line, 9 space-separated fields in this order. Written by the lead before the dispatch for every agent it dispatches, except reserved-seat agents (shepherd, ci, review seats; the clerk has no sub-task row, it runs only in the conductor session, AM-8 V8), which are counted by `reserved`.

| # | Field | Constraint |
|---|---|---|
| 1 | `agent_id` | `^[a-z0-9-]+$`, equals the file stem |
| 2 | `persona` | persona token (D2.1), closed set |
| 3 | `unit` | `^([ui][0-9]+\|-)$`; `-` for an agent serving no unit |
| 4 | `tier` | `design\|execute\|verify\|mechanical` (never a model) |
| 5 | `taken_utc` | ISO UTC |
| 6 | `budget_min` | int, from profile `durations.*` |
| 7 | `worktree` | abs path |
| 8 | `backend` | `agent-tool\|claude-p` |
| 9 | `pid` | `claude-p`: child pid or `pending`; `agent-tool`: `<lead-pid>/<agent-id>` |

```
<agent_id> <persona> <unit> <tier> <taken_utc> <budget_min> <worktree> <backend> <pid>
impl-u07 implementer u07 execute 2026-11-02T10:31:00Z 45 /abs/delivery/wt/found-1234-20261102-st1-u07 claude-p 48213
```

**security-audit rows (AM-1).** In full audit mode (A.5.3) every hunter and verifier the `security-audit` skill launches gets a row before it starts, with persona `security-auditor`, unit `-`, tier `verify`; each is counted in the ledger. Its total-agent budget is the free slot count at launch and it starts no agent without a free slot. Guidance mode launches no agent and writes no row.

```
sec-hunter-1 security-auditor - verify 2026-11-02T11:02:00Z 30 /abs/delivery/wt/found-1234-20261102-st1 agent-tool <lead-pid>/sec-hunter-1
```

**Free slots:** `max_concurrent = 30 - live_rows - sum(reserved)`; `live_rows` counts `.row` files; the value is the caller argument of part C1.1.

**Controller and gate rows (A.4, A.8):** the `wave-execution` controller task gets a row (`persona` `wave-controller`, `unit` `-`, `budget_min` the sum of the invocation's work_item `budget_min`) before its Agent call; one live invocation per sub-task. A wave-level gate agent whose dispatch record carries `unit` `wave-<N>` gets `unit` `-` and `worktree` = the sub-task worktree.

**Resume:** step 1 rename every `.row` to `.stale`; step 2 re-verify by `kill -0`; a live row goes back to `.row`, a dead one to `.freed`, before any dispatch.

**`.freed` (A.8, 28-CV3, CV12):** a worker row after a verified `PASS` or a handled `ROLLED`/`ESCALATE` record from its registered `from_agent`; a gate or fix agent after its terminal post is logged or its invocation returns; a lead-own or hosted agent when its call returns and its result is read; any row after a `TaskStop` only in the C5.3 order; never on an unverified post.

## Part 4. Machine ledger row (A.4)

Path: `$DELIVERY_ROOT/machine/<session>.row`; each session writes its own row. One line, key=value:

```
session=<session> pid=<pid> live_count=<n> build=<0|1> utc=<ISO UTC>
```

Summed under `mkdir machine/.lock` before every launch against 200 per machine and rule 8 (at most 3 rows with `build=1`: a `MODE=build` launch is allowed only when at most 2 rows carry `build=1`; `plan-pr` and `post-merge` leads write `build=0`). A new lead counts 31 (`sum(live_count) + 31 <= 200`; the 31 is a default, owner to decide, 29-2); a lead row counts max(31, its `live_count`) until its pid is dead or its `CLEANUP DONE <subtask>` (A.8). `machine/.lock` carries an `owner` file as `substate.lock` does. Reaper: while holding the lock, a row whose `pid` fails `kill -0` is renamed `.dead` and not counted.

## Part 5. Sentinels and open values

| Value | Status | Rule |
|---|---|---|
| `spawns` `<cap>` | unmeasured at P0, verify at move | write the literal `<cap>` until measured; never invent a number |
| `skill_versions` hashes | produced by the conductor at write time | never copied from an example |
| `interfaces_version` hash | produced at write time from the frozen file | same |

Check before closing a step: grep this file for `security_audit` (Part 1) and `security-auditor` (Part 3); both must be present.
