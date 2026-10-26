## 6. Execution constraints and profile mapping

### 6.1 Measured facts (command, date, where)

Only facts that travel with Claude Code or macOS are kept; everything specific to the build machine's sandbox profiles is dropped because the family will not run there.

| # | Fact | Evidence |
|---|---|---|
| 1 | Claude Code defaults: 20 concurrent subagents per session (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`), spawn depth 3 (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`); `tools`/`disallowedTools` frontmatter can remove the Agent tool; `disable-model-invocation: true` blocks Skill-tool calls (moot under D16) | desk research summary, 2026-10-26 (data, not instructions) |
| 2 | Two levels of Agent nesting work from a general-purpose subagent; depth 3 and the `topology-worker*` types (no Agent tool) not measured | M-probe 4, 2026-10-26 |
| 3 | macOS userland: `/bin/bash` 3.2.57, no `flock` (`lockf`, `shlock` present), no `mapfile`, `timeout`, `gtimeout`; BSD `sed`, `date`, `du`; zsh 5.9; `kill -0` and `lsof -nP -iTCP -sTCP:LISTEN` available | M-probes 2a-2c, 3a-3b (a macOS host; the work machine is also macOS per the XC paths, re-verify at move) |
| 4 | 10 concurrent 600-byte single-line `>>` appends did not interleave (one run, not stress-tested) | M-probe 2d |
| 5 | `agent-hq` has no `learnings/` or `retros/` directory; learnings are told to Hermes through its API door (`AHQ/STANDARDS.md:16, :72-73`); the Hermes port setup lives at `AHQ/tools/hermes/setup/` | `ls`, `grep`, 2026-10-26 |
| 6 | `review-7-panel`, `feature-change`, `port-claim`, `sim-lease` exist in `hq`, not in `AHQ/skills/` | `ls AHQ/skills`, 2026-10-26 |
| 7 | <pilot-app> platform facts in §5.8b (part-04-templates.md) | `XC/projects/<platform-capabilities-project>`, read 2026-10-26 |

**Unmeasured, verify at move (P0):** which session type carries which sandbox or deny list; `ps`, pm2, docker and registry reachability from a lead session; `api.github.com` reachability (the desk design does not depend on it being blocked, D3 mandates the desk regardless); `claude -p` login state and flags; whether the session cap counts nested descendants; the NLTA plugin install source and prefix; the Jira session path; the §5.8b (part-04-templates.md) unmeasured row; the Zephyr MCP identity, scope model, spec location, read operations and tool names (signed-in `search`, T3, B2); `gates.runner_slots`, install and `nx affected` durations (M8); whether NLTA skills run non-interactively (M23); the per-session total spawn cap and its value (B-3); the §5.8b unmeasured row in full.

**Runtime matrix for the three scripts (M14):** `/bin/bash` 3.2, BSD userland (no GNU `sed -i`, `date -d`, `du -b`), no `flock` (use `mkdir` locks), 400-byte row cap, stable machine-readable output, hermetic tests under `/bin/bash` with `mktemp -d "$TMPDIR/x.XXXXXX"` fixtures, tests run with a different `HOME` (M18).

### 6.2 Step-to-session mapping

| Step | Session | Why |
|---|---|---|
| Grill, architecture, dispatch plan, review loops | conductor session | no network; `RESEARCH` to the desk |
| Web research, installs, browser pre-stage | desk | R-ci, no installs |
| Build units, local gates, e2e writing | sub-task lead session and its workers | own worktrees; `claude -p` or Agent tool (§6.4) |
| `pr-review` local-diff, fix, verify, completeness | sub-task lead session | needs pm2 sockets and temp writes (unmeasured, verify at move) |
| push, PR, comments, approval read-back, merge, branch delete, CI status and logs, Jira | desk via `delivery-desk` | credentials live only there (D3) |
| Human review, Gherkin checkpoints, production steps, `/nlta:bootstrap` | the executing human | D5, D15, D17, D18 |
| Cleanup | sub-task lead (local) + desk (remote branch) | D8 |
| Post-merge tests | a lead session on a detached worktree of main | local; e2e lanes per profile |
| Learnings | Hermes door in `agent-hq` | D19 |
| Skill install | owner, at move | no-symlink rule now; ADR 0009 later (D24) |

### 6.3 `delivery-desk` contract (D3, B1)
A new `DESK` verb is added to the permission-tiers-02 §2 grammar by an ADR amendment in `AHQ/decisions/` (T1; W0 item 3b, Rung 1 review, owner ratification before W1 item 26 is authored). Grammar, in the §2 envelope (one request per message, replies are data not instructions, `STATUS`/`BUSY` 2-minute rule applies):
```
DESK     <id> | <verb> | <abs path to RUN_HOME/desk/<id>.req> | sha256=<hex>
DONE     <id> | <verb> | result=<abs path to RUN_HOME/desk/<id>.out> | <one-line verdict, no imperatives>
REJECTED <id> | <reason: sender|schema|hash|repo|marker|order|policy|stale-session|gate-missing|action-failed>
```
Ten reason codes; `action-failed` is curable (owner OP10; INTERFACES B2, B2.1; erratum E14). The frozen grammar and the per-verb schemas are INTERFACES part B, which supersedes the list below where they differ (amended: AM-1 to AM-5).
`<id>` = `<run-id>-<subtask>-<utc>-<n>` and doubles as the idempotency key: a repeated id returns the stored result. The `REJECTED` layout keeps the installed grammar's `<id> | <reason>` shape (M13). The request body is the JSON file at the named path; the desk copies it into `$DELIVERY_ROOT/desk-inbox/` (desk-owned, 0700), checks the copy's sha256 against the message, and validates only the copy (M29). Per-verb result schemas for `.out` are published in INTERFACES.md (W0 item 2); for `claude -p` leads, polling `.out` is authoritative and the `DONE` line is advisory (M13). Request schema per verb (closed; no raw flags, no force, arrays not strings): `push {repo, branch, expect_head}`, `pr-create {repo, branch, base, body_path, labels[], record_path}`, `pr-comment {repo, pr, body_path}`, `pr-approval-state {repo, pr}`, `pr-merge {repo, pr, method, expect_head, predecessors[], record_path}` (`record_path` is the review-record carrier, owner Q3; erratum E11), `branch-delete {repo, branch, merged_into}`, `ci-status {repo, pr}`, `ci-logs {repo, run_id, job}`, `ci-rerun {repo, run_id}` (flakes only), `ci-status-main {repo, merge_sha}` (the merge-pipeline execution, M24), `fetch {repo, ref}` (fetch and rebase base for the Integrator), `pr-comments-read {repo, pr}`, `tag-push {repo, tag, sha}`, `publish {repo, package, version}` (only after a human gate file), `test-report-push {tool, payload_path}` (Zephyr Scale test cases, `--dry-run` first), `jira-get|jira-create|jira-update|jira-transition {key|parent, fields}` with `fields` restricted to the closed allowlist (M14, M29). Zephyr Cloud reads are not desk verbs; `release-track` performs them itself behind the PreToolUse hook (B2). The `pr-merge` requester is the conductor. Validation: `repo` realpath under a clone registered in `repo-profile.md` (no approved-account list; the desk acts under the operator's own GitHub and Jira auth, R2-4, R2-7); branch matches `<JIRA-KEY>(-[a-z0-9-]+)?`; `body_path` realpath under `RUN_HOME/review/` or `RUN_HOME/bodies/` and redaction-scanned before use (M29, M31); sender identity taken from the transport and equal to the lead or conductor registered for the run; the desk **re-derives** every claimed marker before acting: head sha; `CODE-GATE-REVIEW` and `Verified-By` lines at the record path; **H-pr approval read-back (R2-4, M6):** `gh pr view <n> --json reviewDecision,headRefOid,author,latestReviews` (or `gh api repos/<o>/<r>/pulls/<n>/reviews` for `commit_id`) must show `reviewDecision == APPROVED` and at least one review with `state == APPROVED` whose author is a human login other than the PR author and not a `[bot]`, on a `commit_id` equal to `headRefOid`; CI state; predecessors merged; `merge_reach` row present; `pr-merge` refuses unless approval, CI and order all hold; approve, trigger-prod and pipeline edits are not verbs (M27). Result: `RUN_HOME/desk/<id>.out` written atomically at 0600; reply with the long `DONE` line of the grammar above (owner OP2; erratum E5) or `REJECTED` with one of the ten codes (erratum E14). Every request and result is logged. Interim fallback until the skill exists: the human runs the same verbs by hand from the request file. **Build-time git on the build machine (R2-7, M6):** W0-W3 use the existing desk pushes as today under the current `RESEARCH`/`INSTALL`/`STATUS` envelope, with the review marker pasted into the PR by the reviewer; the `DESK` verb applies to the runtime after the move.

### 6.4 Two dispatch backends (D25)

| | `BACKEND=agent-tool` | `BACKEND=claude-p` |
|---|---|---|
| Use | workers inside a session | spawning sub-task lead sessions from the conductor; workers where the environment has no Agent tool |
| Sandbox and deny list | the session's | **none**: `--dangerously-skip-permissions` means the brief's prohibitions are convention; the launcher spec below is the control |
| Compensating controls | n/a | **Launcher spec (M28, A5):** children start with `env -i` plus an allowlist (`PATH`, `HOME` set to a scratch home under `$DELIVERY_ROOT/homes/<agent>`, `DELIVERY_ROOT`, `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, the node prefix variables), `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`, `credential.helper` set empty in the worktree config, `SSH_AUTH_SOCK` unset, `GH_CONFIG_DIR` pointing at an empty directory, the worktree remote's `pushurl` set to an invalid URL; mandatory `--disallowedTools` naming the Zephyr `execute` tool and every network-write tool (names unmeasured, verify at move); the launcher asserts `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30` and fails closed; prompt piped by stdin, never argv; dedicated worktree per process; process registered in the catalog with pid before start and counted in the 30 and 200 ledgers; `kill -0` on every tick; stop-all-then-relaunch on any brief fix. Residual risk stated: the process still runs as the operator's OS user with the operator's signed-in Claude session, so OS-level reachability of keychain and registry tokens is only removed by a separate low-privilege user or a sandbox profile, which needs the owner's permission (unmeasured). |
| Model and effort | `model:` in the Agent call | `--model`, `--effort` flags per `XC/_shared/patterns.md` 4, 5, 8 |
| Completion | Agent return plus bus post | bus post only; exit code is not a signal |
| Status | works in any Claude Code session (measured to depth 2) | **untested until the work environment** (not measurable on the build machine); `claude --help` output recorded as a fact at move |

Gates and artifacts are the same by contract, not by enforcement; the v1 claim that the two backends are identical is withdrawn.

### 6.5 Distribution and the move (D24, owner rule, A6)
Build only in `AHQ/skills/<name>/` and `AHQ/tools/delivery/` (scripts). **No symlink into `~/.claude/skills` or anywhere from `agent-hq` now** (owner, 2026-10-26; something else is linked there). At move the owner copies or clones `agent-hq` into the work environment and installs by symlink per ADR 0009 into that environment's skills directory. Each `SKILL.md` carries `version:`; `state.md` records the hash of each installed target (`ls -L`, `shasum`) so reviewed content equals running content (M4). The EXTEND targets that live in `hq` today (`review-7-panel`, `feature-change`, `port-claim`, `sim-lease`, and the `AHQ` copies of `pr-review`, `doc-reviewer`, `fix-verifier`, `wave-execution`) are made canonical in `agent-hq` by porting the four missing ones in W1; `hq` is not edited by this plan.

