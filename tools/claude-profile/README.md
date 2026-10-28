# cprof — isolated per-shell Claude Code profiles

Design: `architecture/claude-profile.md`. Each profile has its own OAuth token (or, with
`--auth bedrock`, the shell's AWS credentials) and a clean `CLAUDE_CONFIG_DIR`; it applies to one
shell and `cprof off` restores that shell exactly. First-time walkthrough: `tools/onboarding.md`.

## Why use cprof

A profile is a disposable Claude Code identity: its own config dir, workspace, and auth, so a
one-off or risky task never touches your main `~/.claude`. `--tier executor|desk` goes further
and borrows agent-hq's own permission system for that profile — the deny-list and sandbox config
in this repo's `config/settings.json` + `config/tiers/<tier>.json` — so the profile runs under
the same guardrails this repo runs under, not whatever happens to be in your personal
`~/.claude/settings.json`. `cprof link` wires a profile's skills/agents/config to a source
checkout; it now defaults to agent-hq itself (`$HOME/projects/agent-hq`) instead of the old
`$HOME/.claude` default, so a profile can pick up this repo's own skills and agents with one
command — pass an explicit path (e.g. `~/.claude`) to link from your personal setup instead.

## Quickstart

```sh
export CPROF_OWNER=<your-github-account>
cprof new try --tier executor [--auth bedrock]   # drop --auth bedrock to use an OAuth token
cprof link try                                   # links skills/agents/config from agent-hq
cprof use try && cprof doctor && cprof off       # checks links, tier render, and auth vars
cprof launch try                                 # full tiered session (or `cprof use try` + `claude`)
cprof rm try                                     # when done with it (after `cprof off`)
```

See Install and Usage below for the full flag reference, and `tools/onboarding.md` for a
first-time walkthrough with both OAuth and Bedrock credential setup.

## Install (once, by hand)

Add this line to `~/.zshrc` (agents do not edit dotfiles):

    source ~/projects/agent-hq/tools/claude-profile/cprof.zsh

## Usage

    cprof new <name> [--template T] [--auth oauth|bedrock]   # oauth prompts for the token (hidden); bedrock reads none
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

## Auth modes (`--auth`; architecture/claude-profile-02.md Extension 2026-10-26)

Code lives in `cprof-auth.zsh`. `<profile>/auth` holds the mode (mode 600); no file means `oauth`, so existing profiles are unchanged.
An unknown mode fails with `unknown auth mode: '<x>' (oauth|bedrock)`, exit 1, and no profile dir.

With `--auth bedrock`, cprof stores no Anthropic credential of any kind — no API key, no OAuth
token file. Authentication is pure AWS: `use`/`launch` export `CLAUDE_CODE_USE_BEDROCK=1` and let
`AWS_PROFILE`/`AWS_REGION`/the `AWS_*` keys pass through from the shell or `profile.env`. For the
common case of an SSO-backed `credential_process` in `~/.aws/config` (no static keys on disk),
that means re-auth is transparent: when the SSO token expires, the normal browser SSO prompt
fires in whichever shell is driving AWS, and the profile picks up the refreshed credentials on
the next call with no cprof-specific step. `profile.env` is where a Bedrock profile pins model
ids (`ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`) and can carry `AWS_PROFILE`
or `AWS_REGION` as a default for that profile; see the Bedrock walkthrough in
`tools/onboarding.md` for setting these up end to end.

- **oauth** (default): the token file, as above. `use`/`launch` export `CLAUDE_CODE_OAUTH_TOKEN` and unset the higher-precedence auth vars.
- **bedrock**: `new` writes `auth` = `bedrock`, prompts for no token and writes no token file; it ends
  `(auth: bedrock, no token; AWS credentials come from your shell)`.
  - `use` and `launch` unset `ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY`
    and export `CLAUDE_CODE_USE_BEDROCK=1` with the usual `CLAUDE_CONFIG_DIR` and DISABLE vars. `AWS_PROFILE`, `AWS_REGION`, the `AWS_*`
    keys and `AWS_BEARER_TOKEN_BEDROCK` pass through untouched (from the shell or `profile.env`); `launch` strips the Anthropic vars
    even if `profile.env` sets them. `off` restores everything (`CLAUDE_CODE_USE_BEDROCK` is tracked).
  - `use` honours `profile.env`, including auth vars; `launch` strips them. Do not put Anthropic keys in a bedrock profile's `profile.env`;
    `cprof doctor` warns when one is set.
  - No `AWS_REGION`/`AWS_DEFAULT_REGION`: `cprof: WARN: no AWS_REGION/AWS_DEFAULT_REGION in this shell; Claude Code falls back to the AWS profile's region, then us-east-1` (stderr, exit 0).
  - Models: set `ANTHROPIC_MODEL` and all three `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` to Bedrock ids in `profile.env` (ids are
    account-specific; the `us.` inference-profile prefix is for US regions, `eu.`/`apac.`/`global.` elsewhere, see `ANTHROPIC_BEDROCK_REGION_PREFIX`).
  - Tiered render inputs: hq `settings.json`, `tiers/<tier>.json`, `tiers/auth-bedrock.json`, [overlay]. The fragment adds sandbox hosts only
    (Bedrock runtime and control plane, STS, SSO/OIDC/portal); its `<region>` comes from `AWS_REGION` > `AWS_DEFAULT_REGION` (the same
    variables Claude Code reads; there is no cprof-only region override). `<sso_region>` comes from `CPROF_SSO_REGION` (default: the
    region): Claude Code reads the SSO region from the AWS profile, which cprof cannot read, so this override stays. No valid region id:
    `AWS region '<x|unset>' is not a region id; export AWS_REGION (or AWS_DEFAULT_REGION) ...`, exit 1, no profile left.
    The tiered render reads the region from the shell only, not from `profile.env`.
  - `tier.src` gains `region <r>[ sso=<s>]` before `rendered <sha>`; a changed region counts as a stale input (`region`) and re-renders at launch,
    unless `settings.json` was hand-edited (then launch warns `not re-rendered`; run `cprof sync <name> --force`).
  - `launch --dry-run` shows `CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=<r|unset> AWS_PROFILE=<p|unset>`, never a token.
  - `cprof token <name>`: `'<name>' uses --auth bedrock; it has no token`, exit 1. `ls` shows `[bedrock]` instead of `[token]`.
  - `doctor`: the tier row gains `; auth=bedrock`; with a bedrock profile active, `CLAUDE_CODE_USE_BEDROCK=1` is `ok` in the auth-vars section (WARN if not 1).

## Tier verbs (permission-tiers P2; `architecture/permission-tiers.md` Components 3, D2, D3)

Code lives in `cprof-tiers.zsh` (sourced by `cprof.zsh`); needs `jq`. HQ config dir: `${CPROF_HQ_CONFIG:-$HOME/projects/agent-hq/config}`.

    cprof new <name> --tier executor|desk [--overlay <project>] [--force]   # token prompt unchanged (R-2)
    cprof launch <name> [--dry-run] [-- <claude args>]
    cprof sync <name> [--force]
    cprof trust ls | baseline [--note "<text>"]
    cprof link <name> [<source-root>]                                      # code: cprof-link.zsh

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
- `link <name> [<source-root>]` (Extension B-F, dynamic source Extension 2026-10-27; needs `jq`; run it with no claude session
  open on that profile) links a profile to `<source-root>` (never `$CLAUDE_CONFIG_DIR`), default `$HOME/projects/agent-hq`;
  pass `$HOME/.claude` to get the old personal-profile-linking behavior, or any other root. `<source-root>` is canonicalized
  (symlinks resolved, repeated/trailing slashes collapsed) before use. If no `<source-root>` is given and the default does
  not exist, `link` prints an explicit WARN and every entry skips gracefully (exit 0) rather than failing silently. Each
  entry resolves independently: `<source-root>/config/<entry>` first, else `<source-root>/<entry>` when that entry isn't
  found under `config/` — the fallback is evaluated per entry, not once for the whole root, so a root could mix layouts.
  This covers agent-hq's layout (`CLAUDE.md` and `settings.json` live under `config/`; `skills`/`agents` live at the root)
  and a flat root like `$HOME/.claude` (every entry resolves via the second form) with one rule. `skills`, `agents`,
  `plugins` always; `CLAUDE.md` and `settings.json` on plain profiles. On a tiered profile `CLAUDE.md` is skipped
  (`skip: CLAUDE.md (tiered: global rules file stays excluded)`) and the rendered `settings.json` is kept (`kept: ...`). An
  entry missing under `<source-root>` skips gracefully (`skip: <entry> (none in <source-root>)`) — e.g. `plugins` when
  linking from agent-hq, which has no `plugins/` directory. It also merges `.mcpServers` of `<source-root>`'s sibling
  `*.json` file (named after the root's own basename — `$HOME/.claude` → `$HOME/.claude.json`; agent-hq has no such file,
  so this step skips gracefully too: `skip: .mcpServers (no <path>)`) into the profile's `.claude.json` (main wins per key,
  profile-only servers and every other key survive; env/header keys matching `SECRET|TOKEN|KEY|PASSWORD|AUTH`
  are dropped and named as `stripped: <server>.env.<KEY>`, values never printed — but `command`/`args`/`url` fields are
  never scrubbed, so merging from any root other than `$HOME/.claude` prints an explicit WARN immediately before the
  merge). Anything replaced is moved to `<profile>/config-backup-<UTC stamp>/` (700, `backup: <dir>` printed);
  an already-correct link prints `ok:` and a re-run prints `0 linked`, creates no backup and leaves `.claude.json` byte-identical.
  Never touches `token`, `profile.env`, `tier`, `tier.src`, `workspace/`; it does write one new file, `<profile>/link-src`
  (the resolved root, plus the root's git HEAD if it is a git working tree) as an audit trail of what was linked and when.
  Exit 1: usage, invalid name, nonexistent explicit `<source-root>`,
  no such profile, `jq` missing, unreadable/invalid JSON, backup/link/merge failure.
  `doctor` adds a `-- link rows (main-profile links) --` row per profile, comparing each entry against the root recorded
  in that profile's `link-src` (falling back to `$HOME/.claude` if the profile was never linked, or predates this field)
  (`linked`, `other-link`, `file`, `-`, `rendered`; `mcpServers=in-sync(N)|missing:<names>|absent`, always against
  `$HOME/.claude.json`'s key list regardless of root).
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
