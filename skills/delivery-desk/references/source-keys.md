# delivery-desk: source keys

Every bare id in this skill (`SKILL.md`, `references/*`) resolves here to an openable
`path:line-range` (paths from the agent-hq root). `OD` = `architecture/delivery-workflow-sources/owner-decisions.md`;
`CL` = `architecture/delivery-workflow/changelog.md`; `IF` = `architecture/delivery-workflow/INTERFACES.md`;
`PB` = `architecture/delivery-workflow/interfaces/part-b-desk.md`; `PA` = `.../interfaces/part-a-state.md`;
`PD` = `.../interfaces/part-d-enums-topics.md`; `PC` = `.../interfaces/part-c-waves-control.md`.

| Key | Source | Says |
|---|---|---|
| design §6.3 | `architecture/delivery-workflow/part-05-execution-constraints.md:36-44` | `delivery-desk` contract (D3, B1) |
| D3 (owner) | `OD:4` | a desk skill owns all git/GitHub steps |
| D23 | `OD:21` | ci-fix-loop never edits pipeline definitions or triggers |
| D1, D1 (part) | `PD:6-11` | Step 0 input validation (`INPUT-ERROR` lines) |
| D3 (part), "D3 canonical status" | `PD:105-107` | status vocabulary, canonical ticket statuses |
| Q1 | `OD:58` | the conductor relays `DESK` lines for `claude -p` leads |
| Q2 ("RESOLVED Q2") | `architecture/delivery-workflow/tasks/26-delivery-desk.md:124` | registration, gate, answer and rebind lines are not verbs |
| Q3 | `OD:60` | `pr-attach` verb plus `record_path` on `pr-create` and `pr-merge` |
| OP1 A | `OD:63`; `IF:198` (O-OP1) | no detail on the `REJECTED` line; detail in `.out` |
| OP5 B | `OD:67`; `IF:202` (O-OP5) | terminal vs curable; curable resent with a fresh id |
| OP6 A | `OD:68`; `IF:203` (O-OP6) | R2-7 is runtime only; build-time git keeps the existing envelope |
| OP9 A | `OD:71`; `IF:206` (O-OP9) | traces scanned; images attached unscanned and labelled |
| OP10 A | `OD:72`; `IF:207` (O-OP10) | tenth code `action-failed`, curable |
| R2-4 | `OD:38` | operator's own locally configured GitHub auth; no bot account |
| N10 | `OD:80`; `IF:45` | "ALWAYS HUSKY=0 on desk pushes" |
| N11 | `OD:81-84`; `IF:47` | tag-push set per repo in repo-profile; no entry, refused |
| M24 | `CL:206` | Tier 1 location; §6.3 `ci-status-main` |
| M27 | `CL:40` | no approve or trigger-prod verbs |
| M29 | `CL:211` | forgeable request channel: sha256, desk-owned copy |
| M30 | `CL:212` | agent-writable gates: the desk writes gate files |
| R4-J9 | `IF:244` | applied-result scan on resume |
| R4-J20 | `IF:255` | `pr-create` and `push` CI bounds |
| C5.1 | `PC:111-130` | lead outbox and inbox layout (`.desk`, `.desk.relayed`, `.desk.refused`, `CONDUCTOR-REQUEST`) |
| C5.3 | `PC:142-151` | lead resume and hand-over |
| AM-2 | `IF:24`; `IF:35` | amendment 1.1.0 -> 1.2.0 (row 12, PC-6: `release-track` owns test reporting) |
| AM-4 | `IF:26`; `IF:37` | amendment 1.3.0 -> 1.4.0 (24-Q2 push, W2-4 `fetch` and `.desk.refused`, 22 `jira-create`, 20 Q1 grant file, 20 Q6 `default_branch`) |
| OQ-3 (release-track) | `OD:92` | the desk runs publish/tag-push only after the H-prod grant (frozen B4 stands) |
| R1-6 | `architecture/delivery-workflow/reviews/26-delivery-desk-2b/panel7-delivery-desk-r1-2026-10-26.md:12` | review finding: the redaction scan fails closed |
| R1-7 | same file `:13` | review finding: images classified by content, not by name |
| INTERFACES §Script interfaces | `IF:49-57` | `desk-req.sh` and other script contracts |
| Part B sections | `PB:7-24` B1; `:25-51` B2; `:52-68` B2.1; `:69-76` B3; `:77-107` B4; `:108-111` B5; `:112-143` B6; `:144-151` B7; `:152-172` B8 | desk contract |
| Part A sections | `PA:7-52` A.1; `:91-105` A.2.1; `:106-155` A.2.2; `:156-203` A.3; `:287-328` A.6; `:329-348` A.7 | state, gates, profile keys, names, `HUSKY=0` |
