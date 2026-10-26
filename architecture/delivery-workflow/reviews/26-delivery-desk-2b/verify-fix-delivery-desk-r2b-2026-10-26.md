CLEAN

Fix-verifier (Sonnet, not the fixer), round 2b, 26 delivery-desk, against INTERFACES 1.4.0 (d121866). B 0 / M 0 / L 1 (informational, does not change the verdict).

## Closure (current text)
| id | status | evidence | source |
|---|---|---|---|
| AM4-a | closed | verbs.md:38-53, checks.md:95/:103, schemas `verbs.push`: first push needs GATE-PASS + PREPR: PASS, later push GATE-PASS + `ci/<pr>.md` naming the head or PREPR: PASS, fast-forward only; first/later derived from `gh pr list --repo`, never from the request; missing evidence = `marker` (stricter, no new code) | part-b:83; part-a:174-175 |
| AM4-b | closed | verbs.md:125-128 fetch requester = lead before `02-integrate.md` and each `pre-pr-gate`, plus cleanup verify; schemas `verbs.fetch.requester` | part-b:95 |
| AM4-c | closed | checks.md:18 `.desk.refused` written by the conductor, terminal `sender`, desk writes nothing | part-c:117 |
| AM4-d | closed | verbs.md:216-222, SKILL.md:76-77: top-level `parent` only, `fields.parent` = `schema`, `summary`+`issuetype` required, rest optional; schemas `allOf` matches | part-b:100 |
| AM4-e | closed | verbs.md:169-172 quote matches `owner-decisions.md:92` verbatim; frozen B4 kept; schemas `$comment` on publish/tag-push | part-b:97 |
| AM4-f | closed (DEFAULT (author), flagged) | grant file path/gate/verdict match A.2.1; the `<run-id>` in the line is a flagged author default (integrator erratum, out of scope) | part-a:102; part-b:157,164-170 |
| AM4-g | closed | verbs.md:106-109, checks.md:104, schemas marker `merge-target`: `baseRefName` = `default_branch` (A.2.2) | part-a:117 |
| AM4-ver | closed | 1.4.0 in SKILL:14, checks:3-5, schemas; A.2.1 91-105, A.2.2 106-155, A.6 287-328, A.7 329-348, N10 :45, N11 :47, Script interfaces :49-57, O-OP* :198-207, R4-J9 :244, R4-J20 :255 all open on the cited lines | part-a; INTERFACES |
| PR4-C1 | closed | verbs.md:24 -> part-a:116 `clones[]` | part-a:116 |
| PR4-C2a | closed | SKILL.md:153 quotes "ALWAYS HUSKY=0 on desk pushes" = OD:80 | OD:80 |
| PR4-C2b | closed | source-keys.md:33-39 keys C5.1 (PC:111-130), C5.3 (142-151), AM-2, AM-4 (IF:24/26/35/37), OQ-3 (OD:92), R1-6/R1-7 (panel7 r1 :12/:13) all land on the right lines | |
| PR4-C5a, C5b | closed | SKILL.md:133 and :113 (+ checks.md:98) carry `DEFAULT (author)` | |
| V2-1 | closed | SKILL.md:153-155 "inline per-command, never exported, never `--no-verify`" + A.7 link; exit criterion :204-205 "inline (never exported) ... no `--no-verify`" | part-a:333 |

## Regression hunt
1. schemas.json semantic diff (json.load, f68f6f2 snapshot vs current, plus HEAD = f68 content): every difference is explained: r1 (leading-'-' on git_ref/tag/package; branch pattern moved out; pr/ci_run_id min 0; minProperties/minItems removed; STATUS/BUSY regexes R1-9; policy trigger R1-4), r2 (`envelope.verb` `^[a-z-]+$`, schema trigger r2-21), r2b (push requester/markers, fetch requester, jira-create `allOf`, pr-merge `merge-target`, GATE regex + `gate_verdicts` + `grant_source`, publish/tag-push comments, version). No unexplained change.
2. Cites: all part-a/b/c, INTERFACES and OD line cites in skills/delivery-desk (scripted scan plus manual opens) open on the cited content in the current files.
3. Push first/later: the desk classifies first vs later itself from GitHub; the requester names no marker. Reads of `substate.md` and `ci/<pr>.md` only add refusals and implement the B4 requester column of 1.4.0; no trust beyond part B (the gate-run record is equally requester-side and frozen). See L1.
4. `bash SCRATCH/s9-26.sh`: DESK-SCHEMAS-OK; check-doc-length 0 blocking; SKILL.md 2,798 words.

## Findings
| id | sev | file:line | issue | source |
|---|---|---|---|---|
| L1 | L | references/checks.md:93-95 | Text says "nothing the requester wrote counts", but the first/later row reads requester-side files (`substate.md` `prepr`/`head`, `ci/<pr>.md`); and part B B5 lists only head and gate run for `push`. Not a trust extension (stricter, author-flagged, integrator note 2), only wording: say "except the AM-4 first/later evidence named in B4" | part-b:83,110 |
