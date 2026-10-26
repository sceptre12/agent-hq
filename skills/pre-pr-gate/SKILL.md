---
name: pre-pr-gate
description: Use when a rebased sub-task branch is ready to become a PR and no PR may open before local review, fix and verification are done. Runs the stage 4b gate - cold CI-parity run by a separate gate runner, version-bump, dist, redaction and scope checks, G48 pre-round check, 7-seat local-diff pr-review, separate fixer, fix-verifier, rounds 1-3, completeness validator, Verified-By, pr-body.md - and ends with exactly one PREPR token. Not for an open PR (ci-fix-loop) or document review (doc-reviewer).
version: 0.1.0
---

## Trigger

Use when a lead holds a rebased sub-task branch (also `st0` in `plan-pr` mode) and is about to
push or open a PR. Caller: `delivery-run`, stage 4b. `push` and `pr-create` require
`PREPR: PASS` for the head (INTERFACES part B4); the lead copies the token to `substate.md`
`prepr`. Do not use it on a PR that is already open.

Step 0 (inputs, `NAME=value`; `DELIVERY_ROOT` is the environment variable). Check each against
INTERFACES part D1, D2.2 row 10, D2.1:
`RUN_HOME` (path), `SUBTASK`, `HEAD` (40-hex sha of the rebased branch), `WORKTREE` (path),
`REPO_PROFILE` (`<abs path>@<sha>`), `SECURITY_AUDIT` (`guidance|full`). Print
`INPUT-ERROR <field> <reason>` (reason `missing|enum|path|unset|format`), one line per failing
field, then stop. No retry, no prompt. `DELIVERY_ROOT` unset is `INPUT-ERROR DELIVERY_ROOT unset`.
A profile file that does not exist is `INPUT-ERROR REPO_PROFILE path`; verify the sha with
`git hash-object <path>` = `<sha>` (A.2 `repo_profile`), a mismatch is
`INPUT-ERROR REPO_PROFILE format` (as D2.2 row 6 treats an `interfaces_version` mismatch; open
point 7). Read `primary_repo` and `plans_dir` from `RUN_HOME/state.md` (A.2). Then read these
A.2.2 profile keys; a missing one is `INPUT-ERROR <key> missing`: `gates.command`,
`gates.parallel`, `gates.min_free_kb`, `gates.runner_slots`, `node.prefix_cmd`,
`secrets.pattern_file`, `sensitive_paths[]`, `worktree_base`.
Design-only profile fields (part-04 §5.8; not INTERFACES keys, so never an `INPUT-ERROR`):
`install.rebuild_allowlist`, `e2e.dist_scan_cmd`, `version_bump_rule`, the PR template path and
the exact lint, typecheck, test and build command strings. The standardization pre-check is a
part-04 §5.7 row (C8); no §5.8 field names its command. If one is absent, the row it feeds has
no evidence and fails (checklist rule "no evidence = FAIL"); name the missing field in that row.

Output: line 1 of `RUN_HOME/review/<subtask>/checklist-<subtask>.md` is `PREPR: PASS` or
`PREPR: STOP <ids>` (comma-separated failed checklist row ids `C1`-`C26`); the same file is the
checklist body, and the token is only written there, never printed (D1.1). Template:
`references/templates/step-completeness-checklist.md` (item 27). Depth for each step:
`references/steps-detail.md`.

## Steps

Files are under `RUN_HOME/review/<subtask>/` unless stated; `status/` is
`RUN_HOME/<subtask>/status/` (A.6). `HEAD` is the current head: when the head moves it is the
new sha, and the record is `record-<new head>.md`. PR base = main (card 10 In: "branch rebased on
main"); the ref name is open point 6. Write a slot row before each agent you dispatch (A.4),
except reserved-seat agents (review seats, counted by `substate.md` `reserved`, A.3). Personas
(D2.1 closed set): `gate-runner`, `gate-checker` (G48 check), `fixer`, `fix-verifier`,
`validator`, `review-seat` (Verified-By), `security-auditor`.

1. **Rebase, then review the landing head.** Rebase onto the PR base and check that `HEAD`
   equals the rebased tip; a mismatch fails C3. If a record exists and
   `git merge-base HEAD <PR base>` differs from `git merge-base <record head> <PR base>` (ref per
   open point 6; record head from
   its line 1), run a non-author delta verify of reviewed-head..new-head instead of a full
   re-review (part-03 "Rebase-before-verify", M16).
2. **Node and cold gate.** Activate node with `node.prefix_cmd` (one shot) and check
   `node --version` equals `.nvmrc`. Install `--frozen-lockfile --ignore-scripts`, then
   `pnpm rebuild` of `install.rebuild_allowlist` only; a node or install failure fails C7 (install
   is part of CI-parity, part-01 stage 4b). Dispatch a separate mechanical gate-runner agent
   under a `gate-runner/<n>` lease (`catalog.sh register lane-lease gate-runner/<n> ...`, written
   `live` directly; A.5); after the `df -k` check against `gates.min_free_kb` it runs
   `gates.command` and the CI-parity commands (the profile's exact lint, typecheck, test and build
   strings in CI order; part-01 stage 4b, part-04 §5.8), cold, with `--skip-nx-cache`
   (cache-satisfiable gates are false-green), then releases its lease, pass or fail (a runner
   that dies holding it: open point 9)
   (`catalog.sh release lane-lease gate-runner/<n>`; A.5.1 `lane-lease`). A failure fails C6/C7
   (and C9). The runner itself writes `RUN_HOME/<subtask>/gate-runs/<HEAD>.md` (`GATE-PASS`,
   part A.7); you never write it. This run is the first-push `GATE-PASS` only while the head is
   unchanged. The per-push rule and `HUSKY=0` are stated once, in part A.7; link, do not restate.
   Reviewers never hunt lint or typecheck.
3. **Version-bump check (C24).** Take the affected apps from the dispatch plan's per-sub-task
   affected-app list (`<plans_dir>/dispatch-plan.md`; part-04 5.8b "Version-bump rule"). Check
   that each one under `apps/` (not `apps/examples/`, not any `e2e` path) has a changed
   `package.json` `version` since the merge base with the PR base, and that no unaffected app
   gained one (profile `version_bump_rule`).
4. **Dist scan (C25).** Run `e2e.dist_scan_cmd` on a production build of the affected apps. Any
   mock fixture, auth-bypass or `__E2E__`-gated chunk in `dist/` is Blocking.
5. **Standardization pre-check (C8).** Run the profile's standardization pre-check.
6. **Redaction gate (C10).** Run `command grep -E -f <secrets.pattern_file>` over the diff, the
   gate logs and `pr-body.md` (once drafted; step 19 re-runs this step). Exit 1 is clean, exit 0
   is a hit, exit 2 or more (unreadable pattern file, bad ERE) fails C10, never read as clean.
7. **Scope-check, preventive (C11).** Per unit in `substate.md` `integrated`, run
   `scope-check.sh <tasks-file> <unit worktree> <base-sha>` with the INTERFACES script-table
   forms (`<tasks-file>` = `<primary_repo>/.tasks/<unit>-<slug>.md`, unit worktree
   `<worktree_base>/<run-id>-<subtask>-<unit>`, `<base-sha>` = `git -C <unit worktree> merge-base
   HEAD <sub-task branch>`). Then match `git -C <WORKTREE> diff --name-only <merge-base of HEAD
   and the PR base>..HEAD` against `sensitive_paths[]` (A.2.2). Each `CREEP` or sensitive hit
   needs a matching `INSTALLED` row or a human grant; no source yet defines where either is
   looked up (open point 1), so a hit with no evidence the validator can re-run fails C11.
8. **G48 pre-round check.** Dispatch a mechanical-tier agent to check the artifacts listed in
   `references/g48-classes.md` against its finding classes; it writes its list to its own
   `status/<agent-id>.md`. Hand a non-empty list to a fixer dispatch (the step 12 role, own
   `agent-id`) before any seat reads; it writes `fix-<agent-id>-<r>.md`, `r` the round it
   precedes (1 before round 1), disjoint by `agent-id` (A.6). Whether `fix-verifier` also checks
   a G48 fix is open point 4. Repeat after every fix and after step 19 drafts `pr-body.md`.
9. **Security seat.** Pass `SECURITY_AUDIT` to `pr-review`; under `guidance` (default) its
   security seat loads `skills/security-audit` diff-scoped, writes no file, launches no agent.
   Under `full` (only on an explicit operator request or a `security_sensitive: yes` epic, set
   by the conductor, never decided here) run `references/security-seat.md` now, before round 1,
   and again whenever the head moves, with a slot row per agent (persona `security-auditor`).
   Run the gate row `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json`;
   a non-zero exit fails `C26` (`PREPR: STOP C26`, A.5.3).
10. **Seat set.** Set `ROLES` to all 7 seats: smaller sets wait for the D12 RACI remap and 3-seat
    probe (owner D12; D2.3 `pr-review` "seat count 7 until the D12 remap and probe are recorded").
    Once D12 is recorded in D2.3 and the profile asks for a tailored set, run `review-tailor`
    with `SLUG=<subtask>-diff-<n>` (minted here; `<n>` counts local-diff reviews of this
    sub-task) and the D2.2 row 4 inputs (`references/steps-detail.md` "Seat set").
11. **Round r (r = 1..3): run `pr-review` local-diff.** Inputs `PR_REVIEW_MODE=local-diff`,
    `ROLES`, `RECORD_PATH=RUN_HOME/review/<subtask>/record-<HEAD>.md` (absolute, D2.2 `(path)`),
    `STACK_BASE` = the PR base sha the branch was rebased onto, `STACK_HEAD` = `HEAD`,
    `SECURITY_AUDIT`, `BUS_PORT` = the `review-bus` row candidate for this sub-task in the P8
    port table of `<plans_dir>/dispatch-plan.md` (A.5.2: `ports.bus_base + 10·(2N+1)`; template
    `skills/delivery-dispatch-plan/references/templates/dispatch-plan.md` "P8 Port table").
    `pr-review` Step 1 runs the A.5.2 order (claim, register, launch pinned to that port,
    start); on a refusal (`port-check.sh` exit 1 or 2) it makes exactly one claimed retry at
    `BUS_PORT + 10`; a second refusal, or exit 3 (registry unusable, no retry), stops the line
    and is reported to the lead (A.5.2, D2.3, AM-3 OQ-2). You claim no port and never pick one.
    On that stop, record the refusal line in the checklist and name the checklist path to the
    lead; its effect on C12 and what follows is open point 5. One
    review orchestrator per loop (D35). Read the bus topics `pr-check-N-closed` with
    `peek:true`, a fresh `agent_id` per reader, `limit 200`. `pr-review` writes record lines 1-2.
12. **Fix.** Dispatch a separate fixer (never the author nor a seat). It commits in `WORKTREE`
    and writes `fix-<agent-id>-<r>.md` with a non-empty `fix:` field, the commit sha, exact fix
    text and a protected-values list (card 10 Out "fix commits"; C14). One fixer per worktree at a
    time, or one worktree per fixer with disjoint file sets and serial integration. A second fix
    round that adds Mediums escalates the fixer one tier; never a third top-tier attempt (ADR
    0014 T1). Re-run step 8 on the fix. A fix without a `fix:` field or sha fails C14.
13. **Fix-verify.** Run `fix-verifier` with `FILE_SET` = the failing files; a change outside it is
    `ISSUES_FOUND`. Write `verify-<seat-id>-<r>.md`. If the head moved, repeat steps 1-2 (and
    step 9 under `full`) on the new head, then a delta verify. Go back to step 11 until CLEAN
    with 0 Blocking and 0 Medium.
14. **Round cap.** After round 3 with findings open, fail `C12`, `C15` when the last verify is
    not CLEAN, and every other failed row; go to step 20 (`PREPR: STOP <ids>`), stop THIS
    sub-task and name `record-<HEAD>.md` and the checklist path to the human; other sub-tasks
    continue (D7). No round 4.
15. **Final head gate.** If fix rounds moved the head, dispatch the gate runner again under a
    fresh `gate-runner/<n>` lease (released after the run) to re-run the same cold command on the
    final head and write `gate-runs/<final head>.md` (row C9). Without it `push` is refused.
16. **Completeness validator.** Dispatch a verify-tier agent to walk every checklist row except
    C13, C21 and C22, re-run each evidence command itself on the final head (so steps 3-7 are
    re-checked there) and diff the plan's unit list (`<plans_dir>/dispatch-plan.md`) against
    `substate.md` `integrated`. It walks C13, C21 and C22 after step 19, when their evidence
    exists. Fail on any single failing Blocking row; never a weighted score.
17. **Verified-By.** Dispatch a seat whose id differs from line 2's `Reviewed-By`; it re-derives
    the head sha and 0 Blocking / 0 Medium from line 1
    (`CODE-GATE-REVIEW: PASS head=<sha> blocking=0 medium=0`) and appends line 3
    `Verified-By: <seat-id> head=<sha>` to the record.
18. **Catalog check (C21).** Read `RUN_HOME/catalog.tsv`; for each `kind`+`handle` pair of this
    sub-task take the latest row (A.5 supersede key); none may be `planned`. Confirm no
    `gate-runner/<n>` lease of this skill is still `live`. The review bus, its port and pm2 rows
    are cleaned up by `delivery-cleanup` (A.5.1), not here.
19. **`pr-body.md`.** Build it from the profile's PR template: record path, Test Steps, redacted
    screenshots and traces from the e2e lane, auto-healed diffs listed for the test-adequacy
    seat. Write atomically (temp name, `mv`). Re-run steps 6 and 8 on it.
20. **Token.** Write the checklist with `PREPR:` on line 1 (temp file, `mv`): `PASS` only if
    every row has evidence and none failed, else `STOP <failed ids>`. Do not print the token.

A failing row outside the review loop (steps 1-7, 10, 15, 19): record its row id and evidence
in the checklist and name the checklist path to the lead. Whether it then enters the step 12 fix
loop or stops the line is open point 3; this skill picks neither. `PASS` stays impossible while
any row fails or lacks evidence.

## Red flags

| Rationalization | Do instead |
|---|---|
| "The author's own green run is enough" | The gate runner is a separate agent and writes `GATE-PASS` itself. |
| "Cached nx run is fine" | Cold, `--skip-nx-cache`. |
| "Let seats find lint and type errors" | Gates catch them; seats never hunt them. |
| "Fix first, G48 later" | G48 before round 1 and after every fix, fixes land before seats read. |
| "Same fixer retries at the same tier" | Escalate one tier on a second round that adds Mediums; no third top-tier try. |
| "Round 4 will close it" | Round 3 is the cap; STOP and hand the record path to the human. |
| "Pick a free bus port after a refusal" | `pr-review` makes one claimed retry at `BUS_PORT + 10`; a second refusal stops the line. |
| "Keep the gate-runner lease for the next run" | Release it after each run; step 15 registers a fresh one (a held lease is exit 3). |
| "Fewer seats are fine for a small diff" | All 7 until D12 is recorded. |
| "Read the bus without peek" | `peek:true`, fresh `agent_id`, `limit 200`. |
| "Weighted score passes it" | One failing Blocking row fails the gate. |
| "Verified-By can be the reviewing seat" | The seat must differ from line 2. |
| "Grep exit 2 means no match" | Only exit 1 is clean; 2 or more fails C10. |
| "Prose is enough for the human" | Name the file path (record, checklist). |

## Exit criteria

- [ ] Step 0 passed or `INPUT-ERROR` lines printed and nothing else ran.
- [ ] On PASS: `gate-runs/<final head>.md` exists, written by the gate runner (`GATE-PASS`).
- [ ] On PASS: `record-<HEAD>.md` line 1 is `CODE-GATE-REVIEW: PASS ...`, line 3 `Verified-By` differs from line 2.
- [ ] Every review-loop (step 12) fix has a `fix-<agent-id>-<n>.md` with a non-empty `fix:`, a sha and a
      CLEAN `verify-*` record; G48 fixes (step 8) are pending open point 4.
- [ ] Redaction, scope, version-bump and dist rows have evidence; under `full`, `C26` passed.
- [ ] On every exit path: no `gate-runner/<n>` lease of this skill is `live`; on PASS no `planned` catalog row.
- [ ] `checklist-<subtask>.md` line 1 is exactly one `PREPR:` token; `pr-body.md` exists on PASS.
- [ ] On `STOP` or a failure outside the loop: the failed row ids are in the checklist and the
      lead or human was given the checklist and record paths.

## Provenance

Card 10 friction (part-02 §2.2 card 10; part-06 sources row "4b Pre-PR gate"):
`enforcement-gates:10`, `:141`; PR #18/#19 second verify; `pr-review-local-diff-bus-facts`;
`pr-review-orch-reads-closed`; `brain-workflow-shift:26`. Spec `tasks/20-pre-pr-gate.md`;
INTERFACES 1.3.0. Pilot: pending.
