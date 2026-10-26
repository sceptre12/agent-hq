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
`REPO_PROFILE` (`<abs path>@<sha>`), `SECURITY_AUDIT` (`guidance|full`).
Print `INPUT-ERROR <field> <reason>` (reason `missing|enum|path|unset|format`), one line per
failing field, then stop. No retry, no prompt. `DELIVERY_ROOT` unset is
`INPUT-ERROR DELIVERY_ROOT unset`. Then read the profile keys named below; a missing key is
`INPUT-ERROR <key> missing`.

Output: line 1 of `RUN_HOME/review/<subtask>/checklist-<subtask>.md` is `PREPR: PASS` or
`PREPR: STOP <ids>` (comma-separated failed checklist row ids `C1`-`C26`); the same file is the
checklist body. Template: `references/templates/step-completeness-checklist.md` (item 27).
Depth for each step: `references/steps-detail.md`.

## Steps

All files below are under `RUN_HOME/review/<subtask>/` unless stated. Every agent you dispatch
gets a slot row first (INTERFACES A.4) and runs in `WORKTREE`.

1. **Rebase, then review the landing head.** Rebase onto the PR base; `HEAD` must equal the
   rebased tip, else stop with `PREPR: STOP C3`. If main moved after a record exists (merge-base
   of head and main differs from the record's head), a non-author delta verify of
   reviewed-head..new-head replaces a full re-review (part-03 "Rebase-before-verify", M16).
2. **Node and cold gate.** Activate node with `node.prefix_cmd` (one shot), require
   `node --version` equals `.nvmrc`. Install `--frozen-lockfile --ignore-scripts`, then
   `pnpm rebuild` of `install.rebuild_allowlist` only. A separate mechanical gate-runner agent,
   under a `gate-runner` lease (`catalog.sh register lane-lease gate-runner/<n> ...`, then
   `start`; A.5), runs `gates.command` and the CI-parity commands in order, cold, with
   `--skip-nx-cache` (cache-satisfiable gates are false-green), after the `df -k` check against
   `gates.min_free_kb`. The runner itself writes `RUN_HOME/<subtask>/gate-runs/<HEAD>.md`
   (`GATE-PASS`, part A.7); you never write it. This run is the first-push `GATE-PASS` only
   while the head is unchanged. The per-push rule and `HUSKY=0` are stated once, in part A.7;
   link, do not restate. Reviewers never hunt lint or typecheck.
3. **Version-bump check (C24).** Every app under `apps/` (not `apps/examples/`, not any `e2e`
   path) affected since the merge base has a changed `package.json` `version`; none added for an
   unaffected app (part-04 5.8b "Version-bump rule").
4. **Dist scan (C25).** Run `e2e.dist_scan_cmd` on a production build of affected apps. Any mock
   fixture, auth-bypass or `__E2E__`-gated chunk in `dist/` is Blocking.
5. **Standardization pre-check.** Run the profile's standardization pre-check (checklist C8).
6. **Redaction gate.** `command grep -E -f <secrets.pattern_file>` over the diff, the gate logs
   and `pr-body.md` (once drafted, step 15 re-runs it); the exit code gates (no match = clean).
7. **Scope-check, preventive.** `scope-check.sh <tasks-file> <WORKTREE> <base-sha>` per unit
   (`base-sha` = `git merge-base HEAD <sub-task branch>`), plus the diff against the profile's
   sensitive-path list (manifests, lockfiles, hooks, CI config). Each `CREEP` or sensitive hit
   needs a matching `INSTALLED` row or a human grant, else row C11 fails.
8. **G48 pre-round check.** A mechanical-tier agent checks the diff, the plan and `pr-body.md`
   against the known finding classes (`references/g48-classes.md`). Fixes land before any seat
   reads. Repeat after every fix.
9. **Security seat, guidance (default).** With `SECURITY_AUDIT=guidance` the security seat loads
   `skills/security-audit` diff-scoped, writes no file, launches no agent. Under `full` (only on
   an explicit operator request or a `security_sensitive: yes` epic, set by the conductor, never
   decided here) run `references/security-seat.md` now, before round 1; slot rows for every
   agent (persona `security-auditor`); gate row: `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json`,
   non-zero exit fails `C26` (`PREPR: STOP C26`).
10. **Seat set.** If the profile asks for a tailored set, run `review-tailor` with
    `SLUG=<subtask>-diff-<n>` (minted here; `<n>` counts local-diff reviews of this sub-task);
    else all 7 seats.
11. **Round r (r = 1..3): `pr-review` local-diff.** Inputs `PR_REVIEW_MODE=local-diff`, `ROLES`,
    `RECORD_PATH=record-<HEAD>.md`, `STACK_BASE`/`STACK_HEAD`, `SECURITY_AUDIT`, `BUS_PORT` = the
    `review-bus` candidate of this sub-task's dispatch-plan port table. `pr-review` Step 1 runs
    the A.5.2 order (claim, register, launch pinned to that port, start); you claim no port. A
    refusal is reported to the lead and never re-picked. One review orchestrator per loop (D35).
    Read the bus topics `pr-check-N-closed` with `peek:true`, a fresh `agent_id` per reader,
    `limit 200`. The record's lines 1-2 are written by `pr-review`.
12. **Fix.** A separate fixer (never the author nor a seat) writes `fix-<agent-id>-<r>.md` with a
    non-empty `fix:` field, exact fix text and a protected-values list. One fixer per worktree
    at a time, or one worktree per fixer with disjoint file sets and serial integration. A
    second fix round that adds Mediums escalates the fixer one tier; never a third top-tier
    attempt (ADR 0014 T1). Re-run step 8 on the fix.
13. **Fix-verify.** `fix-verifier` with `FILE_SET` = the failing files; a change outside it is
    `ISSUES_FOUND`. Write `verify-<seat-id>-<r>.md`. If the head moved, repeat steps 1-2 on the
    new head, then a delta verify. Back to step 11 until CLEAN with 0 Blocking and 0 Medium.
14. **Round cap.** After round 3 with findings open: write `PREPR: STOP <ids>`, stop THIS
    sub-task, name `record-<HEAD>.md` and the checklist path to the human; other sub-tasks
    continue (D7). No round 4.
15. **Final head gate.** If fix rounds moved the head, the gate runner re-runs the same cold
    command on the final head under a `gate-runner` lease and writes `gate-runs/<final head>.md`
    (row C9). Without it `push` is refused.
16. **Verified-By.** A seat whose id differs from line 2's `Reviewed-By` re-derives the head sha
    and 0 Blocking / 0 Medium from line 1 (`CODE-GATE-REVIEW: PASS head=<sha> blocking=0 medium=0`)
    and appends line 3 `Verified-By: <seat-id> head=<sha>` to the record.
17. **Completeness validator.** A verify-tier agent walks every checklist row, re-runs each
    evidence command itself, and diffs the plan's unit list against the branch units. Fail on
    any single failing Blocking row; never a weighted score (`PREPR` has one verdict).
18. **Catalog check.** `catalog.sh list --live --subtask <subtask>`: no `planned` row remains
    (C21); release your own gate-runner lease and review bus rows.
19. **`pr-body.md`.** From the profile's PR template: record path, Test Steps, redacted
    screenshots and traces from the e2e lane, auto-healed diffs listed for the test-adequacy
    seat. Write atomically (temp name, `mv`). Re-run step 6 on it.
20. **Token.** Write the checklist with `PREPR:` on line 1 (temp file, `mv`). `PASS` only if
    every row has evidence. Print the token as the last stdout line.

## Red flags

| Rationalization | Do instead |
|---|---|
| "The author's own green run is enough" | The gate runner is a separate agent and writes `GATE-PASS` itself. |
| "Cached nx run is fine" | Cold, `--skip-nx-cache`. |
| "Let seats find lint and type errors" | Gates catch them; seats never hunt them. |
| "Fix first, G48 later" | G48 before round 1 and after every fix, fixes land before seats read. |
| "Same fixer retries at the same tier" | Escalate one tier on a second round that adds Mediums; no third top-tier try. |
| "Round 4 will close it" | Round 3 is the cap; STOP and hand the record path to the human. |
| "Re-pick the bus port after a refusal" | Report the refusal to the lead; never re-pick. |
| "Read the bus without peek" | `peek:true`, fresh `agent_id`, `limit 200`. |
| "Weighted score passes it" | One failing Blocking row fails the gate. |
| "Verified-By can be the reviewing seat" | The seat must differ from line 2. |
| "Prose is enough for the human" | Name the file path (record, checklist). |

## Exit criteria

- [ ] Step 0 passed or `INPUT-ERROR` lines printed and nothing else ran.
- [ ] `gate-runs/<final head>.md` exists, written by the gate runner (`GATE-PASS`).
- [ ] `record-<HEAD>.md` line 1 is `CODE-GATE-REVIEW: PASS ...`, line 3 `Verified-By` differs from line 2.
- [ ] Every fix has a `fix-<agent-id>-<n>.md` with a non-empty `fix:` and a CLEAN `verify-*` record.
- [ ] Redaction, scope, version-bump and dist rows have evidence; under `full`, `C26` passed.
- [ ] No `planned` catalog row; leases released.
- [ ] `checklist-<subtask>.md` line 1 is exactly one `PREPR:` token; `pr-body.md` exists on PASS.

## Provenance

Card 10 friction: `enforcement-gates:10`, `:141`; PR #18/#19 second verify;
`pr-review-local-diff-bus-facts`; `pr-review-orch-reads-closed`; `brain-workflow-shift:26`.
Spec `tasks/20-pre-pr-gate.md`; INTERFACES 1.1.0. Pilot: pending pilot (pilot-run-id).
