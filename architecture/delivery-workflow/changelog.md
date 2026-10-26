# Changelog: agent-workflow-design.md v1 -> v2 (2026-10-26)

Every panel finding (B, M, A), every §8 revision-list line, and every owner decision maps to a v2 section below. "Superseded by Dn" means the owner's ruling replaced the panel's recommended fix; the ruling wins and the text says so. Nothing is silently dropped.

## 1. Panel findings

| # | Finding (short) | Where in v2 | How |
|---|---|---|---|
| B1 | GITOP/GITDONE unauthenticated free-form channel | §6.3, §2.2 card 15, §0 line 2 | Replaced by `delivery-desk`: request file at 0600, closed per-verb JSON schema (no flags, no force), sender id bound to the registered lead/conductor, idempotency key = id, desk re-derives every marker, `DONE`/`REJECTED` with reason codes, atomic 0600 result files, logging (no per-request account lock: no accounts, R2-4; INTERFACES B3; erratum E6). CI watching = `ci-status`/`ci-logs` verbs on the tick. Transport is the new `DESK` verb added to permission-tiers-02 §2 by ADR amendment (T1). |
| B2 | Permission-tiers amendment and decision 13 unscheduled | §6.3, §7 item 3b and waves W0/M/P0-P1 | The amendment is now scheduled: W0 item 3b (ADR adding `DESK`), owner ratification gates W1 item 26 (`delivery-desk`); interim fallback: the human runs the desk verbs by hand from the request file. Pilot target (D13) is <pilot-app> after the move, scheduled as P1. |
| B3 | Circular provenance rule | §2 intro (b), §2.2 cards 7/11/13, §7 items 23-25, P1-P2 | D14: the three skills ship as pilot drafts with `Provenance: pending pilot`, used in P1, closed in P2. Wave labels corrected: W3 is review, P1 is the pilot. |
| B4 | `ROLES` subset strands RACI | §2.3 pr-review (a), §2.2 card 4, §7 item 4, P0, §8 item 2 | Redefined as a RACI remap (absorbing seat or N/A per omitted check, derived Consulted lists, hard gate timeout), enabled only after the 3-seat probe (D12). Until then 7 seats everywhere for code. |
| B5 | Slot ledger and nesting unsound | §4 Slot ledger, §3.1 seat table, §6.1 rows 5 and 9, §7 item 4 | Lead is sole header writer; per-agent row files; lock dir with pid+UTC and `kill -0` stale break (120 s); shepherd emits FREE-CANDIDATE only; stage x Agent-holder x depth x slot table; one session per sub-task keeps depth <= 2 (measured OK); flat-dispatch fallback; execute-tier conductor statement. |
| M1 | Open decisions unprioritised | §8, §0 | All 25 decisions are settled by the owner; §8 holds only measurements and two recorded tensions. |
| M2 | Internal counts disagree | §7 work-item table, §4 slot table, §0 line 1 | One enumerated table (33 items) derives every count and LOE; 15 new + 5 extend stated once; slot rows sum (27+3=30, 13+3+14=30); orchestrator seat not counted (stated); `slot-ledger.sh` dropped; throughput formula in §5.3. |
| M3 | Elapsed does not sum; W3 critical path | §7 wave table | 14-18 h plus latency with rework allowance in the range; W3 pipelined per skill as authored; EXTENDs on a separate branch. |
| M4 | Skill-home inversion | §6.5, §7 header, §2.1 note | Build only in `agent-hq` (D2); EXTEND targets made canonical in `agent-hq` by porting the four `hq`-only skills (W1 item 8); installed-target hash in `state.md`; `ls -L` check at W0 and at move. |
| M5 | `review-7-panel` not installed; HQ-only list wrong | §2.1 note, §6.1 row 12, §7 item 8 | Corrected list (review-7-panel, feature-change, port-claim, sim-lease are in hq only); ported in W1; installed yes/no per REUSE row recorded in INTERFACES.md. No symlink step (owner rule). |
| M6 | `disable-model-invocation` contradiction | §2 intro (a), §2.2 common note | D16: nowhere in the family; authoring-checklist exemption recorded; §8 item 4b. Panel's "entry skill only" superseded by D16. |
| M7 | Role-name collision | §3.5 | XC roles are lenses; the severity classifier seat gets a distinct name from the `pr-review` agent id. |
| M8 | Completion-signal conflict; ADR 0023 not in gate | §2.3 wave-execution, §2.2 card 6, §7 items 3 and 9 | ADR 0023 amendment is YES (owner); `delivery-run` builds on extended `wave-execution`; `UNIT-VERDICT` is a bus post, the sole completion signal; status files are heartbeat only. Panel's "drop the extension" alternative superseded by the owner's ADR 0023 yes. |
| M9 | Topic-template drift | §5.0 | `pr-check-N-closed` literal; topic table with no conductor topic (conductor messages are inbox files, INTERFACES C5, D4; erratum E7); lead registered consumers. |
| M10 | No Verified-By; no durable record carrier | §2.2 card 10 steps 11 and record path, §6.3 `pr-merge` | Verified-By seat distinct from Reviewed-By; record under `RUN_HOME/review/<subtask>/`; desk re-derives record 0B/0M at the path; delta-verify trigger in §4. |
| M11 | Two cron consumers | §4 Merged tick | One merged prompt, `run_in_background`, stall action is a superset of the CLAUDE.md rule; tick lag measured in P1. |
| M12 | Shared-host resources not namespaced | §4 Namespacing | run-id and sub-task in every pm2 app, data_dir, temp dir, worktree; port-claim register; `pm2 jlist` check; D4 resolved the literal 30. |
| M13 | Executor allowlist vs commands | §6.1 table, §4 Wave shape, §6.2 | Facts measured and tabled with probe ids; blocked steps routed to the desk (install, registry, docker, pm2 at home); worktrees added serially with `--detach`; machine-load cap via the 200 ledger; registry reachability marked not run. |
| M14 | No shell or runtime target | §6.1 Runtime matrix | bash 3.2, BSD userland, no flock (mkdir locks), 400-byte row cap, hermetic tests under /bin/bash, different HOME. |
| M15 | Reboot-resume; budgets from tick | §4 Reboot and resume, §5.8 measured durations | Resume marks all rows stale and re-verifies before dispatch; budgets from measured medians in the repo profile. |
| M16 | No ownership of cross-cutting files | §2.2 card 5, §4 rule 3, §5.3 | Shared-file owner and serial-lane table; overlap computed and rejected; merge-order dependencies; delta-verify trigger defined. |
| M17 | GATES/ROUTE duplicated | §5.8, §5.3 header, §6.3 | D22: repo-profile is sole authority; others link with sha; desk reads the approved-account list from one file. |
| M18 | Paths hard-coded; planes mixed | §5.11, §5.8 (`run_root`, `worktree_base`, `desk_mailbox`), §6.1 matrix | Artifact-to-plane table; roots resolved from the profile, fail loudly when unset; tests with a different HOME. |
| M19 | Literal Opus pins | §0.1 Tiers, §3 throughout | Tier names (design, execute, verify, mechanical) mapped by model-routing.md or repo-profile. |
| M20 | Cold-read: codes, length, no summary | §0 (15-line summary), §0.1 glossary, §7 (landing page + parts in agent-hq) | Added summary and glossary; v2 stays near v1's length and is split into parts when committed. Per-skill task specs are W1 outputs in the 11-section template (item 27 templates, dispatch at build). |
| M21 | Load-bearing artifacts undefined; INTERFACES review | §5.0, §2.4 row INTERFACES, §5 intro, §7 item 2 | Schemas and grammars defined; INTERFACES reviewed at 2b; change-control rule; `slot-ledger.sh` dropped. |
| M22 | Parameter surface undefined | §2 intro, §2.2 common note, §7 item 2 | Per-skill input enums in INTERFACES.md; Step 0 `INPUT-ERROR`. `BACKEND=claude-p` is owner-granted by D25 rather than rejected (superseded). |
| M23 | `BACKEND=claude-p` drops sandbox; "identical" claim | §6.4 | D25: built now; "identical" claim withdrawn; missing sandbox/deny list stated; compensating controls listed; counted in 30/200 ledgers via row files and catalog process rows; untested until the work environment; `claude --help` recorded at move. Panel's "defer" default superseded by D25. |
| M24 | Prompt injection via logs, tickets, comments | §2.2 card 11, §2.3 fix-verifier, §3.0 COMMON | Read-only diagnoser returns a schema record; fixer briefed only from it; `file_set` flag in fix-verifier; data-not-instructions in every brief; applies to clerk and intake inputs. |
| M25 | Lockfile and manifest edits bypass no-installs | §2.2 card 10 step 5, §5.8 sensitive-path list, §3.0 | scope-check preventive with deny-by-default sensitive paths; `INSTALLED` row or human grant required; dependency-edit ban in briefs; published-artifact simulation via the desk. |
| M26 | `catalog.tsv` executable column | §5.6, §2.2 card 8 | Kind plus handle only; fixed per-kind cleanup table in the script; realpath constraint; control chars rejected; script-only appends. |
| M27 | Owner-only gates enforced by agent state; harness-api approve | §2.1b harness-api row, §6.3 (no approve/trigger-prod verbs), §2.2 card 13, §1 stage 7 | D15 split; approve and trigger-prod not agent-callable; desk re-derives human approval from the PR itself. |
| M28 | Secrets leak | §2.2 card 10 step 4, §5.7 | Redaction gate with exit code before storing logs or opening a PR; "no secrets in diff or PR body" row. |
| M29 | Self-hosting the EXTENDs | §7 header | W3 reviews pinned to unmodified installed skills; EXTENDs on a separate branch; slot accounting by hand until catalog.sh is gated. |
| M30 | Context leakage into SKILL.md | §0.5 intro, §3.6 intro | Skills carry generalized rules plus a repo-profile hook; citations stay in the design doc or a non-installed provenance file. |
| M31 | MVP re-cut | §0 line 10, §7 items 23-25 | Owner chose FULL BREADTH with the three pilot drafts at draft quality (D14, MVP ruling). |
| A1 | Evidence labels; undefined terms | §0 Evidence labels, §0.1 Profiles, §6.1 (command, date, profile per row) | Applied. |
| A2 | Control-plane files writable by all | §3.0, §3.1 Writes column, §2.2 card 7 | Each agent writes only `status/<own-id>.md`; fixed-template nudges; verifier re-runs the done command. |
| A3 | `HUSKY=0` skips scanners | §1 stage 5, §3.0, §5.7 | D21: allowed in the create-pr flow only after the affected lint+test+typecheck pass is recorded (once per push or batch since R2-3; erratum E1); secret/SAST pre-check stays in pre-pr-gate. |
| A4 | read_messages 50 vs 200 | §2.2 card 10 step 6, §2.3 pr-review (c) | `limit 200`, `peek:true` on every conductor read. |
| A5 | UI e2e lane runtime | §5.3 lane table, §5.8 lane resource profile | Per-lane ports and browser pre-stage via desk INSTALL; device lanes human-run; every port cataloged. |
| A6 | Home-vs-work symmetry asserted | §6.5 | Distribution row: copy agent-hq, symlink at install (D24); `version:` in frontmatter recorded in state.md. |
| A7 | Stand-in CI pilot; credentials | §7 P0-P1 | The stand-in-CI leg is removed: the pilot runs on <pilot-app> in the work environment with real desk, CI and Jira (D13); budgets from measured durations before STALLED fires. |

## 2. Panel §8 revision list (line by line)

| Revision-list line | v2 |
|---|---|
| [B1] closed per-verb argv schema, sender binding, idempotency, desk re-derivation | §6.3 |
| [B1] reply set, CI watching as executor-sent verb on the tick, atomic 0600 results, no account lock (R2-4; erratum E6) | §6.3 |
| [B5] lead sole writer, per-agent rows, pid+UTC stale-lock rule | §4 Slot ledger |
| [B5] seat table; Sonnet-only conductor statement | §3.1 |
| [B2] schedule the amendment; decisions 3 and 13 as gates; interim fallback | §7 item 3b (W0, gates item 26), §6.3 fallback, §7 P1 (D13) |
| [B3] decision 14 as W0 gate; `pending pilot`; fix wave labels | §2 intro, §7 (D14) |
| [B5] nested-spawn probe as W0 exit with flat fallback | §7 item 4, §3.1 |
| [B4] 3-seat probe in W0 | §7 item 4 (dry run) and P0 (real bus), D12 |
| [B4] EXTEND (a) as RACI remap with hard timeout | §2.3 pr-review |
| [M20] owner summary, glossary, split | §0, §0.1, §7 header |
| [A1] define desk, Worker1, Worker2, executor; label stage table | §0.1 Profiles (renamed conductor, lead, desk, worker for the work environment); stage table labelled `design` by default |
| [M5] HQ-only list; Rung 2b rows conditional on install | §2.1 note, §7 item 8 (port, not symlink) |
| [M4] owning repo and gate per EXTEND; decision 2 blocking | §6.5, D2 |
| [M8] delivery-run and wave-execution; ADR 0023 ask | §2.3 (owner YES) |
| [M21] INTERFACES reviewed by review-7-panel; change control | §2.4, §5 intro, §7 item 2 |
| [M6] disable-model-invocation on entry skill only | Superseded by D16 (none) |
| [M22] per-skill inputs/outputs, enums, INPUT-ERROR | §2 intro, §7 item 2 |
| [M10] Verified-By and durable record path | §2.2 card 10 |
| [M9] `pr-check-N-closed`; topic table, no conductor topic (erratum E7) | §5.0 |
| [M24] split diagnoser and fixer | §2.2 card 11 |
| [M25] scope-check preventive; dependency-edit bans | §2.2 card 10, §3.0, §5.8 |
| [M27] strip approve/trigger-prod; irreversible verbs | §6.3, §2.1b |
| [M28] redaction gate; no secrets row | §2.2 card 10, §5.7 |
| [A3] HUSKY=0 after recorded hook pass | §1 stage 5, §3.0 (D21 form: affected gates once per push or batch, R2-3; erratum E1) |
| [M30] citations out of SKILL.md | §0.5 intro, §3.6 |
| [M16] shared-file owner table, overlap, merge order | §2.2 card 5, §5.3, §4 |
| [M2] 14 of 14 -> 13 of 14; slot-ledger.sh | §7 (counts derived; slot-ledger.sh dropped) |
| [M7] lenses; distinct names | §3.5 |
| [M19] tiers from model-routing | §0.1, §3 |
| [M2] Mixed row sum; orchestrator slot | §4 slot table |
| [M11] merged tick; run_in_background | §4 |
| [M12] namespace; port-claim | §4 |
| [M15] reboot-resume rule | §4 |
| [M21] state.md schema, grammars, vocabulary | §5.0 |
| [M26] catalog kind+handle | §5.6 |
| [M17] repo-profile sole authority; sensitive paths there | §5.8 (D22) |
| [M18] artifact-to-plane; resolve roots | §5.11, §5.8 |
| [A5] per-lane resource profile | §5.3, §5.8 |
| [M13] measure every command; route blocked ones | §6.1, §6.2 |
| [M14] runtime matrix; 400-byte cap | §6.1 |
| [M23] defer claude-p or specify sandbox; drop identical claim | §6.4 (D25: build, specify, mark untested) |
| [A1] verification column; items 1-6 owner-stated | §6.1 (all rows carry probe id, date, profile; work facts marked unmeasured) |
| [A6] distribution row; version stamp | §6.5 |
| [M2] enumerated work-item table | §7 |
| [M3] 14-18 h; W3 pipelining | §7 |
| [M29] pin W3 to unmodified skills | §7 header |
| [M31] pilot drafts after the tracer; owner option | §7 items 23-25, P1-P2 (owner: full breadth) |
| [M5] review-7-panel symlink; installed yes/no | §2.1 note (port, no symlink per owner rule) |
| [A7] no real credentials in stand-in leg; budgets from measured durations | §7 P1 (stand-in leg removed; pilot is on <pilot-app>); §4 budgets |
| [M1] decision columns; move decisions into W0 packet | §8 (all decisions settled by the owner) |
| [A2] per-agent status files; fixed nudges | §3.0, §2.2 card 7 |
| [A4] cite or reconcile cap; peek:true | §2.2 card 10, §2.3 |

## 3. Owner decisions

| Decision | Where in v2 | How |
|---|---|---|
| D1 human acceptance replaces S1 gate; artifact still reviewed | §1 stage 2, §2.2 card 3, §5.2 item 13 | Review loop runs first (to 0B/0M or round 3), H1 acceptance is the gate, open findings travel in the packet. |
| D2 hosted in agent-hq | §6.5, §7 | Build only in `AHQ/skills`, `AHQ/tools/delivery`. |
| D3 desk skill owns git/GitHub/Jira; T1 adds a `DESK` verb by ADR amendment | §2.2 card 15, §6.3, §7 item 3b, §0 line 2 | `delivery-desk` with request files; `DESK`/`DONE`/`REJECTED` grammar specified; ADR scheduled in W0. The first-round "no grammar change" wording is removed. |
| D4 30 per sub-task, 200 machine; raise env or split | §4 Numbers, §3.1, §0 line 5 | One session per sub-task with `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30`; machine ledger of session rows; claude-p rows counted. |
| D5 one PR per sub-task; human reviews; agents merge via desk in plan order | §1 stages 5a-5b, §6.3 `pr-merge` (predecessors, approval re-derived) | Applied; hq local `--no-ff` route removed. |
| D6 adopt D35, D55, D57, D59, D60, D62; others advisory | §4 Quality rules, §2.3 fix-verifier (class_sweep dropped), §1 stage 4b (no D44) | Applied; D44/D54/D58/D61/D66 named as advisory only. |
| D7 stop after round 3, human gets findings, others continue | §1 stage 4b, §2.2 cards 3/10/11 | Replaces fix-verifier's "report and continue" and D44. |
| D8 branch delete only when content-merged | §2.2 card 9, §1 stage 5c | Ancestor OR rebase/squash content check; else keep and flag; remote delete via desk. |
| D9 cleanup catalog-only; report non-catalog finds | §2.2 card 9 | Applied. |
| D10 shepherd flags and redirects every 10 min; lead decides TaskStop; Sonnet | §2.2 card 7, §4 Merged tick | Applied; tier execute. |
| D11 Jira only via desk; no Notion; D62 cadence on Jira | §2.2 card 14, §2.1b, §6.3 jira verbs | All Notion text removed; clerk composes, desk writes, 30-minute cadence. |
| D12 smaller seats only after RACI remap + 3-seat probe | §2.2 card 4, §2.3 pr-review (a), §7 item 4/P0 | Applied. |
| D13 pilot = <pilot-app> after the move | §7 P1, §0 line 11 | Applied; not present on this machine (stated). |
| D14 three pilot drafts, provenance from pilot | §2 intro (b), §2.2 cards 7/11/13, §7 | Applied. |
| D15 release: agents stage and poll; production is human; T3 <pilot-app> agents track only, build toward the Zephyr API/MCP | §2.2 card 13, §5.5, §1 stage 7, §2.1b row 7, §5.8b, §7 P0 and M, §8 item 4 | Read-only Zephyr leg (version and tag state per environment, deployment history, promotion confirmation); never promote or roll back; caller-side GET-only allowlist guard before every `execute`, refused calls logged and stop-the-line; identity and scope unmeasured (P0 signed-in `search`); owner installs the MCP at move; agent-run DEV2 to DEMO promotion left as a marked future step pending a later ruling. |
| D16 all model-invocable; T2 accepts the skill-authoring §4 exemption | §2 intro (a) | Applied; exemption recorded in the family's authoring checklist; dropped from the tensions list. |
| D17 e2e via NLTA plugin; gap named when no harness | §3.6, §1 stages 4/6, §5.4, §5.8 e2e fields | Full method with pitfalls from bug reports and learnings, cited by path. |
| D18 sign-off = executing human; no role map | §1 gates, §5.2 item 13, §9 | Role map from ways-of-working not used. |
| D19 learnings via the Hermes port in agent-hq | §1 stage 8, §5.11, §6.1 row 11, §6.2 | Door recipe; capture queue until the owner turns it on. |
| D20 always full width, no ramp-up | §4 Numbers, §2.2 card 6 | Applied; XC playbook ramp overridden, serial Wave 0 contracts kept as a dependency. |
| D21 work-only; HUSKY=0 allowed with per-commit affected gates | §0 framing, §1 stage 5, §3.0, §5.7, §2.3 feature-change | Applied; `GATE-PASS` record once per push or batch (R2-3; INTERFACES A.7; erratum E1). |
| D22 repo-profile sole authority | §5.8, §5.3 | Applied. |
| D23 ci-fix-loop never edits pipeline definitions | §2.2 card 11, §1 stop-the-line | Applied. |
| D24 symlinks per ADR 0009 at install | §6.5 | Applied at the owner's install step only. |
| D25 build claude-p now; count in ledger; drop identical claim; state controls; untested | §6.4, §4 Slot ledger | Applied. |
| ADR 0023 YES: extend wave-execution; amendment recorded | §2.3, §7 items 3 and 9 | Applied; DAG-frontier expressed as `depends_on` edges, consistent with ADR 0023's own "if ever needed" clause. |
| MVP full breadth | §0 line 10, §7 | Applied. |
| Owner rule: no symlinking now; build in agent-hq; owner moves | §6.5, §7 waves (W0-W3 end at "ready to move"; M, P0-P2 after) | Applied. |
| WORK-ONLY framing | §0 framing, §0.1 profiles, §6.2, unmeasured markers throughout | Home-only assumptions removed; unknown work facts marked "unmeasured, verify at move". |

## 3b. Coordinator additions (owner update during the revision)

| Addition | Where in v2 | How |
|---|---|---|
| Read `<platform-capabilities-project>`; tie repo profile, CI loop, branching, PR review, e2e and release-track to it | §0.5 last row, §5.8b (<pilot-app> repo-profile seed), §1 stages 5b and 7, §2.2 card 11 Sonar classes, §3.6 steps 2 and 8, §9 | Read meta, architecture index/01/04/04-02/05, conventions, conventions-02, contribution-guidelines 00-05, playwright-generator README/02/10. Every coordinator-relayed fact was checked against the cited file before use; one correction: the slow pre-commit belongs to `<app-repo>` (00 §7, 04 §A), `<platform-repo>`' pre-commit is empty. Citations only; no text copied into skill drafts. |
| No home-profile considerations anywhere; single environment = work | §0 framing, §0.1 profiles, §4 namespacing and merged tick, §6.1 (rebuilt as portable facts only), §6.2, §6.4 | Removed every home sandbox fact, "at home" clause, home-vs-work phrasing; unknowns marked "(unmeasured, verify at move)". |
| Work session history arrives later; note what it should confirm | this table, next row | See list below. |

**Assumptions the work session history should confirm (for the evaluator):**
1. That the <pilot-app> PR-open pipelines and merge-pipeline stage order in §5.8b are current (the cicd doc is dated 2026-10-10).
2. That `HUSKY=0` is still the standing rule on `<app-repo>` and that `pnpm nx affected -t lint test typecheck` is the right affected-gate command for D21.
3. The merge method used on `main` (squash or merge) and the required-check names, which decide `pr-merge` validation in §6.3.
4. Whether the NLTA plugin is installed in <pilot-app> and whether `nl-context-provider.json` exists, which decides whether `/nlta:bootstrap` is a Wave 0 human step.
5. Which session holds GitHub, Harness, Jira and Zephyr credentials in practice, which decides whether `delivery-desk` is one session or several.
6. Whether review loops there used 7 seats in practice and how long a `pr-review` round and a CI round took, which seed the measured budgets in `repo-profile.md`.
7. Whether `claude -p` was the dispatch mechanism in past work sessions and with which flags (`--model`, `--effort`, `--dangerously-skip-permissions`, `--allowedTools`), which decides §6.4's compensating controls.
8. Whether past e2e work followed the `banners-e2e` pattern and whether the `dft-mfe-generator:e2e` sub-generator was ever run for real.
9. Whether Sonar false failures were handled by re-run (as §2.2 card 11 assumes) or by other means.
10. How Zephyr promotions were tracked (dashboard, CLI, logs), which decides what `release-track` can poll.

## 3c. Round-2 owner rulings on the recorded tensions (T1-T3)

| Ruling | Where in v2 | How |
|---|---|---|
| T1 (D3): add a `DESK` verb to permission-tiers-02 §2 by ADR amendment | §0 line 2, §6.3, §7 item 3b and W0 row, §8 item 4 | Verb line, `DONE`/`REJECTED` reply grammar and reason codes specified; ADR is W0 item 3b and gates `delivery-desk` authoring; practice-only pointer wording removed. |
| T2 (D16): §4 side-effect exemption accepted | §2 intro (a), §8 item 4 | Kept as recorded; removed from the tensions list. |
| T3 (D15): track only on <pilot-app>; build release-track toward the Zephyr API/MCP | §2.2 card 13, §2.1b row 7, §1 stage 7, §5.8b, §6.1 unmeasured, §7 P0 and M, §9 | Read-only Zephyr leg with caller-side allowlist guard; `zephyr-summary.md` used as paraphrased data; install command recorded for the owner's move step; P0 signed-in `search`; future promotion step marked and not built. |

Additional assumption the work session history should confirm: 11. How Zephyr promotions were performed and by whom (UI, API, CI token), and whether a protected-environment setup already exists, which decides the P0 identity measurement for the MCP leg.

## 3d. Round-2 panel (agent-workflow-design-v2-panel.md) and owner answers R2-1..R2-8

Every round-2 id maps to a v2 section; "line" cites are the first words of the edited line so they survive renumbering.

| Id | Where in v2 | How |
|---|---|---|
| B1 completion signal | §5.0 "Completion signal (B1, M15)"; §2.3 wave-execution row; §2.2 card 6 steps; §3.0 done token; §4 Namespacing; §5.11 bus row | One canonical topic `<run-id>-<subtask>-rendezvous`; `session_id = <run-id>-<subtask>` pinned by the caller and stable across resume (ADR 0023 amendment adds `session_id` and `output_topic` overrides plus preflight rules 13-15); `bus.endpoint` file under `RUN_HOME/<subtask>/` with `data_dir` under RUN_HOME, not TMPDIR; COMMON block reads coordinates from it and has the `status/<id>.verdict` fallback; the conductor reads state files, never a sub-task bus. |
| B2 Zephyr guard | §2.2 card 13 "Technical guard"; §2.1b row 7; §3.1 note; §6.4 launcher; §5.8 fields; §5.8b unmeasured; §7 P0 and M; §0 line 15 | Per R2-1 nothing is installed (the three install commands are removed); every non-release-track agent type and claude-p worker launched with the Zephyr `execute` tool disallowed (frontmatter `disallowedTools`, `--disallowedTools`); release-track's `execute` behind a PreToolUse hook reading `zephyr.read_ops`, refusing and logging all else; tool names unmeasured. Panel's "do not install at user scope / desk read wrapper" superseded by R2-1 (operator-local MCP, technical guard). |
| B3 merge reaches prod S3 | §1 stage 5b (rewritten); §5.8b rows "PR merge pipeline and `merge_reach`", "Version-bump rule", "PR author and approval"; §2.2 card 10 step 2b; §2.2 card 13; §5.3; §0 line 4; §9 | Merge-pipeline stages written into the profile with the R2-2 paths; inline `ALLOW_DEPLOYMENT_CHECK` in the <platform-cicd-repo> YAML is human-only (D23); S3 prod is the backup, live prod is the human Zephyr promotion; the human approving review covers the backup upload (R2-5); desk `pr-merge` refuses while `merge_reach` is missing; dispatch plan lists and pre-pr-gate checks the `package.json` bump for every affected app under `apps/` (excluding examples and e2e). Panel's "agents never add a version bump unless prod-eligible" superseded by R2-5 (a bump is required for every affected app). |
| M1 task specs | §7 item 2b, item 1, stop conditions | W0 item 2b generates one 5.3b spec per W1 item, Plan-checker checks before W1 dispatch; installed table in item 1. |
| M2 persona briefs | §3.2/3.3 table; §3.0 heading; §7 item 27b | Persona table inlined (tier, inputs, outputs, done token, stop rule); W1 item 27b authors `references/briefs/<persona>.md`; COMMON block gains bus coordinates and the commit line. |
| M3 counts | §7 "Counting rule", item table, totals row, wave table, parallelism note; §0 line 12; §2.3; §2.4 | 37 items, 140.5 h (125-155) with an explicit rework row; W0 19.25 / W1 37.25 / W2 6 / W3 60 / R 18; elapsed 16-20 h; ADR 0023 amendment is W0 item 3 everywhere; §2.4 2b items aligned with §7 item 31 (four heavy skills). |
| M4 W0 cannot exit | §7 item 8 (W0, before item 2), W0 row, item 26 | Item 8 moved to W0 ahead of item 2 (R2-7); W0 4-6 h plus owner latency, peak 17; item 26 blocked on owner ratification while other W1 items proceed; stale-cleanup thresholds added to the unmeasured row. |
| M5 later-wave capacity | §7 items 30-31, W3 row, P1a/P1b, M row; card 13 P1 exit | Heavy loops capped at 2 buses; order 30, 31, 32; P1 split into build-through-merge and release observation with exit criteria per draft; M given a duration (unmeasured, about half a day). |
| M6 PR identity, build-time git, packet | §5.8b "PR author and approval"; §6.3 H-pr read-back and "Build-time git on the build machine"; §7 Ready-to-move packet and P0 | PR author = operator (R2-4); approval = GitHub approving review by another human, read back via `gh pr view --json` or the reviews API with `commit_id == headRefOid`; build-time git uses the existing desk pushes (R2-7); ratified-ADR rows in the packet and P0 exit. |
| M7 HUSKY and commit rule | §3.0 commit line; §5.8 single `HUSKY=0` statement; §5.8b Hooks; §1 stage 5 | One statement: inline per-command, after the batch `GATE-PASS` (R2-3); commit pattern with Jira key; key read-back before branch creation. |
| M8 gate load | §4 "Gate-runner semaphore"; §5.8 `gates.*`; §7 P0 | Catalog lease `gate-runner`, N from the profile, exact command string with `--base/--head/--parallel`, disk preflight, per-unit duration; once per push or batch (R2-3); install and nx durations measured at P0. |
| M9 CI capacity | §4 rule 8d; §2.2 card 11; §5.8 `ci.*`; §5.8b unmeasured | Profile fields, desk `pr-create` lease and push staggering, capacity failures counted globally, Zephyr tag derivation unmeasured. |
| M10 verbatim ports | §7 item 8; §2.3 feature-change row; §2.1 note | Port-and-strip (Notion, <personal-project>, D44-as-rule removed, grep-verified); Jira-key branch naming from the profile in feature-change. |
| M11 approved-account file | §6.3 validation; §0 line 2; §5.8b "PR author and approval" | Superseded by R2-4/R2-7: no approved-account list in the runtime; operator's own auth; desk validates repos against the registered clones in the profile. |
| M12 path authority | §0 Path keys; §5.0 "`DELIVERY_ROOT`"; §4 Numbers; §5.8; §5.11; §7 M row | One `DELIVERY_ROOT`, set at move, no default, umask 077, fail loudly; RUN_HOME, desk mailbox, machine ledger derived from it; primary repo's profile governs a multi-repo epic; `run_root`/`desk_mailbox` fields dropped. |
| M13 DESK grammar clash | §6.3 grammar block and following sentence; §7 item 2 | `REJECTED <id> \| <reason>` keeps the installed layout; per-verb `.out` result schemas in INTERFACES.md; `.out` polling authoritative for claude-p leads. |
| M14 verb coverage | §6.3 verb list | Added `fetch`, `pr-comments-read`, `tag-push`, `publish`, `test-report-push`, `ci-status-main`; Zephyr reads are release-track's own (B2), not a desk verb; `pr-merge` requester = conductor. |
| M15 UNIT-VERDICT drift | §5.0 "Completion signal"; §2.2 card 6; §4 Slot ledger | JSON `output_schema` record with unit, verdict, head, reason; ROLLED/ESCALATE branches; head verified before freeing the slot. |
| M16 review-record contract | §5.0 "Review record contract"; §2.2 card 10 step 11 | `CODE-GATE-REVIEW: PASS head=... blocking=0 medium=0` adopted as written by pr-review; `Verified-By: <seat> head=<sha>` appended. |
| M17 waves mapping | §2.3 wave-execution row; §7 items 2 and 3 | Unit-table to `waves/` mapping in INTERFACES.md; amended preflight rules in the ADR 0023 amendment; plan-check runs them before round 1. |
| M18 fixer disjointness | §4 rule 8c; §2.2 card 10 step 7; §2.2 card 6 | One fixer per worktree at a time or disjoint file sets with serial integration; `file_set` per fixer. |
| M19 cross-sub-task sequencing | §4 rule 8b; §1 stage 3; §5.3; §2.2 cards 1 and 6 | Dependency-free with disjoint globs or strictly ordered; `RELEASE`/`INVALIDATE` conductor messages via inbox files only, no conductor topic (INTERFACES C5, C6; erratum E7); successor starts after predecessor `merge_sha`. |
| M20 seat table | §3.1 new rows; lead row; §2.2 card 6 | All personas rowed; Integrator is the single writer of the sub-task branch; lead writes state only. |
| M21 claude-p control channel | §2.2 card 6 "Control channel"; §5.0 `inbox/`; §7 item 2 | Inbox files only, no conductor topic (§5.0; INTERFACES C5, D4; erratum E7); resume invocation defined. |
| M22 plan-plane artifacts | §1 stage 3; §5.3; §5.8b "Plan-plane PR"; §7 P0 | Sub-task 0 plan PR first in merge order; globs in the owner table; acceptability confirmed at P0. |
| M23 NLTA not unattended | §3.6 step 3 "In-skill prompts"; §7 P0 | Stage 1 plan folded into the batched checkpoint; `nl-run-e2e` args from the unit spec; non-interactive run measured at P0; plugin-internal npx noted. |
| M24 Tier 1 location | §3.6 step 8; §5.8b Testing row; §1 stages 5b and 6; §6.3 `ci-status-main` | E2E is step 1 of the merge pipeline (post-merge); PR-time Tier 1 unmeasured; desk reads the merge-pipeline execution in 5b and 6 with the response defined. |
| M25 mock code in dist | §3.6 step 2 "Build-flag and credential rules"; §2.2 card 10 step 2c; §5.8 `e2e.mock_gate`, `e2e.dist_scan_cmd`; §9 | playwright-generator 12, 16, 16a, 17, 18e, 19, 20b read; `__E2E__`, full dist exclusion, `fileReplacements` + `IgnorePlugin`, independent credential gate restated as binding; dist scan is a gating pre-pr-gate row. |
| M26 credential model | §3.6 step 2 "Auth mode"; §5.8 `e2e.auth_mode` | Synthetic storage state pinned for <pilot-app>; aliases only for Tier 2 deployed-target lanes; only the desk lane reads the credentials file. |
| M27 Module Federation lanes | §3.6 step 2 "Lane profile"; §5.8 `e2e.remotes_resolution`, `e2e.serve_targets` | Remotes resolution, serve target set, serial lane for fixed-port MFEs, deployed-target ban, launchability checklist as a Wave 0 lane-readiness row. |
| M28 claude-p controls | §6.4 Compensating controls (launcher spec); §0 line 6; §2.2 card 1 | `env -i` allowlist, empty git config, no credential helper, no SSH agent, empty `GH_CONFIG_DIR`, invalid `pushurl`, mandatory `--disallowedTools`, asserted env cap; residual OS-level risk stated with the owner-permission path. |
| M29 forgeable request channel | §6.3 (sha256 in the message, desk-owned copy, transport identity, `body_path` realpath); §2.2 cards 14 and 15 | Applied; closed Jira field allowlist. |
| M30 agent-writable gates | §5.0 "Human gates"; §2.2 card 14; §0.1 glossary H row | Gate files written by the desk after human confirmation or external evidence; `state.md` holds pointers; desk verifies H1 before `jira-create` and H-e2e before generation. |
| M31 ignore-scripts, redaction | §1 stage 4b; §2.2 card 10 step 2; §5.8 `install.rebuild_allowlist`, `secrets.pattern_file`; §6.3 `body_path` scan; §3.6 step 6 | `--frozen-lockfile --ignore-scripts` plus rebuild allowlist measured at P0; redaction desk-side on bodies and attachments; umask 077 via `DELIVERY_ROOT`. Hermes capture redaction is covered by the desk `body_path` scan rule and card 1's stage 8 ownership. |
| M32 CYCLE DONE | §1 "Two exits"; stages 5c and 8; §2.2 card 9 | CLEANUP DONE at 5c; CYCLE DONE at stage 8; second cleanup pass for stage 6 and 7 worktrees. |
| M33 evidence files | §0 Path keys; §0.1 glossary; §7 item 8b; §9 | Copied verbatim into `AHQ/architecture/delivery-workflow-sources/` (R2-6) and cited from there. |
| M34 context leakage | §0.5 intro; §2.2 card 11 | Provenance sentences in cards marked for `references/provenance.md`; §5.8b named as the deliberate exception and why. |
| M35 dangling references | §7 item 1; §2.1 note; §7 item 33 | Facts 1-7; "row 6"; cross-reference resolver check in item 33. |
| A1 glossary | §0.1 (H gates, T1-T3/R2, Hermes-G, lane-waves); §8 item 4; §9 | Added; Worker2 removed; T1-T3 inlined in §8. |
| A2 nvm one-shot | §3.6 step 7; §3.0; §2.2 card 10 step 2; §5.8 `node.prefix_cmd` | Applied. |
| A3 slot liveness | §4 Slot ledger | Lead pid plus agent id, dead on lead restart; `catalog.sh` exemption stated. |
| A4 atomic ceiling | §4 Numbers | `mkdir` lock on `machine/`; rule 8 binds, 200 is the ceiling; conductor sole launcher. |
| A5 env var ownership | §4 Numbers; §6.4; §2.2 card 1 | Launcher sets and asserts the variable, fails closed. |
| A6 UI evidence | §3.6 step 6; §2.2 card 10 step 13; §3.1 lane runner row | Screenshots and traces saved under RUN_HOME, redacted and attached by the desk. |
| A7 Playwright binaries | §3.6 step 7 | INSTALL spec and `PLAYWRIGHT_BROWSERS_PATH` under `DELIVERY_ROOT`; manager decision owner/desk. |
| A8 auto-heal | §3.6 step 6; §2.2 card 10 step 13 | Disabled for units touching the component under test, else healed diffs listed in the PR body for the Test-adequacy seat. |
| A9 stage 8 owner | §1 stage 8; §2.2 card 1 | Assigned to `delivery-pipeline` with the template-pack dependency. |
| Panel §7 questions 1-8 | — | Answered by R2-1 (1), R2-2/R2-5 (2), R2-3 (3), R2-4 (4), R2-7 (5, 6), R2-4/R2-7 (7: no list), R2-6 (8); each applied above. |
| §8 claimed-not-delivered (21 ids) | rows above | r1-B1 -> M29/M13/M14; r1-B5 -> M20/A3/A4; r1-B2 -> M6; r1-B3 -> M5; r1-M2/M3 -> M3; r1-M5 -> M4/M35; r1-M8/M9 -> B1/M15; r1-M10 -> M16; r1-M13 -> M8; r1-M16 -> M18; r1-M17 -> M11; r1-M18 -> M12; r1-M20 -> M1/A1; r1-M22 -> M2/M7 (INTERFACES stays a W0 output, now with task specs); r1-M23/D25 -> M28; r1-M25 -> M31; r1-M27 -> M30; r1-M28 -> M31; r1-M30 -> M34; r1-A5 -> M27; r1-A1 -> M35. |

Fix-verifier follow-up (6 residuals, `agent-workflow-design-v2-fixverify.md`): §5.7 per-commit record changed to per pushed batch (R2-3); stage 5b states the full version-bump scope and cross-references §5.8b; M row drops Zephyr access for the desk (R2-1); `account` removed from both REJECTED reason lists; the `<run-id>-conductor` topic removed, conductor messages are inbox files only; parallelism note recounted to 29 parallel / 8 serial-or-capped.

Assumptions the work session history should confirm, added this round: 12. That `gh pr view --json latestReviews` (or the reviews API) exposes the review's commit id on the work GitHub instance. 13. That a second human reviewer is routinely available for <pilot-app> PRs (otherwise H-pr cannot be satisfied under R2-4). 14. How past sessions ran NLTA skills from subagents, if ever.


## 3e. Owner ruling B-1 (build runs with up to 50 agents; report wall-clock)

| Ruling | Where in v2 | How |
|---|---|---|
| B-1 build concurrency 50; wall-clock first; agent-hours as cost only | §7 (rewritten: headline, "Build-time concurrency", effort table with a split column, schedule table, critical path, owner waits, build cost, runtime cost guardrail, after-the-move table); §0 lines 11 and 12 | Headline is about 12 h elapsed (10-14 h) plus listed owner waits; 50 reached by raising `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` per build session (Worker1 25, Worker2 25, desk 5) with a summed build ledger, stated as distinct from the runtime 30/200 ledger; wide items split by directory (INTERFACES 4 ways, `wave-execution` 3, conductors 2 each, task specs 10, templates and briefs 4 each, ports 4) with one integration step each; the W3 2-bus cap lifted to 4 buses; explicit critical path (ports -> INTERFACES -> its 2b loop -> task specs -> `wave-execution` -> conductors -> heavy loops -> packet); owner waits (3b and ADR 0023 ratification, move, D7 stops) listed and uncounted. Build cost about $2,400-3,500 API-rate equivalents from `measured-runs.md` and `pricing-summary.md` (11-agent panel $10-13 per review, Fable passes $31-43 for three), assumptions stated, seat-plan caveat stated. Runtime guardrail: `cost.subtask_budget` and `cost.review_round_budget` in the repo profile, tokens summed from slot rows per tick, warn at 80%, stop dispatching at 100% with a `BUDGET` inbox message and a human decision, tied to the D7 round-3 stop. B-2 (HTML visual) and B-3 (Hermes grounding) are not applied here: B-3 is the separate cross-check pass the coordinator announced; B-2 is a separate deliverable. |

## 3f. Ruling B-3: grounding in Hermes learnings (`hermes-learnings-digest.md` §C-E)

| Digest row | Where in v2 | How |
|---|---|---|
| G48 pre-round check (owner yes; `RLM:101`, D69, G51) | §4 Quality rules (rule); card 4 review-tailor; card 10 step 5b; card 11; §7b | Adopted as a rule in every loop before round 1 and after each fix, mechanical tier; stated as the reason the D7 round-3 stop should rarely fire; round counts recorded in P1a. |
| PROMPT-OPEN (pending tool call, `brain-group-process-retro:153-158`, proposal 8) | card 7 shepherd; §4 Merged tick | Flag `PROMPT-OPEN <agent>`; lead answers or stops; turn-close rule for `claude -p` leads (`caretaker-turn-timeout`). |
| Orphan sweep after TaskStop (`stopped-agent-orphan-loop:17-20`) | §4 Merged tick | Sweep by cwd and pid, kill by pid, catalog rows. |
| Safety denial is not a classifier block (G52 `RLM:106`) | §1 stop-the-line "Not stop-the-line" | Added. |
| One owning document per contract (D63, D67) | card 3 delivery-architecture; card 5 owner table | Added with the cross-document-conflict evidence. |
| Brief constraints verbatim to nested spawns (`dispatch-stop-conditions-02:307-320`) | §3.0 COMMON last clause | Added for every Agent-tool holder. |
| Per-session total spawn cap (`session-length-cost-economics:157-170`) | §4 "Session spawn cap"; §6.1 unmeasured | `spawns: n/cap` in `substate.md`, stop at cap minus 5, fresh lead via M21; value unmeasured. |
| W3 bus cap tension (S12, G17) | §7 item 31; parallelism note | 4 buses derived as 4 x 12 = 48 <= 50; the 2-bus cap retired. |
| D57 trigger, D59 quoted, D60 "shorter" | §4 Quality rules; card 4 | Implemented; D65 byte bar labelled advisory. |
| ADR 0014 T1 count in fixer step (D27/D28) | §4 Quality rules | Applied as an hq ADR: tier up on the second Medium-adding round, never a third top-tier attempt. |
| D51 reading rule (S2) | §4 Quality rules | Loop stops on a contradicted frozen fact. |
| G46 no mid-round injection | card 4 | Added. |
| P12/P17 protected values in fixer briefs | §4 Quality rules | Added. |
| D54 fixer-brief hint | §4 advisory list | Advisory (D6); kept as a hint line only. |
| Parallel downstream scratch-rebase verify (retro proposal 3) | §4 advisory list | Advisory (D6): optional Integrator practice. |
| Adjacent defects ticketed, not fixed (`workflow-orchestration:122`) | card 7 | Added. |
| Budgets from measured durations | already §4 Reboot and resume | none. |
| Validator fails on any Blocking row (`brain-workflow-shift:26`) | card 10 step 10 | Added. |
| Positive-control run of every gate script (`enforcement-gates:401`) | §7 P0 row | Added. |
| GATE-PASS not an agent claim (`enforcement-gates:10`) | card 10 step 2 | The gate runner is a separate mechanical agent that writes the record; desk re-derivation of markers stays as in §6.3. |
| Cold NX cache in pre-pr-gate (`enforcement-gates:141`) | card 10 step 2 | `--skip-nx-cache`. |
| File-count basis in the dry run; `git status --ignored` before worktree removal | card 9 | Added. |
| Routing table encodes S2 and Haiku mechanical | §0.1 Tiers row | Added. |
| Dedup key on every reported cost figure | §7 build cost | Added. |
| P15 "no Agent tool below depth 1" | §6.1 row 2 (already) | Superseded by measurement; marked for XC at the move (unchanged). |
| D44, D58, D61, D66, D65 | §4 advisory list | Advisory per D6, labelled. |
| Learnings already IN v2 per digest (D35, D55, D62, D13, P1-P2, P5-P7, stall rule, cleanup method, D8 ancestor rule, D23, token rule, no-sleep polling, main chat is a router) | unchanged | No edit; listed in §7b. |
| New §7b "Grounding in learnings" | §7b | Stage and caretaker to learning ids with one-line incidents, no project names. |

## 3g. Ruling B-4: no cost metric; maximum safe parallelism under the 50 cap

| Ruling | Where in v2 | How |
|---|---|---|
| B-4 no cost metric, no added scope | §0 line 12; §7 headline, work-items table, estimate basis, P0/P1a/P2 rows; §7b | Removed the build-cost section and every dollar figure, the runtime `cost.subtask_budget` / `cost.review_round_budget` guardrail with its 80% warning, 100% stop and `BUDGET` inbox message, the cost dedup key, the §7b cost-guardrail row, and the effort (agent-hours) column, totals and rework-hours row; `measured-runs.md` and `pricing-summary.md` are no longer cited (they served only cost). Kept unchanged because they limit agents for safety and correctness: the 30/200 runtime caps, the 50 build cap with the Worker1/Worker2/desk session split, the per-session spawn cap, the D7 round-3 stop, the derived 4-bus cap, and model routing by task difficulty (§0.1 Tiers, framed as correctness). The wall-clock schedule, critical path and 50-agent peak stand. Nothing new was added. §3e's cost sentences are superseded by this row. |
| fix-verify-2 follow-up (B-1b, B-1d, B-1e, B-1g, B-4c, REG-2) | §7 critical path, schedule rows t0-t1, t6.5-t8.5, t8.5-t10.8, item 31, build-time concurrency; §5.3; card 10; §2.1 note, §2.3 feature-change row, §7 item 8 | Critical path restated as 11.8 h without the item 8 term (8 and 2 run together in t0-t1); t6.5-t8.5 marked "cap binds, trios queue"; bus orchestration spread across Worker1 and Worker2 (2 buses each at 12 slots, hence 4 buses = 48); 12 slots per bus used throughout item 31 and the schedule; "Cost table per wave" removed from the dispatch-plan template and card 10's "Cost:" relabelled "Slots:"; the three personal-project strip-target mentions made generic. |

## 4. Dropped or changed v1 content (explicit)
- `GITOP`/`GITDONE` grammar (v1 §6.3): replaced by `delivery-desk` (D3).
- hq code gate `--no-ff` merge route, `sceptre12`-only pushes, home Hermes capture, Notion adapter, GitHub Issues and local-markdown adapters: removed (work-only, D11, D19). Approved-account list is now a desk-side file (M17).
- `slot-ledger.sh`: dropped (M2); `desk-req.sh` added in its place as the third script.
- `fix-verifier` `class_sweep` extension: dropped (D54/D58 advisory, D6); replaced by `file_set` (M24).
- Ramp-up rule (v1 §4 rule 9, decision 20): removed (D20).
- Stand-in-CI pilot leg and throwaway owner repo (v1 W4): removed; pilot is P1 on <pilot-app> (D13, A7).
- v1 §8 25 open decisions: all settled; §8 now lists measurements and two recorded tensions.
