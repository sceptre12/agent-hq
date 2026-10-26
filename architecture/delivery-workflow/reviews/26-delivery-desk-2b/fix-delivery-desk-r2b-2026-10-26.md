# Fix r2b: 26 delivery-desk (INTERFACES 1.4.0 reconcile, pre-round r3 FAILs, V2-1), 2026-10-26

Fixer: Opus subagent (not the author, not a seat or verifier; Rule 4). Write scope: `skills/delivery-desk/*` and this record.
Inputs: `git diff a83bc8b d121866 -- architecture/delivery-workflow/` (AM-4, INTERFACES 1.4.0), `preround-delivery-desk-r3-2026-10-26.md`, `verify-fix-delivery-desk-r2-2026-10-26.md` V2-1.

## Fix table

| id | status | file:line after | change |
|---|---|---|---|
| AM4-a | FIXED | verbs.md:38-53; checks.md:95, :103; SKILL.md:104-105; schemas.json `verbs.push.requester`, `.markers` | B4 `push` first vs later push. First/later is re-derived by the desk from `gh pr list --repo --head=<branch> --state=open`: one open PR = later push (`<pr>` = it), none = first push (stricter rule, also when the branch exists on the remote without a PR), more than one = `marker` `pr-ambiguous`. `PREPR: PASS` read from `substate.md` `prepr`/`head` (A.3); CI evidence = a line of `ci/<pr>.md` containing `expect_head`. Missing evidence = `marker`, `detail` `prepr` / `ci-or-prepr`. All `DEFAULT (author)`. |
| AM4-b | FIXED | verbs.md:125-128; schemas.json `verbs.fetch.requester` | `fetch` requester: the lead before `02-integrate.md` and before each `pre-pr-gate`; `delivery-cleanup` verify (W2-4, part-b:95). |
| AM4-c | FIXED | checks.md:18 | `.desk.refused`: a refused relay never reaches the desk; the conductor writes it, the lead treats it as terminal `sender`; the desk writes nothing (part C:117). |
| AM4-d | FIXED | verbs.md:216-222; SKILL.md:76-77; schemas.json `verbs.jira-create.request.allOf`, `$comment` | Top-level `parent` is the only carrier; `fields.parent` is `schema` (check 5, schema `not required parent`); `fields` requires `summary` and `issuetype`, all else optional (part-b:100). |
| AM4-e | FIXED | verbs.md:169-172; schemas.json `verbs.publish.$comment`, `verbs.tag-push.$comment`; source-keys.md:37 | Owner OQ-3 quoted verbatim from `owner-decisions.md:92`; frozen B4 kept (tag-push file only under `approval: human`). |
| AM4-f | FIXED (DEFAULT (author)) | human-gates.md:12, :17-21, :35, :57; SKILL.md:50-51; schemas.json `regexes.GATE`, `regexes.gate_verdicts`, `regexes.grant_source` | `grant.<subtask>.<n>` ok, file `RUN_HOME/gates/grant.<subtask>.<n>.ok`; B8 form `GATE <run-id> grant.<subtask>.<n> ok <text>`; typed text must start `ref=<sensitive path>` else refused in session. Marked `DEFAULT (author), pending an INTERFACES erratum`. |
| AM4-g | FIXED | verbs.md:106-109; checks.md:104; schemas.json `verbs.pr-merge.markers` (+`merge-target`) | `pr-merge`: PR `baseRefName` must equal profile `default_branch` (A.2.2 :117) else `marker` `base`; absent key `marker` `default_branch` (`DEFAULT (author)` code). Part B names no "main" in content-merged (B5) or merge derivations, so `branch-delete` is unchanged. |
| AM4-ver | FIXED | SKILL.md:14; checks.md:3-5; schemas.json `$comment`, `interfaces_version` | 1.2.0 -> 1.4.0; part-a cites re-checked: A.2.1 91-105, A.2.2 106-155, A.6 287-328, A.7 329-348; INTERFACES cites +2 (N10 :45, N11 :47, O-OP* :198-207, R4-J9 :244, R4-J20 :255, Script interfaces :49-57). |
| PR4-C1 | FIXED | verbs.md:24 | `part-a-state.md:115` -> `:116` (`clones[]`). |
| PR4-C2a | FIXED | SKILL.md:153; source-keys.md:25 | N10 now quotes `owner-decisions.md:80` verbatim: "ALWAYS HUSKY=0 on desk pushes". |
| PR4-C2b | FIXED | source-keys.md:33-39 | Added C5.1 (PC:111-130), C5.3 (PC:142-151), AM-2 (IF:24, :35), AM-4 (IF:26, :37), OQ-3 (OD:92), R1-6, R1-7 (panel7 r1 :12, :13); `PC` prefix defined. |
| PR4-C5a | FIXED | SKILL.md:133 | serial-queue rule tagged `DEFAULT (author)`. |
| PR4-C5b | FIXED | SKILL.md:113; checks.md:98 | `<remote>` = `origin` tagged `DEFAULT (author)`. |
| V2-1 | FIXED | SKILL.md:153-155, :204-205; verbs.md:57 | HUSKY bullet: "inline per-command, never exported, never `--no-verify`" + A.7 link (no restatement); exit criterion: "inline (never exported) ... no `--no-verify`". |
| size | done | SKILL.md | step 9 profile-resolution parenthetical replaced by a pointer to checks.md §Per-field roots (already there, :56-61). 19,342 -> 19,485 bytes. |

## Hunk map (this round only)

- SKILL.md :14 -> AM4-ver; :50-51 -> AM4-f; :76-77 -> AM4-d; :83 -> size; :104-105 -> AM4-a, AM4-g; :113 -> PR4-C5b; :133 -> PR4-C5a; :153-155 -> PR4-C2a, V2-1; :204-205 -> V2-1.
- verbs.md :24 -> PR4-C1; :38-53 -> AM4-a; :57 -> V2-1, AM4-ver (A.7 cite); :106-109 -> AM4-g; :125-128 -> AM4-b; :169-172 -> AM4-e; :216-222 -> AM4-d.
- checks.md :3-5 -> AM4-ver; :18 -> AM4-c; :95 -> AM4-a; :98 -> PR4-C5b; :103 -> AM4-a; :104 -> AM4-g; :182 -> AM4-ver (IF cite).
- human-gates.md :7 -> AM4-ver (A.2.1 cite); :12, :17-21, :35, :57 -> AM4-f.
- source-keys.md :7 (PC prefix), :19-26, :30-31, :33-40, :42 -> PR4-C2a/C2b, AM4-ver, AM4-e.
- schemas.json: `$comment`, `interfaces_version` -> AM4-ver; `verbs.push` -> AM4-a; `verbs.fetch` -> AM4-b; `verbs.jira-create.request` -> AM4-d; `verbs.publish`/`tag-push` `$comment` -> AM4-e; `verbs.pr-merge.markers` -> AM4-g; `regexes.GATE`, `gate_verdicts`, `grant_source` -> AM4-f. Note: the file was re-serialized (one json.dump, then a compact re-layout: definitions, reason codes and regex entries one per line; verbs expanded to `request`/`result` properties), so its textual diff is whole-file; the semantic diff is only the keys listed here (JSON-equal otherwise to the r2 content).

## Integrator / owner notes (not decided here)

1. INTERFACES inconsistency (integrator, erratum needed): A.2.1 (`part-a-state.md:102`, AM-4 20 Q1) writes the grant line as `GATE grant.<subtask>.<n> ok <text>` (no `<run-id>`), and B8 (`part-b-desk.md:157` regex, matrix :164-170) has no `grant.*` gate. The skill implements `GATE <run-id> grant.<subtask>.<n> ok <text>` as `DEFAULT (author)`; the `ref=<path>` leading token is also an author default (the desk cannot compute the path).
2. Part B does not say how the desk tells a first push from a later one, nor where `PREPR: PASS` lives for the desk (only A.3 `substate.md`, a lead-written file: the desk "re-derives" from a requester-side record here). Candidate erratum: name the evidence file and the derivation.
3. `ci/<pr>.md` "naming that head": only line 1 (`CI:`) is fixed in part D1; the skill accepts any line containing the 40-hex head.
4. `pr-create` `base` is not checked against `default_branch` (A.2.2 names only `pr-merge`); integrator may extend.
5. OQ-3 says "publish/tag-push only after the H-prod grant" while frozen B4 lets `tag-push` under `release_tags.approval: none` run without a file; the skill keeps frozen B4 ("frozen B4 stands"). Owner to confirm the reading if needed.
6. C4 KNOWN (spec 26 line 5 "1.1.0") left as instructed.

## Checks (from W)

- `bash SCRATCH/s9-26.sh`: DESK-SCHEMAS-OK (against part-b 1.4.0); no MISSING / D16-VIOLATION / NO-USE-WHEN / RULE-MISSING; check-doc-length 0 blocking; SKILL.md 2,798 words.
- `json.load` schemas.json: ok; 816 lines (< 1000). References: checks 189, verbs 233, human-gates 77, source-keys 42 lines (< 500).
- `python3 -I` probe d) (jsonschema Draft7 on `verbs.jira-create.request`): story with parent ok; epic without parent ok; `fields.parent`, missing summary, missing issuetype, story without parent, epic with parent all rejected (7/7 PASS).
- `python3 -I` probe f) (`grep -E` on `regexes.GATE`): `GATE <run> grant.st2.1 ok ref=...` and `grant.pm.12` match; the A.2.1 form without `<run-id>`, `grant.st2` (no `<n>`), `grantXst2.1` refused; H-prod and H1 lines still match (7/7 PASS).
- `wc -c SKILL.md`: 19,485 (cap ~19,500).
