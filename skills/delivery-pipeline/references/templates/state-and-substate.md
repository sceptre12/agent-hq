# Template: `state.md` and `substate.md` (design 5.0; INTERFACES A.2, A.3, A.4)

Fill-in skeletons for the two run-state files and the two single-line records that sit beside them (slot row, machine ledger row). Every field name, enum and regex below is copied from `INTERFACES.md` 1.1.0; if this file and INTERFACES differ, INTERFACES wins and this file is the defect. Regex dialect: POSIX ERE.

- **Writer / Reader (`state.md`):** writer the conductor (`delivery-pipeline`) only. Readers: conductor at resume, `delivery-run` Step 0 (`interfaces_version` only), `delivery-desk` (gate pointers, `plans_dir`, `repo_profile` pinned `@<sha>`), the human.
- **Writer / Reader (`substate.md`):** writer the sub-task lead only. Readers: conductor (never the bus), shepherd tick, lead at resume. Two writers on one `substate.md` is stop-the-line `S6`.
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
| `session` (launcher name) | `^[a-z0-9-]+$`, distinct from the bus `session_id` |

## Part 1. `state.md` (conductor; A.2)

Path: `RUN_HOME/state.md`. A gate field holds a pointer, never a verdict (M30): a verdict is a gate file the desk writes after the human types the confirmation, or external evidence the desk reads back. An agent never writes under `gates/`.

```yaml
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
    session: <session>                # lead's launcher session; names its machine/<session>.row
    lead_id: <identity or ->          # from the lead's REGISTER line; - for claude-p
    backend: agent-tool               # agent-tool|claude-p
    state: planned                    # planned|released|building|pr-open|merged|stopped|cleaned
    pr:                               # int once the pr-create .out exists, else empty
    merge_sha:                        # 40-hex from the pr-merge .out; empty until merged
    released_utc:                     # ISO UTC when RELEASE was written, else empty
skill_versions:
  delivery-pipeline: <version>@<sha256 of installed SKILL.md>
  # one entry per skill the run uses: name: <version>@<sha256>
interfaces_version: <version>@<sha256 of INTERFACES.md>   # e.g. 1.1.0@<64-hex>
security_audit: guidance              # guidance|full (AM-1); default guidance
machine_ledger_row: <abs path>        # $DELIVERY_ROOT/machine/<session>.row of the conductor session
```

### 1.1 Field rules

| Field | Rule (INTERFACES) |
|---|---|
| `stage` | closed enum; `done` after CYCLE DONE, `stopped` after a run-level stop |
| `gates` | `H0`, `H1` scalar; `H-e2e`, `H-pr`, `H-prod` lists; values are paths or external-evidence pointers (A.2.1) |
| `subtasks[].state` | transitions in 1.2; `released` only after `RELEASE` (part C6) |
| `skill_versions` | value encodes version plus hash: `<version>@<sha256 of SKILL.md>` (`ls -L`, `shasum -a 256`) |
| `interfaces_version` | consumers re-check after an amendment; `delivery-run` Step 0 compares it with the dispatch-plan header |
| `security_audit` | the conductor sets `full` only on an explicit operator request or when `architecture.md` carries the header line `security_sensitive: yes`; it is passed on as the input `SECURITY_AUDIT` (D2.2, D2.3). Guidance mode writes no file and launches no agent. AM-1 |
| `primary_repo` | recorded before `plans_dir` is created; in a multi-repo epic the primary profile governs and links the others (`linked_profiles[]`, A.2.2) |

### 1.2 `subtasks[].state` transitions (conductor writes)

| Event | New state | Source of truth |
|---|---|---|
| stage 3 plan accepted | `planned` | dispatch plan |
| `RELEASE` written (or launch of an independent sub-task) | `released` | conductor |
| `phase: building` read in the lead's `substate.md` | `building` | `substate.md` |
| `pr-create` `.out` | `pr-open` (`pr` set) | desk result |
| `pr-merge` `.out` | `merged` (`merge_sha` set) | desk result |
| `stop_reason` non-empty | `stopped` | `substate.md` |
| `CLEANUP DONE <subtask>` | `cleaned` | cleanup record |
| back-edge: sub-task re-enters stage 4 | `pr-open` or `merged` to `building`; `merge_sha` cleared in the same write when `INVALIDATE ... predecessor-reentered` goes to successors | part C6 |
| `POSTMERGE: FAIL` | new entry `st<N>` (next free integer), state `planned`, then stage 4 for it | A.2 post-merge re-entry |
| after the last sub-task merges | add entry `id: pm`, start its lead with inbox `RELEASE pm` | A.2 stages 6-7 host |

### 1.3 Gate files the pointers name (A.2.1; the desk is the only writer)

| Gate | File or pointer | Content |
|---|---|---|
| H0 | `RUN_HOME/gates/H0.ok` | key=value lines `utc=`, `by=`, `ref=` (sha256 of `plans_dir/brief.md`), `text=` |
| H1 | `RUN_HOME/gates/H1.ok`, `H1.changes` or `H1.reject` (with `notes=RUN_HOME/gates/H1.notes.md`) | same form; `ref=` sha256 of `h1-packet.md` or `jira:<KEY>@<comment-id>`; only `.ok` unlocks `jira-create` |
| H-e2e | `RUN_HOME/<subtask>/gates/H-e2e.<subtask>.ok` | same form; `ref=` sha256 of the batched `.feature` list in `test-plan.md` |
| H-pr | pointer only `gh:<owner>/<repo>#<pr>@<commit_id>` | no file |
| H-prod | `RUN_HOME/gates/H-prod.<step_id>.ok`, one per human release step | same form; `ref=` the release-plan `step_id` |

`state.md` holds no separate Jira pointer; a Jira-side H1 approval lives in the `ref=` of `H1.ok`.

### 1.4 Example (shapes only; replace every value)

```yaml
run_id: found-1234-20261102
epic: <JIRA-KEY>-1234
plans_dir: /abs/repo/plans/<JIRA-KEY>-1234
primary_repo: /abs/repo
repo_profile: /abs/repo/plans/repo-profile.md@<40-hex sha>
delivery_root: /abs/delivery
stage: 4
gates: {H0: /abs/delivery/found-1234-20261102/gates/H0.ok, H1: /abs/delivery/found-1234-20261102/gates/H1.ok, H-e2e: [], H-pr: [], H-prod: []}
subtasks: [{id: st0, session: lead-st0-a1, lead_id: lead-st0, backend: agent-tool, state: merged, pr: 812, merge_sha: <40-hex sha>, released_utc: 2026-11-02T10:14:00Z}]
skill_versions: {delivery-pipeline: 0.1.0@<sha256>}
interfaces_version: 1.1.0@<sha256>
security_audit: guidance
machine_ledger_row: /abs/delivery/machine/conductor-a0.row
```

## Part 2. `substate.md` (lead; A.3)

Path: `RUN_HOME/<subtask>/substate.md`. Created by the lead from `substate.seed.md` (copied verbatim into `RUN_HOME/<subtask>/` at lead start, never edited). The seed holds exactly: `subtask_id`, `session_id`, `reserved`, `frontier`, `interfaces_version`, `phase: seeded`. In modes `plan-pr` and `post-merge` the lead initializes from `subtask_id`, `session_id` and `phase: seeded` only.

```yaml
subtask_id: <subtask>
session_id: <run-id>-<subtask>        # bus session_id, pinned, stable across resume
live: <n>/30 (derived)                # derived from the count of slots/*.row; never hand-set
reserved: {shepherd: 1, clerk: 1, ci: 1, review: 10}   # review: 10 per concurrent pr-review
spawns: <n>/<cap>                     # cap measured at P0 (unmeasured: verify at move); lead stops at cap - 5
frontier: []                          # current DAG frontier, unit ids
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
```

### 2.1 Field rules

| Field | Rule |
|---|---|
| `live` | always `<n>/30` and always derived; the literal `(derived)` marks that nobody types the number |
| `stop_reason` | `stop-the-line:<row>` (regex `^stop-the-line:[A-Z]+[0-9]+[a-z]?$`) \| `d7-round3` \| `invalidate` \| `spawn-cap` \| `human` |
| stop-the-line row ids | closed: `S1` classifier or harness block; `S2` failed gate; `S3` authoring on main; `S4` spawn without a free slot; `S5` verifier authored the code; `S6` two writers on one `substate.md`; `S7` unrecorded production write; `G1` build or publish from the main checkout; `G3` release step before its simulation; `G4` hooks skipped without a recorded pass; `G5` fix commits left unpushed; `D23` pipeline-definition edit by an agent; `S8` sub-task bus down after two failed restarts |
| `phase` | the conductor maps it to `subtasks[].state` (Part 1.2) |
| `prepr`, `integrated`, `ci`, `postmerge` | lead-to-conductor transport of the `PREPR`, `INTEGRATED`, `CI`, `POSTMERGE` tokens (D1); `pr-create` only after `prepr: PASS` for `head`; the conductor sends `pr-merge` only after it reads `pr` set and `ci: GREEN <head>` |
| `integrated` | one entry per accepted Integrator C2 record: `u<N> <head>` where the record `unit` is `i<N>` |
| `invocation` | passed as the caller input `invocation` of `wave-execution` (C1.1) |

### 2.2 Lock (`substate.lock/`)

Lifetime lock: the lead runs `mkdir RUN_HOME/<subtask>/substate.lock` at start. `owner` file content `<pid> <ISO UTC>`, regex `^[0-9]+ [0-9TZ:-]+$`, written to a temp file in the lock directory then `mv`d. Stale when the pid fails `kill -0`, or `owner` is missing or unparsable and the directory is older than 120 s. A break is logged as `lock_breaks: [<utc>]`. Break and waiter rules are the single statement in INTERFACES A.3 (link only; do not restate them in a skill). Hand-over on the spawn-cap path: the old lead writes `stop_reason: spawn-cap`, removes its lock and exits.

### 2.3 Companion files in `RUN_HOME/<subtask>/`

| File | Writer | Format |
|---|---|---|
| `bus.endpoint` | lead (`delivery-run`), atomic, after the bus starts and before any dispatch | key=value lines `port=`, `data_dir=` (absolute), `pm2_app=`, `pid=`, `session_id=` (equals the bundle `session_id`), `topic=` (equals the bundle `output_topic`) |
| `inbox/*.md` | conductor and desk | conductor messages `RELEASE`, `INVALIDATE`, desk `ANSWER` lines (part C5) |
| `status/<agent-id>.md`, `.verdict`, `.verdict.consumed` | each agent, own file | `NEXT: <unit>.<n> <one line>`, regex `^NEXT: (u[0-9]+)\.([0-9]+) .+$` (part C3) |
| `gates/H-e2e.<subtask>.ok` | desk | Part 1.3 |
| `gate-runs/<sha>.md` | gate runner | `GATE-PASS` record, A.7 (link only) |

Completion signal: the single topic `<run-id>-<subtask>-rendezvous` on the sub-task bus; the payload is the bare JSON `{"unit": "<id>", "verdict": "PASS|ROLLED|ESCALATE", "head": "<sha>", "reason": "<code>"}` (part C2). Fallback when the bus is unreachable: the same record in `status/<agent-id>.verdict` (part C4). The conductor never reads a sub-task bus; it reads `state.md`, `substate.md` and inbox files.

## Part 3. Slot row (A.4)

Path: `RUN_HOME/<subtask>/slots/<agent-id>.row`. One line, 9 space-separated fields in this order. Written by the lead before the dispatch for every agent it dispatches, except reserved-seat agents (shepherd, clerk, ci, review seats), which are counted by `reserved`.

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

**Resume:** step 1 rename every `.row` to `.stale`; step 2 re-verify by `kill -0`; a live row goes back to `.row`, a dead one to `.freed`, before any dispatch. After an accepted result (the `UNIT-VERDICT` `head` verified in the worktree) or a `TaskStop`, the lead renames the row `.freed`.

## Part 4. Machine ledger row (A.4)

Path: `$DELIVERY_ROOT/machine/<session>.row`; each session writes its own row. One line, key=value:

```
session=<session> pid=<pid> live_count=<n> build=<0|1> utc=<ISO UTC>
```

Summed under `mkdir machine/.lock` before every launch against 200 per machine and rule 8 (at most 3 rows with `build=1`). Reaper: while holding the lock, a row whose `pid` fails `kill -0` is renamed `.dead` and not counted.

## Part 5. Sentinels and open values

| Value | Status | Rule |
|---|---|---|
| `spawns` `<cap>` | unmeasured at P0, verify at move | write the literal `<cap>` until measured; never invent a number |
| `skill_versions` hashes | produced by the conductor at write time | never copied from an example |
| `interfaces_version` hash | produced at write time from the frozen file | same |

Check before closing a step: grep this file for `security_audit` (Part 1) and `security-auditor` (Part 3); both must be present.
