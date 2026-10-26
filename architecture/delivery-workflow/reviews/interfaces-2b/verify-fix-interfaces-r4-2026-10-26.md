ISSUES_FOUND 0/0/7

Round-4 fix-verifier (final round), fresh read-only agent (not the fixer, Rule 4). Scope: D/INTERFACES.md and D/interfaces/part-a..d, against panel7-interfaces-r4 (J1-J23, PR10-C5), fix-interfaces-r4 and fix-interfaces-r4-0, owner-decisions.md:78-84, ADR 0054/0055, measurements-2026-10-26.md and part-03. A, B, C, D = interfaces/part-a-state.md, part-b-desk.md, part-c-waves-control.md, part-d-enums-topics.md; I = INTERFACES.md. Regex spot checks run with `grep -E` (DESK, DONE, REJECTED, INPUT-ERROR with `ci.required_checks[]`, `job`, audit lines, CONDUCTOR-REQUEST, stop-the-line `S8`/`D23`): all behave as written. `check-doc-length.sh`: 0 blocking files.

## Issues (0 B, 0 M, 7 L)

| id | sev | file:line | defect | source |
|---|---|---|---|---|
| V4-1 | L | I:127 vs A:150 | The decisions-log row A.3 still lists the seed keys as `subtask_id session_id reserved frontier phase`; A.3 now says "exactly" those plus `interfaces_version` (R4-J23). Two key lists for the seed. A careful author follows A.3. | A:150, I:233 |
| V4-2 | L | C:21, D:38 | The persona token `gate-checker` now labels the `wave-execution` step_complete gate agent (R4-J12), but it already names the pr-review gate checker of design 3.1 (part-03:15; D4 topic row, D:118). One token, one brief path (`briefs/<persona>.md`), two roles. The slot-row persona is label-only, so low impact. | part-03:15, D:118 |
| V4-3 | L | B:14 vs A:110, A:130 | Registered clones of a linked repo come from "each linked profile's `clones[]`" (B:14), but the resolution procedure matches only the `linked_profiles[].clone` entry (A:130). A second clone listed only in the linked profile's `clones[]` is registered under B:14 and `REJECTED repo` under A:130. | A:130 |
| V4-4 | L | C:73 vs C:79-80 | "Any non-PASS record = failed gate" (R4-J15) does not say whether the controller then enters the fix loop (ADR 0054 A5: a failed gate runs the fix loop) for a unit the lead has just paused (`ESCALATE`) or is re-dispatching (`ROLLED`). The wave-execution and delivery-run authors could diverge, and fix agents could write into a paused unit worktree. The `tier_override` re-invocation also does not say it waits for the live invocation to end (same pinned `session_id`). | ADR 0054 A5 (`0054-*.md:98-112`) |
| V4-5 | L | B:83-84, B:22, B:110 | The desk waits "up to 5 minutes" for `ci.min_push_spacing_s`, the same 5 minutes a requester polls before re-sending the same `<id>` (B:22), and it blocks the single desk session meanwhile. `pipeline-bound` and `push-spacing` are not in the B5 per-verb marker list or the B2.1 `marker` trigger text, and B3 does not place the `gh` count step. | B:22, B:62 |
| V4-6 | L | A:298, A:55 | `delivery-dispatch-plan` copies `interfaces_version` "from `state.md`" into the plan header, but A.2's reader list and D2.2 row 5 do not name it as a reader or input (only `RUN_HOME`). A careful author reads `RUN_HOME/state.md`. | A:55, D:78 |
| V4-7 | L | A:107-126 | A.2.2 still omits profile keys read elsewhere in the set: `e2e.harness` (D:49) and the lane `verify_cmd`/`cleanup_cmd` for catalog kind `db` (A:262). These were not in the J1 list; stated for completeness. | A:262, D:49 |

## Per-J resolved list (verified at the cited lines)

- J1 RESOLVED. A:105 serialization (one YAML document, dotted = nested map, `"yes"`/`"no"` quoted, regexes single-quoted) and a single writer, `delivery-intake`, stated as a sentence rather than a column (same writer for every key). Keys added: A:109-122 (`clones[]`, `linked_profiles[]`, `worktree_base`, `ci.min_push_spacing_s`, `ci.max_open_pr_pipelines`, `jira.status_map`, `secrets.pattern_file`, `gates.*`, `node.prefix_cmd`, `zephyr.read_ops`). `release-track` is a reader of `release_tags.*` (A:124-126). See V4-7 for two keys outside the J1 list.
- J2 RESOLVED (V4-3 is a residual edge). `repo_profile` is in the desk's reads (A:55), plus `linked_profiles[]` (A:110) and the resolution rule (A:130, B:14, B:96).
- J3 RESOLVED. A:296 step table, `step_id` `^[a-z0-9-]+$` (A:16), minted by `delivery-architecture` and kept by `release-track`; B4 `publish`/`tag-push`/`step_id`, H-prod A:99, B:170.
- J4 RESOLVED. A:128 (malformed entry = `REJECTED policy`, key in `detail`, absent approval never "no gate"), B:64, B:96.
- J5 RESOLVED. POSIX ERE declared at I:43-45 and D:10; no named groups, `\d`, `\s`, `\w` or `\n` left in any regex (grep); B:46 uses numbered groups; B:79 `job` is `^[^[:cntrl:]]{1,200}$`.
- J6 RESOLVED. Anchored ERE for `DESK`, `DONE`, `REJECTED` at B:36-38, tested; non-matching `DESK` logged with no reply (B:41); "no imperatives" marked authoring-only. The `DONE` verdict class `[^|[:cntrl:]]+` is valid ERE (the proposed `[^\|\n]+` was not).
- J7 RESOLVED. D:8 `[A-Za-z_][][A-Za-z0-9_.]*` accepts `ci.required_checks[]` and `merge_pipeline.stages[]` (tested).
- J8 RESOLVED. B:47 targets `repo#branch@expect_head` and `repo#tag@sha`; "already present" only on an equal remote sha or PR head.
- J9 RESOLVED. B:22 applied-result scan before any send, per requester, per verb record.
- J10 RESOLVED (an edge with a third actor remains and is not raised). A:178 re-reads `owner` after the break `mv` and renames back on mismatch; 1 s retry and 60 s timeout, exit 4, I:41.
- J11 RESOLVED. A:174 closed table (`S1`-`S8`, `G1`, `G3`, `G4`, `G5`, `D23`) matches the regex at A:161; C:178 writes `stop-the-line:S8`.
- J12 RESOLVED. `invocation` is in D:98 and A:162; record path, order, fields and the lead-derived `worktree` at C:21-22 and A:196; A:42 agrees. The `gate-checker` label is V4-2.
- J13 RESOLVED, and the depth claim holds (check 5). measurements:105-118 shows levels 0, 1, 2 hold the Agent tool and level 3 does not. A background controller at depth 1 makes its workers, gate and fix agents depth 2, none of which dispatches (part-03:10-23 "Holds Agent tool: no"). Review stays lead 0, orchestrator 1, seats 2 (part-03:25), so no dispatching agent lands at depth 3. The fallback is a blocking call (C:23) and E16 is logged (I:269). A claude -p lead with a background task is the case card 7 already names (C:176).
- J14 RESOLVED. C:35; `delivery-run` copies nothing; the agent reads `Brief:` first.
- J15 RESOLVED apart from V4-4. C:73, C:80, D:98.
- J16 RESOLVED. D:79 adds `REPO_PROFILE`, `REPO`, `SESSION`, `PM_SHA`; A:87 passes `PM_SHA` to the `pm` lead. `REPO` for `pm` is not in the dispatch-plan table, a small gap that the primary clone fills.
- J17 RESOLVED. A:298 gives `ticket`, `branch` (matches the B4 branch regex), `repo`, the sub-task worktree path, and the `st0` copy step.
- J18 RESOLVED. D:27 and C:121 give `LIVE` and `ROLLED-BACK` as terminal; `WAITING-HUMAN` is rewritten atomically.
- J19 RESOLVED. A:290-294 and D:139, D:147 make v1, retro and execution-log RUN-only; "also committed" is gone; E17.
- J20 RESOLVED apart from V4-5. B:83-84, I:230.
- J21 RESOLVED. I:39 and C:173: `base-sha` by `merge-base`, never stored; tasks file under `primary_repo`, derived from `PLANS_DIR`.
- J22 RESOLVED. D:94-100 transport rule and UPPER_SNAKE names; `wave-execution` stays snake_case; no stale lowercase names found by grep.
- J23 RESOLVED apart from V4-1 and V4-6. `interfaces_version` is in the seed (A:150), the plan header (A:298) and `delivery-run` Step 0 (D:79, D:163).
- PR10-C5 RESOLVED. A:312 (gate-runner sentence and `--no-verify`), A:101, B:64 and I:197 now carry a `DEFAULT (integrator)` tag or a verbatim owner quote.

## Check results

(1) Every M above is resolved at the cited lines; the residuals are Low only.

(2) No new regex break (tested above). Each new term (`invocation`, `tier_override`, `linked_profiles[]`, `clones[]`, `PM_SHA`, `REPO`, `SESSION`, `interfaces_version`, `S1`-`S8`, `pipeline-bound`, `push-spacing`) has one spelling and a producer and consumer in the five files, except the Low points V4-1 to V4-6.

(3) N10 and N11 follow owner-decisions.md:80-84. HUSKY=0 is set only on desk pushes (A:312, B:83). The commits-outside-a-push reading is tagged `DEFAULT (integrator)` with an owner question for any wider skip (I:29, A:312). N11 is applied as ruled: profile-set per repo and refusal with no entry (A:128, B:96). The `release_tags.used/pattern/approval` forms, `step_id` and the J4 malformed-entry rule are all tagged `DEFAULT (integrator)` (R40-1, R4-J4). Nothing is extended without a tag.

(4) ADR 0054 and 0055 are not contradicted. `invocation` and `tier_override` are additive optional caller inputs, the same pattern as `max_concurrent` (ADR 0054 A0, A1: "invocation argument"). They are tagged `DEFAULT (integrator)` and do not change the spec hash or any ADR decision, so this is not a finding. Housekeeping for the W1 port: the ADR's "1 invocation argument" count (`0054-*.md:260`, also :204 and :210) becomes 3. ADR 0055 leaves the code pairings to part B (`0055-*.md:138-147`), so `pipeline-bound` and `push-spacing` under `marker` do not conflict.

(5) J13 holds against measurements:115-118 and part-03:10-25, as shown in the J13 entry above.
