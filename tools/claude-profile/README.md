# cprof — isolated per-shell Claude Code profiles

Design: `architecture/claude-profile.md`. Each profile has its own OAuth token and clean
`CLAUDE_CONFIG_DIR`; it applies to one shell and `cprof off` restores that shell exactly.

## Install (once, by hand)

Add this line to `~/.zshrc` (agents do not edit dotfiles):

    source ~/projects/agent-hq/tools/claude-profile/cprof.zsh

## Usage

    cprof new <name> [--template T]   # prompts for the token (hidden); piping it also works
    cprof use <name>                  # this shell only; cd's into the profile workspace
    cprof off                         # restore env, prompt, and directory
    cprof excludes <name>             # re-apply claudeMdExcludes to an existing profile
    cprof ls | current | token <name> | rm <name> | doctor [--no-claude] | help

Profiles live in `${CPROF_ROOT:-$HOME/claude-profiles}`:
`<name>/{config,workspace,token,profile.env}` plus optional `_templates/<t>/` seeds copied into
`config/`. `profile.env` is sourced on `use` in an isolated scope; on `off`, names it adds are unset and names it changes (exported or not) are restored. `use` refuses an empty or unreadable `token` file. `new` and `use` mark first-run onboarding complete (`hasCompletedOnboarding`) in the profile's own `.claude.json`. Get a token
with `claude setup-token`. Never pass a token in argv.

`cprof current` prints the active name, or nothing. The `[cprof:<name>]` prompt prefix is cosmetic
and Warp may ignore it; trust `cprof current` and `${+CLAUDE_CONFIG_DIR}`.

## Tier verbs (permission-tiers P2; `architecture/permission-tiers.md` Components 3, D2, D3)

Code lives in `cprof-tiers.zsh` (sourced by `cprof.zsh`); needs `jq`. HQ config dir: `${CPROF_HQ_CONFIG:-$HOME/projects/agent-hq/config}`.

    cprof new <name> --tier executor|desk [--overlay <project>] [--force]   # token prompt unchanged (R-2)
    cprof launch <name> [--dry-run] [-- <claude args>]
    cprof sync <name> [--force]
    cprof trust ls | baseline [--note "<text>"]
    cprof link <name>                                                       # code: cprof-link.zsh

- `--tier executor` renders `<owner>` from `CPROF_OWNER` (a GitHub account name, `[A-Za-z0-9-]`); it fails closed if `CPROF_OWNER` is unset, empty or malformed.
- `new --tier` renders `config/settings.json` = hq `settings.json` + `tiers/<tier>.json` + optional
  `tiers/overlays/<project>.json` + `claudeMdExcludes`. Scalars: later wins; `permissions.allow` and `hooks`: hq only;
  `permissions.deny`, `sandbox.network.allowedDomains`, `sandbox.filesystem.allowWrite`: set-union; `_tier/_source/_overlay/_note` dropped.
  Writes `tier` (one word), `tier.src` (`<sha256> <path>` per input, then `rendered <sha256>`), and `workspace/CLAUDE.md` from the tier template.
- `launch` reproduces the `use` environment in a subshell, `cd`s to `workspace/`, and execs `claude` with `--dangerously-skip-permissions`
  (executor) or `--permission-mode auto` (desk) plus `--settings '{"crossSessionInbound":"accept"}'`. Exit 2 if there is no `tier` file or
  `-- args` carry the other tier's flag. `--dry-run` prints the exec line with the token redacted.
  Unlike `use`, launch deliberately strips `ANTHROPIC_API_KEY`/`CLAUDE_CODE_USE_*`/`CLAUDE_CODE_DISABLE_AUTO_MEMORY` set by `profile.env` (it unsets the higher-precedence auth vars and exports the launcher vars after sourcing it); `use` honours them.
- `launch` also checks the render is current (architecture/claude-profile.md Extension G): it compares `tier.src` input hashes with the current hq
  `settings.json`, `tiers/<tier>.json` and overlay. Fresh: silent. No `tier.src`: `cprof: WARN '<n>' has no tier.src; staleness not checked`, launches.
  Stale and not hand-edited: `settings.json.bak-<stamp>` (600), re-render, `cprof: '<n>' render was stale (<inputs>); re-rendered (backup: <path>)`, launches.
  Stale and hand-edited: sync's exit-3 text plus `-- not re-rendered; launching on the current file`, no write, launches (never `--force`).
  Re-render fails: `re-render failed; not launching (a stale executor could be missing a deny)`, exit 1. `--dry-run` + stale: writes nothing, prints `dry-run: render stale (<inputs>); would re-render`.
- `link <name>` (Extension B-F; needs `jq`; run it with no claude session open on that profile) links a profile to the main profile `$HOME/.claude` (never `$CLAUDE_CONFIG_DIR`):
  `skills`, `agents`, `plugins` always; `CLAUDE.md` and `settings.json` on plain profiles. On a tiered profile `CLAUDE.md` is skipped
  (`skip: CLAUDE.md (tiered: global rules file stays excluded)`) and the rendered `settings.json` is kept (`kept: ...`). It also merges `.mcpServers` of `$HOME/.claude.json`
  into the profile's `.claude.json` (main wins per key, profile-only servers and every other key survive; env/header keys matching `SECRET|TOKEN|KEY|PASSWORD|AUTH`
  are dropped and named as `stripped: <server>.env.<KEY>`, values never printed). Anything replaced is moved to `<profile>/config-backup-<UTC stamp>/` (700, `backup: <dir>` printed);
  an already-correct link prints `ok:` and a re-run prints `0 linked`, creates no backup and leaves `.claude.json` byte-identical.
  Never touches `token`, `profile.env`, `tier`, `tier.src`, `workspace/`. Exit 1: usage, invalid name, no such profile, `jq` missing, unreadable/invalid JSON, backup/link/merge failure.
  `doctor` adds a `-- link rows (main-profile links) --` row per profile (`linked`, `other-link`, `file`, `-`, `rendered`; `mcpServers=in-sync(N)|missing:<names>|absent`).
- `sync` re-renders using the tier from the `tier` file and the overlay from `tier.src`; exit 3 if `settings.json` was hand-edited since the last render
  (hand-edited since last render: `--force` discards ALL hand edits except claudeMdExcludes; a `config/settings.json.bak-<UTC stamp>` backup, mode 600, is written first and printed as `backup: <path>`).
  Existing `claudeMdExcludes` are kept; `skipDangerousModePermissionPrompt` is `true` for executor (fragment wins) and omitted for desk unless already present.
- `doctor` adds a row per tiered profile (render hash match/MISMATCH; executor: deny >= 40, `sandbox.enabled` and `skipDangerousModePermissionPrompt=true`, else WARN; without `jq` a WARN line says tier rows were skipped).
- `trust ls` pretty-prints `_trust/ledger.jsonl` (control characters in fields become `?`; non-JSON lines print `UNPARSEABLE line <n>`); `trust baseline` appends the single BASELINE row (exit 4 if one exists); see `tools/trust/README.md`.

## Known limits

- **Walk-up CLAUDE.md.** Claude Code loads CLAUDE.md by walking up from the cwd, and
  `CLAUDE_CONFIG_DIR` does not stop that: any cwd under `$HOME` loads `$HOME/.claude/CLAUDE.md`
  (measured 2026-10-01). `cprof new` / `cprof excludes <name>` therefore write a per-profile
  `claudeMdExcludes` into `config/settings.json` covering `~/.claude/CLAUDE.md`, `CLAUDE.local.md`,
  `rules/**`, `~/projects/CLAUDE.md`, `CLAUDE.local.md`, `~/CLAUDE.md`, `~/CLAUDE.local.md` and the resolved symlink target. A repo's own
  CLAUDE.md still loads. `cprof doctor` marks ancestor files EXCLUDED or WARN and prints the
  `/context` Memory Files rows, which are authoritative.
- **`.claude.json` relocates.** It lives under `CLAUDE_CONFIG_DIR` (verified 2026-10-01), so each profile has its own.
- **Token-only auth.** `CLAUDE_CODE_OAUTH_TOKEN` gives no Remote Control and no claude.ai
  connectors; local MCP works. `--bare` ignores the token, so do not use it.
- `doctor` makes one real API call (`claude -p hi`) to read the init event; `--no-claude` skips it.
