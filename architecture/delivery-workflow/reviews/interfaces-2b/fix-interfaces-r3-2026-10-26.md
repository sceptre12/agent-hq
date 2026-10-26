# Fix record: INTERFACES 2b, round 3 (2026-10-26)

Fixer: round-3 fixer (separate Opus agent). Input: `reviews/interfaces-2b/panel7-interfaces-r3-2026-10-26.md` (APPROVAL BAR NOT MET 0/28/20). Scope: every M row of class FIX plus PR8-C5. Lows (H28-H47) are out of scope. Refuted rows (H48, H49) are skipped. Paths below are relative to `architecture/delivery-workflow/`. Every new rule is `DEFAULT (integrator)` and is logged in `INTERFACES.md` under "Decisions added by the round-3 fix".

## Findings

H1 FIXED interfaces/part-a-state.md:17 `review-tailor` writes `review-tailor-<slug>.md` itself and the caller mints `SLUG`. The same writer is now named in A.1 derived paths, the A.6 row and the D6 row. D1.1 (part-d:13) says a token whose carrier is a file is never printed instead. `SLUG` is added to the D2.2 row 4 inputs.
H2 FIXED interfaces/part-a-state.md:16 The Integrator now has its own work_item id `i<N>` (it merges `u<N>`). Unit fields use `^[ui][0-9]+$` in the slot row (A.4), the dispatch record (C1.1), C1.2 (part-c:29) and B8 `ANSWER`. The C2 PASS head check runs on the sub-task worktree for an `i<N>` record. The `integrated` entry regex is `^u[0-9]+ [0-9a-f]{40}$` (A.3), and D1.1 and D2.1 token shapes match.
H3 FIXED interfaces/part-a-state.md:281 `ticket-clerk` runs only in the conductor session, so `tickets.tsv`, the cursor and the event log each have one writer and every `jira-*` request carries `run`. B1 requester map updated (part-b:18-19); D3 updated (part-d:105).
H4 FIXED interfaces/part-a-state.md:277 (a) `merge-<sha>.md` is four key=value lines (`pr`, `merge_sha`, `method`, `merge_reach`). (b) `branch-delete` gains a `merge_sha` field (part-b:80), and the B5 squash check confirms it against line 2 of `merge-<merge_sha>.md`. (c) The executor writes the `.req` and the host session sends the `DESK` line. (d) The cleanup record has sections dry-run/approved/executed/residual and is written to a temp file, then `mv`'d into place.
H5 FIXED interfaces/part-a-state.md:103 New A.2.2 table of profile keys: `merge_method`, `merge_reach`, `ci.required_checks[]`, `merge_pipeline.stages[]`, `jira.archive_status`, `durations.*`. A.4 `budget_min`, B5 CI, B6 `ci-status`/`ci-status-main`, D2.2 row 11 and D3 archive now point to it.
H6 FIXED interfaces/part-d-enums-topics.md:37 Closed persona token set in D2.1 (kebab-case of the §3.1-§3.3 names, plus `gate-runner`). The single briefs root is `skills/delivery-run/references/briefs/<persona>.md` (part-c:33). The A.4 slot field type now cites the token set.
H7 FIXED interfaces/part-b-desk.md:69 Every listed field is required. On `jira-create`, `parent` is present exactly when `fields.issuetype` is not `Epic`; anything else is `schema`.
H8 FIXED interfaces/part-b-desk.md:63 B3 step 8 now checks the `merge_reach` row together with the gate files (`gate-missing`). B5 notes that the code is `gate-missing`, not `marker`. The FRZ-g marker list is unchanged.
H9 FIXED interfaces/part-c-waves-control.md:36 The row is split into "completion record" (`output_schema`) and "done condition" (`done_condition`). `token` is the last stdout line of `command` when it exits 0; the gate agent passes only when that line equals `token`.
H10 FIXED interfaces/part-c-waves-control.md:31 `.tasks/<unit>-<slug>.md` replaces `NN-slug` in C1.2 (two rows), C3, A.6 and D6.
H11 FIXED interfaces/part-d-enums-topics.md:69 New input-transport rule: UPPER_SNAKE `NAME=value` args, with `DELIVERY_ROOT` as env only. Every D2.2 row's inputs are rewritten as identifiers, adding `RUN_HOME`, `SUBTASK`, `HEAD`, `PM_SHA`, `PLANS_DIR` where they apply.
H12 FIXED interfaces/part-d-enums-topics.md:55 `MERGED <subtask> <merge_sha>` and its regex are added to the D2.1 conductor-message row.
H13 FIXED interfaces/part-b-desk.md:119 The `ci-status` aggregate is computed over `ci.required_checks[]` by precedence: failure > pending (or a required check absent) > cancelled > success. A required `skipped` counts as success, and the aggregate is never `skipped`. B5 CI now reads the aggregate.
H14 OWNER INTERFACES.md:31 Added owner note N11; the contract is unchanged.
H15 FIXED interfaces/part-c-waves-control.md:11 Wave 0 setup is done in the lead by `delivery-run` before the first `wave-execution` call. The steps and their producers are listed (worktree adds serial, the rest parallel, design §4). `00-constitution.md` stays the only setup wave file.
H16 FIXED interfaces/part-c-waves-control.md:20 `dispatch_budget` is now rule 11's sum over all waves: the A5 term for `01-build.md` and the 0023 term for the barrier waves.
H17 FIXED interfaces/part-b-desk.md:74 `pr-create` now re-derives the review record's content (`marker`), as `pr-merge` already does. B5 per-verb list and FRZ-g / decisions-log rows updated (INTERFACES.md).
H18 FIXED interfaces/part-c-waves-control.md:138 "Mark stale" is removed. Resume runs `catalog.sh audit` and writes only `release`/`fail` for `GHOST` rows.
H19 FIXED interfaces/part-c-waves-control.md:138 New step (3a): the new lead releases every `live` `lane-lease` row (`lane/<name>`, `gate-runner/<n>`) whose holder is dead or is the old lead, then re-leases them per C1.1.
H20 FIXED interfaces/part-c-waves-control.md:119 At start, each lead renames earlier `register*` files to `<name>.<utc>`, so the `register.consumed` gate keys on that start's line. B1 (part-b:22) now says "of its own start".
H21 FIXED interfaces/part-c-waves-control.md:117 The inbox file name is now `<seq>-<utc>-<type>.md`. `<seq>` is allocated by an `O_EXCL` marker `inbox/.seq/<seq>` and files are processed in `<seq>` order. The `pm/outbox` counter uses `pm/outbox/.seq/`.
H22 FIXED interfaces/part-a-state.md:85 Back-edge added: `pr-open`/`merged` -> `building` on `predecessor-reentered`, with `merge_sha` cleared. On post-merge re-entry the conductor adds `st<N>` and re-invokes `delivery-dispatch-plan` with `NEW_UNITS`. Its outputs are those of stage 3, and the `pm` lead never edits `subtasks[]`.
H23 FIXED interfaces/part-d-enums-topics.md:19 The conductor creates `RUN_HOME` and `plans_dir` at stage 1 and passes them to intake (`PLANS_DIR`). New token `PROFILE: <path>@<sha>` (intake stdout), which the conductor copies to `state.md` `repo_profile` (A.2). A new profile goes to `<primary_repo>/plans/repo-profile.md` (A.6).
H24 FIXED interfaces/part-c-waves-control.md:52 `delivery-dispatch-plan` dispatches the Plan-checker (depth 1, brief, inputs) after it writes `waves/`. The fix loop runs to `PLAN-CHECK: clean` or round 3 (D7). D2.2 row 5 output updated.
H25 FIXED interfaces/part-d-enums-topics.md:105 `delivery-dispatch-plan` fills `ticket` from `tickets.tsv` (key, else slug), and the conductor never edits the unit table. D2.2 row 5 now reads `tickets.tsv`.
H26 FIXED interfaces/part-b-desk.md:73 No push precedes 4b. The first push is the stage-5 push after `PREPR: PASS`, and later pushes only fast-forward.
H27 FIXED interfaces/part-c-waves-control.md:117 Two cleanup triggers are defined. The `pm` lead's cleanup runs after `release-<pm_sha>.md`, with evidence and approver named. The conductor's `final` cleanup runs before `stage: done`. `SUBTASK` is omitted for `final` (D2.2 row 9).
PR8-C5 FIXED interfaces/part-b-desk.md:22 The register-before-DESK sentence now carries `DEFAULT (integrator)`.

## Owner notes added

- N11 (INTERFACES.md:31): human gate on `tag-push` (H14), open, owner, not decided here. Sources: `part-02-skill-inventory.md:74` and `owner-decisions.md:23`. Options (a)/(b). Recommended answer: (a), mirroring `publish`.
- N10 (INTERFACES.md:29): added the r3 H36 first-push signal and a "Recommended answer:" line. It recommends keeping D21 as written and having the desk derive "first push" from the absent remote branch.
- The count sentence (INTERFACES.md:27) now reads "Two open owner notes, N10 and N11".

## Checks

`bash tools/check-doc-length.sh .` (worktree root): `0 blocking file(s) over 500 lines; 0 allowlisted file(s) over 500 lines; 2 file(s) over 40000 bytes (second dimension, informational only, not blocking)`. The two files are `changelog.md` (not written here) and `interfaces/part-a-state.md` (42792 bytes, 300 lines).

`wc -l`: INTERFACES.md 231; part-a-state.md 300; part-b-desk.md 162; part-c-waves-control.md 176; part-d-enums-topics.md 160 (total 1029).

Not re-checked here: a full C1 cite-resolution sweep of the pre-existing text. The cites added in this round were opened and verified: `part-03-personas-and-concurrency.md:80`, `:10-44`; `spec-format.md:120-128`; ADR 0054 `:118-121`; ADR 0055 `:166-168`; `part-02-skill-inventory.md:74`; `owner-decisions.md:23`.
