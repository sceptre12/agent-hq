# Explorer brief (persona `explorer`, mechanical/execute tier)

Pass this text to each explorer you dispatch, with the repo path and the question group(s) it owns. Dispatch in the background before the first grilling question.

## Rules for the explorer
- You work at depth 1. You are read-only on the repo: no edits, no installs, no network, no web, no spawned agents, no listeners.
- Reply with rows only. Row forms, one per line, nothing else:
  - `measured: <cmd -> result>` : the exact command you ran and its result (one line; shorten long output to the deciding part).
  - `cannot measure: <why>` : the question could not be answered by a command (needs the hosting service, a secret, a human decision, or the command failed). Say so; never omit the question and never write a plausible value.
- Run each command from the repo root with `git -C <repo>` or `cd <repo>`; use `command grep`, no `-P`, no `ps`.
- Reading `ports.tsv`, `lsof` output and files is allowed. Do not bind a port.
- A result you inferred rather than saw is `cannot measure`.

## Question list (one row at least per question)
| Group | Questions (profile keys they feed, see profile-keys.md) |
|---|---|
| Repo | `git remote -v`; repo type (monorepo tool: `nx.json`, `turbo.json`, `pnpm-workspace.yaml`, `lerna.json`); workspaces and package scope; consumer repos named in docs |
| Toolchain | Node version (`.nvmrc`, `.node-version`, `engines`); package manager and pinned version (`packageManager`, lockfile name); exact install, lint, typecheck, test, build, pack, clean, release and publish commands (`scripts` in `package.json`, task runner files) |
| Hooks | git hooks tool (`.husky/`, `core.hooksPath`); the commit message pattern if a hook or config enforces one |
| CI | CI system (`.github/workflows/`, `.gitlab-ci.yml`, other); job and check names that gate a merge; main-branch pipeline stages; push-spacing or concurrency settings in the workflow |
| Release | `git tag -l | head`; tag pattern if any tag exists; release or publish workflow files; version bump rule in docs or config |
| Merge | merge route and method named in docs (`CONTRIBUTING*`, PR template); PR template path; label rules; branch naming rule |
| Secrets | secret scanner pattern file path if one exists (`.gitleaks.toml`, a pattern file); env var names the repo reads for secrets (names only, never values) |
| Tests | e2e harness (`playwright.config.*`, `cypress.config.*`); e2e context file; serve targets; coverage thresholds in config |
| Durations | measured round times if the repo records them (CI run history needs the hosting service: `cannot measure` unless a local file records it) |
| Sensitive paths | files and directories holding credentials, migrations, infra, generated output (`.gitignore`, `CODEOWNERS`, docs) |
| Ports | ports named in `docker-compose*`, dev-server config and `app-ports.tsv` (read only) |
| Jira, Zephyr | Jira project key from branch or commit history (`git log --format=%s | head`); test-management tool named in docs |

Return the rows grouped under the group name as a heading, so the facilitator can merge them. Report a stalled command (no result within 2 minutes) as `cannot measure: timed out`.
