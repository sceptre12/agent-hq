# claude-profile (`cprof`) — design record

One-line summary: a sourceable zsh function, `cprof`, that scopes a single terminal shell to an
isolated Claude Code profile (own OAuth token, clean config dir, no auto-memory) and restores the
shell exactly on `cprof off`. Script lives in hq; profiles live outside it.

Status: ratified 2026-10-01 (owner approval via ExitPlanMode; Fable T6 ratification with
amendments, folded in below). Source plan: `~/.claude/plans/sunny-leaping-rocket.md`.
Extension 2026-10-21 (`cprof link` + tiered launch re-render): **RATIFIED 2026-10-21 — Fable T6/T5 RATIFY-WITH-EDITS (edits applied 23e329b2); owner ratified, verbatim: "1" (option 1: as written)** — see the last section; dispatch plan
`plans/cprof-link.md`. Everything above that section is the ratified 2026-10-01 design, unchanged.

## What This Is

The owner runs several Claude Code sessions that each need a separate OAuth token and a config with
no inherited `~/.claude` settings, CLAUDE.md, skills, plugins, hooks, MCP or auto-memory, and nothing
pulled from hq main. A profile is scoped to one shell and can be entered and left repeatedly.

## Owner rulings (2026-10-01, AskUserQuestion)

Blank start plus an optional template; token pasted once and stored in a chmod-600 file inside the
profile; script in hq, profiles outside it; shell function with `use` / `off`.

## Verified facts this design rests on

Sources: docs-research agent (code.claude.com/docs) and local inventory agent, 2026-10-01.

- `CLAUDE_CONFIG_DIR` relocates settings, CLAUDE.md, skills, plugins, sessions, auto-memory, and
  keys the macOS Keychain entry per directory.
- `~/.claude.json` relocates under `CLAUDE_CONFIG_DIR` (measured 2026-10-01; see Hermes skill `learnings/claude-profile-isolation` (was learnings/claude-profile-isolation.md)).
- Auth precedence: `ANTHROPIC_AUTH_TOKEN` > `ANTHROPIC_API_KEY` > `apiKeyHelper` >
  `CLAUDE_CODE_OAUTH_TOKEN` > profile > `/login` keychain. Higher-ranked vars must be unset.
- `CLAUDE_CODE_OAUTH_TOKEN` works interactively. Limits: no Remote Control, no claude.ai
  connectors; local MCP still works. `--bare` ignores it, so `--bare` is not used.
- `~/.zshrc:15` exports the main token globally; a profile overrides it and `off` restores it.
- `~/.claude/CLAUDE.md` and `settings.json` symlink into `hq/config/`; a different
  `CLAUDE_CONFIG_DIR` bypasses both.
- CLAUDE.md is also loaded by walking up from the cwd, and `CLAUDE_CONFIG_DIR` does not stop that.
  MEASURED (step 3 verifier, orchestrator, Fable T3, 2026-10-01): any cwd under `$HOME` loads
  `$HOME/.claude/CLAUDE.md` as a Project memory file even with `CLAUDE_CONFIG_DIR` set elsewhere. The
  earlier belief that a workspace outside `~/projects` makes the walk-up find nothing is FALSE.
- No managed settings exist (`/Library/Application Support/ClaudeCode` absent). Claude Code 2.1.287.

## Components

- `tools/claude-profile/cprof.zsh` — the function; `cprof-checks.zsh` (sourced by it) holds the
  claudeMdExcludes helpers and doctor, split to stay under the 300-line file limit.
- `tools/claude-profile/README.md` — usage, install line, known limits.
- Profile root `${CPROF_ROOT:-$HOME/claude-profiles}` (override exists so tests use a temp dir):
  `_templates/<t>/` optional seeds; `<name>/config/` (= `CLAUDE_CONFIG_DIR`), `<name>/workspace/`
  (default cwd), `<name>/token` (mode 600), `<name>/profile.env` (optional).
  Parent directories are mode 700 (created under `umask 077`).

## Interfaces (subcommands)

- `new <name> [--template T]` — layout, optional template copy into `config/`, token read from
  stdin. Sets `hasCompletedOnboarding: true` in the profile's `config/.claude.json` so interactive
  claude skips the first-run login screen (shipped in PR #3; owner confirmed 2026-10-02).
- `use <name>` — current shell only. Switching A to B restores first, then applies B.
- `off` — restores the shell, prompt and original directory.
- `excludes <name>` (re-apply claudeMdExcludes), `ls`, `current` (prints nothing when inactive), `token <name>` (rotate), `rm <name>` (shows what
  will be deleted, asks to confirm, refuses the active profile), `doctor`, `help`.
- `use` exports `CLAUDE_CONFIG_DIR`, `CLAUDE_CODE_OAUTH_TOKEN`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`,
  `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1`; unsets `ANTHROPIC_AUTH_TOKEN`,
  `ANTHROPIC_API_KEY`, `CLAUDE_CODE_USE_{BEDROCK,VERTEX,FOUNDRY}`; sources `profile.env`; prefixes
  the prompt; `cd`s into `workspace/`.

## Settled decisions (Fable T6 amendments, 2026-10-01, binding)

1. **Diff-based off.** Snapshot the exported-name set before `use` and again after sourcing
   `profile.env`; `off` unsets every added name and restores every changed one. Covers the
   DISABLE_* vars and anything `profile.env` exports. Implementation note: the exported-name set is
   read from zsh's `parameters` (scalar + export) rather than `env | cut`, which mis-splits
   multi-line values; semantics are the same. `OLDPWD`, `_`, `SHLVL`, `PWD` are excluded.
2. **Set vs. unset.** `${+VAR}` plus the value (and exported-ness) held in non-exported
   `typeset -gA` arrays, so they never reach claude's env; restore with export or unset to match.
3. **Token write.** `read -rs`, strip CR/whitespace, `( umask 077; print -r -- "$tok" > token )`
   after removing any old file. No echo, no create-then-chmod, never in argv.
4. **Verification 1** excludes `OLDPWD` and `_` from the env hash (or hashes `typeset -p` of the
   tracked names plus the exported-name set).
5. **Verifications 2 and 3 test by project key, not mtime.** `jq '.projects|keys' ~/.claude.json`
   must NOT gain the workspace path; `~/.claude/projects/<workspace-slug>/` must NOT appear;
   `$CLAUDE_CONFIG_DIR/.claude.json` and `$CLAUDE_CONFIG_DIR/projects/<workspace-slug>/` SHOULD.
6. **Verification 4 positive control.** Capture the init event under the main config first and show
   it lists the user's MCP servers and plugins, before an empty list under the profile counts.
7. **Doctor walk-up** (superseded in part by 9-10). Enumerate `CLAUDE.md`, `CLAUDE.local.md`, `.claude/CLAUDE.md` in every
   ancestor from cwd to `/`; for cwd also `.claude/settings*.json`, `.claude/rules/`, `.mcp.json`,
   `AGENTS.md`. Replaces the "under ~/projects" test.
8. **Prompt prefix is cosmetic.** Warp may ignore PS1; `cprof current` and `${+CLAUDE_CONFIG_DIR}`
   are authoritative.
9. **Walk-up fix: per-profile `claudeMdExcludes` (Fable T2, 2026-10-01, DECISION b).** `cprof new`
   (and `cprof excludes <name>` for existing profiles) ensures `config/settings.json` has
   `claudeMdExcludes` containing `$HOME/.claude/CLAUDE.md`, `$HOME/.claude/CLAUDE.local.md`,
   `$HOME/.claude/rules/**`, `$HOME/projects/CLAUDE.md`, `$HOME/projects/CLAUDE.local.md`, plus
   `readlink -f ~/.claude/CLAUDE.md` when it is a link. Merged into any existing file with jq as a
   unique union (fails clearly rather than clobbering if jq is missing or the JSON is invalid);
   written under `umask 077`. Measured: zero memory rows in the workspace; a repo under `~/projects`
   loads only its own CLAUDE.md; a template's CLAUDE.md still loads.
10. **Doctor.** Ancestor hits are annotated `EXCLUDED` vs `WARN loaded`; doctor then prints the
   `### Memory Files` rows from `claude -p "/context" --no-session-persistence < /dev/null` (local,
   no model call) and WARNs on any row under neither `$CLAUDE_CONFIG_DIR` nor `$PWD`. That table is
   authoritative. The init-event check uses `jq -c 'select(.subtype=="init")'` with stdin closed.

Deliberately not done: `CLAUDE_CODE_DISABLE_CLAUDE_MDS` (would kill a template's own CLAUDE.md);
forced `--setting-sources` (breaks project repos opened inside a profile).

## Constraints

- Install is a manual one-line `source` in `~/.zshrc`; agent dotfile edits trip the classifier.
- `~/projects/agent-hq` main checkout is where the sourced path points; work happens in worktrees.
- Doctor makes one real API call (`claude -p hi`) for the init event; `--no-claude` skips claude.

## Dispatch plan (Rules 4-7)

Parallelization (Rule 7): of 5 tasks, 0 safe to parallelize (each depends on the previous; steps 2-3
share a worktree and file); assessed against a ~30-agent ceiling; kept serial.

1. Fable ratification (done 2026-10-01, AMENDMENTS folded in).
2. Sonnet: write this doc, `cprof.zsh`, README in worktree `wt/claude-profile`; gates pass.
3. Separate Sonnet instance: empirical test with throwaway profile and dummy token; measures every
   Verification item above (amended).
4. Haiku: merge to hq main, push, remove worktree, keep branch.
5. Owner: add the `source` line, `cprof new <real>`, `cprof use`, `cprof doctor`.

## Verification (step 3, as amended)

1. Env round-trip hash identical across `use` / `off` (values hashed, token never printed).
2. `~/.claude.json` isolation by project key (amendment 5).
3. Main `~/.claude` untouched by project key (amendment 5).
4. Clean load with positive control (amendment 6); OWNER-RUN if a dummy token blocks the init event.
5. Shell scoping: a second terminal shows no `CLAUDE_CONFIG_DIR` and its original token.
6. Walk-up: `cd ~/projects/agent-hq && cprof doctor` shows hq `CLAUDE.md` as `WARN loaded` (its own repo file) and the user-level ones `EXCLUDED`.

## Extension (2026-10-21): `cprof link` + tiered launch re-render

**RATIFIED 2026-10-21 — Fable T6/T5 RATIFY-WITH-EDITS (edits applied 23e329b2); owner ratified, verbatim: "1" (option 1: as written)** (Note:
`decisions/0014-model-tier-operating-policy.md:62` keeps a revision of an existing record at Opus
unless another trigger fires; T5, `:61`, "settings/permissions", applies to part B.)

Owner ask (verbatim, 2026-10-21): "something that i tend to need to do is copy over the claude
settings from my main profile over into the newly created profiles basically everything excluding
the auth part since I am going to be using a new token with the profile.. Since i do that often
enough is there a skill that a new profile could use or soemthing we can add as apart of cprof to
make that process automatic. Typically i want the symlinkage as well so things remain up to date"
→ "yeah I do still want this for non tiered profiles" → on tiered profiles self-updating at launch
while keeping the deny list and sandbox: "Yeah i like the self updating tiered profile while
keeping deny list and sandbox".

This reverses the 2026-10-01 "no inherited `~/.claude`" default (What This Is) **per profile, only
when the owner runs `cprof link <name>`**. Unlinked profiles behave exactly as today.
Prior art (DATA, not a rule): Hermes skill `brain/cprof-hq-linked-profile` (status proposed,
unverified), the manual procedure done 3 times; differences are listed under Non-goals.

### A. Components

- **New `tools/claude-profile/cprof-link.zsh`** (~120 lines), sourced by `cprof.zsh` next to
  `cprof-checks.zsh` / `cprof-tiers.zsh` (`cprof.zsh:24-26`; keeps every file under the ADR 0016
  ~300 default, `cprof.zsh` is 271 lines). Holds `_cprof_link` and `_cprof_doctor_links`.
- `cprof.zsh`: one `source` line (after `:26`), `link) _cprof_link "$@" ;;` in the dispatcher
  (`:255-270`), two help lines (`:229-247`).
- `cprof-tiers.zsh`: extract the `tier`/overlay/`rendered` parse of `_cprof_sync` (`:63-67`)
  into `_cprof_tier_state <dir>` (sync behaviour unchanged); new `_cprof_tier_stale <dir>`;
  staleness step in `_cprof_launch` after the token and `claude`-on-PATH checks (`:111-114`) and
  before the subshell (`:115`). File goes from 180 to ~215 lines.
- `cprof-checks.zsh`: `_cprof_doctor` calls `_cprof_doctor_links` right after
  `_cprof_doctor_tiers` (`:104`).
- Tests: new `test_cprof-link.zsh` (hermetic, same harness as `test_cprof.zsh:8-16`); launch
  staleness cases appended to the tier section of `test_cprof.zsh` (fake hq tree `:81-86`).
  `tools/code-gate/test-map.tsv` gains rows (sorted, `LC_ALL=C`): `cprof-link.zsh →
  test_cprof-link.zsh`, `cprof.zsh → test_cprof-link.zsh`, `cprof-checks.zsh → test_cprof-link.zsh`
  (existing rows `:8-11` stay). README gets a `link` paragraph and the launch change.

### B. Link map (`cprof link <name>`)

Main profile = literal `$HOME/.claude/` and `$HOME/.claude.json`, never `$CLAUDE_CONFIG_DIR`
(so running `link` inside an active profile still copies from main). Tiered = `<profile>/tier`
exists (same test as `cprof-tiers.zsh:94`, `:137`). On a tiered profile the verb SKIPS `CLAUDE.md`
(does not create the link; no extra exclude entry is added) and prints `skip: CLAUDE.md (tiered: global rules file stays excluded)`.
An existing `CLAUDE.md` entry on a tiered profile is left as is.

| `<profile>/config/` entry | Source / target | Plain profile | Tiered profile |
|---|---|---|---|
| `CLAUDE.md` | symlink → `$HOME/.claude/CLAUDE.md` | link | **skip** (tiered profiles keep `claudeMdExcludes`; the global rules file stays out, owner ruling 2026-10-21: "1") |
| `skills` | symlink → `$HOME/.claude/skills` | link | link |
| `agents` | symlink → `$HOME/.claude/agents` | link | link |
| `plugins` | symlink → `$HOME/.claude/plugins` | link | link |
| `settings.json` | symlink → `$HOME/.claude/settings.json` | link | **kept** (rendered file: deny list + sandbox; part G keeps it fresh) |
| `.claude.json` | `.mcpServers` of `$HOME/.claude.json` | jq merge of that one key; file stays a real file | same |
| `token`, `profile.env`, `tier`, `tier.src`, `workspace/` | — | never touched by the `link` verb (the part G launch re-render does rewrite `tier`/`tier.src` on tiered profiles, `cprof-tiers.zsh:42-43`; `workspace/` is never touched) | same |

**Link target choice: `$HOME/.claude/<entry>`, not the hq target.** (1) The owner's words are
"from my main profile"; `~/.claude` is the main profile and the link follows it if it is ever
repointed. (2) `skills`, `agents`, `plugins` are real directories in `~/.claude` (measured `ls -la
~/.claude`, 2026-10-21), so there is no hq target for three of five entries; one rule for all.
(3) Tests run with `HOME=$T/home`, so the targets are hermetic. Only `CLAUDE.md` and
`settings.json` chain on (to `~/projects/agent-hq/config/`, measured same `ls`). The Hermes how-to
linked those two straight to hq; that is the one deliberate difference.

Per entry: source absent in main → `skip`; already a symlink to the exact target → `ok`, no
backup; anything else present (file, dir, other link) → **moved** into the backup dir, then
`ln -s`; if `ln` fails the moved entry is moved back and the verb stops (exit 1).

`.mcpServers` copy: `jq` reads only `.mcpServers` from `~/.claude.json` (that file holds
`oauthAccount`, `userID`, `projects` and other account state, measured key list 2026-10-21; it is
never linked or replaced). Env and header keys whose name matches
`SECRET|TOKEN|KEY|PASSWORD|AUTH` (case-insensitive) are dropped, as in the Hermes how-to step 4,
and each dropped `server.env.KEY` name (never its value) is printed. Merge:
`.mcpServers = ((.mcpServers // {}) * $main)`, so main wins per key, profile-only servers and
owner-added keys survive; every other key of the profile's `.claude.json` (onboarding flag
written by `cprof-checks.zsh:39-52`, `userID`, `oauthAccount`, `projects`) is untouched. Write is
tmp + `mv` under `umask 077` (same pattern as `cprof-checks.zsh:51`). Today's main has 4 servers
and no env/header keys (names-only read, 2026-10-21). Main has no `.mcpServers` → `skip`.

### C. Auth boundary

Never read or written: `<profile>/token`, `profile.env`, the Keychain, `.claude.json` keys other
than `.mcpServers`, `~/.claude*` (read-only source). The only write outside `config/` is the new
backup dir. Tokens stay owner-provided at `cprof new` (ADR 0053 R-2, `decisions/0053-permission-
tiers.md:28`: "We'll do similar how to i need to already provide the token on profile creation
I'll continue doing that"); `link` adds no token path. HTTP MCP logins (Notion, Linear) are per
config dir and stay per profile: the owner runs `/mcp` inside the profile.

Consequences the owner is choosing (from the ask, stated so nothing is a surprise):
- A plain linked profile's `settings.json` is hq's, so its `claudeMdExcludes` (written by `new`,
  `cprof-checks.zsh:7-34`) goes into the backup, and memory loads like main. MEASURED 2026-10-21
  (Claude Code 2.1.307, unauthenticated `claude -p "/context"` with a temp `CLAUDE_CONFIG_DIR`
  whose `CLAUDE.md` links to `~/.claude/CLAUDE.md`, cwd in this worktree): rows = User (the
  linked file), Project `~/projects/CLAUDE.md`, Project repo `CLAUDE.md`; no duplicate row.
- A tiered profile keeps its excludes, which list `~/.claude/CLAUDE.md` and its resolved hq path
  (`cprof-checks.zsh:13-15`). MEASURED same day: an exclude on the resolved path does **not** drop
  a symlinked `$CLAUDE_CONFIG_DIR/CLAUDE.md`; an exclude on the link path does. Hence `link` does
  not link `CLAUDE.md` on tiered profiles (ruling 2026-10-21, see B and H.6); the executor's
  `workspace/CLAUDE.md` is unaffected.
- Writes follow the links: a plugin install or settings change made inside a plain linked profile
  lands in main's `~/.claude/plugins` / hq `config/settings.json`. Executor Bash writes to
  `~/.claude` stay sandbox-blocked (`allowWrite` is `~/projects` + caches,
  `permission-tiers-02.md` §1); no new write path is added.
- Linked executors run main's plugin hooks and MCP servers, and the copied stdio MCP commands (e.g. `uvx`/`npx` started by the harness), outside the Bash deny list and sandbox; the harness also writes main's `~/.claude/plugins/` metadata through the link. Owner-chosen consequence of 'everything excluding auth' (Fable ratification 2026-10-21); MCP denies remain per-name (E12 pattern).
- `cprof excludes <name>` on a plain linked profile replaces the `settings.json` link with a file
  (`mv -f` at `cprof-checks.zsh:33` renames over the link; the Hermes how-to caveat). Re-running
  `cprof link` restores the link (file backed up). Not changed here (no scope creep; named only).
- UNVERIFIED: whether Claude Code itself ever rewrites `settings.json` by rename (which would also
  turn the link into a file). Doctor's link row shows it (`settings.json=file`).

### D. Backup and idempotency

Backup dir `<profile>/config-backup-<UTC %Y%m%dT%H%M%SZ>/` (stamp format of `cprof-tiers.zsh:72`),
mode 700, created lazily on the first replacement, never when nothing is replaced. It receives
moved entries and a copy of `.claude.json` before the merge (the copy only when `.mcpServers`
would change). Existing backup dir with the same stamp → exit 1, nothing changed. A second
`cprof link` run on a linked profile prints only `ok`/`kept`/`skip` lines (an unchanged `.mcpServers` prints `ok: .mcpServers (in-sync, N)`; a `copied:` line only when the merge changed the file), creates no backup and leaves
`.claude.json` byte-identical. `link` never deletes a backup.

### E. Output and exit codes (`link`)

One line per entry, then a summary:
`linked: CLAUDE.md -> $HOME/.claude/CLAUDE.md` · `ok: skills (already linked)` ·
`kept: settings.json (tiered: rendered file)` · `skip: agents (none in $HOME/.claude)` ·
`copied: .mcpServers (4: aws-mcp linear notion serena)` · `stripped: serena.env.X_TOKEN` ·
`backup: <dir>` · `cprof: linked '<name>' (L linked, K ok, S skipped)`. Summary counts: `copied` lines count as linked, `kept` as ok, `skip` as skipped; `stripped:` and `backup:` lines are not counted, so an idempotent re-run shows `0 linked`.

Exit 0: done (any mix of linked/ok/skip/kept). Exit 1: usage, invalid name
(`_cprof_valid_name`, `cprof.zsh:32-34`), no `<profile>/config`, `jq` missing (checked before
any change, `_cprof_need_jq`), unreadable/invalid `~/.claude.json` or profile `.claude.json`, or any
backup/link/merge failure (stops at that entry; earlier entries stay done and backed up). Run it
with no claude session open on that profile (claude rewrites `.claude.json`).

### F. Doctor

New section after the tier rows (style of `cprof-tiers.zsh:132-155`), one row per non-`_` profile:
`-- link rows (main-profile links) --` then
`<name>: CLAUDE.md=linked skills=linked agents=linked plugins=linked settings.json=rendered; mcpServers=in-sync(4)`.
Values: `linked` (symlink to the exact `$HOME/.claude` target), `other-link`, `file`, `-`
(absent; expected for `CLAUDE.md` on a tiered profile, which `link` skips), `rendered` (tiered profile's real file, expected). `mcpServers=missing:<names>` when
main has servers the profile lacks, `absent` when main has none. No jq → one
`WARN: link rows skipped: jq not installed` line. Informational: an unlinked profile shows
`file`/`-` without WARN.

### G. Tiered launch re-render (`cprof launch <name>`, tiered)

Inputs: `tier.src` lines `<sha256> <path>` (`cprof-tiers.zsh:43`) vs the current list
`$(_cprof_hqcfg)/settings.json`, `tiers/<tier>.json`, and `tiers/overlays/<ov>.json` when
`tier.src` names one (overlay parse `:66`). Stale = the ordered `<sha> <path>` lists differ
(content change, or a different hq dir). Clean = `rendered` hash equals the current
`settings.json` hash (`:68`). Re-render = backup `config/settings.json.bak-<stamp>` (mode 600, as
`:72-74`) then `_cprof_render` (`:28-44`, unchanged rules) — the same render `sync` runs. The hq
inputs are the main checkout's working tree (`~/projects/agent-hq/config`), which is already live for
main (`~/.claude/settings.json` links to it).

`--tier executor` renders `<owner>` from `CPROF_OWNER` (a GitHub account name, `[A-Za-z0-9-]`); it fails closed if `CPROF_OWNER` is unset, empty or malformed.

| State | Action | Printed | Result |
|---|---|---|---|
| fresh (lists equal) | launch as today | nothing | exec claude |
| no `tier.src` | launch as today (cannot judge) | `cprof: WARN '<n>' has no tier.src; staleness not checked` | exec claude |
| stale + clean | backup, re-render in place, launch | `cprof: '<n>' render was stale (<changed inputs>); re-rendered (backup: <path>)` | exec claude |
| stale + hand-edited | **no** re-render, never `--force`; launch on the current file | the sync exit-3 text (`:69`) + `-- not re-rendered; launching on the current file` | exec claude |
| stale + render fails (input missing, jq missing, merge error, backup fails) | **abort**, no exec | `cprof: '<n>' re-render failed; not launching (a stale executor could be missing a deny)` | exit 1 |
| `--dry-run` + stale | nothing written | `dry-run: render stale (<inputs>); would re-render` or the hand-edited line | exit 0 |

Abort on render failure because a stale render can lack a deny the hq fragment now holds; desk
gets the same rule (one code path). Exit codes 2 (tier/flag refusal, `:94-110`) are unchanged
and checked first.

### H. Non-goals

1. No MCP auth copy: no Keychain entries, no `oauthAccount`, secret-looking env/header keys are
   stripped; HTTP MCP logins stay per profile (`/mcp`).
2. No automatic `--force`: a hand-edited render is never overwritten by launch; `sync --force`
   stays the owner's explicit verb.
3. No change to `new --tier` rendering or merge rules (`permission-tiers-02.md` §1, D2) or to
   `sync` behaviour (helper extraction only), and no refresh of `workspace/CLAUDE.md` at launch.
4. No Hermes skill and no auto-link inside `cprof new`: the owner runs `cprof link <name>`.
5. No other `~/.claude` content (projects, sessions, history, plans, hooks, keybindings) and no
   project-scoped `.projects[*].mcpServers`; no fix to `cprof excludes` on linked profiles.
6. No `CLAUDE.md` link on tiered profiles (owner ruling 2026-10-21, "1": keep the global CLAUDE.md
   excluded, matching the ratified tier design). Mechanism is SKIP in `link`, not an added exclude
   entry; the part C measurement is why an exclude would not have covered a link.

## Extension (2026-10-26): `--auth bedrock`

**Status: owner ruling 2026-10-26 (AskUserQuestion); code and this amendment go through the PR gate.**
Option chosen, verbatim: "Add Bedrock mode to cprof (Recommended)". The option described: a small code change plus tests;
`cprof new <name> --auth bedrock`; `use`/`launch` export `CLAUDE_CODE_USE_BEDROCK=1` and pass `AWS_PROFILE`/`AWS_REGION`
through; a bedrock sandbox fragment for the Bedrock and STS endpoints; this design record amended; a PR through the gate.
Everything above this section is unchanged; oauth profiles behave exactly as before.

### What changes vs the 2026-10-01 token-only design

- 2026-10-01 is token-only: every profile has `token`, and `use` unsets `CLAUDE_CODE_USE_{BEDROCK,VERTEX,FOUNDRY}`.
  A bedrock profile instead has `<profile>/auth` = `bedrock` (mode 600) and no `token`; an absent `auth` file means oauth.
- Bedrock mode unsets `ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY`
  and exports `CLAUDE_CODE_USE_BEDROCK=1`; `AWS_*` and `AWS_BEARER_TOKEN_BEDROCK` pass through from the shell or `profile.env`.
- Why unset although Bedrock ranks first: with `CLAUDE_CODE_USE_BEDROCK` set, cloud-provider credentials rank first, then
  `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `apiKeyHelper`, `CLAUDE_CODE_OAUTH_TOKEN`, profile, `/login`; and a managed policy can
  refuse a Bedrock session while an Anthropic key or token is present (Claude Code docs, read 2026-10-26). A stray Anthropic
  credential must not leak into the profile either.

### Components

- New `tools/claude-profile/cprof-auth.zsh` (sourced by `cprof.zsh` before `cprof-tiers.zsh`): mode file read/validate, region
  lookup and check, render-input substitution, token write/read (moved from `cprof.zsh`), `_cprof_auth_apply` shared by `use` and `launch`,
  dry-run words.
- New `config/tiers/auth-bedrock.json`: `_auth` marker plus seven `sandbox.network.allowedDomains` (allowances only, like an overlay):
  `bedrock-runtime.<region>`, `bedrock.<region>`, `sts.<region>`, `sts`, `sso.<sso_region>`, `oidc.<sso_region>`,
  `portal.sso.<sso_region>` (all `.amazonaws.com`).
- Render inputs, in merge order: hq `settings.json`, `tiers/<tier>.json`, `tiers/auth-bedrock.json` (bedrock only), overlay.
  `<region>` = `AWS_REGION` > `AWS_DEFAULT_REGION`, the variables Claude Code itself reads, so the host list and the model calls
  use one region (no cprof-only region override). `<sso_region>` = `CPROF_SSO_REGION`, else the region: Claude Code takes the SSO
  region from the AWS profile, which cprof cannot read, so this one override stays.
  Inputs on disk are never modified; `_auth` is dropped from the output like `_tier`. Oauth renders are byte-identical to before.
- `tier.src` gains `region <r>[ sso=<s>]` before `rendered <sha>` (bedrock only). Staleness (part G) compares it too, so a changed
  region or SSO region is a stale input named `region` and re-renders at launch.

### Interfaces (exact messages)

- `new`: `unknown auth mode: '<x>' (oauth|bedrock)` (exit 1, no dir); success ends
  `(auth: bedrock, no token; AWS credentials come from your shell)`; no valid region on a tiered render:
  `AWS region '<x|unset>' is not a region id; export AWS_REGION (or AWS_DEFAULT_REGION) before rendering a bedrock profile (the sandbox host list needs it)`
  (exit 1, no profile left). Region regex `^[a-z]{2}(-gov)?-[a-z]+-[0-9]$`.
- `use`/`launch` with no region: `cprof: WARN: no AWS_REGION/AWS_DEFAULT_REGION in this shell; Claude Code falls back to the AWS profile's region, then us-east-1` (exit 0).
- `token`: `'<name>' uses --auth bedrock; it has no token` (exit 1). `ls`: `[bedrock]`.
- `launch --dry-run` env words: `CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=<r|unset> AWS_PROFILE=<p|unset>`; oauth keeps `CLAUDE_CODE_OAUTH_TOKEN=<token>`.
- `doctor`: tier row `<name>: tier=<t>; auth=bedrock; ...`; auth-vars section prints
  `ok: CLAUDE_CODE_USE_BEDROCK=1 (active profile uses --auth bedrock)` or `WARN: active profile is bedrock but CLAUDE_CODE_USE_BEDROCK is not 1`.

### Non-goals

1. No Vertex or Foundry mode.
2. No AWS credential storage in the profile: cprof writes no AWS key, token or config; the shell (or the owner's `profile.env`) supplies them.
3. No change to oauth profiles: no `auth` file, same token path, same render bytes, same messages.
4. The host list is derived from the AWS General Reference endpoint pages, not from the Claude Code docs (which name none);
   it must be live-tested per region, and a sandbox block is reported as a design signal, never worked around.

### Verification

`tools/claude-profile/test_cprof-auth.zsh` (hermetic, same harness as `test_cprof.zsh`) covers the contracts above; the existing
`test_cprof.zsh`, `test_cprof-link.zsh` and `test_cprof-checks.zsh` pass unchanged.
