# Fix record, INTERFACES 2b, round 1c (2026-10-26)

Fixer: narrow fixer r1c (Opus), not the author, orchestrator or verifier (Rule 4). Inputs: ADR 0054 and ADR 0055 (both accepted 2026-10-26), the item lists at the end of `reviews/adr-0055-rung1.md` (18) and `reviews/adr-0054-rung1.md` (15), r1b record. Files edited: `INTERFACES.md`, `interfaces/part-b-desk.md`, `interfaces/part-c-waves-control.md`. No ADR, design, rung-1 record or freeze-status line edited. Line numbers are current (after this fix).

## ADR 0055 rung-1 items

ADR55-1  ALREADY INTERFACES.md:162 (E5), part-b-desk.md:34 long `DONE` form, OP2 A
ADR55-2  ALREADY INTERFACES.md:27 N3-N7 retired into rows O-OP1..O-OP10
ADR55-3  ALREADY INTERFACES.md:64 B1 row: desk-held registry (OP3 B)
ADR55-4  CHANGED INTERFACES.md:145 row FRZ-c adds the per-code class; B2.1 pairing row :66 and O-OP10 :125 already had `action-failed`
ADR55-5  CHANGED part-b-desk.md:13 `DESK_ADDRESS` = `desk` FROZEN; INTERFACES.md:144 FRZ-b
ADR55-6  ALREADY part-b-desk.md:5 scope cites OP6 A
ADR55-7  ALREADY part-b-desk.md:12 desk tier, "never source" scoped to `INSTALL`, requester tiers (OP4 A)
ADR55-8  CHANGED part-b-desk.md:13 desk address no longer open (see FRZ-b)
ADR55-9  CHANGED part-b-desk.md:16 registration line FROZEN, reply regex added, producer/consumer named
ADR55-10 ALREADY part-b-desk.md:35 token `run`, `yyyymmddThhmmssZ` (OP7 A)
ADR55-11 ALREADY part-b-desk.md:29 ten codes incl. `action-failed`
ADR55-12 ALREADY part-b-desk.md:47 `sender` uses the desk-held registry
ADR55-13 ALREADY part-b-desk.md:45-56, :62 class column; B3 step 9 `action-failed`
ADR55-14 CHANGED part-b-desk.md:68 `fields.subtask` `^(st[0-9]+|pm)$` vs envelope `subtask` `^(st[0-9]+|pm|run)$` reconciled
ADR55-15 CHANGED part-b-desk.md:105 `.out` for a failed action: `REJECTED`/`action-failed`, `detail`, `.inflight` kept
ADR55-16 ALREADY part-b-desk.md:74, :134 OP9 A cited
ADR55-17 ALREADY part-a-state.md:77 no `conductor_id`; `lead_id` conductor's own record
ADR55-18 ALREADY INTERFACES.md:162 E5, :171 E14 (`action-failed`)

## ADR 0054 rung-1 items

ADR54-1  ALREADY part-c-waves-control.md:19 no 3-unit reservation; gate and fix agents count (Q3)
ADR54-2  ALREADY part-c-waves-control.md:20 Q5 ruling cited
ADR54-3  ALREADY part-c-waves-control.md:36 `done_condition` per-work_item field, rule 9 (Q2)
ADR54-4  CHANGED part-c-waves-control.md:37 verifier row now states which output the gate agent reads (A4 :88-89)
ADR54-5  ALREADY part-c-waves-control.md:3, :23 refs `:38-197`, A9 `:179-197`
ADR54-6  ALREADY part-c-waves-control.md:32 `TaskStop` only already-live agents
ADR54-7  CHANGED part-c-waves-control.md:3, :23 "ratifies" -> accepted 2026-10-26
ADR54-8  ALREADY part-a-state.md:179 `30 - live_rows - sum(A.3 reserved)`, no reservation rows
ADR54-9  ALREADY INTERFACES.md:27, :127 N1 retired (O-Q3)
ADR54-10 ALREADY INTERFACES.md:126 N2 retired (O-Q2)
ADR54-11 ALREADY INTERFACES.md:128, :133 N8 retired (O-Q4, O-Q9)
ADR54-12 ALREADY INTERFACES.md:129 N9 retired (O-Q5)
ADR54-13 ALREADY INTERFACES.md:105, :169 no "meanwhile"/`## Done condition`/"proposed text"
ADR54-14 CHANGED INTERFACES.md:74 C1.1 row: ratified with ADR 0054; also :69 B5 row for ADR 0055
ADR54-15 CHANGED INTERFACES.md:172 new erratum E15 (part-02 :60, :84 per-wave `max_concurrent`, no `bus_endpoint`, `TaskStop` of dependents)

## ADR 0055 `[freeze]` items (ADR 0054 has none)

FRZ-a     CHANGED part-b-desk.md:16 registration line FROZEN, request and reply regex; INTERFACES.md:143
FRZ-b     CHANGED part-b-desk.md:13 desk session `desk`, closed set `{desk}`; INTERFACES.md:144
FRZ-c     CHANGED part-b-desk.md:43 terminal {sender, schema, hash, repo, policy}, curable {marker, order, stale-session, gate-missing, action-failed}; INTERFACES.md:145
FRZ-d     CHANGED part-b-desk.md:18 conductor-only set `^(pr-merge|publish|tag-push|test-report-push)$`, epic `jira-create` via `run`; INTERFACES.md:146
FRZ-e     CONSISTENT part-b-desk.md:17, :62 step 5 JSON `subtask` = id `<subtask>` (label only); INTERFACES.md:147
FRZ-f     CONSISTENT part-b-desk.md:74, :95 `lanes/` and `review/<subtask>/` roots (label only); INTERFACES.md:148
FRZ-g     CHANGED part-b-desk.md:99 per-verb list stated; gate run now also for `pr-merge` (matched B4 :78); INTERFACES.md:149
FRZ-order CHANGED part-b-desk.md:36, :62 replay before copy and hash; INTERFACES.md:150
FRZ-h     CONSISTENT part-b-desk.md:156 H-prod path (label only); INTERFACES.md:151
FRZ-i     CHANGED part-b-desk.md:39 non-collision regex, profiles checked 2026-10-26; INTERFACES.md:152
B2-REPEAT CHANGED part-b-desk.md:36, :48, :62; INTERFACES.md:100 a repeated id with a stored `.out` returns it with no hash compare (ADR 0055 :185-191); "differing hash = `REJECTED schema`" removed from B2 and B2.1

## Checks

- `bash tools/check-doc-length.sh .`: 0 blocking files over 500 lines (INTERFACES.md 178, part-a 278, part-b 158, part-c 173, part-d 155).
- grep `REJECTED schema|different .request_sha256.|ratifies with|owner to decide` over the five files: no hits.
- Every cited ADR line range opened and checked against the accepted text.
ADR55-ACCEPT part-b-desk.md:4 sources row updated to accepted ADR pointers and OP1-OP10
ADR55-ACCEPT part-b-desk.md:20 grammar authority row cites ADR 0055 accepted 2026-10-26
