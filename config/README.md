# config/ — global Claude Code configuration (symlink-installed)

Source of truth for the **machine-level** Claude Code config that otherwise lives
unversioned in `~/.claude/`. Authored here, installed by symlink — the same pattern
`skills/` uses (ADR 0009), extended to config by **ADR 0027**.

| File | Installed at | Holds |
|------|--------------|-------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Global Rules 1–7, 9–13 |
| `settings.json` | `~/.claude/settings.json` | model, env, hooks, plugins, TUI prefs |

## Install (fresh clone / second machine)

```sh
ln -sfn ~/projects/agent-hq/config/CLAUDE.md     ~/.claude/CLAUDE.md
ln -sfn ~/projects/agent-hq/config/settings.json ~/.claude/settings.json
```

Same class of one-time setup step as symlinking skills (ADR 0009) and
`git config core.hooksPath tools/git-hooks` (ADR 0007).

## Before you install on a second machine — read this

`settings.json` holds no absolute machine paths today.
For an isolated trial, use `tools/onboarding.md` instead of this global install, which replaces `~/.claude/CLAUDE.md` and `~/.claude/settings.json`.

## Rules

- **Never put a credential in here.** hq has a remote and gets pushed. Anything
  secret belongs in the environment or a git-ignored `*.local.json`, never in
  `config/`. `.gitignore` and invariant check 20 are backstops, not permission.
- `config/CLAUDE.md` is *not* hq's own `CLAUDE.md` — that one stays at the repo
  root and is a different file with a different job.
- Edit these files here and commit; the symlink means the change is live
  immediately, with no copy step and nothing to drift.
