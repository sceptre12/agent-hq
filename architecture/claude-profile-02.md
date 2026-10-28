# claude-profile (`cprof`) — design record, part 2: Extensions 2026-10-26 and 2026-10-27

Part 2 of 2 of `architecture/claude-profile.md`; part 1 holds the status header (which governs this file), the
ratified 2026-10-01 design (What This Is through Verification) and Extension (2026-10-21) `cprof link` + tiered
launch re-render, whose lettered parts A-H (link map B, exit codes E, doctor F, staleness G) are cited below.

## Extension (2026-10-26): `--auth bedrock`

**Status: owner ruling 2026-10-26 (AskUserQuestion); code and this amendment go through the PR gate.**
Option chosen, verbatim: "Add Bedrock mode to cprof (Recommended)". The option described: a small code change plus tests;
`cprof new <name> --auth bedrock`; `use`/`launch` export `CLAUDE_CODE_USE_BEDROCK=1` and pass `AWS_PROFILE`/`AWS_REGION`
through; a bedrock sandbox fragment for the Bedrock and STS endpoints; this design record amended; a PR through the gate.
Everything in part 1 (`claude-profile.md`) is unchanged; oauth profiles behave exactly as before.

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
- `CPROF_SSO_REGION`, when set, must match the same regex before any substitution; otherwise the render refuses with
  `CPROF_SSO_REGION '<v>' is not a region id (same form as AWS_REGION, e.g. us-east-1)` (exit 1, no profile left; tests a6f, a6g).
- `_cprof_render` fails closed: the merge pipeline runs under `pipefail`, the result must be a JSON object, and an executor render
  must keep a non-empty `permissions.deny` and `sandbox.enabled == true`; otherwise
  `render produced an invalid or weakened settings object; nothing written` (exit 1; test a6h). The guard covers every render,
  oauth included, plus `sync --force` and the launch re-render.
  Follow-up: the guard does not yet check `allowUnsandboxedCommands` or a wildcard `allowedDomains` entry coming from an overlay.
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

## Extension (2026-10-27): dynamic `cprof link` source root

**Status: task-specified amendment (dispatched change request, 2026-10-27); code and this amendment land together.**
**Fix-up pass (2026-10-27, same day): a 7-agent pr-review panel on the original diff returned READY WITH CONDITIONS
(0 Blocking, 7 Medium, 5 Advisory); every finding (M1-M7, A1-A5) was applied before merge and is folded into this
section below in place, not as a separate extension — there is no separate ratification step for a same-day fix-up
pass that lands before the PR gate.**
Ask: `cprof link`'s source was hardcoded to `$HOME/.claude` (part B, `claude-profile.md`). The owner now treats agent-hq itself
(`~/projects/agent-hq`) as the primary thing to link a profile against day to day, while still needing the old
personal-profile behavior (linking against `$HOME/.claude`) on demand. This amends part B's link map and part E's
exit codes (cross-referenced inline at both, per the fix-up pass's M1); parts C (auth boundary), D
(backup/idempotency), G (tiered launch re-render) and H (non-goals) are otherwise unchanged. Part F (doctor) is
**also** amended by the fix-up pass (M2, below) — the original same-day draft of this extension said doctor would
stay untouched, but that turned out to misreport every entry of an agent-hq-linked profile as `other-link`, so it is
corrected here rather than shipped as a known bug.

### What changes vs. the 2026-10-21 design

- `cprof link <name>` takes an optional second positional argument, `<source-root>`: `cprof link <name> [<source-root>]`.
  Default (no second arg): `$HOME/projects/agent-hq`, not `$HOME/.claude`. Pass `$HOME/.claude` explicitly to get the
  2026-10-21 behavior back verbatim, or any other directory.
- Per-entry resolution is now a function of `<source-root>`, not a literal `$HOME/.claude/<entry>` join: for each entry
  independently, `_cprof_link_src` tries `<source-root>/config/<entry>` first, falling back to `<source-root>/<entry>`
  only when that specific entry is absent under `config/` (A1/A5: the fallback is evaluated per entry, not once for
  the whole root via a `<source-root>/config` directory-existence pre-check — a root could even mix layouts, an entry
  under `config/` while another sits at the top level, with no special case). This covers agent-hq's own layout
  (`config/CLAUDE.md`, `config/settings.json`, top-level `skills/`, `agents/`, no `plugins/`) and `$HOME/.claude`'s
  flat layout (every entry directly under the root, with no `config/` at all) with one rule. An entry absent under
  both locations skips exactly as before (`skip: <entry> (none in <source-root>)`), so `plugins` skips gracefully
  when linking from agent-hq.
- The `.mcpServers` source is likewise derived from `<source-root>`, not hardcoded to `$HOME/.claude.json`: it is the
  sibling file named after the root's own last path component (`${root:h}/${root:t}.json`) — `$HOME/.claude` →
  `$HOME/.claude.json` (unchanged for that root), `~/projects/agent-hq` → `~/projects/agent-hq.json` (does not exist, so
  this step skips gracefully: `skip: .mcpServers (no <path>)`, counted as skipped same as any other absent entry).
- `<source-root>` is canonicalized before any other use (A2/A4): zsh's `${root:A}` modifier resolves symlinks and
  collapses repeated/trailing slashes in one pass. This replaces the original `${root%/}` (a single-slash strip that
  could leave a malformed sibling-`.mcpServers`-path join on a multi-trailing-slash input) and additionally follows
  symlinks, which the original did not. Applied uniformly to both the explicit and the default root.
- An explicit `<source-root>` that is not a directory errors immediately (`no such source: '<source-root>'`, exit 1,
  nothing changed) before any profile or `jq` check runs. The default root is never validated this way: if
  `~/projects/agent-hq` does not exist on a given machine, every entry and `.mcpServers` simply skip (same as any other
  absent source), rather than the whole verb erroring — the hard error is reserved for an explicit, caller-provided
  mistake, per the existing part E rule that usage-shaped errors are checked first. M4 (fix-up): this all-skip path is
  no longer silent — `link` prints an explicit `WARN: default source root '<root>' does not exist; every entry will
  skip ...` up front when it detects this case, before entering the per-entry loop.
- M5 (fix-up, security — pairs with A3): the wider default root widens the `.mcpServers` merge's blast radius too,
  and the secret-scrub regex (part B) never covers `command`/`args`/`url` fields, which run verbatim when `claude`
  starts. Rather than gate the merge behind a new `--force`/confirmation flag — which would make `link` non-scriptable,
  breaking the exact idempotent-rerun and test-harness invocations part D's guarantees and this suite depend on — `link`
  now prints an explicit `WARN: merging .mcpServers from a non-default root (<path>) — ...` immediately before merging
  in MCP config from any root other than the literal `$HOME/.claude`, so the risk is surfaced every time rather than
  silently trusted. (The simpler of the two options named by the security review; reasoning kept here rather than only
  in the fix-up commit message, per this doc's own convention of recording the "why" next to the "what".)
- A3 (fix-up, pairs with M5): a live, mutable root (e.g. the owner's own agent-hq checkout) can drift after a profile
  is linked to it, with no prior record of what was actually linked or when. `link` now writes a new file,
  `<profile>/link-src`, every time it completes (even a pure skip-fest, so the record always reflects the most recent
  invocation): line 1 is `root <resolved-root>`; line 2, present only when `<resolved-root>` is itself a git working
  tree, is `commit <sha>` (`git -C <root> rev-parse HEAD`, errors suppressed — a non-git root, e.g. `$HOME/.claude`,
  gets no line 2). This is a new file, not one of the five part B/C entries nor `token`/`profile.env`/`tier`/`tier.src`/
  `workspace/` — it adds an audit trail, it does not change what `link` reads or writes among those.
- M2 (fix-up): `_cprof_doctor_links` no longer assumes every profile was linked against the literal `$HOME/.claude`.
  It reads each profile's `link-src` (above) for the root to compare that profile's entries against, via the same
  `_cprof_link_src` resolution `link` itself uses; a profile with no `link-src` (never linked, or linked by a cprof
  build that predates this file) falls back to `$HOME/.claude`, so pre-2026-10-27 profiles and doctor output are
  unaffected. The `.mcpServers` row's comparison baseline is intentionally **not** changed here: it still reads
  `$HOME/.claude.json`'s key list regardless of root, because the panel finding (M2) was specifically about the
  per-entry symlink rows reporting `other-link`, not about the `mcpServers=missing:<names>` baseline, which stays a
  statement about the owner's one real main account either way (see Non-goals below).

### Components

- `tools/claude-profile/cprof-link.zsh`: `_cprof_link_src <root> <entry>` helper, rewritten per entry (A1, no
  whole-root directory pre-check), prints the resolved path and returns 1 if absent under both locations. `_cprof_link`
  gains the `root=$2` parameter, canonicalization (A2/A4), the explicit-root directory check, the M4 missing-default
  WARN, the M5 non-default-root `.mcpServers` WARN, computes `main_cj` from `root` instead of a hardcoded assignment,
  and writes the new `link-src` audit file (A3) on every successful completion. `_cprof_doctor_links` is amended (M2):
  it reads `link-src` per profile and resolves each entry's expected source via `_cprof_link_src` against that root,
  instead of a hardcoded `$HOME/.claude/$e` join; its `.mcpServers` baseline is unchanged (still `$HOME/.claude.json`).
- `cprof.zsh` help text: `cprof link <name> [<source-root>]` line updated to describe the new default and override.
- `tools/claude-profile/README.md` and `tools/onboarding.md`: usage and prose updated for the new default and the
  `cprof link <name> ~/.claude` form of the old behavior; `tools/onboarding.md`'s skills-pollution caveat corrected
  (M6+M7, same root cause, one fix) — a bare `cprof link <name>` is **not** exempt from that caveat: with the new
  default it now symlinks the profile's `skills`/`agents` straight into the live `~/projects/agent-hq` checkout, the
  same footgun class the caveat exists to warn about.
- Tests: `test_cprof-link.zsh` updated — every pre-existing case that relied on the old bare-`cprof link <name>` default
  now passes `$M` (the test harness's fake `$HOME/.claude`) as an explicit second argument, preserving the exact
  assertions from the 2026-10-21 design; new cases cover the agent-hq-shaped default (via a fake tree at
  `$HOME/projects/agent-hq` inside the hermetic `$HOME`, made a real git repo so A3's `commit` line has something to
  record), `plugins`/`.claude.json` skipping gracefully from that tree, an explicit nonexistent `<source-root>`
  erroring, a missing-default-root case (M4), a doctor row for the agent-hq-linked profile (M3, aligned with M2's
  fix), and a non-default-root `.mcpServers` merge warning (M5).

### Interfaces (exact messages)

- New skip line, entry: `skip: <entry> (none in <source-root>)` (replaces the old `skip: <entry> (none in $HOME/.claude)`
  wording with the resolved root; unchanged when `<source-root>` is `$HOME/.claude`).
- New skip line, `.mcpServers` when the sibling json is entirely absent: `skip: .mcpServers (no <path>)` (distinct from
  the existing `skip: .mcpServers (none in <path>)`, which still fires when the file exists but has no `.mcpServers` key).
- New usage error: `no such source: '<source-root>'` (exit 1) for an explicit root that is not a directory.
- New WARN (M4), printed once, before the per-entry loop, only when no `<source-root>` was given and the default does
  not exist: `WARN: default source root '<root>' does not exist; every entry will skip (pass an explicit <source-root>,
  or create it)`. Exit code is still 0 (part E's existing all-skip-is-not-an-error rule; this is a WARN, not an error).
- New WARN (M5), printed once, immediately before an off-default-root `.mcpServers` merge actually proceeds (i.e. the
  sibling json exists and has a non-empty `.mcpServers`): `WARN: merging .mcpServers from a non-default root (<path>)
  — command/args/url fields are not secret-scrubbed and run verbatim when claude starts; review <profile-.claude.json>
  before trusting this profile`. Never printed when `<source-root>` canonicalizes to `$HOME/.claude`.
- Usage line: `usage: cprof link <name> [<source-root>]` (was `usage: cprof link <name>`).
- Everything else in part E (`linked:`, `ok:`, `kept:`, `copied:`, `stripped:`, `backup:`, the summary line and its exit
  codes) is byte-for-byte unchanged.

### Non-goals

1. No change to `_cprof_doctor_links`'s `.mcpServers` comparison baseline: it still reads `$HOME/.claude.json`'s key
   list regardless of which root a profile was linked to (M2 only changed the per-entry symlink-vs-root comparison,
   per its own finding text — the baseline is a statement about the owner's one real main account, which does not
   move just because a given profile happened to link skills/agents from elsewhere).
2. No new env-var override for the default root (e.g. no `CPROF_LINK_ROOT`): the default is the literal
   `$HOME/projects/agent-hq` path, matching how the 2026-10-21 design hardcoded `$HOME/.claude` directly; tests get
   hermeticity by pointing `$HOME` itself at a temp dir and building the fake agent-hq tree under it, not by adding a
   second knob.
3. No change to `cprof new --tier`'s `CPROF_HQ_CONFIG`-based hq config lookup (`cprof-tiers.zsh`): that is a separate,
   pre-existing override for a different purpose (tier rendering) and is untouched here.
4. No `--force`/confirmation flag gating a non-default-root `.mcpServers` merge: M5 chose the warning-only option
   (see "What changes", above) specifically to keep `link` scriptable; a blocking flag remains available as a future
   escalation if a warning proves insufficient in practice, but is not added here.

### Verification

`tools/claude-profile/test_cprof-link.zsh` (hermetic, same harness as `test_cprof.zsh`) covers the contracts above,
including the fix-up pass's additions: a missing-default-root WARN and graceful all-skip (M4), the `link-src` audit
file's `root`/`commit` lines for both a git-tree root and a non-git root (A3), a doctor row for a profile linked from
the agent-hq default showing `linked` rather than `other-link` (M3, exercising the M2 fix), and an explicit WARN
before a non-default-root `.mcpServers` merge (M5). The full existing suite (`test_cprof.zsh`, `test_cprof-link.zsh`,
`test_cprof-checks.zsh`, `test_cprof-auth.zsh`) passes unchanged in behavior for every case that still applies.
