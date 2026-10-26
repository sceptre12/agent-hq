# Task Spec — 29: `delivery-pipeline` (the conductor)

> Item 29 of design §7 (`part-06-build-plan-and-sources.md:28`), wave W2. Heavy item. Read `build-common.md` first; it is binding.
> Branch/worktree: no branch work by the authors (`delivery-w0` worktree; the integrator, Worker1, commits).
> Spec status: written 2026-10-26 after W1. INTERFACES version read: `1.5.0` (FROZEN; AM-1, AM-2, AM-3 applied at writing; AM-4 and AM-5, including the conductor conventions 29-1..29-39, reconciled at item 33, §11; integrator note, `reviews/29-delivery-pipeline-2b.md`). Pending mechanism decisions of the next amendment are carried as RESOLVED lines citing "AM-4 queue" (§11).

| Field | Value |
|---|---|
| Tier | `design` for both pieces and the integration step (§7 table, items 28-29 "design"); models via `tools/model-routing.md`, never named in skill text (M19) |
| Review rung | `review-7-panel` (7 seats, up to 3 rounds, then the owner, D7); heavy item per `part-02` §2.4 and `part-06` item 31; bus run from Worker1 (build-common) |
| Depends on | INTERFACES 1.5.0 frozen (done); item 9 `wave-execution` EXTEND (§7 row 28-29 "after INTERFACES and item 9"); the W1 skills it invokes by their D2.2 named inputs (14-17, 19, 21, 22, 25); item 27 templates under `references/templates/` (read, cite); item 27b `skills/delivery-run/references/briefs/conductor.md` (read) |
| Parallel with | item 28 `delivery-run` (W2; file-disjoint; the conductor passes the D2.2 row 6 inputs, it never edits `skills/delivery-run/`) |
| Split | 2 pieces plus 1 integration step (design §7 row 28-29: "`SKILL.md` and `references/` (2 agents) 1.5 h plus 0.5 h integration"), §3 |
| Budget | 1.5 h authoring (both pieces in parallel), 0.5 h integration; review rounds after |

## 1. Objective
Write the `delivery-pipeline` skill: the conductor session (design card 1, §1 process map, §0.1 gates) that owns `state.md`, waits on the human gates H0/H1/H-e2e/H-pr/H-prod through the desk-written gate files, sequences stages 1-8 (intake, architecture, acceptance, dispatch plan, one `delivery-run` lead session per sub-task under the 30/200 caps, merge in plan order, post-merge verify, release track, cleanup, capture), relays `DESK` lines for `claude -p` leads (owner Q1), never reads a sub-task bus (inbox and state files only), reports D7 stops to the owner, resumes, and ends at CYCLE DONE.

## 2. Context Package
- Card: `part-02-skill-inventory.md:48` (card 1); process map, stop-the-line, back-edges, two exits `part-01-summary-and-process-map.md:60-84`; §0.1 gates and profiles `:27-41`; §3.1 conductor row and §4 numbers, rule 8/8b, reboot, merged tick `part-03-personas-and-concurrency.md:10-12`, `:65-95`; launcher §6.4 `part-05-execution-constraints.md:46-57`; §6.5 version hashes `:59-60`.
- Authority for every field, token, path and regex: INTERFACES 1.5.0 parts A (A.1 paths and run-id, A.2 `state.md`, A.2.1 gate files, A.3 `substate.md` and stop ids, A.4 machine row, A.6 artifacts and `merge-<sha>.md`), B (B1 registry and relay, B2 grammar, B4 conductor verbs, B8 human lines), C (C5 inbox/outbox/resume, C6 `RELEASE`/`INVALIDATE`, C7 tick split), D (D1 Step 0, D1.1 tokens, D2.1 enums, D2.2 rows 1-15 inputs, D3 ticket events, D6 planes). Where design prose and INTERFACES differ, INTERFACES and its errata E1-E42 win (amended: AM-4, AM-5 added E27-E42).
- Owner rulings: D4, D5, D7, D14, D16, D18, D19, D20, D25, Q1, OP3, OP7, OQ-1 (`architecture/delivery-workflow-sources/owner-decisions.md`).
- Inputs already on disk: `skills/delivery-pipeline/references/templates/{state-and-substate,retro-and-execution-log,artifact-to-plane}.md` (item 27); `skills/delivery-run/references/briefs/conductor.md`, `read-back.md`, `capture-agent.md` (item 27b).
- Anatomy: `tools/skill-authoring.md` §2-§5; owner deviation recorded in the checklist: model-invocable (D16).

## 3. Scope
**Split plan (Rule 7: two file-disjoint pieces in parallel, then one integration agent).** The reference file names below are fixed by this spec so P1 can link them before P2 writes them.

| Piece | Owner files (only these) | Reads, never writes |
|---|---|---|
| P1 `SKILL.md` (design) | `skills/delivery-pipeline/SKILL.md` | INTERFACES, design, `references/templates/` |
| P2 references (design) | `skills/delivery-pipeline/references/stages.md` (per-stage entry, invoked skill and named inputs, exit token, `state.md` writes), `tick-relay.md` (the 1-minute tick: outbox relay incl. `.desk.refused`, `register`, `CONDUCTOR-REQUEST`, `substate.md` and `RUN_HOME/*/escalations/` reads, dead-lead check, ticket events), `launcher.md` (§6.4 launcher spec and ledger checks), `resume.md` (conductor resume, `REBIND`, applied-result scan, lead relaunch), `stops-and-posts.md` (gate waits, D7 and stop-the-line handling, status-post contents), `provenance.md` | INTERFACES, design, `references/templates/` |
| Integration (design, 1 agent, after P1 and P2) | cross-file fixes in the seven files above only | all |

P1 and P2 take names, tokens and regexes from INTERFACES only, never from each other's in-progress text; the integrator reconciles, checks every `references/*.md` link resolves, and runs §9.

**In scope:** Step 0 (`INPUT-ERROR`, D1; D2.2 row 1); ORCHESTRATOR-CHECK (card 1); stage 1 run-id minting (A.1, provisional form), `RUN_HOME` and `plans_dir` creation, `state.md` first write including `orchestrator_tier`, `skill_versions`, `interfaces_version`, `machine_ledger_row`, `security_audit: guidance`; each stage's skill call with exactly its D2.2 named inputs; gate waits on files only; the `security_audit` rule (A.2, OQ-1); `ticket-clerk` runs, whose wave 1 is the epic `jira-create` with `<subtask>` `run` (the conductor sends no separate epic request; it copies the epic key from `tickets.tsv`, parent `-`, into `state.md` `epic`; A.1, A.6, D3); lead launch per backend (C5.2) under the 30/200 and rule-8 caps; `RELEASE`/`INVALIDATE`/`MERGED` inbox writes (C5.1, C6); the relay tick (B1, C5.1); stage 5b `pr-approval-state` then `pr-merge` in plan order, `merge-<sha>.md`; the `pm` host (A.2); post-merge re-entry (A.2); `final` and abandoned-run cleanup (C5.1); stage 8 capture with a different read-back agent and the `RUN_HOME/capture/` queue (D19, A.1); CYCLE DONE and `stage: done`.

**Out of scope:** every other `skills/*` directory (W1 directories, item 28, ports); `skills/delivery-pipeline/references/templates/` (item 27; RESOLVED Q3 of spec 27, plan-check §3); briefs (item 27b); `tools/delivery/*`; INTERFACES, ADRs and design (a gap is a `.decisions/29.md` fork or STUCK, never an edit); the merged 10-minute tick (the lead's, C7); bus reads of any kind.

**Do NOT create:** tests or scripts under the skill; symlinks; a conductor bus topic or any bus read (E7, C5); a `conductor_id` or registry in `state.md` (OP3); any write under `gates/` (desk only, M30); a status-post file grammar (RESOLVED Q2); a cost metric (B-4); `disable-model-invocation`.

## 4. Contracts
| Contract | Produced / consumed | Authority |
|---|---|---|
| Named inputs | `DELIVERY_ROOT` (env); `INTENT` with `PRIMARY_REPO`, or `RUN_HOME` (dir under `$DELIVERY_ROOT` with `state.md`) | D2.2 row 1, D1 |
| `state.md` | sole writer; every A.2 field and `subtasks[]` transition with its source; atomic temp+`mv` | A.2, A.1 atomic writes |
| Stage tokens read | `PROFILE:` (to `repo_profile`), `ARCH: ready`, `PLAN-CHECK:`, `PREPR:`, `INTEGRATED:`, `CI:`, `POSTMERGE:`, `RELEASE:`, `CLEANUP DONE` | D1.1 |
| Gate files read | `H0.<run-id>.ok`; `H1.<run-id>.ok\|.changes\|.reject` with `H1.notes.md`; `H-e2e.<subtask>.<run-id>.ok`; H-pr pointer `gh:<o>/<r>#<pr>@<commit>`; `H-prod.<step_id>.<run-id>.ok` (gate-file names carry the run id; amended: AM-5 26, A.2.1) | A.2.1, B8 |
| Inbox writes | `RELEASE <subtask>`, `INVALIDATE <subtask> <reason>` (receiver id; 4 reasons), `MERGED <subtask> <merge_sha>`; file `<seq>-<utc>-<type>.md` via `inbox/.seq/` `O_EXCL`; optional `SendMessage` `INBOX <subtask>` pointer only | C5.1, C5.2, C6 |
| Registry | consume `outbox/register` (`REGISTER ...`), send `REGISTER-SENDER`, read `REGISTERED`, rename `register.consumed`/`.refused`; `-` identity: no line, consumed at once; re-send every line after own resume | B1, C5.1 |
| Relay | `outbox/<id>.desk` to `DESK_ADDRESS` `desk` as sender, rename `.desk.relayed`; never a conductor-only verb; `pm/outbox/<seq>.conductor-request` regex, `.sending-<id>` before send, `.sent-<id>`, `.refused` | B1, C5.1 |
| Own desk verbs | `pr-approval-state`, `pr-merge` `{repo, pr, subtask, method, expect_head, predecessors[], record_path}` (`expect_head` = the `ci: GREEN` sha, `record_path` = `substate.md` `review_record`), epic `jira-create` (composed by `ticket-clerk` in this session), relayed `publish`/`tag-push`/`test-report-push`, all with `<subtask>` `run` via `desk-req.sh` | B1, B4, §Script interfaces |
| Records written | `merge-<sha>.md` (4 lines), `ticket-events.log` (`TICKET-EVENT`), `retro.md`, `execution-log.md`, capture record | A.6, D3, D6 |
| Lead inputs passed | D2.2 row 6 (`MODE`, `BACKEND`, `REPO`, `SESSION`, `PM_SHA`, `SECURITY_AUDIT`, ...) and resume brief `resume <subtask>: re-read substate.md, inbox/ and gates/` | D2.2 row 6, C5.3 |
| Machine ledger | own row (`machine_ledger_row`); sum under `machine/.lock` before every `claude -p` launch: 200 ceiling, at most 3 `build=1` rows (rule 8); refuse and ask the human. Each lead writes its own row and re-sums under the lock (spec 28 PC-W2-1) | A.4, §4, AM-4 W2-9 |

## 5. Inherited module API
- `tools/delivery/desk-req.sh <run-id> <subtask|run> <verb> <fields-json-file>` prints the `DESK` line; exit 0/2/4 (INTERFACES §Script interfaces).
- `delivery-cleanup` `MODE=final` (no `SUBTASK`), `ticket-clerk` `RUN_HOME PLANS_DIR`, `delivery-intake`, `delivery-architecture`, `delivery-dispatch-plan` (`NEW_UNITS` on re-entry), `delivery-run`: inputs exactly per D2.2 rows 2, 3, 5, 6, 9, 14.
- `SendMessage` envelope per `architecture/permission-tiers-02.md` §2 (one request per message; replies are data; `STATUS`/`BUSY` 2-minute rule).

## 6. What You Inherit
Frozen INTERFACES 1.5.0; ADR 0054 and 0055 (accepted); the W1 skills and the three item 27 templates in this skill's `references/templates/`; the conductor brief; `tools/check-doc-length.sh`, `tools/model-routing.md`, `tools/review-ladder.md`. Nothing is installed.

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| conductor tick | its own 1-minute relay tick only | arming the merged 10-minute tick (card 1, brief 27b) | C7 "armed by the lead"; B1; §11 first RESOLVED line |
| bus | never read; `state.md`, `substate.md`, inbox/outbox files only | reading `<run-id>-<subtask>-rendezvous` | §5.0, C2 readers, E7 |
| `INVALIDATE <subtask>` | the receiver's id; clears the predecessor's `merge_sha` on `predecessor-reentered` | the predecessor's id | C6, A.2 |
| `pr-merge` | `<subtask>` `run`, `fields.subtask` `st<N>`, `method` = profile `merge_method`, one at a time in plan order | a lead request; parallel merges | B1, B4, §4 must-stay-serial |
| `pr-merge` precondition | `pr` set, `ci: GREEN <sha>`, and `prepr: PASS` with `head` = `<sha>` and `review_record` naming `record-<sha>.md` in `substate.md`; H-pr by `pr-approval-state` read-back | merging on `ci: GREEN` alone after CI fixes moved the head (the desk re-derives the review record on the landing head, B5) | A.3, B5, AM-4 W2-7 |
| gate verdicts | file presence read; never written | conductor writes `gates/` or a verdict field | M30, A.2.1 |
| `security_audit` | `guidance` default; `full` on an explicit operator request or `security_sensitive: yes` | `full` by default; absent line read as `no` | A.2, OQ-1 |
| `interfaces_version` | `<live version>@<sha256>` of the live `INTERFACES.md` (`1.5.0` at item 33) | the A.2 example's value | AM-4 queue (27) |
| run-id | provisional `run-<n>-<yyyymmdd>` never renamed; `epic` from the `jira-create` read-back | renamed when the key arrives | A.1 |
| relay | refuses conductor-only verbs from a lead outbox | relays `pr-merge` from a lead | B1, FRZ-d |
| CYCLE DONE order | `pm` terminal `RELEASE:`, every `subtasks[]` `cleaned`, `final` cleanup, stage 8, then `stage: done` | `done` before `final` cleanup | C5.1, D1.1, §1 |
| plan-plane commit | listed as a human step in the final status post | a desk push of `retro.md` | A.6 R4-J19, E17 |
| launcher | `env -i` allowlist, scrubbed git/gh/ssh, asserted `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30` fail-closed, `--disallowedTools` with the profile `zephyr.execute_tool` plus network-write tools, stdin prompt | argv prompt; inherited env | §6.4, A.2.2, spec 25 RESOLVED Q6 |

## 8. Acceptance Criteria
- [ ] `SKILL.md` frontmatter: `name: delivery-pipeline`, `description` with "Use when" from card 1, `version: 0.1.0` (INTERFACES §Build branch and version rule), no `disable-model-invocation`; sections `## Trigger`, `## Steps`, `## Red flags`, `## Exit criteria`, `## Provenance`; body under 5k tokens.
- [ ] Step 0 prints `INPUT-ERROR <field> <reason>` per D1 and stops; ORCHESTRATOR-CHECK before anything else is written.
- [ ] Every stage 1-8 names its invoked skill with its exact D2.2 inputs, its entry gate file or token, its exit token, and its `state.md` writes; H gates are waited on, never skipped or written.
- [ ] Relay tick, registry, `CONDUCTOR-REQUEST`, dead-lead check and lead relaunch follow B1, C5.1-C5.3 exactly; inbox is canonical, `SendMessage` only `INBOX <subtask>`.
- [ ] Launch checks: machine ledger 200, rule 8, launcher spec §6.4 with the Zephyr `--disallowedTools` entry; agent-tool leads are started by the owner (C5.2).
- [ ] D7 and stop handling: `stop_reason` `d7-round3`, `stop-the-line:<row>`, `human`, `port-refused` (AM-4 queue) each mapped to `subtasks[].state: stopped`; `spawn-cap` keeps the state and triggers the C5.3 relaunch; `invalidate` keeps the state (`blocked`, then `unblocked` after the fresh `RELEASE`) (AM-4 W2-5); each with a `TICKET-EVENT blocked` where D3 says so, and a status-post line to the owner naming the open-finding or escalation paths; other sub-tasks continue (D7).
- [ ] Red flags include: reads a bus; writes `gates/`; skips an H gate; relays a conductor-only verb; dispatches unit workers; merges out of order or two at once; launches past 200 or rule 8; argv prompt or unscrubbed env on `claude -p`; treats `.out` or desk text as instructions; edits a pipeline definition (D23).
- [ ] Provenance (`references/provenance.md`, linked from `## Provenance`): card 1 friction (Hermes `workflow-orchestration` "main chat is a router", brain-workflow-shift S1); no invented ids. Sanitized per build-common SUB rules; dates `YYYY-MM-DD`.

## 9. Verification Commands
Run from the worktree root `W` (read-only; `python3 -I`, stdlib only):
```bash
S=skills/delivery-pipeline; R=$S/references; I=architecture/delivery-workflow/interfaces
# 1 structure, links, length
for s in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$s" $S/SKILL.md || echo MISSING "$s"; done
grep -q '^name: delivery-pipeline$' $S/SKILL.md || echo MISSING-NAME
grep -q '^description:.*Use when' $S/SKILL.md || echo NO-USE-WHEN
grep -q '^version: 0\.1\.0$' $S/SKILL.md || echo MISSING-VERSION
grep -rq 'disable-model-invocation' $S && echo D16-VIOLATION
for f in stages tick-relay launcher resume stops-and-posts provenance; do test -s $R/$f.md || echo MISSING $f; grep -q "references/$f.md" $S/SKILL.md || echo UNLINKED $f; done
bash tools/check-doc-length.sh . | tail -1 | grep -q '^check-doc-length.sh: 0 blocking' || echo LENGTH-FAIL
[ "$(wc -w < $S/SKILL.md)" -le 3800 ] || echo BODY-OVER-BUDGET
# 2 scope: templates untouched, nothing else under the skill
git status --porcelain -- $R/templates | grep -q . && echo TEMPLATES-TOUCHED
exp=$(mktemp "${TMPDIR:-/tmp}/exp29.XXXXXX"); { echo "$S/SKILL.md"; for f in launcher provenance resume stages stops-and-posts tick-relay; do echo "$R/$f.md"; done; } | sort > "$exp"; find $S -type f ! -path "$R/templates/*" | sort | diff - "$exp" >/dev/null || echo EXTRA-OR-MISSING-FILE; rm -f "$exp"
# 3 rules present (union of SKILL.md and references)
for t in H0.ok H1.ok H1.changes H1.reject 'H-e2e' 'H-pr' 'H-prod' REGISTER-SENDER REGISTERED register.consumed register.refused '.desk.relayed' CONDUCTOR-REQUEST '.sending-' 'RELEASE pm' INVALIDATE MERGED 'merge-<sha>.md' 'CLEANUP DONE' 'CYCLE DONE' 'stage: done' 'stage: stopped' port-refused d7-round3 spawn-cap 'env -i' 'CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30' disallowedTools zephyr.execute_tool security_sensitive interfaces_version orchestrator_tier 'TICKET-EVENT' 'INBOX <subtask>' 'capture/' REBIND '.desk.refused' 'escalations/' review_record; do cat $S/SKILL.md $R/*.md | grep -qF -- "$t" || echo RULE-MISSING "$t"; done
# 4 closed sets copied exactly from INTERFACES
python3 -I - <<'PY'
import glob
t=''.join(open(p).read() for p in ['skills/delivery-pipeline/SKILL.md']+[p for p in glob.glob('skills/delivery-pipeline/references/*.md')])
for r in ['predecessor-reentered','predecessor-rebased','contract-changed','plan-changed']: assert r in t, r
for v in ['pr-merge','pr-approval-state','publish','tag-push','test-report-push','jira-create']: assert '`%s`'%v in t, v
for s in ['planned','released','building','pr-open','merged','stopped','cleaned']: assert '`%s`'%s in t, s
for rx in [r'^MERGED (st[0-9]+) ([0-9a-f]{40})$', r'^REGISTER ([a-z0-9-]+) (st[0-9]+|pm) ([^ ]+) ([a-z0-9-]+)$']: assert rx in t, rx
assert 'peek:true' not in t, 'BUS-READ'   # the bus reader idiom (C2) must not appear in conductor text
print('PIPELINE-29-OK')
PY
```
**Done condition (one, machine-checkable):** the block prints none of `MISSING`, `UNLINKED`, `NO-USE-WHEN`, `D16-VIOLATION`, `LENGTH-FAIL`, `BODY-OVER-BUDGET`, `TEMPLATES-TOUCHED`, `EXTRA-OR-MISSING-FILE`, `RULE-MISSING`, the Python step exits 0, and the last line printed is `PIPELINE-29-OK`; then the `review-7-panel` record is 0 Blocking / 0 Medium or a D7 stop is handed to the owner.

## 10. Branch
Work only in worktree `delivery-w0` (`~/projects/agent-hq-worktrees/delivery-w0`, branch `wt/delivery-w0`); no `git add`, commit, branch, push or rebase (the integrator, Worker1, commits).

## 11. Decision Gate Reminder, resolutions and open questions
If INTERFACES, the design and an owner ruling conflict, or a field is missing, write `.decisions/29.md` (fork, options, recommendation, `Outcome: Blocked`) and stop. Do not reword an owner ruling.
- RESOLVED (INTERFACES C7, B1): the conductor arms only its 1-minute relay tick; the merged 10-minute tick is the lead's. Card 1 and the 27b conductor brief line "arm the merged 10-minute tick" are errata for item 33.
- RESOLVED (INTERFACES §4 via design, card 1): stage skills run inside the conductor session may dispatch their own agents (explorers, review seats, Plan-checker, capture and read-back agents); the conductor never dispatches unit workers.
- RESOLVED (spec 25 RESOLVED Q6; plan-check §3): `launcher.md` carries the `--disallowedTools` entry for the Zephyr `execute` tool, named from the profile `zephyr.execute_tool` (unmeasured, verify at move).
- RESOLVED (AM-4 queue 24-Q2; corrected by the W2 plan-check against B5, AM-4 W2-7): `PREPR: PASS` gates only a PR's first push. The `pr-merge` precondition is `pr` set and `ci: GREEN <sha>` plus `prepr: PASS`, `head` = `<sha>` and `review_record` = `.../record-<sha>.md`, because the desk re-derives the review record on the landing head (B5, FROZEN); when CI fixes move the head the lead re-runs `pre-pr-gate` (spec 28 PC-W2-3) before the conductor merges.
- RESOLVED (AM-4 queue, 11-Q11-R1): an `INPUT-ERROR` reply from a stage skill or reviewer is not a D7 round; the conductor fixes the input and re-invokes with the same round count.
- RESOLVED (AM-4 queue, 12-OQ, 27): the conductor sets `security_audit` from the one required `security_sensitive: yes|no` line of `architecture.md`; a missing line is an `INPUT-ERROR security_sensitive missing`, never read as `no`; `interfaces_version` is written as the live version `@<sha256>` (`1.5.0` at item 33), never copied from the A.2 example.
- RESOLVED (AM-4 queue, 27b): `stop_reason: port-refused` written by a lead after its one +10 retry maps to `subtasks[].state: stopped`; the conductor reports it to the owner with the port and the sub-task; it never picks a port.
- RESOLVED Q1 (A.2.1 "only `.ok` satisfies the gate"; C5.1 abandoned run, AM-2 row 14; PLAN-CHECK DEFAULT): on `H1.reject` the conductor writes `stage: stopped`, posts the stop naming `gates/H1.notes.md`, then runs `delivery-cleanup` `MODE=final` (abandoned run). No ticket exists yet (`jira-create` needs `H1.ok`), so no `TICKET-EVENT`. A new attempt is a new `INTENT`.
- RESOLVED Q2 (D2.2 row 1 "one status post per gate; `state.md` path printed at end of turn"; PLAN-CHECK DEFAULT): the post is printed in the conductor session at end of turn, no file and no grammar. `stops-and-posts.md` fixes its contents: stage; the gate waited on and its file path; open escalations (`RUN_HOME/*/escalations/*.md`); stop rows per sub-task with the record or checklist paths; the `ticket-clerk` report line; human steps; the `state.md` path last.
- RESOLVED Q3 (A.2.2 and R4-J1: `delivery-intake` is the sole profile writer, and D2.2 row 2 has no restore mode; PLAN-CHECK DEFAULT; AM-4 W2-6): the restore is a human step in the final status post, naming the profile path and the per-ticket fields. The conductor never writes the profile and never invokes `delivery-intake` for it.
- RESOLVED Q4 (template `retro-and-execution-log.md` Part B; PLAN-CHECK DEFAULT; AM-4 W2-6): the counter is the run's `RUN_HOME/execution-log.md` row written at stage 8. Archiving `RUN_HOME` (and the desk-held `desk-inbox/<id>.req` retention, A.1) is a human step in the final post until an amendment names the target. `RUN_HOME` is already durable, never temp (A.1).
- RESOLVED Q5 (B1 "never relays"; A.3 `substate.md` writer is the lead only; PLAN-CHECK DEFAULT; AM-4 W2-4): the conductor renames the file `<id>.desk.refused`, logs it in the run log and puts a status-post line naming the lead and the file. It writes no stop row, because it never writes `substate.md`; the lead treats `.desk.refused` as terminal `sender` at once (B1 no-reply path: `.req.noreply`, escalation `human-step`; spec 28 PC-W2-8).
- RESOLVED PC-W2-9 (A.2 transitions; A.3 `stop_reason`; C5.3 triggers; AM-4 W2-5): `subtasks[].state: stopped` is written for `stop-the-line:<row>`, `d7-round3`, `human` and `port-refused`. `spawn-cap` keeps the state and is a C5.3 trigger: for `claude -p` the conductor relaunches through the launcher with the resume brief once the old `substate.lock` is gone; for `agent-tool` the status post asks the owner to start a new session with that brief. `invalidate` keeps the state; the conductor writes `TICKET-EVENT ... blocked`, then `unblocked` after it sends the fresh `RELEASE`.
- RESOLVED PC-W2-10 (D3 `blocked` on `ESCALATE`; C2 escalations location): the relay tick lists `RUN_HOME/*/escalations/*.md`, writes `TICKET-EVENT <key> blocked` once per new escalation file, and lists open escalations in the next status post.
- AM re-check (1.5.0, item 33): the conductor conventions 29-1..29-39 adopted by AM-5 are stated in INTERFACES A.8, B9 and C8 (29-5 and 29-6 held back as owner items O-1/O-2 with the lead defaults in INTERFACES "Owner items from the item 29 panel") and listed in `skills/delivery-pipeline/references/provenance.md`; they win over any sentence of this spec, notably: session tokens and launch intent, the five new `state.md` fields, `RESUME.<subtask>.<run-id>.ok` as the only exit from `stopped`, `stale-session`, B1 no-reply and send gate, tick duties, merge order, `pm` host and re-entry rules, escalation ticket keys, the read-back verdict, gate-file names carrying the run id (AM-5 26).
- AM-4 rows W2-1..W2-10 (`reviews/plan-check-w2-specs.md`) are treated as decided. Re-check: INTERFACES `Amendments` re-read at writing (1.3.0, AM-1..3). AM-1 (`security_audit`) and AM-2 rows 4, 5, 8, 14 are reflected above; AM-3 OQ-2 reaches the conductor only through `port-refused`. A later amendment touching parts A-D means update this spec and the skill, or mark STUCK.
