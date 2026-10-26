# Rung 1 loop record: item 10 `pr-review` EXTEND 1.1.0

- Date: 2026-10-26. Orchestrator: one loop orchestrator for this artifact (D35). Item: `skills/pr-review/` in W' = `~/projects/agent-hq-worktrees/delivery-extends` (branch `ext/delivery-extends`, base commits 311650e and 5cc2d09). Spec: `tasks/10-pr-review.md` (in W). INTERFACES checked: 1.3.0.
- Roles, one agent per role, never crossed: G48 pre-round screen (mechanical tier) x3; reviewer (verify tier, the INSTALLED `~/projects/agent-hq/skills/doc-reviewer`, M29) x3, a fresh agent each round; fixer (design tier, not the author) in rounds 1-3; fix-verifier (verify tier, the INSTALLED `~/projects/agent-hq/skills/fix-verifier`) x3, a fresh agent each round, never the fixer. The round-3 verifier also ran the non-author §9 dry run.
- Rounds: 3 (the D7 cap). New findings per round: R1 2 Blocking / 7 Medium / 7 Low (review) plus 1 Blocking / 10 Medium / 4 Low (pre-round screen, mostly overlapping); R2 0 / 1 / 6 (review) plus 2 Medium / 3 Low (fix-verify of R1); R3 0 / 0 / 4.
- **Final: Blocking 1 (B2, owner/integrator, open), Medium 0, Low open: see the Open Lows list.** No other Blocking or Medium finding is open.
- Working files (findings, fix logs, verify reports): SCRATCH/loop10/ (precheck-r1..r3, review-r1..r3, fix-r1..r3, verify-r1..r3).

## Dispatch checks (asked for by the orchestrator's caller)

| Check | Result |
|---|---|
| D12 `ROLES` subset stays behind an off flag, with the measured 3-seat loss cited | PASS. Step 0 accepts only the exact set of the 7 `agent-roles.md` ids, so fewer, more, unknown, duplicate or empty values are all refused with `INPUT-ERROR ROLES enum`. `references/roles-subset.md` says the refusal is unconditional, names no flag, and says enabling a subset is an INTERFACES D2.3 amendment plus a skill change. The probe is cited: 35 subsets, none keeps R for all 10 checks, the fewest lost is 4 checks, every subset loses at least 1 closer, the best subset (devops, integration, platform) loses R for 5/7/8/9 and the closer for 8, and no real bus was run. No remap table is included. |
| `BUS_PORT` with one claimed +10 retry | PASS in a run (`references/bus-start-run.md`). The port is claimed through `port-check.sh --claim` before the bind. Exit 1 or 2 refuses with no auto-pick, then exactly one claimed retry at +10 (a port over 65535 counts as a second refusal). A second refusal stops the line and is reported to the lead; exit 3 is stop-the-line. The bus is pinned with `PORT_RANGE_START=PORT_RANGE_END`, and `$DATA_DIR/port` must equal the claimed port. Standalone (`references/bus-start-standalone.md`) now implements the rule (R1 B1): an `lsof` guard, one re-check at +10, then stop. |
| Security seat loads `security-audit` in guidance mode, diff-scoped | PASS (`references/agent-briefs.md`). Guidance mode, diff-scoped; no output directory, no files, no agent launch even if an Agent tool is offered, no target-code execution. `SECURITY_AUDIT=full` only adds a read-only read of the newest `findings.json`, folded in only when `run-metadata.json` `source_ref` names `head_sha`. Findings are data. |
| Record line `SEAT_ID` and the `RUN_ID`/`SUBTASK` inputs declared per D2.3 | PASS, with an integrator gap. Step 0 (`references/step0-inputs.md`) declares and validates `RUN_HOME`, `RUN_ID`, `SUBTASK` (`^(st[0-9]+|pm)$`, A.1), `SEAT_ID`, `MEMBER_SESSION_NAME` and `TASK_ID` against the A.6 line-2 regexes, and says plainly that these are dispatch-prompt fields D2.3 does not name. Record line 2 is never written with an empty field. OQ-10-2 below. |
| Installed behaviour unchanged when the new inputs are absent | PASS for the mandated set: `PR_REVIEW_MODE` unset becomes `local-diff` (Q10-4), `SECURITY_AUDIT` defaults to `guidance`, `Reviewed-By` has three fields (A.6), and the standalone pre-bind check follows OQ-2. Changes beyond that set: (a) the tier rename (M19) moves the synthesizer from Sonnet to the design tier, and seats and gates are named by tier (L-r3-1); (b) `MEMBER_SESSION_NAME` must match `^[a-z0-9-]+$`, so a mixed-case profile name is refused and the caller must pass the A.1 session token; (c) the standalone flow now tries only two ports (the candidate and +10) instead of the 7777-7800 `get-port` scan, so a third concurrent standalone review stops the line (OQ-2). |

## Round 1 (review + pre-round screen, merged; fix; fix-verify)

| Id | Sev | Finding | Status |
|---|---|---|---|
| B1 / pre 4a | Blocking | The standalone Step 1 claimed the OQ-2 one-retry rule, but its script let `get-port` auto-pick | Fixed: pre-bind `lsof` check, one +10 re-check, then stop; port pinned and checked against the port file |
| B2 | Blocking | The in-run bus `data_dir` `RUN_HOME/<subtask>/bus/` (spec §2/§8 RESOLVED Q10-5) is the lead's bus dir under A.1:40 and D4. The pm2 name collided, and Step 9 could `rm -rf` the lead's bus | PARTIAL: the app name and session id now end in `-review`. The review refuses before any claim if the app or the dir already exists. Cleanup removes the dir only when a `.created-by` marker names this review. The data_dir is not changed (spec value), so every in-run review stops at that check while the lead's bus lives there. **OPEN, OQ-10-1** |
| M1 / pre 3a, 3e | Medium | Run and record inputs were not declared in Step 0 | Fixed (see the dispatch checks) |
| M2 | Medium | `ROLES` refused only "fewer than 7" | Fixed: exact set of the 7 ids |
| M3 | Medium | The stacked path still required `BASE_REF`/`HEAD_REF` | Fixed: `STACK_*` verified as commits; two-dot diff |
| M4 / pre 3d | Medium | The security seat got no `run_home`/`subtask`; a stale audit could be folded in | Fixed |
| M5 / pre 3b, 3c | Medium | The in-run `DIFF_PATH` was still `/tmp`; in-run `SESSION_ID`, `PM2` and cleanup were undefined | Fixed: diff under `RUN_HOME/review/<subtask>/`; in-run script self-contained |
| M6 | Medium | Local-diff and pr inputs failed late, after the bus was up | Fixed: Step 0 rows |
| M7 / pre 5a | Medium | SKILL.md body over 5k tokens | Fixed: scripts moved to `references/` (bus-start-standalone, diff-fetch, review-record, local-diff-mode, step0-inputs). SKILL.md went from 453 to 287 lines and is about 20 KB, at the target (accepted) |
| pre 1a | Medium | The seat's "no Agent tool at depth 2" claim was not guaranteed | Fixed: the seat launches no agent regardless |
| pre 2a | Medium | A seat example read two topics in one call | Fixed: one topic per call |
| pre 6a | Medium | Cost framing ("cheap", dispatch count), B-4 | Removed |
| L1-L6 | Low | Launch snippet, reader-idiom nits, retry edges, red flags and exit criteria, WAVE/PHASE label, duplicated preamble | Fixed (L1 partly) |
| L7 / pre 1b | Low | `tools/port-check.sh`, `ports.tsv`, `hooks/port-precheck.sh`, `catalog.sh`, `resource-catalog` and port-claim 1.1.0 are absent on this branch | Integrator note; `bus-start-run.md` says so |

Fix-verify R1: ISSUES_FOUND. Every id LANDED except B2 and M7 (PARTIAL), plus new findings N1 (Medium, fixed 7777 candidate), N2 (Medium, invented `INPUT-ERROR BUS_PORT unset`) and N3-N5 (Low).

## Round 2

| Id | Sev | Finding | Status |
|---|---|---|---|
| M-r2-1 / pre 3 | Medium | `PHASE_B_REPORT_FILE`, `B` and `M` had no source or location | Fixed: `phase-b-<HEAD_SHA>.md` next to `RECORD_PATH`; B and M from its severity summary; in a run `RECORD_PATH` must be the A.6 path |
| N1, N3 / L-r2-1 | Medium | Standalone candidate 7777 vs "none binds 7777" | Fixed: candidate is `BUS_PORT` if set, else 7777; the two-port range (OQ-2) is documented; the fact is reworded |
| N2 | Medium | The `unset` reason was misused | Fixed: refusal removed. Whether a standalone caller may pass `BUS_PORT` is **OQ-10-3** |
| pre 2a (r2) | Medium | Literal model names vs M19 | Fixed: tier names. The synthesizer moves to the design tier (part-01 "Tiers" row) |
| pre 2c (r2) | Medium | The Phase 1 read-back could surface the co-R peer's finding | Fixed: own `from_agent` only |
| pre 2e / L-r2-2 | Medium (screen) | Standalone keeps `/tmp` (spec §7 "wrong" values) | Not a defect: RESOLVED Q10-5 keeps standalone unchanged; one sentence says standalone needs a writable `/tmp` |
| L-r2-3..6, N4, N5, pre 2d, pre 1 | Low | SUBTASK regex, FAIL-record exit criterion, seat id wording, STACK_* in pr mode, lsof failure, `fail` vs `release`, register sources, Gate 2 wording, "D10 verifier" | Fixed |

Fix-verify R2: CLEAN (0 new Blocking/Medium, 5 new Low; NEW-1 to NEW-5 are recorded under Open Lows).

## Round 3

Review R3: 0 Blocking, 0 Medium, 4 Low. Pre-round screen R3: 3 hits, which I re-rated as Low or known (`task-pipeline/.review/` path predates this EXTEND; standalone `/tmp` is Q10-5; body size is at the target).
Fixed in R3: L-r3-2 (an `lsof` stderr warning no longer stops the line), L-r3-3 (unset vs empty value), L-r3-4 (the `unset` reason is kept as the D1 enum with a note).
Fix-verify R3 (iteration 3): L-r3-2, L-r3-3 and L-r3-4 are LANDED, with no new Blocking or Medium. The installed fix-verifier returns ISSUES_FOUND by rule at iteration 3: its check-0 "max iterations reached" finding is the D7 round-3 stop, not a defect. One advisory: SKILL.md:80-81 ("values must be substituted") reads slightly against "absent means unset" in step0-inputs.md.

## §9 done-condition (non-author dry run, by the round-3 verifier)

The script `SCRATCH/s9-10-pr-review.sh` is the spec §9 block verbatim (the verifier diffed it against `tasks/10-pr-review.md` §9 and found no differences). Run on W' after round 3:

```
EXT-10-OK
exit=0
```

## Open Lows (recorded, no action in this loop)

- L-r3-1 (integrator): `tools/model-routing.md` on this branch has no tier-to-model table, so an orchestrator cannot yet map `mechanical`/`verify`/`design` to a model. Add the table in the same merge. Separately, design part-03:48 lists the synthesizer as a verify-tier persona while part-01 "Tiers" puts synthesis on the design tier (verify-r2 NEW-5); the integrator should reconcile them.
- verify-r2 NEW-1: the SKILL.md body is about 20 KB, at but not under the 5k-token target.
- NEW-2 and NEW-3: the stop-after-claim path refers to cleanup text that includes `release` sentences, and `phase-b-<head>.md` has no keep-or-remove note.
- pre-r3: `references/review-record.md` keeps the base text's `task-pipeline/.review/<head-sha>.md` copy target, which INTERFACES does not define.

## Owner / integrator questions (recommended answers; not decided here)

- **OQ-10-1 (Blocking B2; spec vs INTERFACES).** Spec §2/§8 RESOLVED Q10-5 puts the per-review bus `data_dir` at `RUN_HOME/<subtask>/bus/`. A.1:40 gives that directory to the sub-task lead's bus (`session_id = <run-id>-<subtask>`), and D4:119 calls the review bus "`pr-review`'s own local bus". Until this is resolved, every in-run review refuses at the pre-check. Recommended: put the per-review bus at `RUN_HOME/review/<subtask>/bus/` (A.1 already gives `review/<subtask>/` to `pr-review`), with spec errata to §2, §7 and Q10-5 and a one-line A.1/D4 note. The skill then changes one path variable and its literal cleanup guard.
- **OQ-10-2 (integrator).** D2.3's `pr-review` row does not name `RUN_HOME`, `RUN_ID`, `SUBTASK`, `SEAT_ID`, `MEMBER_SESSION_NAME`, `TASK_ID` or the catalog `correlation_id` field. Recommended: add them to D2.3 as `DEFAULT (integrator)` in the next INTERFACES patch, since the skill already validates them in Step 0.
- **OQ-10-3 (owner).** D2.3 says `BUS_PORT` is "absent standalone". The skill accepts an optional standalone `BUS_PORT` as the candidate and otherwise uses 7777. Recommended: accept it, because it gives standalone callers a way past the two-port OQ-2 range without auto-pick.
- **OQ-10-4 (owner).** OQ-2 says the retry is "claimed before bind" and applies to standalone `pr-review`. Standalone has no run (no `project`/`source`), so the skill does an `lsof` re-check, as spec Q10-5 reads it ("the R-x +10 and re-check is done exactly once"). Recommended: accept the `lsof` re-check for standalone, with `port-check.sh --claim` only inside a run.
- **OQ-10-5 (owner awareness).** Behaviour changes outside the mandated set: the synthesizer moves to the design tier (M19 / part-01), `MEMBER_SESSION_NAME` must be lowercase (A.6), and standalone tries two ports instead of a scan (OQ-2). Recommended: accept all three.
