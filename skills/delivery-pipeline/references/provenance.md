# delivery-pipeline provenance

Provenance: Hermes `learnings/workflow-orchestration` (`SKILL.md:73`, "the main chat is a router"; the drift back into deciding recurs within two turns) and Hermes `brain/brain-workflow-shift` S1 (`SKILL.md:16`, owner standard of 2026-10-26 to shift main-chat orchestration into skills), the friction named on design card 1 (`architecture/delivery-workflow/part-02-skill-inventory.md`, card 1).

## Friction behind the conductor

| Learning (id as recorded) | What happened | Rule it produced here |
|---|---|---|
| `workflow-orchestration` `SKILL.md:73`; scope-control retro (2026-08-26) `:42-44` | "The main chat is a router" was acknowledged, followed for one or two turns, then drifted back into deciding | the conductor holds state and gates only; stage skills do the work; it never dispatches unit workers |
| `brain-workflow-shift` S1 (`SKILL.md:16`) | the owner asked for the main-chat orchestration to move into built skills | the run is carried by named skills with named inputs (D2.2), not by chat improvisation |
| `brain-workflow-shift` G2, G3 (`SKILL.md:20-21`) | one router session carried 350 ledger rows and 130 distinct sub-agents in 14 hours | per-sub-task leads in their own sessions under 30/200 caps; the conductor reads files on a 1-minute tick |
| learn-017 (context-store execution log) | an orchestrator executed worker instructions, leaving 16 PRs and 45+ branches to clean up | Red flag "dispatches unit workers"; cleanup only of catalog rows (D9) |
| pattern 16 (`patterns:140`), D62 (`RLM:79`), Rule 13 | a session ended before its context was written and stranded its artifacts | stage 8 capture owned by the conductor, with read-back by a different agent and the `RUN_HOME/capture/` queue (design part-06 sources, row 8) |

Learning ids and line cites are those of the learnings digest (design part-06 §7b); they are history, cited as data. No project, client or person name is carried.

## Sources

- Design v2: card 1; §1 process map, stop-the-line, back-edges, two exits; §0.1 gates and profiles; §3.1 conductor row; §4 numbers, rule 8 and 8b, reboot and resume, merged tick; §6.4 launcher; §6.5 version hashes.
- INTERFACES 1.4.0 (AM-1 to AM-4 applied): A.1, A.2, A.2.1, A.2.2, A.3, A.4, A.5.1, A.6; B1, B2, B2.1, B4, B5, B6, B8; C2, C5.1-C5.3, C6, C7; D1, D1.1, D2.1, D2.2 rows 1-15, D3, D4, D6.
- Owner rulings (`architecture/delivery-workflow-sources/owner-decisions.md`): D4, D5, D7, D14, D16, D18, D19, D20, D25, Q1, OP3, OP7, OQ-1.
- Task spec `architecture/delivery-workflow/tasks/29-delivery-pipeline.md` and its plan-check `reviews/plan-check-w2-specs.md` (rows W2-1..W2-10, now in INTERFACES 1.4.0 or errata E33, E34).
- Inputs read, not written: `references/templates/` (item 27); `skills/delivery-run/references/briefs/conductor.md`, `read-back.md`, `capture-agent.md` (item 27b).

## Errata applied (not edited here; item 33 owns the source fixes)

- Card 1 and the conductor brief "arm the merged 10-minute tick": the lead arms it (C7); the conductor arms only its 1-minute relay tick (B1).
- Design §1 CYCLE DONE profile restore, archive and execution counter: human steps in the final post and the stage 8 `execution-log.md` row (E33, AM-4 W2-6).
- Design §0.1/§4 "the conductor talks to leads by `SendMessage`": the inbox file is canonical, `SendMessage` carries only `INBOX <subtask>` (E9, C5.2).

## Conventions pending INTERFACES

INTERFACES 1.4.0 is silent on each choice below; the skill uses it as written, and each line is proposed for AM-5 in exact text (queued in the build's `am5-queue.md`, integration step 2026-10-26). Where `SKILL.md` and the references first differed (token forms, the `blocked` set, the resume order, the refused-relay log, the `pm` relaunch, the `security_sensitive` reasons, the capture split), the integration step chose one form and states it in both.

- (29-1, proposed) A.1 `session` token shapes: a lead's launcher session is `<run-id>-<subtask>-l<n>` (`n` the launch count for that sub-task, from 1); the conductor's is `<run-id>-c<n>` (`n` the count of conductor sessions for the run); both inside `^[a-z0-9-]+$` and distinct from the bus `session_id`.
- (29-2, proposed) A.4 conductor launch check: a new lead counts 31 against the machine ledger (at most 30 slot and reserved agents plus its own seat, the W2-9 `live_count`), so a launch is allowed only when `sum(live_count) + 31 <= 200`; rule 8 allows a `MODE=build` launch only when at most 2 rows carry `build=1`; `plan-pr` and `post-merge` leads write `build=0`.
- (29-3, proposed) A.2 run-level `stage` while sub-tasks move in parallel: `1`-`3` run-wide; from the first lead launch until the `pm` lead starts, `stage` is the least advanced stage over the sub-tasks not yet `cleaned`, mapped from `substate.md` `phase` (`seeded|building|integrating` -> `4`, `prepr` -> `4b`, `pr-open|ci` -> `5`, `5a` once `ci: GREEN <sha>` is read and the H-pr read-back is not yet true, `5b` while the conductor's `pr-merge` is in flight, `merged` -> `5c` until `CLEANUP DONE <subtask>`); `6` and `7` follow the `pm` lead's `phase`; `8` from `CLEANUP DONE final`.
- (29-4, proposed) B1, C5.1 "run log": a refused relay (`<id>.desk.refused`) and a refused `CONDUCTOR-REQUEST` (`.refused`) are logged as one line in the conductor's turn output (the session transcript) plus a status-post line; no run-log file is written under `RUN_HOME`.
- (29-5, proposed) A.2 stages 6-7 host on post-merge re-entry: the existing `subtasks[]` `pm` entry is reused with a new `session`; the second `pm` lead is launched only once the old `pm` lead's `substate.lock` is gone or stale (C5.3 lock rule), with `PM_SHA` = the re-entry sub-task's `merge_sha` and a fresh inbox `RELEASE pm`, which sets the entry `state: released` again.
- (29-6, proposed) C5.3 relaunch limits: at conductor resume the dead-lead check also covers `merged` sub-tasks not yet `cleaned` (their lead still owes `delivery-cleanup` mode `subtask`); a lead that dies again after one relaunch before its `phase` advances is reported to the owner, not relaunched a third time.
- (29-7, proposed) B1 no-reply for the conductor's own requests (`pr-approval-state`, `pr-merge`): after the 5 + 5 minute wait the conductor renames `<id>.req` to `<id>.req.noreply`, treats it as terminal `sender` and posts it as a human step in place of the C2 escalation (a C2 record is per unit; the conductor's request belongs to no unit).
- (29-8, proposed) D3 `blocked` on escalations: a file under `RUN_HOME/*/escalations/` or `RUN_HOME/escalations/` is new when the previous status post did not list it; after a conductor resume every open escalation counts as new once, and `ticket-clerk` absorbs a repeat `blocked` for a ticket already `Blocked`.
- (29-9, proposed) D2.2 row 1, card 1 missing state at resume: a `RUN_HOME=` under `$DELIVERY_ROOT` without `state.md` prints `INPUT-ERROR RUN_HOME path`, an unparsable one `INPUT-ERROR RUN_HOME format`; the conductor then prints a rebuild report derived from the row files (`*/substate.md`, `merge-*.md`, `cleanup-*.md`, `gates/`, `tickets.tsv`, `desk/*.out`, the dispatch plan), writes nothing, and stops until the owner decides.
- (29-10, proposed) B1 applied-result scan order at conductor resume: the scan (local writes only: `merge-<sha>.md`, `merge_sha`, `MERGED` and due `RELEASE` inbox files, `gates.H-pr`) runs before every send, the `REGISTER-SENDER` re-send included.
- (29-11, proposed) A.2 `security_audit` input errors: a missing `security_sensitive:` line in `architecture.md` is `INPUT-ERROR security_sensitive missing`; two such lines, or a value other than `yes|no`, is `INPUT-ERROR security_sensitive format`.
- (29-12, proposed) A.2.1, B5 H-pr pointer: the conductor records `gh:<owner>/<repo>#<pr>@<commit_id>` in `gates.H-pr` only when the `pr-approval-state` result has `h_pr` true and `headRefOid` equal to the sub-task's `ci: GREEN <sha>`; otherwise it asks again on a later tick.

## Status

Version `0.1.0` (NEW skill). INTERFACES version checked: 1.4.0, 2026-10-26. The `claude -p` backend and the launcher controls are untested until the work environment (design §6.4); values marked "unmeasured, verify at move" stay so.
