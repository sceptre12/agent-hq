# INVARIANTS — hq structural self-check

Run these checks from the content of the repo, never from memory. Fix any FAIL before
committing. This file itself must always be present (check 6).

Each check lists: **what to verify**, **how**, **pass condition**.

---

## Structure

**4. STANDARDS.md keeps at least 9 numbered sections**
`grep -c "^## [0-9]\+\." ~/projects/agent-hq/STANDARDS.md` → output ≥ 9
PASS: at least 9 numbered sections present.

**6. INVARIANTS.md exists (meta-check)**
`ls ~/projects/agent-hq/INVARIANTS.md` → file present.
PASS: file exists.

---

## CLAUDE.md size and content

**10. (retired 2026-10-21: agentmemory removed by owner)**
Always passes; number kept so the numbering stays stable.

---

## Memory / store rules

**14. No nested git repos inside hq**
`find ~/projects/agent-hq -name '.git' -not -path '~/projects/agent-hq/.git'` → no output
(Run: `find ~/projects/agent-hq -mindepth 2 -name '.git'`)
PASS: empty output — no nested repos.

---

## Environment (post-stack)

**16. (retired 2026-10-21: agentmemory removed by owner)**
Always passes; number kept so the numbering stays stable.

**17. Serena registry excludes hq**
`~/.serena/serena_config.yml` `projects:` list contains no path under `~/projects/agent-hq`.
PASS: no hq path in the Serena project list. Config absent → WARN, not FAIL.

**18. Stack services loaded (WARN)**
`launchctl list` → contains `com.headroom.default` (the agentmemory service was retired 2026-10-21).
PASS: the service is loaded. Missing → WARN (runtime state, not structural).

**19. No runtime dirs in hq tree**
`find ~/projects/agent-hq -maxdepth 1 \( -name data -o -name .serena \)` → no output.
PASS: no `data/` or `.serena/` directory at the hq top level.

---

## Container execution lane (ADR 0008)

**20. No Anthropic token material committed in hq**
`! git -C ~/projects/agent-hq grep -qE 'sk-ant-(oat|ort|api)[0-9]{2}-'` → command succeeds.
PASS: no tracked file contains the token family.

**21. Runner script present and executable**
`test -x ~/projects/agent-hq/tools/container-exec/hqx-run.sh` → command succeeds.
PASS: file exists and is executable.

**22. Base Dockerfile present**
`test -f ~/projects/agent-hq/tools/container-exec/Dockerfile` → command succeeds.
PASS: file exists.

**23. Image build never bakes the token**
`! grep -qE 'CLAUDE_CODE_OAUTH_TOKEN' ~/projects/agent-hq/tools/container-exec/Dockerfile` → command succeeds.
PASS: the token is injected at run, never present as an `ENV`/`ARG` in the Dockerfile.

---

## Source file length (ADR 0016)

**24. No un-allowlisted hq code file exceeds 300 lines**
`bash ~/projects/agent-hq/tools/check-file-length.sh ~/projects/agent-hq` → exits 0
PASS: script exits 0 (no violations outside `.file-length-allowlist`).

---

## Doc length, non-skill (ADR 0021)

**25. No un-allowlisted hq non-skill doc exceeds 500 lines**
`bash ~/projects/agent-hq/tools/check-doc-length.sh ~/projects/agent-hq` → exits 0
PASS: script exits 0 (no violations outside `.doc-length-allowlist`).
NOTE (ADR 0029): the script also lists allowlisted-but-over-cap files by name and line count.
That list is expected forward-only debt and does **not** affect exit status; only the
*blocking* count in the summary line does.
NOTE: check 25 is in the `--fast` subset, so it runs on **every commit** via the pre-commit
hook — not only in the full run. ADR 0029's approval gate applies before a change is
committed, and pre-commit is hq's only automatic trigger (there is no CI). Keep
`check-doc-length.sh` cheap (its line counting is batched) or commits get slow.

---

## Code gate (Rule 10, architecture/hq-code-gate.md)

**27. The pre-push hook is installed in every gated worktree**
`HQ=<checkout> bash tools/code-gate/gate-invariants.sh a` -> exits 0
PASS: `core.hooksPath` is `tools/git-hooks`, and every worktree from `git worktree list --porcelain`
that contains `tools/code-gate/scope.conf` has an executable `tools/git-hooks/pre-push`.
WARN (exit stays 0): a worktree WITHOUT `scope.conf` is a pre-gate branch; the line
`WARN 27 pre-gate branch, pre-push not yet present: <path>` is printed.
NOTE: a pre-gate worktree pushing main is detected by check 29, not 27. A fresh clone has
hooksPath unset and runs no check at all; that residual is not covered.

**28. The code-gate test map is well-formed**
`HQ=<checkout> bash tools/code-gate/gate-invariants.sh b` -> exits 0
PASS: `tools/code-gate/test-map.tsv` exists, rows are two-field, sorted and unique, no source is a bare
`*`/`**`, and every row's source (or glob) and test exist.

**29. Every code commit on origin/main went through the PR gate**
`HQ=<checkout> bash tools/code-gate/gate-invariants.sh c` -> exits 0
PASS: from the first first-parent commit on `origin/main` whose tree has `tools/code-gate/scope.conf`
(never skipping after it), every commit keeps `scope.conf` (else FAIL "gate config removed"), and every
commit touching in-scope files (scope read from its FIRST PARENT) is a 2-parent merge with a
`Code-Gate-PR: #N` trailer, no evil merge, PR N on main with head == `^2` and a clean marker, checked
via `gh`. A `gh` failure FAILs "cannot audit" (fail closed). FAILs when `origin/main` is absent.
A commit with zero parents per `git rev-list --parents` (the repository bootstrap root) is exempt, but only in a non-shallow repository: a shallow clone FAILs "cannot audit", and a failure to read a commit's parents FAILs "cannot audit"; every later first-parent commit is audited as before.

---

## Notes

- Run at Compound time and after any structural change.
- `--fast` (the pre-commit subset) = checks 14, 19, 24, 25. `--code-gate` runs only 27-29.
- Phase-2 addition (retired 2026-10-21, agentmemory removed by owner): the `~/.agentmemory/personal/` and `work/` path check is moot.
