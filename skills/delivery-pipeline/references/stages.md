# Stages 1-8: entry, skill call, exit token, `state.md` writes

Authority: INTERFACES 1.7.0 parts A-D (AM-1 to AM-7 applied; AM-6 and AM-7 changed A.8, B8, B9, C8; including the W2 plan-check rows W2-1..W2-10 and the adopted conductor conventions 29-n in A.8, B9, C8, D8; `provenance.md` §Conventions). Where this file and INTERFACES differ, INTERFACES wins and this file is the defect. Stage numbers are design §1.

## Conventions for every stage

- **Inputs.** Every skill call passes its D2.2 named inputs as `NAME=value` arguments; `DELIVERY_ROOT` is the environment variable only. `REPO_PROFILE` is always `state.md` `repo_profile` (`<abs path>@<sha>`). No other input is invented.
- **`state.md` writes.** One YAML document, written to a temp file in `RUN_HOME` and `mv`d into place (A.1). The conductor is its only writer (A.2). A gate field holds a path or pointer, never a verdict (M30).
- **`INPUT-ERROR` from a stage skill or reviewer** is not a D7 round (D1, `interfaces/part-d-enums-topics.md:6-11`; AM-4 11-Q11-R1): the conductor fixes the input and re-invokes with the same round count. It never answers by guessing a value.
- **Gate-file names (A.2.1, AM-5 26).** Every gate file carries the run id: `H0.ok` in this file means `RUN_HOME/gates/H0.<run-id>.ok`, `H1.changes` means `H1.<run-id>.changes`, `H-e2e.<subtask>.ok` means `H-e2e.<subtask>.<run-id>.ok`, and so on.
- **Hand-off.** Every stage ends with one status post (`stops-and-posts.md`) and the `state.md` path printed last.
- **Run-level `stage`.** Stages 1-3 and 8 are run-wide. From the first lead launch until the `pm` lead starts, `stage` is the least advanced stage over the sub-tasks not yet `cleaned` (phase map below); `6` and `7` follow the `pm` lead's `phase`; `8` starts the capture. This is the skill's reading of A.2 "§1 stage" for a run whose sub-tasks move in parallel.

| `substate.md` `phase` (A.3) | stage |
|---|---|
| `seeded`, `building`, `integrating` | `4` |
| `prepr` | `4b` |
| `pr-open`, `ci` | `5` (`5a` once `ci: GREEN <sha>` is read and the H-pr read-back is not yet true; `5b` while the conductor's `pr-merge` for it is in flight) |
| `merged` | `5c` until `CLEANUP DONE <subtask>` |
| `post-merge` / `release` (`pm` only) | `6` / `7` |

## Stage 1: intake (grill)

- **Entry.** Step 0 and ORCHESTRATOR-CHECK in `SKILL.md` passed with `INTENT` and `PRIMARY_REPO`.
- **Run-id (A.1).** When the human names an existing epic as an intake input, `<epic-key-lowercased>-<yyyymmdd>`; otherwise the provisional `run-<n>-<yyyymmdd>`, `n` the first free integer under `$DELIVERY_ROOT` that day. If `RUN_HOME` already exists for the minted id with a different epic, append `-2`, `-3`. A run-id is never renamed, not even when the epic key arrives.
- **Create** under `umask 077`: `RUN_HOME = $DELIVERY_ROOT/<run-id>` (never `/tmp` or `$TMPDIR`), then `plans_dir` = `<PRIMARY_REPO>/plans/<epic>/` (or `plans/<run-id>/` for a provisional id; never renamed later). `primary_repo` is recorded before `plans_dir` is created (A.1 multi-repo rule).
- **Own machine row (A.4, AM-4 W2-9).** Mint the conductor session token `<run-id>-c<n>` (`launcher.md` §Session token). Under `$DELIVERY_ROOT/machine/.lock` write `machine/<session>.row` = `session=<session> pid=<pid> live_count=<n> build=0 utc=<ISO>`; `launcher.md` §Machine ledger.
- **`state.md` first write** (every A.2 field, template `templates/state-and-substate.md` Part 1):

| Field | Value at stage 1 |
|---|---|
| `orchestrator_tier` | this session's tier from `tools/model-routing.md` (`design` for the conductor, design §3.1) |
| `run_id`, `delivery_root` | the minted id; `$DELIVERY_ROOT` |
| `epic` | the named epic, or empty until the `jira-create` read-back (stage 2) |
| `plans_dir`, `primary_repo` | as created above |
| `repo_profile` | empty until the `PROFILE:` token |
| `stage`, `gates`, `subtasks` | `1`; every gate empty, lists `[]`; `[]` |
| `skill_versions` | per skill the run uses: `<version>@<sha256>`, version from the installed `SKILL.md` frontmatter, hash `shasum -a 256` of the installed target (`ls -L`) (design §6.5) |
| `interfaces_version` | `<version>@<sha256>` of the live `architecture/delivery-workflow/INTERFACES.md`: its `version:` value and the file's sha256; never copied from the A.2 example (AM-4 27): the live version, `1.7.0` at AM-7 (the A.2 example still reads 1.4.0; the value is always taken from the live file) |
| `security_audit` | `guidance` (set finally at stage 2) |
| `machine_ledger_row` | the absolute path of the row above |

- **Claim the run and arm the tick.** Send `REGISTER-SENDER <run-id> | run | <own sender-id>` to `desk` (B1: the first line for a run names `run`) and arm the 1-minute relay tick (`tick-relay.md`) right after the send; the claim and its no-reply re-send are exempt from the send gate (29-27). The skill below starts on the tick that finds `REGISTERED <run-id> | run | ok` (tick step 4c).
- **Skill.** `delivery-intake` with `RUN_HOME=`, `PLANS_DIR=`, `PRIMARY_REPO=`, `INTENT=` (D2.2 row 2).
- **Exit token.** The last stdout line `PROFILE: <path>@<sha>` (`^PROFILE: (/[^[:space:]]+)@([0-9a-f]{40})$`), copied to `repo_profile`; `facts.md` line 1 `FACTS: <n> facts`.
- **Gate H0.** Post with the H0 `GATE` line and end the turn; the tick that finds `RUN_HOME/gates/H0.ok` (desk-written) writes `gates.H0` = its path, `stage: 2`.

## Stage 2: architecture and H1

- **Entry.** `H0.ok` exists.
- **Skill.** `delivery-architecture` with `RUN_HOME=`, `PLANS_DIR=`, `REPO_PROFILE=` (D2.2 row 3). Its own review loop stops at round 3 (D7, `owner-decisions.md:8`); a stop goes to the owner in the post.
- **Exit token.** `PLANS_DIR/review-architecture.md` line 1 `ARCH: ready`; `drafts/index.md` line 1 `DRAFTS: <n> drafts`.
- **`security_audit` (A.2, owner OQ-1, `architecture/delivery-workflow-sources/owner-decisions.md:89`).** `architecture.md` carries exactly one line `security_sensitive: yes|no`. `yes`, or an explicit operator request in this session, sets `full`; `no` sets `guidance`. A missing line is `INPUT-ERROR security_sensitive missing`, two lines or another value `INPUT-ERROR security_sensitive format`; never read as `no`. The conductor re-invokes `delivery-architecture` (same round count) after the input is fixed.
- **Gate H1.** Wait for the one live H1 file in `RUN_HOME/gates/` (the desk renames earlier ones to `<name>.<yyyymmddThhmmssZ>`, A.2.1):
  - `H1.ok`: `gates.H1` = its path; go on.
  - `H1.changes`: re-invoke `delivery-architecture` with the same three inputs; it reads `RUN_HOME/gates/H1.notes.md` itself and every note binds. Record `h1_handled: <file name> <utc=>` in `state.md` only after the call returns (29-17), so a crash mid re-run re-runs it; the stage 2 skip also needs `review-architecture.md` newer than that `utc=`. Then wait for H1 again: the old `H1.changes` stays the live file until the desk writes the next one (A.2.1, `interfaces/part-a-state.md:101`), so H1 is pending again only when the live H1 file's name or `utc=` differs from `h1_handled`.
  - `H1.reject`: RESOLVED Q1. Write `stage: stopped`, post the stop naming `RUN_HOME/gates/H1.notes.md`, run `delivery-cleanup` `RUN_HOME=` `MODE=final` (abandoned run, C5.1) once, with the stage 8 step 2 stop path; a resume of a `stopped` run without `CLEANUP DONE final` runs it (29-30). No `TICKET-EVENT`: no ticket exists before `H1.ok`. A new attempt is a new `INTENT`.
- **Tickets.** After `H1.ok` run `ticket-clerk` with `RUN_HOME=`, `PLANS_DIR=` (D2.2 row 14). Its wave 1 is the epic `jira-create` with `<subtask>` `run`; the conductor sends no separate epic request. Copy the epic key from the `tickets.tsv` row whose `parent` is `-` into `state.md` `epic` (A.1, A.6); the run-id stays. For every created ticket append `TICKET-EVENT <key> published` (D3) and let the clerk apply it.
- **Writes.** `stage: 3`.

## Stage 3: dispatch plan

- **Entry.** `H1.ok`; `tickets.tsv` holds the keys the plan needs.
- **Skill.** `delivery-dispatch-plan` with `RUN_HOME=`, `PLANS_DIR=`, `REPO_PROFILE=` (D2.2 row 5); add `NEW_UNITS=RUN_HOME/pm/new-units.md` only on the post-merge re-entry (stage 6).
- **Exit token.** `RUN_HOME/plan-check.md` line 1 `PLAN-CHECK: clean`. `PLAN-CHECK: <n> findings` after round 3 is a D7 stop of the plan: post it with the path and wait for the owner; no lead is launched. The wait is recorded by the record itself: a resume that finds `PLAN-CHECK: <n> findings` or the plan's round-3 stop record re-posts it and re-invokes `delivery-dispatch-plan` only on the owner's word, so no round 4 runs without the owner (29-34).
- **Stop without `plan-check.md` (29-34).** `delivery-dispatch-plan` can stop before writing `plan-check.md` (a profile sentinel it cannot fill, a port-candidate clash; `skills/delivery-dispatch-plan/SKILL.md:28`). The conductor posts the skill's stop line (the missing key or the clash) and waits; the re-run of `delivery-intake`, a `repo_profile` refresh and an H0 re-ask follow the owner's word, never a guess.
- **Review round 3 (29-23).** A clean `plan-check.md` is not enough: `delivery-dispatch-plan` also stops its review loop at round 3 with open B/M findings written to the plan's review section (`skills/delivery-dispatch-plan/references/plan-check-loop.md:20`). Before the first launch read that section of `dispatch-plan.md`: a `PLAN-REVIEW: STOP round-3` line there (INTERFACES 1.6.0 AM-6 (g)) is a D7 stop: post the path, dispatch nothing.
- **Check.** The `dispatch-plan.md` header `interfaces_version` equals `state.md` `interfaces_version`; else stop and report (D7 change control).
- **Writes.** One `subtasks[]` entry per dispatch-plan sub-task row: `id`, `backend` (the plan's `BACKEND`), `state: planned`, `session` and `lead_id` empty, `pr`, `merge_sha`, `released_utc` empty. `stage: 4` at the first launch. No human gate (Rule 11); the post informs the human.

## Stage 4 and 4b: one lead per sub-task

- **Launch order.** `st0` (the plan PR) is first in merge order; merge order governs only the stage 5b merge precondition, never a release (29-18). A sub-task with no `depends-on` predecessor is released at launch; a successor is released only when every `depends-on` predecessor's `merge_sha` is in `state.md` (C6, rule 8b). The due `RELEASE` is written by the tick's re-derivation (29-14), so a crash never loses it.
- **Launch intent (29-13, 29-26).** After every fail-closed check and the worktree add, `session`, `launched_utc`, `state: released` (released-at-launch only) and `relaunch_phase` are written to `state.md` in one write, before the exec; the ledger check counts a launched entry with no machine row yet as 31 (and `build=1` for `MODE=build`) only while it is live (`launcher.md` step 3), never the sub-task being relaunched.
- **Sub-task worktree (29-22).** For `claude-p` the conductor adds `<worktree_base>/<run-id>-<subtask>` on the dispatch-plan `branch` (catalog `worktree` row `planned`, then the add, then `start`) and runs the child there; `pm` is exempt: the `pm` lead creates its detached post-merge worktree `<worktree_base>/<run-id>-pm` at `PM_SHA` (catalog `worktree` row) as its first step and runs there; the 29-22 exemption covers only the sub-task-branch worktree (INTERFACES 1.6.0 AM-6 (b)).
- **Launch.** `launcher.md`: machine ledger check, then `claude -p` through the launcher spec, or the owner starts an `agent-tool` lead (C5.2).
- **Skill (in the lead).** `delivery-run` with the D2.2 row 6 inputs, all from `state.md` and the dispatch plan: `RUN_HOME=`, `SUBTASK=`, `MODE=` (`plan-pr` for `st0`, `build` for `st<N>`, `post-merge` for `pm`), `BACKEND=`, `PLANS_DIR=`, `REPO_PROFILE=`, `REPO=` (the dispatch-plan sub-task `repo`), `SESSION=`, `PM_SHA=` (`pm` only), `SECURITY_AUDIT=` (`state.md` `security_audit`); `DELIVERY_ROOT` in the environment.
- **Release.** Inbox `RELEASE <subtask>` (`tick-relay.md` §Inbox writes); then `state: released`, `released_utc`.
- **Read on the tick** (`tick-relay.md`): `phase: building` -> `state: building` and `TICKET-EVENT <key> dispatched` once; `prepr: PASS` for `head` -> `TICKET-EVENT <key> prepr-pass` once per sub-task; H-e2e files `RUN_HOME/<subtask>/gates/H-e2e.<subtask>.ok` -> appended to `gates.H-e2e` (the lead enforces H-e2e, A.2.1).
- `<key>` is the dispatch-plan sub-task table `ticket` (A.6); a slug resolves to its key through `tickets.tsv` (D3). The conductor never edits the unit table.

## Stage 5 and 5a: PR, CI, human review

- The lead pushes, opens the PR and runs `ci-fix-loop`. The conductor reads `substate.md` `pr` (copied by the lead from its `pr-create` `.out`) -> `subtasks[].pr` and `state: pr-open`; `ci` -> `GREEN <sha>` or `HUMAN <reason>` (a `HUMAN` value is a human item in the post).
- 5a is the human approving review. The conductor waits; it never approves and never writes an H-pr file (there is none).

## Stage 5b: merge (conductor only, serial, plan order)

1. **Precondition** (spec 29 §7, AM-4 W2-7): the sub-task is `state: pr-open` with `merge_sha` empty (29-37); `substate.md` has `pr` set, `ci: GREEN <sha>`, `prepr: PASS`, `head` = `<sha>`, and `review_record` = `RUN_HOME/review/<subtask>/record-<sha>.md`; every merge-order predecessor (every sub-task with a lower dispatch-plan `merge order`, `st0` first; D5 `owner-decisions.md:6`; 29-18) has `merge_sha` in `state.md`; no other `pr-merge` of this run is in flight; no terminal `pr-merge` `REJECTED` or `.req.noreply` blocks this `head` (29-16). If CI fixes moved the head, wait: the lead re-runs `pre-pr-gate` on `<sha>` first.
2. **H-pr read-back.** `pr-approval-state` `{repo, pr}` via `desk-req.sh <run-id> run pr-approval-state <fields-json-file>`, the `DESK` line sent by `SendMessage` to `desk`. On `DONE` with `h_pr` true and `headRefOid` equal to the `ci: GREEN <sha>`, append `gh:<owner>/<repo>#<pr>@<commit_id>` to `gates.H-pr`; otherwise ask again on a later tick and keep H-pr in the post.
3. **`pr-merge`** `{repo, pr, subtask, method, expect_head, predecessors[], record_path}`: `repo` the sub-task's `repo`, `subtask` `st<N>`, `method` the profile `merge_method`, `expect_head` `<sha>`, `predecessors[]` the PR numbers of the merge-order predecessors (29-18), `record_path` the `review_record`; envelope `<subtask>` `run`.
4. **On `DONE`:** write `RUN_HOME/merge-<sha>.md` (`<sha>` = `merge_sha`) atomically, four lines in order `pr=<int>`, `merge_sha=<40-hex>`, `method=<squash|merge|rebase>`, `merge_reach=<profile row verbatim>` from the `.out` (A.6); set `subtasks[].merge_sha`, `state: merged`; then write inbox `MERGED <subtask> <merge_sha>` (`^MERGED (st[0-9]+) ([0-9a-f]{40})$`); then the tick re-derives and writes each successor's due `RELEASE` (29-14).
5. **On `REJECTED`:** post it, then act per `stops-and-posts.md` §Desk refusals (29-33). Never merge two at once, never out of plan order.

## Stage 5c: cleanup per sub-task

The lead runs `delivery-cleanup` `MODE=subtask` on `MERGED`. The conductor reads `RUN_HOME/cleanup-<run-id>-<subtask>.md` line 1 `CLEANUP DONE <subtask>` -> `state: cleaned`.

## Stages 6 and 7: the `pm` host

- **Start.** After the last sub-task merges: add `subtasks[]` `id: pm` with `repo` = `primary_repo` and `backend` = the `st0` backend (29-19; `pm` is in no dispatch-plan row) (on a post-merge re-entry the existing `pm` entry is reused with a new `session`: 29-5, owner item O-1, lead default; a second `pm` lead that finds a fresh `substate.lock` refuses with `stop_reason: stale-session`), launch its lead with `MODE=post-merge` and `PM_SHA` = that last `merge_sha` (the `pm` lead runs in the detached post-merge worktree at the merge sha, never the main checkout; A.8 s7-4, owner D7 stop), and let the tick write inbox `RELEASE pm` by re-derivation (A.2 stages 6-7 host; `RELEASE pm` carries no sha; 29-25). The launch prompt carries `STAKES`, `CONTENTION`, `NOVELTY` copied from lines 2-4 of `PLANS_DIR/review-architecture.md` (`key: value`, the values `delivery-architecture` step 13 writes), which `release-track` Step 0 needs (29-28); if those lines are absent the conductor guesses no value, launches no `pm` lead and posts the path as a human step; a `pm` lead that stops on `INPUT-ERROR` is posted with its `lead.log` and `substate.md` paths. `stage: 6`.
- **Read** from `RUN_HOME/pm/substate.md`: `pm_sha`, `postmerge_record`, `release_record`, `postmerge`.
- **`POSTMERGE: PASS`** (`postmerge-<pm_sha>.md` line 1): `TICKET-EVENT <key> verified` for each sub-task ticket; `stage: 7`.
- **`POSTMERGE: STOP <reason>`** (`RUN_HOME/postmerge-<pm_sha>.md` line 1, `postmerge` stays empty; `skills/post-merge-verify/SKILL.md:50`): read that file each tick while `postmerge` is empty; on STOP post the reason and the record path; for a destructive row name the row and give the line `GATE <run-id> H-destructive.<row-id> ok <text>` (the desk writes `RUN_HOME/gates/H-destructive.<row-id>.<run-id>.ok` and honours it, `post-merge-verify` reads it; A.2.1, B9, owner D7 stop R2-15); a row the human must decide (`STOP product-decision`) is posted for the owner with the line `VERDICT <run-id> pm <row-id> <text>` and then `GATE <run-id> RESUME.pm ok <text>` (the desk writes the answer as the `pm` `verdict` inbox file `VERDICT pm <row-id> <text>` and the `RESUME.pm` gate; INTERFACES 1.6.0 AM-6 (a): the desk writes no verdict of its own, except the human-decision `VERDICT`, 1.7.0 AM-7 touch-up 7 (B8, C8), E47); the conductor authors neither; write no ticket event; wait (default). A `pm` `stop_reason: human` alongside this record is this row, not a `stopped` mapping (29-31). The `pm` lead is not relaunched (29-19).
- **`POSTMERGE: FAIL`** (post-merge re-entry, A.2): handled once per `pm_sha` (29-36): the re-entry runs only when no `subtasks[]` entry carries `pm_sha` equal to the current `pm/substate.md` `pm_sha`, on the tick and at resume alike. Read `RUN_HOME/pm/new-units.md`, add `subtasks[]` `st<N>` (`N` the next free integer, `state: planned`, `pm_sha` = the current `pm_sha`) in one `state.md` write, re-invoke `delivery-dispatch-plan` with `NEW_UNITS`; then read `st<N>`'s `ticket` from `dispatch-plan.md` and use that key in the post and its events, deriving no second key (29-20). `st<N>` is launch-ready only when `dispatch-plan.md` has its row and `RUN_HOME/plan-check.md` line 1 is `PLAN-CHECK: clean` and newer than `pm/new-units.md`, with the 29-23 round-3 read applied to the re-entry review (29-29); then continue at stage 4 for `st<N>`. The old `pm` lead is not relaunched (29-19). When `st<N>` merges it is the last merge, so stages 6-7 run again with its `merge_sha` as `PM_SHA`; before the new `pm` lead: the old `pm` lead's `substate.lock` is gone or stale (C5.3 lock rule), and the old `<worktree_base>/<run-id>-pm` worktree is removed by `delivery-cleanup` `MODE=subtask` `SUBTASK=pm` (`post-merge-verify` Step 2 refuses a stale path, `skills/post-merge-verify/SKILL.md:27`); if `delivery-cleanup` refuses the `POSTMERGE: FAIL` evidence, post the worktree path and its catalog row as a human step and wait (29-19; question for `delivery-cleanup`).
- **Stage 7.** `release-track` runs in the `pm` lead; its conductor-only verbs arrive as `CONDUCTOR-REQUEST` lines (`tick-relay.md`). H-prod files `RUN_HOME/gates/H-prod.<step_id>.ok` are appended to `gates.H-prod` when the desk writes them. Read `release-<pm_sha>.md` line 1: `RELEASE: LIVE` or `RELEASE: ROLLED-BACK` is terminal; `RELEASE: WAITING-HUMAN` is not (post the human step and keep waiting). The `pm` lead then runs its own cleanup; `CLEANUP DONE pm` with a terminal `release_record` and a cleanup record newer than the current `pm` `launched_utc` -> `pm` `state: cleaned` (29-19, 29-32; an older record is the re-entry cleanup of the previous `pm` lead, which the `mv` reuses by name).

## Stage 8 and CYCLE DONE (order fixed, spec 29 §7)

1. `pm` terminal `RELEASE:` read; every `subtasks[]` entry `cleaned`.
2. `delivery-cleanup` `RUN_HOME=` `MODE=final` (no `SUBTASK`; approver the conductor; evidence every `cleanup-<run-id>-<subtask>.md`, C5.1) -> `RUN_HOME/cleanup-<run-id>-final.md` line 1 `CLEANUP DONE final`. `stage: 8`. One run only (default, 29-30): without that line (a SPOT-CHECK FAIL leaves only the `.tmp`, and a C2 escalation addressed to the approver would reach the conductor itself), post the `.tmp` path and its SPOT-CHECK block as a human step, advance nothing and re-run only on the owner's word.
3. Capture (design §1 stage 8, D19): the conductor dispatches a capture agent (brief `skills/delivery-run/references/briefs/capture-agent.md`) that drafts the retro, the execution-log rows, the session dump and the learnings under `RUN_HOME/capture/` (queued until the Hermes port is on). From those drafts the conductor writes `RUN_HOME/retro.md` (five questions) and the `RUN_HOME/execution-log.md` rows, one per unit (`templates/retro-and-execution-log.md` Parts A and B; these rows are the run's execution counter, RESOLVED Q4, E33). Then a different read-back agent (brief `read-back.md`) re-reads the stored capture against the run record and writes `RUN_HOME/capture/read-back.md` line 1 `READ-BACK: pass` or `READ-BACK: <n> differences` (29-24; the brief names no token). On differences the conductor fixes `retro.md`/`execution-log.md` once and dispatches a fresh read-back; a second failure goes to the owner in the final post. The capture record is complete only with `READ-BACK: pass` and no placeholder text.
4. `TICKET-EVENT <key> done` for each ticket of the run; run `ticket-clerk` once more.
5. Write `stage: done` (CYCLE DONE), print the final status post (`stops-and-posts.md` §Final post) and the `state.md` path, delete the 1-minute tick.

`stage: done` is never written before step 2 completes.
