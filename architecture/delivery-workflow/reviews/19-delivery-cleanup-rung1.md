# Item 19 `delivery-cleanup`: Rung 1 loop record

- **Artifact:** `skills/delivery-cleanup/SKILL.md` and `references/{dry-run-table,executor-rules,cleanup-record}.md`.
- **Spec:** `architecture/delivery-workflow/tasks/19-delivery-cleanup.md`. The RESOLVED lines and the §3 do-not-create list were binding.
- **Loop:** one orchestrator (D35). Each role ran as a separate agent, and no agent was reused across roles or rounds:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed `doc-reviewer`.
  - Fix: Opus.
  - Fix-verify: Sonnet, running the installed `fix-verifier`.
- **Order:** the screen ran before round 1 and after each fix, and its findings went to the fixer first.
- **Round cap:** 3 rounds (D7). **Date:** 2026-10-26.
- **Sources:** the spec, INTERFACES (1.2.0 at the start, 1.3.0 by AM-3 during the loop), `owner-decisions.md`, part-01 (M32), part-02 card 9, `tools/delivery/{catalog.sh,catalog-audit.sh,desk-req.sh}`, `~/projects/agent-hq/tools/port-check.sh`, `skills/port-claim`, `skills/resource-catalog` and `tools/skill-authoring.md`.
- Reviewers skipped lint and typo nits.

## Round 1
- **Pre-round screen: 0 B, 7 M, 7 Advisory.**
  - `pm` and `final` evidence and the approver did not match C5.1.
  - The INTERFACES pin was stale.
  - Provenance was not linked.
  - Bus, cron and bgtask handling was wrong.
  - Per-kind commands restated A.5.1.
  - `failed` and `kept` rows were unhandled.
- **Review: 0 B, 4 M, 7 L. Verdict: READY WITH CONDITIONS.**
  - The record had no single writer and no failure path.
  - "Capture first" contradicted "a failed guard means keep".
  - The source of PR evidence was missing.
  - The `merge_sha` source for `pm` and `final` was missing.
- **Fix:** all fixed, none rejected.
- **Fix-verify: ISSUES_FOUND, 0 B, 1 M, 1 L.** The `tools/catalog.sh` path was wrong, and the record over-claimed the conductor's failure signal.

## Round 2
- **Post-fix screen: 1 B, 4 M, 3 Advisory.**
  - Blocking: the `final` mode said stage 6-7 worktrees are released, but the A.5.1 "PR open or merged" guard keeps them.
  - "Any REJECTED means keep" contradicted the B2.1 curable codes.
  - The merge test was against "base", not main.
  - "Capture" was undefined.
- **Review: 0 B, 6 M, 6 L.**
  - The step order was impossible.
  - Planned and GHOST rows had no action.
  - The branch-delete hand-off was undefined.
  - `pm` rows had two owners.
  - Port-claim fields had no source.
  - There was no cross-kind order.
- **Fix:** all fixed. G1 is now consistent: kept with `no-pr-evidence` until the owner decides (OQ-B).
- **Fix-verify: CLEAN, 0 B, 0 M, 3 L.**

## Round 3 (final, D7)
- **Post-fix screen: 1 B, 8 M, 7 Advisory.**
  - Blocking: a `released` port claim is refused while the registry check is not free, and the skill had no refusal branch.
  - The `catalog.sh keep` signature was wrong.
  - Ownership of the Step 8 checks was unclear.
  - Desk `fetch` was not handled.
  - The outcome of `.req.noreply` was missing.
  - `DELIVERY_ROOT` was not checked.
  - The port `source` field was described two ways.
  - The `port-check.sh` path was wrong.
- **Review: 1 B, 4 M, 6 L. Verdict: NOT READY.**
  - Blocking: GHOST "release alone" skipped port, bus and branch residue.
  - The merge test ran against a lagging local main.
  - cron and bgtask need host-session tools.
  - `db` had no profile key.
  - The dry-run builder and resume path were undefined.
- **Fix:** all 27 dispositioned: 25 fixed, G2 folded into R1, and R3 and R4 fixed on the conservative path as owner questions.
  - Skill defaults added: the cross-kind order; the `no-claim-row`, `pid-identity`, `clone-unpushed` and `worktree-residue` guards; the `.md.new` and `.md.tmp.<n>` names.
- **Fix-verify: CLEAN, 0 B, 0 M, 2 L.**
- **Post-fix screen: 1 B, 4 M, 6 Advisory.** These came after the last fix, so no further round ran (D7). They are listed under Final status.

## Final status
**After round 3, the loop stopped at the D7 cap: 1 Blocking, 4 Medium and 2 Low are open. The owner decides.** The fix-verifier found the round-3 fixes CLEAN (0 B, 0 M). The post-fix screen then raised these new findings, which were not fixed:
- **S1, Blocking** (`executor-rules.md:29`): the clone guard checks only porcelain and unpushed commits. `rm -r` would also delete ignored files such as `.env` and credentials (spec §4 never-touch). Recommended fix: apply the same `git status --ignored` guard as worktrees, otherwise keep the clone.
- **S2, Medium** (`SKILL.md:52`): Provenance pins INTERFACES 1.3.0, and the set is now 1.4.0 (AM-4). Re-pin, and check the AM-4 consumer rows.
- **S3, Medium** (`executor-rules.md:35,37`): `main` is hardcoded in the `fetch` and `branch-delete` fields instead of the profile `default_branch` (A.2.2). This is the same issue as the verifier's V1.
- **S4, Medium** (`executor-rules.md:36`): the host's `TaskStop` hand-off omits the C7 orphan sweep that A.5.1 `bgtask` requires.
- **S5, Medium** (`cleanup-record.md:13,15`; `SKILL.md:28`): the `.md.tmp` then `.md.new` two-temp flow departs from the A.6 "single temp after residual" writer contract. Either fold it back to one temp, or ask for an A.6 amendment.
- **Lows:**
  - V2: no fallback for a `bus` GHOST with no `bus.endpoint` (suggested: `keep bus <handle> no-endpoint`).
  - The screen's advisories G6-G11: Step 8 wording against `.md.new`; mapping `.req.noreply` to B1 `sender`; "any ignored file" being stricter than A.5.1 (owner to confirm); the example branch guard; the provenance "capture" wording; the non-Jira branch names that the B4 regex refuses.

**§9 done-condition:** the verifier ran it as the non-author dry run. `bash v19.sh` printed `SKILL-19-OK` as its last line (exit 0). `check-doc-length.sh` reported 0 blocking.

**Out of scope (cross-item):** `skills/delivery-run/references/briefs/cleanup-executor.md:20` (item 27b) says `.git` is "included or excluded". A.5.1 fixes it as included.

**Owner questions:**
- **OQ-A:** how does the conductor learn that a cleanup failed? None exists in parts C or D, and the skill names none. Recommended: the approver sends `ESCALATE`, reason `human-step` (C2), which appears in the conductor's status.
- **OQ-B:** does a detached `pm` worktree (stages 6-7) whose HEAD is an ancestor of main (`pm_sha`) pass the A.5.1 "PR open or merged" guard? M32 says the second pass releases these worktrees. Recommended: yes, through an INTERFACES amendment. Until then they are kept with `no-pr-evidence` and flagged.
- **OQ-C:** who runs `CronDelete` and `TaskStop` for `cron` and `bgtask` rows, given that the executor is a subagent? Recommended: the host session runs them and the executor records the result. Without the tool, the row is kept with `no-host-tool`.
- **OQ-D:** A.5.1 `db` cites a profile-lane `cleanup_cmd`, but A.2.2 has no such key. Recommended: add `lanes.<name>.{verify_cmd,cleanup_cmd}` to A.2.2. Until then the row is kept with `no-profile-cmd`.
- **Advisory, not raised as a question:** R12 deletes a clone with unpushed commits only behind the `clone-unpushed` skill-default guard.

## Post-D7 fix (owner-authorized, 2026-10-26, no new review round)
The owner authorized applying the loop's recommended fixes after the D7 stop, with the owner-accepted answers to OQ-A..D (AM-5 queue row "(19)"). Fixer: Worker1 integrator. Fix-verify: separate Sonnet agents running the installed `fix-verifier`.
- **S1 (B) fixed:** the clone guard is the worktree check, `git -C <path> status --ignored --porcelain` non-empty → `keep clone <path> ignored-or-dirty` and flag, never delete (`executor-rules.md` clone line; the red flag and the guard column cover clones).
- **S2 fixed:** Provenance pins INTERFACES 1.4.0, AM-4 row 20 (`default_branch`, `list --live`); Step 7 notes that `catalog.sh` prints `live` rows only and `failed` is read from `catalog.tsv`.
- **S3 fixed:** `main` → the profile `default_branch` (A.2.2) in the D8 test, the `fetch` and `branch-delete` fields, red flags and exit criteria.
- **S4 fixed:** host hand-off step 2 runs `TaskStop`, then the A.5.1/C7 orphan sweep (register each orphan as a `process` row, add it to `## approved`).
- **S5 fixed:** one `.md.tmp`; line 1 inserted as the last write, then `mv` (A.6). `.md.new` removed.
- **OQ-A:** a failed cleanup → the approver sends C2 `ESCALATE` reason `human-step` with the `.tmp` path. **OQ-B:** the detached `pm` worktree passes the PR condition of the removal guard (cites AM-5 queue row "(19)"); clean/no-ignored still applies. **OQ-C:** the host session runs `CronDelete`/`TaskStop`. **OQ-D:** `db` rows use `cleanup_cmd`, kept `no-profile-cmd` until the key exists.
- Low V2: `bus` with no `bus.endpoint` → `keep bus <handle> no-endpoint`.
- **Fix-verify 1: all closed, 0 B, 0 M, 2 Advisory** (one wording advisory fixed; "pending the INTERFACES amendment" kept while AM-5 is pending). §9: `SKILL-19-OK`.
- Out of scope, still open: `skills/delivery-run/references/briefs/cleanup-executor.md` ".git included or excluded" (item 27b; AM-5 row says included).

## Functional check (2026-10-26)
A separate Sonnet agent ran the skill literally (host/approver, executor, validator phases) against a fixture under `$TMPDIR/cleanup-fx.XXXXXX`, with the catalog written by the real `tools/delivery/catalog.sh` and the port claimed with the real `~/projects/agent-hq/tools/port-check.sh` (port 7931). Deviations: the claim went to a copy of `ports.tsv` via `PORT_REGISTRY_FILE` so the real registry was not written; clones sat under `RUN_HOME` (`catalog.sh` refuses other roots); one extra unregistered worktree exercised `SQUATTER`; there is no remote, so the desk `DONE` replies were simulated (`desk-req.sh` itself ran locally). Evidence: `$TMPDIR/cleanup-fx-evidence/` (record, `catalog.tsv`, run log).

| # | Assertion | Result |
|---|---|---|
| A1 | merged worktree removed (`git worktree remove`, absent from list, path gone) | PASS |
| A2 | clean clone removed (one `rm -r` by literal path) | PASS |
| A3 | worktree with ignored `.env` kept and flagged (`kept ignored-or-dirty`, residual line), `.env` intact | PASS |
| A4 | clone with ignored `.env` kept and flagged, `.env` intact | PASS |
| A5 | non-catalog directory untouched and reported in `## residual` | PASS (needed a listing source the text lacked, F3) |
| A6 | `sleep 600` gone (`kill -0` before ok, `kill`, `kill -0` after fails) | PASS |
| A7 | port row `released`; `port-check.sh 7931` FREE | PASS |
| A8 | `list --live --subtask st1` empty; no st1 row latest planned/live/failed | PASS |
| A9 | line 1 `CLEANUP DONE st1` written last via one temp + `mv`; four sections in order | PASS |
| A10 | nothing outside the fixture changed (agent-hq main clean, real `ports.tsv` untouched; W diffs only from other agents) | PASS |
Also: tmpdir removed, merged branch deleted, the `.env` worktree's branch kept.

Findings and dispositions (fixed once, then re-verified by a separate Sonnet `fix-verifier`: **CLEAN**, 0 B, 0 M; §9 `SKILL-19-OK`):
- F1 handle examples need `<repo-abs-path>`: fixed. F2 path handles must lie under `RUN_HOME`/`WORKTREE_BASE`: stated. F3 no source found a plain unregistered dir: read-only `ls` of `worktree_base` and `RUN_HOME/<subtask>/` added as a report-only source (never a deletion scope, D9). F4 guard `deferred-desk` added. F5 `worktree-kept` guard; approver `keep` applied by `catalog.sh keep`; rows matched by kind+handle, not row id (also F9). F7 `port-check.sh --audit` lines filtered to scope. F8 validator also checks `port-check.sh <port>`. F10 `kill -0` "operation not permitted" is stop-and-report, not gone; the already-gone rule re-tests a `process` `GHOST` (`catalog-audit.sh` reports any `kill -0` failure as `GHOST`). F11 `INPUT-ERROR` reason mapping added to Step 0.
- **Open for the owner:** F6, the skill has no rule for a repo with no remote (`merge_reach=local`): the D8 hand-off is remote-first and assumes a desk `fetch`. Advisories left as is: `deferred-desk` is defined only in `dry-run-table.md`; D1 reason `sha` is not mapped in Step 0.
- Residue: two fixture `sleep 600` processes (pids 66138, 79808, cwd in the removed fixture) could not be signalled from this sandbox (EPERM); they exit by themselves within 10 minutes.
