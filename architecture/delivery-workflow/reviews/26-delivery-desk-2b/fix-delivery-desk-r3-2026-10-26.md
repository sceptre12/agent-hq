# Fix record: delivery-desk round 3 (final, D7), 2026-10-26

Fixer: Opus subagent (not author, seat or verifier). Input: panel7-delivery-desk-r3-2026-10-26.md. INTERFACES 1.4.0.
Paths relative to skills/delivery-desk/.

| id | status | file:line after | change |
|---|---|---|---|
| R3-M1 | FIXED | SKILL.md:63-67, :109-110; references/checks.md:141-155; references/verbs.md:124-126 | Crash-resume read-back placed at ONE point, B3 step 2 (SKILL step 5). checks.md §Inflight item 1 is the single definition; step 12 keeps only the claim (reusing a step-5 `.inflight`) and the fresh-id guard (item 3). `branch-delete` "present" = `git ls-remote` prints nothing; `merged_check` stored before the act in desk-owned `desk-inbox/<id>.derived` so the step-2 `DONE` is complete. Reconcile only when the desk copy `desk-inbox/<id>.req` exists and the target verb equals the line verb, else continue at check 3. |
| R3-M2 | FIXED | references/checks.md:76-85; SKILL.md:93-94; references/verbs.md:75-79 | `pr-attach`: after the root check each file is copied once (`cp -P`, no symlink follow; non-regular copy = `repo`) to `$DELIVERY_ROOT/desk-inbox/<id>.attach/<k>-<basename>`; classify (mime + extension), scan and upload that copy only; `lanes/` never re-read. `attached[].path` stays the request path. |
| verify-r2b L1 | FIXED | references/checks.md:102-108 | "nothing the requester wrote counts" replaced: a claimed marker counts for nothing; the requester-host files read are named (gate-run record, review record, `merge-<merge_sha>.md` line 2, and for `push` the B4 push-row evidence `substate.md` `prepr`/`head` and `ci/<pr>.md`, part-b:83), each compared to desk-derived `expect_head`/`<pr>`, refusal-only. |
| R3-M3 | OWNER | tools/delivery/desk-req-schema.sh (outside write scope) | not touched |
| R3-L1..L11 | LEFT | - | per brief |

Why step 2 for R3-M1: part B :47 only requires the read-back "before acting again"; B3 (part-b:73) settles a repeat id at step 2, so reconciling there keeps the frozen B3 order exactly (a repeat id is answered where repeats are answered) and still precedes the act. At step 9 the read-back would sit behind checks 3-8, which re-read state the stopped act already changed (content-merged after the remote branch is deleted, open-PR count after pr-create), giving `REJECTED` for an act that happened.

## Hunk map (vs pre-fix)
- SKILL.md: @65 step 5 crash-resume; @87 step 9 branch wording trim (bytes); @93 step 9 attach copy; @109 step 12 claim reuse + `.derived`; @134 step 15 idle-reply wording trim (bytes, same content).
- references/checks.md: @76 attach copy bullet + image bullet on copy; @103 markers trust sentence (L1); @141 §Inflight item 1 rewrite.
- references/verbs.md: @75 pr-attach checks/act on copy; @124 branch-delete `merged_check` stored.

## Owner notes
- OWNER R3-M3: desk-req-schema.sh jira-create (reject `fields.parent`, require `fields.summary`, `fields.issuetype`); sender change outside skills/delivery-desk/.
- New author defaults (owner may override): `desk-inbox/<id>.derived` and `desk-inbox/<id>.attach/` layout; step-2 reconcile gated on the desk copy existing.
- R3-L1 trust question (anchor push evidence on gate-agent checklist) unchanged; D7 round 3, owner decides.

## Checks
- SKILL.md 19,596 bytes (cap ~19,600); 
- `bash SCRATCH/s9-26.sh`: rc=0, DESK-SCHEMAS-OK, no MISSING/VIOLATION/NO-USE-WHEN/RULE-MISSING.
- json.load schemas.json: OK (unchanged).
- check-doc-length.sh: 0 blocking; checks.md 212 lines, verbs.md 237.
