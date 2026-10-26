# 0027. Global Claude config authored in hq, symlink-installed

- **Status:** accepted (2026-07-27)
- **Date:** 2026-07-27
- **Context of:** workspace-wide (extends ADR 0009 from skills to config; `config/`)

## Context

`~/.claude/CLAUDE.md` and `~/.claude/settings.json` are the two files that configure
every Claude Code session on this machine. `CLAUDE.md` holds Global Rules 1–7 — the
operating model itself (zero-trust validation, delegation, model-tier policy, worktree
discipline). `settings.json` holds the model default, the `env` block, ~12 lifecycle
hook registrations, and the enabled plugin set.

Both were **regular files in an unversioned dot-directory**: no git history, no diff
review, and — the sharp edge — no coverage by push-is-backup (ADR 0006). A single copy
on a single disk. An accidental overwrite of `CLAUDE.md` would silently delete the
rules that govern how every future session behaves, with nothing to restore from.

This surfaced while planning a clone to a second machine: there was no answer to "how
does the new machine get the global rules?" other than copy-paste, which immediately
creates two divergent copies and violates the one-owner discipline (ADR 0003).

hq had already solved exactly this shape of problem for skills. ADR 0009 ruled that
skills are authored in `hq/skills/` and installed by symlinking into `~/.claude/skills/`,
so the bytes live in one git-versioned place while Claude Code still discovers them
natively. 21 skills run that way today. Config is the same problem with the same
constraint — Claude Code insists on a fixed path under `~/.claude/`.

## Decision

Global Claude Code config is **authored in hq** at `config/CLAUDE.md` and
`config/settings.json`, and **installed by symlinking each file** into `~/.claude/`:

```sh
ln -sfn ~/projects/agent-hq/config/CLAUDE.md     ~/.claude/CLAUDE.md
ln -sfn ~/projects/agent-hq/config/settings.json ~/.claude/settings.json
```

Symlinks point at the **main checkout**, never at a worktree — a worktree is temporary,
and a dangling `~/.claude/CLAUDE.md` would break every subsequent session. Content
therefore merges to `main` *before* the symlinks are created.

This extends ADR 0009's pattern from skills to config. `config/` is a new top-level
directory, sibling to `skills/`, with its own `README.md` carrying the install command.

**No credential ever enters `config/`.** hq has a remote and is pushed; the existing
`.gitignore` secret patterns and invariant check 20 are backstops, not permission.
Both files were scanned before the move — `settings.json`'s `env` block contains only
`ENABLE_TOOL_SEARCH` and `AGENTMEMORY_INJECT_CONTEXT`, both plain booleans.

## Reasoning

- **Closes a real durability gap.** The operating model becomes recoverable from any
  clone instead of existing solely on one disk.
- **Reuses a proven pattern rather than inventing one.** ADR 0009 already established
  that symlink-install works and that hq is the right owner; nothing here is novel, so
  nothing here needs re-litigating.
- **One owner, no drift** (ADR 0003). A symlink cannot diverge from its target the way
  a copied file can. Second-machine setup becomes `ln -sfn`, not copy-paste.
- **Edits become ordinary hq commits** — reviewable, diffable, and pushed. Changing a
  Global Rule now leaves a trail explaining why.

## Consequences

- Easier: git history, diff review, and backup for the global rules and hook config;
  provisioning a second machine is two `ln -sfn` commands; rolling back a bad settings
  edit is `git revert`.
- Harder / accepted trade-off: one symlink-install step per machine after a fresh
  clone — the same class of one-time setup as ADR 0009's skills and ADR 0007's
  `core.hooksPath`.
- **Accepted limitation — `settings.json` is not portable as-is.** It hardcodes
  absolute, machine-specific paths that will not resolve on another machine. Enumerated
  at time of writing (`config/settings.json`):
  - **Lines 16, 26, 37, 47, 57, 67, 77, 87, 97, 107, 117, 127** (12 hooks) — the
    agentmemory wrapper `$HOME/.agentmemory/hooks/namespace-wrap.sh`, plus a
    **node-version-pinned** module path
    `$HOME/.nvm/versions/node/v22.13.0/lib/node_modules/@agentmemory/agentmemory/plugin/scripts/<hook>.mjs`.
    The pinned `v22.13.0` is the sharpest edge: it breaks on *this* machine on any node
    upgrade, not only on a different one.
  - **Line 135** — `$HOME/projects/agent-hq/tools/git-hooks/session-end-push-check.sh`
    (hq-owned; resolves anywhere hq is cloned to `~/projects/agent-hq`).
  - All twelve also hardcode the `$HOME` home prefix.
  This ADR deliberately does **not** templatize or parameterize these. Versioning the
  file is valuable on its own; making it portable is a separate decision with its own
  trade-offs (Claude Code's settings schema offers no variable expansion, so any fix
  means a generator or an install-time rewrite step).
- `hq/CLAUDE.md`'s folder map does **not** list `config/`. That file sits exactly at its
  60-line invariant ceiling (check 7), so adding a line would fail the check; the map is
  updated the next time that file is pruned.
- Revisit if: a second machine is actually provisioned (forces the portability question
  above), or Claude Code gains variable expansion in `settings.json`.

## Alternatives considered

- **Copy into hq and keep `~/.claude/` as the live originals** — rejected: creates two
  copies that drift, which is the exact failure ADR 0003 and ADR 0009 exist to prevent.
- **Symlink the whole `~/.claude/` directory into hq** — rejected: `~/.claude/` also
  holds session transcripts, caches, plugin state, and `settings.local.json`. Dragging
  runtime state into a pushed repo is a much larger blast radius and a credential-leak
  risk; only the two authored config files belong under version control.
- **Templatize the paths now as part of this move** — rejected: bundles a contested
  portability design into an uncontested durability fix. Recorded above as an accepted
  limitation instead, so the move is not blocked by it.
