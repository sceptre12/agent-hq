# hq code gate — architecture (Rule 10)

One-line summary: executable code pushed to hq `main` must pass a `pr-review` round (0 Blocking / 0 Medium) and
run its mapped tests, enforced by a git `pre-push` hook plus three invariants that make a skipped gate visible.

- **Status:** ratified (owner rulings + Fable T6 amendments, 2026-10-01; Fable T2 ruling after D1v, 2026-10-02, applied);
  D1 built and hardened, ADR not yet written (D3).
- **Scope of this record:** WHAT/WHY (ADR 0011). The ADR number is not allocated here (decision numbers are shared state).

## 1. Verified facts (re-run before relying on them)
- `core.hooksPath` is `tools/git-hooks`, a RELATIVE path (ADR 0007), and `extensions.worktreeConfig` is unset, so all
  worktrees share it and a worktree runs ITS OWN branch's copy of the hooks. A branch that adds `pre-push` gates its own push.
- Before D1 there was no `pre-push` or `pre-merge-commit` hook. `--no-verify` and `-c core.hooksPath=` bypass hooks.
- `origin` is `<owner>/hq` (private). hq had never had a PR. Branch protection returns 403 on this plan, so GitHub
  cannot be the enforcement point and no GitHub-side merge is allowed.
- Integration is a local `git merge wt/<slug>` then a push of `main` (Rule 6).
- `pr-review` takes `REPO` + `PR_NUMBER` but never posts a PR comment and exits 0 offline, so the marker (§4) is posted by
  the orchestrator. ADR 0033's "pr-review BLOCKED" addendum is stale (grant 277416d).
- No `timeout`/`gtimeout` on this host: the runner has its own watchdog. macOS bash is 3.2: no `mapfile`/assoc arrays.

## 2. Rule 10 (owner-approved text; inserted into config/CLAUDE.md by D3)
- Owner, 2026-10-01 (verbatim): "Any code thats getting created to be pushed to hq main must go through a round of
  pr-review additionally tests should be written for it so that the merge to main in the future for changes to that
  specific fiel runs those tests"
- **Scope:** shell/zsh/python/js executables, hooks, tools. Excluded: Markdown, ADRs, learnings, SKILL.md prose,
  `config/settings.json`, `plans/**`.
- **Review:** push the `wt/` branch, open a PR, run `pr-review`; merge only at 0 Blocking / 0 Medium.
- **Tests:** every in-scope file has tests in the versioned map; the hook runs them and blocks on failure; an unmapped
  changed file blocks.
- **Existing untested code:** editing a grandfathered file requires writing its test in the same change; the list only shrinks.
- **Integration:** local merge, push `main`. Never merge on GitHub, never `--no-verify`, never override `core.hooksPath`.
  A code-gate block is stop-the-line (Rule 4).

## 3. Components (all under `tools/code-gate/` unless noted)
| Path | Role |
|---|---|
| `scope.conf` | `include|exclude <glob>` rules (shell `case` globs, `*` crosses `/`); `include mode:100755` takes any exec-bit file; `include tools/code-gate/*` puts the gate's own config in scope |
| `test-map.tsv` | `<source-or-glob>\t<test>`, sorted (`LC_ALL=C`), unique; a source may have several tests; a bare `*`/`**` source is `MALFORMED-MAP` |
| `grandfathered.txt` | the measured inventory of in-scope, non-test, unmapped files; no hand exclusions; shrink-only |
| `lib.sh` | sourced helpers: scope, NUL-delimited diff parsing, map/test/grandfather resolution, `cg_check_map`, `cg_review_commit` (shared by check-review and 29) |
| `run-mapped-tests.sh <base> <head>` | resolves changed files to tests, runs them, prints the `CODE-GATE:` line; `--inventory <rev|WORKTREE>` measures grandfathering |
| `check-review.sh <base> <head>` | main pushes only: walks first-parent merges (§4) |
| `gate-invariants.sh a|b|c` | the logic behind invariants 27/28/29 |
| `tools/git-hooks/pre-push` | entry point, dispatches on the REMOTE ref |
| `tools/check-invariants.sh` + `INVARIANTS.md` | checks 27-29 (`--code-gate` runs only these) |
| `test_*.sh` here, `tools/test_check-invariants.sh` | the gate's own tests, all mapped |

A test file (`test_*`, `*.test.*`, or any map test column) runs itself when changed and needs no map row.

## 4. Behaviour
**pre-push** (stdin `<lref> <lsha> <rref> <rsha>`). Gated remote refs: `refs/heads/main` and `refs/heads/wt/*`; dispatch is on
`<rref>`, so `git push origin wt/x:main` is gated as main. Other refs and deletions pass. Any internal error blocks.
- Base: `main` -> `<rsha>`. An all-zero `<rsha>` blocks, and so does a `<rsha>` that is not local
  (`BLOCK: remote main <rsha> not local; git fetch origin and retry`). `refs/remotes/origin/main` is never used for main.
  A non-fast-forward push to main (`<rsha>` not an ancestor of `<lsha>`) blocks: main is integration-only (Rule 6).
  `wt/*` -> merge-base(`<lsha>`, `origin/main`). This is an early signal only.
- **The gate runs from BASE.** `git archive <base> tools/code-gate --output <dir>/gate.tar`, then `tar -xf <dir>/gate.tar -C <dir>`, into a mktemp dir (two steps, not a pipe: bsdtar stops at the end-of-archive marker, so a piped `git archive | tar -x` can die of SIGPIPE, rc 141 under pipefail, and falsely block; `tools/git-hooks/pre-push:46-48`), then run that copy of
  `run-mapped-tests.sh <base> <lsha>` (and, for main, `check-review.sh`). Scope is read from base. One-time bootstrap: if base
  has no gate, the pushed head's copy runs and `CODE-GATE: BOOTSTRAP` is printed. The map and grandfather list come from head;
  changing them on main needs a reviewed merge, because they are in scope.
- No exact-tree or clean-tree guard. Tests run in a detached temp worktree of `<lsha>` (`git worktree add --detach`, removed
  in a trap), so HEAD, dirty files, `assume-unchanged` and `skip-worktree` cannot change what is tested.

**Runner (`run-mapped-tests.sh`).** Paths come from `git diff --raw -z` / `ls-tree -z` / `ls-files -z` and are read with
`read -d ''`. A deletion is classified by its source mode. Blocks, each printed as `BLOCK <code>:<path>` (`DIFF-FAIL` has no path: it prints a bare `BLOCK DIFF-FAIL`) and collected in
`CODE-GATE: FAIL n_run=<k> failed=<list>`:
- `UNMAPPED` an in-scope source with no map row that is not grandfathered;
- `DIFF-FAIL` a dying `git diff` (`--raw` via `cg_changed` rc 2, or the `--name-only` gate-config diff) is a gate failure, never `PASS n_run=0` (T-20261007-194);
- `STALE-MAP` / `MALFORMED-MAP` a row whose source or test is gone; an unsorted or duplicated map; a one-field row; a bare `*`/`**` source;
- `LIST-FAIL` the map check (`cg_check_map`, rc 2) could not list head's tree once into its one `mktemp -d` dir: git failed, mktemp
  failed, a temp file was unreadable, or the encoded listing was truncated. Fail closed, never `STALE-MAP`. Format:
  `LIST-FAIL: cannot list tree <rev> (<reason>, fail closed)`;
- `GRANDFATHER-GROWTH` a line added to `grandfathered.txt` (skipped only while base has no `scope.conf`); compared in pure bash.
  A grandfather list that cannot be read (git, grep rc >= 2 or sort failure) dies `cannot read grandfather list at <rev>`;
- `GRANDFATHERED-TOUCHED` a grandfathered file changed with no mapped test, or mapped but still listed;
- `TEST-FAILED`, `TEST-TIMEOUT` (default 120 s, `CODE_GATE_TIMEOUT`), `TEST-NOT-RUNNABLE` (not executable or no shebang).
- `COUNT-MISMATCH` (as of PR #24, pending merge) the number of tests run differs from the de-duplicated mapped count; see below.
Order: `DIFF-FAIL` fires at the first diff (before the map check), at the gate-config `--name-only` diff, and again at the per-file list; then the map check runs, then `GRANDFATHER-GROWTH`, then the per-file blocks. Before the first `STALE-MAP` line one
`STALE-MAP-DIAG: rev=<rev> rows=<map rows> entries=<tree entries> ulimit_n=.. ulimit_u=..` line goes to stderr only, never the verdict.
**As of PR #24 (<owner>/hq, head 1020fbf; pending merge, T-159; origin/main's `run-mapped-tests.sh` does not yet contain it):**
- Runner contract: each mapped test runs with stdin from `/dev/null` (`( exec "./$t" ) </dev/null`), so a test that reads stdin cannot eat the test list.
- Before the verdict the runner compares `n_run` with the de-duplicated mapped count `m`. If `n_run != m` it prints `CODE-GATE: BLOCK n_run=<k> mapped=<m>`
  and the block `COUNT-MISMATCH:n_run=<k>,mapped=<m>`, and the gate FAILs.
- Consequence: a gate fix judges pushes only after it is on main and the branch rebases onto it. The pre-push hook archives `tools/code-gate`
  from the push's merge-base (`tools/git-hooks/pre-push` L41-52 on origin/main 607d7d5: `src=$base`, `git archive "$src" tools/code-gate`, then
  `bash "$gate/tools/code-gate/run-mapped-tests.sh" "$base" "$lsha" </dev/null`), so a branch based before the fix is still judged by the old runner.
If the diff succeeded and nothing in scope changed, the verdict is `CODE-GATE: PASS n_run=0` (a failed diff is `DIFF-FAIL`, see above; T-20261007-194). Tests must be hermetic: no simulator, network, port or real DB; use `mktemp -d` fixtures.
**Failure-output contract (`run-mapped-tests.sh:4-5,25-28`):** each block is `BLOCK <code>[:<path>]` on stderr; the verdict goes to stdout, `CODE-GATE: PASS n_run=<k>` (exit 0) or `CODE-GATE: FAIL n_run=<k> failed=<list>` (exit 1); any internal error fails closed as `BLOCK ERROR:<msg>` plus a FAIL verdict. The pre-push hook turns a nonzero exit into `pre-push BLOCK: code gate failed for <rref> (see CODE-GATE line above).` (`pre-push:23,51-52`).

**check-review.sh / `cg_review_commit`.** For each commit in `git rev-list --first-parent <base>..<head>` that touches
in-scope files:
- (a) it is a 2-parent `--no-ff` merge with a `Code-Gate-PR: #N` trailer;
- (rule 8) every in-scope path in `<c>^1..<c>` is in the PR's diff `<c>^1...<c>^2` and is identical to `<c>^2` (mode included);
- (b) `gh pr view N --repo <owner>/hq` (hardcoded, no override) shows `baseRefName` main, `state` OPEN or MERGED,
  and `headRefOid` == `<c>^2`;
- (c) the LAST marker for that head is `CODE-GATE-REVIEW: PASS head=<c>^2 blocking=0 medium=0`.
Any `gh`/`jq` failure fails closed, as does a dying commit walk: `git rev-list --first-parent <base>..<head>` is captured first and a failure prints `DIFF-FAIL: git rev-list ... failed` and FAILs; a failed `git diff`/temp file inside `cg_review_commit` is `DIFF-FAIL` (rc 2). Known edge: if main and the branch both touched one in-scope file, rule 8 fails; rebase first.
ADR note (g5, Fable T3 §12): check-review judges every commit in a push under the BASE scope, while 29 uses each commit's
first parent. A single push that carries a scope-shrinking merge plus a merge relying on it is therefore judged under base
scope: push them separately.

**Invariants (`check-invariants.sh`, full mode).**
- 27 (a): `core.hooksPath == tools/git-hooks`. Every worktree in `git worktree list --porcelain` that has `scope.conf` needs an
  executable `pre-push` (FAIL). One without `scope.conf` gives `WARN 27 pre-gate branch, pre-push not yet present: <path>`, exit 0
  (Fable T3). A pre-gate worktree pushing main is caught by 29.
- 28 (b): the map is well-formed (as the runner's `MALFORMED-MAP`/`STALE-MAP`); a `LIST-FAIL` (tree listing failed) FAILs it
  too, fail closed. `STALE-MAP-DIAG` goes to stderr only.
- 29 (c): the audit starts at the first first-parent commit on `origin/main` whose tree has `scope.conf` and never skips after it.
  A later commit without it FAILs `gate config removed`. Scope is read from each commit's FIRST parent (the gate-introducing
  commit uses its own). Every in-scope commit must pass `cg_review_commit`. A `gh` failure, or a dying `git log`/`git rev-list` for the walk (both captured and checked, `cannot audit`), or a `DIFF-FAIL`, FAILs: fail closed,
  owner 2026-10-02. With no `origin/main`, it FAILs.

## 5. PR flow for a code work unit
1. Worktree `~/projects/agent-hq-worktrees/<slug>` on `wt/<slug>` (absolute path, never `git -C` nesting). Write code + tests + map rows; commit.
2. `git push -u origin wt/<slug>` (pre-push runs the mapped tests). 3. `gh pr create --repo <owner>/hq --base main --head wt/<slug>`.
4. Orchestrator runs `pr-review` (REPO=`<owner>/hq`); fixes loop back to step 2 until 0 Blocking / 0 Medium.
5. Orchestrator (never the author) posts the marker with `gh pr comment N --body "CODE-GATE-REVIEW: PASS head=<sha> blocking=0 medium=0"`.
6. In the main checkout: `git merge --no-ff wt/<slug>` with trailer `Code-Gate-PR: #N`, then `git push origin main` (hook runs tests + check-review).
7. Remove the worktree, keep the branch. Whether GitHub then shows the PR MERGED is unverified (D5).

## 6. Threat model, residuals, rejected alternatives (Fable T2 ruling; record in the ADR)
Owner, 2026-10-02: stay on the FREE GitHub plan, so there is no server-side protection. Invariant 29 fails closed when gh is down.
- **PREVENT:** forgetful or careless agents, and any bypass that rides in the content of the pushed commits, such as editing gate
  scripts, scope, map or grandfather list, or the working tree.
- **DETECT (29):** deliberate out-of-band circumvention, such as another transport, a replaced hook, or another checkout. A client-side
  hook cannot prevent these, and the ADR says so plainly.
- **Residuals:**
  - R1: `pre-push` itself replaced by `exit 0` in a direct commit (detected by 29).
  - R2: an orphan or pre-gate checkout, `git send-pack`, or a foreign `GIT_WORK_TREE` (D1v H4/H5/H6; detected by 29).
  - R3: a fresh clone with `core.hooksPath` unset.
  - R4: scope edges: `*.SH`, extensionless 100644 files, destination-side mode (H12), symlinks into `plans/` (H13).
  - R5: `test_*` naming counts as a test with no map row, and a no-op test passes. Review is the control.
  - R6: dependents of deleted files are not run.
  - R7: 29 is after the fact.
  - R8: anyone with write access to the repo can post the marker.
  - R9: anything else falls under Rule 10's stop-the-line.
- **Not covered by design:** no case-insensitive globs, no symlink resolution, no dependents graph, no L2 guard.
- **L2/D2 DROPPED (Fable T6):** no PreToolUse `hq-git-guard.sh`, no `config/settings.json` change. Reopen only if 29 ever fires.
- **Other rejected alternatives:**
  - merging on GitHub (no protection);
  - GitHub Actions (cannot block);
  - `pre-merge-commit` only (skips fast-forwards, can be skipped with `--no-verify`);
  - per-file header annotations (the owner chose a map).
- **Stale header:** `tools/git-hooks/pre-commit` line 3 ("Bypass: git commit --no-verify") contradicts Rule 10. It is left
  untouched; the ADR notes it.

## 7. As-built notes (D1)
- Grandfathering measured by `run-mapped-tests.sh --inventory WORKTREE`: 29 files. cprof is included like any other file.
- Mapped existing tests: only `tools/sim-lease.sh` -> `tools/test_sim-lease.sh` (verified hermetic, 25 pass). Not mapped: the two fleet tests need a live
  Docker Supabase, `test_install_sweep_launchd.sh` fails, and `test_fileorg.py` has no shebang/exec bit, so they fail the runner contract.
- Bootstrap: the main checkout has no `scope.conf` until this branch merges, so check 27 WARNs (not FAILs) for it, and the D1r push
  of main runs the gate from the pushed head (`CODE-GATE: BOOTSTRAP`). ADR: record the WARN semantics.
- Parallelization (Rule 7): 2 of 8 plan steps (D3, D4) are safely parallel; D1 stayed one unit (shared files); assessed against a ~30-agent ceiling.

## 8. Dispatch order (plan: D0 done)
D1 build (+`test_check-invariants`) -> D1v adversarial proof on non-empty fixtures -> D1r pr-review, marker, local merge with trailer, push `main`
-> D3 docs (Rule 10 into config/CLAUDE.md, ADR, STANDARDS pointer) in parallel with D4 (cprof fix PR: 10 defects, `test_cprof*.zsh`, separate map
rows, `CPROF_ROOT=$(mktemp -d)`) -> D5 measure PR state after a local merge. D2 is dropped.
