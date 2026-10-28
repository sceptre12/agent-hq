# claude-profile (`cprof`) — design record, part 2: Extensions 2026-10-26, 2026-10-27 and 2026-10-28

Part 2 of 2 of `architecture/claude-profile.md`; part 1 holds the status header (which governs this file), the
ratified 2026-10-01 design (What This Is through Verification) and Extension (2026-10-21) `cprof link` + tiered
launch re-render, whose lettered parts A-H (link map B, exit codes E, doctor F, staleness G) are cited below.

## Extension (2026-10-26): `--auth bedrock`

**Status: owner ruling 2026-10-26 (AskUserQuestion); code and this amendment go through the PR gate.**
Option chosen, verbatim: "Add Bedrock mode to cprof (Recommended)". The option described: a small code change plus tests;
`cprof new <name> --auth bedrock`; `use`/`launch` export `CLAUDE_CODE_USE_BEDROCK=1` and pass `AWS_PROFILE`/`AWS_REGION`
through; a bedrock sandbox fragment for the Bedrock and STS endpoints; this design record amended; a PR through the gate.
Part 1 (`claude-profile.md`) is unchanged apart from pointer lines to this file; oauth profiles behave exactly as before.

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

## Extension (2026-10-27): self-contained `profile.env` for `--auth bedrock`

**Status: task-specified fix for a real-world failure; code and this amendment land together.**
**Fix-up pass (2026-10-27, same day): a 7-agent pr-review panel on the original diff returned READY WITH CONDITIONS
(0 Blocking, 5 Medium, 2 Advisory); every finding (M1-M5, A1-A2) was applied before merge and is folded into this
section below in place, not as a separate extension — same precedent as the 2026-10-27 `cprof link` fix-up pass
above.** M1 adds the `doctor` cross-check against `aws configure list-profiles` (Components, Interfaces below). M3/M4
replace the Anthropic model-var glob scan with a second explicit allowlist, matching the AWS allowlist's style
(Components below). M5 corrects the no-`AWS_PROFILE` WARN quote in Interfaces to include the `cprof: ` prefix every
`_cprof_err` message actually carries.
A profile created
with `cprof new xTest --auth bedrock` (no `--tier`, no `profile.env`) inherited `AWS_PROFILE` from an unrelated,
already-running shell that happened to be pointed at a sandbox AWS account; an org-level SCP there explicitly denied
`bedrock:InvokeModelWithResponseStream`, so Claude Code failed with a 403, even though a different, valid AWS
profile (`digital-foundations-nonprod`) was available in other shells. Root cause: a bedrock profile with no
`profile.env` has nothing of its own for `AWS_PROFILE`/`AWS_REGION` — the 2026-10-26 design's "pass through
untouched" is correct as written, but with no `profile.env` there is nothing to pass through *from* except whatever
the calling shell happens to have. Owner requirement: every bedrock profile must work out of the box going forward,
fixed once at the tool level, not patched per-profile.

### What changes vs the 2026-10-26 design

- `new --auth bedrock` now also snapshots the CREATING shell's `AWS_PROFILE`, `AWS_REGION`, `AWS_DEFAULT_REGION` and
  any `ANTHROPIC_DEFAULT_*_MODEL` vars into the new profile's `profile.env`, immediately after writing `auth`. A
  profile is therefore self-contained from the moment it is created, instead of depending on whatever a future
  shell's ambient AWS state happens to be. Only vars actually set in the creating shell are written.
- No `AWS_PROFILE` in the creating shell: `new` still succeeds (a missing AWS credential is not a reason to refuse
  creating the profile — the owner may legitimately want to add it to `profile.env` by hand later), but prints a WARN
  naming the gap, and writes no `AWS_PROFILE=` line (never a blank or wrong one). If literally nothing is available to
  snapshot (no `AWS_PROFILE`, no region, no model vars), `profile.env` is not written at all — an empty file would
  be indistinguishable from "nothing to see here" and would defeat the doctor check below, which treats a present
  but incomplete `profile.env` differently from an absent one.
- **Precedence, confirmed, not changed:** `profile.env` already won over an ambient shell value before this
  extension — both `use` and `launch` source it with a plain, `allexport` assignment (`() { setopt localoptions
  allexport; source "$1"; } "$d/profile.env"`), which unconditionally overwrites whatever the variable already held,
  rather than a `:${VAR:=value}`-style gap-fill. This was verified directly (a subshell exporting a conflicting
  `AWS_PROFILE`, then sourcing a `profile.env` with a different value, ends with the `profile.env` value) and is now
  locked in by test (below). The xTest bug was never a precedence bug — it was the simple absence of `profile.env`
  for that profile, which this extension's auto-snapshot closes going forward.
- `doctor` gains a `-- bedrock profile.env rows (auth=bedrock profiles only) --` section: one WARN row per bedrock
  profile with no `profile.env` at all, and one WARN row per bedrock profile whose `profile.env` exists but has no
  `AWS_PROFILE=` line in it (e.g. a profile snapshotted before this extension, or one legitimately created in a
  shell with no `AWS_PROFILE`). This is how a legacy profile (the real `xTest` on the owner's machine, which
  predates this fix) is made easy to spot. No repair subcommand: the WARN names the fix directly — add
  `AWS_PROFILE=<profile>` (and `AWS_REGION=<region>`) to the profile's `profile.env` by hand; re-running `cprof new`
  is not needed and would refuse anyway (`new` fails if the profile directory already exists).
- **Fix-up pass (M1):** a present `AWS_PROFILE=` line only proves the name was recorded, never that the profile
  still resolves — a renamed/removed AWS profile would otherwise go stale with no WARN, the exact failure class this
  extension exists to close. When `aws` is on `PATH`, `doctor` now also cross-checks the recorded value against
  `aws configure list-profiles` and WARNs (never fails) if it is not found; the check is skipped gracefully, with no
  WARN at all, when the AWS CLI is not installed (`doctor` must not require it).

### Components

- `tools/claude-profile/cprof-auth.zsh`: new `_CPROF_BEDROCK_SNAPSHOT_VARS` (`AWS_PROFILE AWS_REGION
  AWS_DEFAULT_REGION`) and a second explicit allowlist, `_CPROF_BEDROCK_SNAPSHOT_ANTHROPIC_VARS` (`ANTHROPIC_MODEL
  ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
  ANTHROPIC_DEFAULT_FABLE_MODEL`; fix-up pass M3/M4 — this replaces an earlier dynamic glob scan of the whole
  parameter table, which made `profile.env` content shell-session-dependent in a way the AWS half wasn't, and was
  narrower in the test harness than in the glob's actual runtime match set; verified against the installed Claude
  Code CLI and the published environment-variables reference as the full current set of Anthropic model-override
  vars, excluding `ANTHROPIC_DEFAULT_MODEL` — a different "default model for new sessions" setting, not an alias
  pin — and the deprecated `ANTHROPIC_SMALL_FAST_MODEL`), `_cprof_bedrock_snapshot <profile-dir>` (atomic tmp+mv
  write, `umask 077`, mirroring `cprof-link.zsh`'s `link-src` audit-write style, now iterating both allowlists the
  same way) and `_cprof_doctor_bedrock_env` (the new doctor section, iterating every profile under `cprof_root` the
  same way `_cprof_doctor_tiers`/`_cprof_doctor_links` already do; fix-up pass M1 adds the `aws configure
  list-profiles` cross-check, guarded by `${+commands[aws]}`).
- `tools/claude-profile/cprof.zsh`: `_cprof_new` calls `_cprof_bedrock_snapshot` right after writing `auth` = `bedrock`
  (before any tier render or token prompt, matching the existing fail-fast-before-the-token-paste ordering); a
  snapshot write failure removes the half-created profile dir, same as every other `new --auth bedrock` failure mode.
- `tools/claude-profile/cprof-checks.zsh`: `_cprof_doctor` calls `_cprof_doctor_bedrock_env` after
  `_cprof_doctor_tiers`/`_cprof_doctor_links`.
- No change to `_cprof_auth_apply`, `_cprof_use`'s or `_cprof_launch`'s `profile.env`-sourcing code: the precedence
  was already correct (see above); this extension changes what `profile.env` *contains* at creation time, not how
  it is applied.

### Interfaces (exact messages)

- New WARN at `new --auth bedrock` with no `AWS_PROFILE` in the creating shell (via `_cprof_err`, which always
  prepends `cprof: `, fix-up pass M5): `cprof: WARN: no AWS_PROFILE in this shell to snapshot into
  '<name>/profile.env'; set AWS_PROFILE before 'cprof new <name> --auth bedrock', or add it to <path>/profile.env by
  hand` (stderr; `new` still exits 0 and the profile is created).
- `doctor`, new section header: `-- bedrock profile.env rows (auth=bedrock profiles only) --`; per profile:
  `WARN: <name> has no profile.env; AWS_PROFILE will come from whatever shell happens to run 'cprof use/launch
  <name>' -- re-running 'cprof new' is not needed, just add AWS_PROFILE=<profile> (and AWS_REGION=<region>) to
  <path>/profile.env by hand, or re-run 'cprof new' in a shell that already has AWS_PROFILE exported`, or
  `WARN: <name> has profile.env but no AWS_PROFILE in it; add AWS_PROFILE=<profile> to <path>/profile.env by hand`,
  or (fix-up pass M1, only when `aws` is on `PATH` and the recorded name doesn't resolve) `WARN: <name>'s profile.env
  AWS_PROFILE ('<value>') not found in 'aws configure list-profiles'; the AWS profile may have been renamed or
  removed`; `ok: every bedrock profile has profile.env with AWS_PROFILE` when none apply. These three `doctor` rows
  print via plain `print`, not `_cprof_err`, so (unlike the `new`-time WARN above) they carry no `cprof: ` prefix.

### Non-goals

1. No repair/migration subcommand: fixing a legacy profile is a one-line manual `profile.env` edit, named explicitly
   by the doctor WARN, not an automated rewrite of a profile cprof did not fully create in the first place.
2. No change to oauth profiles, to `_cprof_auth_apply`'s bedrock pass-through semantics, or to the tiered render's
   region source (still the shell only, never `profile.env` — unchanged from 2026-10-26).
3. No snapshot of `AWS_BEARER_TOKEN_BEDROCK` or static `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`-style credentials:
   the owner ruling behind `--auth bedrock` (2026-10-26) is that cprof stores no AWS credential of any kind; only
   the identifying/config vars (`AWS_PROFILE`, region, model ids) are ever written to `profile.env`.

### Verification

`tools/claude-profile/test_cprof-auth.zsh`: new cases cover a successful snapshot of `AWS_PROFILE`/`AWS_REGION`/
`ANTHROPIC_MODEL`/`ANTHROPIC_DEFAULT_OPUS_MODEL`/`ANTHROPIC_DEFAULT_FABLE_MODEL` at `new --auth bedrock` (fix-up pass
M3/M4: exercises the full explicit Anthropic allowlist, not just the three names the pre-fix-up glob happened to
also match); the no-`AWS_PROFILE` WARN with a partial `profile.env` written; the nothing-to-snapshot case writing no
`profile.env` at all; a real precedence test (an ambient, conflicting `AWS_PROFILE` exported in the test shell, then
`cprof use`/`cprof launch` on a profile whose `profile.env` sets a different `AWS_PROFILE`, confirming the profile's
value wins in both paths); the three original `doctor` rows (missing `profile.env`, present-but-incomplete
`profile.env`, and the clean `ok` case); and, fix-up pass M1, three more `doctor` cases using a fake `aws` stub on
its own `PATH` entry: the cross-check WARN when `aws` is present and the recorded name isn't in `aws configure
list-profiles`, no WARN when it is, and no WARN at all (check skipped) when `aws` is not on `PATH`. The test
harness's `CLEAN` env list is now byte-for-byte the same as `_CPROF_BEDROCK_SNAPSHOT_ANTHROPIC_VARS`
(`ANTHROPIC_MODEL ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL`) so the snapshot's own hermeticity isn't broken
by whatever Bedrock model vars happen to be set in the machine actually running the tests. The full existing suite
(`test_cprof.zsh`, `test_cprof-link.zsh`, `test_cprof-checks.zsh`, `test_cprof-auth.zsh`) passes. A real-world manual
check (not just the hermetic suite) also confirmed the original fix: a scratch profile created with a realistic
`AWS_PROFILE` snapshotted it into `profile.env`; a subshell exporting a different, conflicting `AWS_PROFILE` and then
running `cprof use` on that profile ended with the profile's own value in effect, and `cprof off` restored the
subshell's original value exactly.

## Extension (2026-10-28): self-heal `new --auth bedrock` against a broken ambient AWS profile

**Status: owner-approved plan, code and this amendment land together.**
The 2026-10-27 extension made every new bedrock profile self-contained by snapshotting whatever `AWS_PROFILE` was
ambient at creation time. That closed the "no `profile.env` at all" bug, but not a sharper one: the owner's `adx-dev`
AWS profile silently resolves to a sandboxed account (`202533503908`) with an org-level SCP that explicitly denies
all Bedrock actions. Twice, a profile got created while `adx-dev` was ambient, snapshotted faithfully (exactly as
designed), and the breakage was only discovered later via a confusing 403 — both times hand-fixed by editing
`profile.env` to point at the known-working profile `digital-foundations-nonprod`. Owner requirement: `new --auth
bedrock` must work out of the box — no new flag, no new env var to remember to set — by detecting a broken ambient
profile and automatically recovering.

Verified finding shaping this design: every AWS profile on the owner's machine shares one SSO session
(`digital-foundations-nonprod`, in `~/.aws/config`'s `[sso-session digital-foundations-nonprod]`). Two profiles
(`digital-foundations-nonprod`, `adx-dev`) use a custom `credential_process` script that, on any credential-export
failure, unconditionally runs `aws sso login` — a browser popup — with no "is the cached token still fresh"
pre-check; the rest reference `sso_session` directly and fail fast, non-interactively, on an expired token. The
owner has explicitly accepted a browser login prompt occurring for whichever profile ends up actually adopted;
repeated/unnecessary prompts across profiles never asked for should still be minimized where possible, not
eliminated at the cost of not working.

### What changes vs the 2026-10-27 design

- The ambient `AWS_PROFILE` candidate is no longer snapshotted blindly. It is checked against a persistent health
  cache (new file, one line per AWS profile) before being written: a cached `good` verdict is trusted with no live
  call (fast path once a profile has been validated once); a cached `bad` verdict skips straight to a substitute
  search, also with no re-test; no cache entry at all (the normal first-time case) triggers one live
  `aws bedrock list-inference-profiles --profile <candidate> --region <region>` call, bounded by the AWS CLI's own
  `--cli-connect-timeout`/`--cli-read-timeout` plus an outer `timeout`/`gtimeout` wall-clock bound when either is on
  `PATH` (a browser SSO prompt during that call is accepted, never killed by the bound).
- **Classification is the crux of correctness** and is owner-approved, literal-text matching, not exit-code-only:
  `AccessDenied*` + `"explicit deny in a service control policy"` is the one signal that means "permanently broken
  for Bedrock" (`bad`). `ExpiredToken`/`UnauthorizedSSOTokenError`/`"Unable to locate credentials"`, or any other
  failure, means "needs a fresh login or could not be determined either way" (`inconclusive`) — routine, not a
  verdict on the profile, and never cached (an inconclusive probe must not poison the cache). A declined or failed
  login prompt is therefore never mistaken for a denied profile.
- A `bad` verdict triggers a substitute search: the most-recently-checked cached-`good` (profile, region) pair, if
  that profile isn't the candidate itself; else `aws configure list-profiles`, with non-`credential_process`
  profiles tried first (they fail fast with no popup risk if also broken, so trying them costs nothing before
  risking a popup on a `credential_process` candidate), live-validating and caching each until the first `good`.
  Fix-up pass B1: before a candidate is probed, it is checked for a same-named-minus-`-sso` sibling profile also
  present in `aws configure list-profiles` (the structural signal this machine's real `~/.aws/config` actually
  supports for "this is an internal raw SSO profile, not the one meant for direct use" -- see Fix-up pass below);
  if an untried, non-excluded sibling exists, the SIBLING is probed in that candidate's turn instead of the raw
  profile. A `good` result, from either path, is re-verified via a live `aws sts get-caller-identity` before being
  accepted as the final substitute -- a candidate that passes the narrow Bedrock probe but fails identity
  resolution is skipped. A clear message names the substitution and quotes the bad verdict's detail. If every
  candidate is exhausted with no `good` found, `new` falls back to snapshotting the ambient candidate anyway, with
  an unmissable WARN summarizing what was tried.
- Fix-up pass M2: probing, substitution search and `doctor` all resolve a candidate's region the same one way --
  that profile's OWN configured region in `~/.aws/config` (`aws configure get region`, a local read, never a live
  call) if it has one, else this shell's ambient `AWS_REGION`/`AWS_DEFAULT_REGION`, else `us-east-1`. Fix-up pass
  M1: the health cache is keyed by `(profile, region)`, not profile name alone -- a verdict cached under one region
  is never trusted under a different one; a region change for the same profile is a cache miss, forcing a fresh
  probe.
- `cprof doctor` gains the same live-validate-and-cache capability for every bedrock profile's recorded
  `AWS_PROFILE` (after the existing `aws configure list-profiles` pre-check from the 2026-10-27 fix-up pass), so a
  plain `doctor` run also keeps the cache warm for profiles a recent `new` never touched — catching drift (a
  profile that worked yesterday and is SCP-denied today) without waiting for the next profile creation. Like `new`,
  a cache hit (either verdict) is trusted with no re-probe.
- `AWS_REGION`/`AWS_DEFAULT_REGION` and the Anthropic model vars are untouched by any of this — only which
  `AWS_PROFILE` value ends up in `profile.env` can change.

### Components

- `tools/claude-profile/cprof-auth-health.zsh` (new file, sourced by `cprof.zsh`; kept separate from
  `cprof-auth.zsh` purely to keep each file under hq's 300-line file-size guidance, the actually-enforced limit
  per `test_cprof-auth.zsh`'s own `a14` assertion -- fix-up pass M6, earlier text here said 200): the health cache
  file `${CPROF_ROOT:-$HOME/claude-profiles}/.aws-profile-health`, one line per `(profile, region)` pair (fix-up
  pass M1), `profile\tregion\tstatus\tchecked_at\tdetail` (`status`: `good`|`bad`; `checked_at`: UTC
  `%Y%m%dT%H%M%SZ`, the same stamp style as `cprof-link.zsh`'s `link-src`) — plain text, no JSON dependency,
  atomic tmp+mv write, `umask 077`, upserting a `(profile, region)` row in place rather than appending a
  duplicate; both the profile name and the detail are sanitized for tabs/newlines before being written (fix-up
  pass M3 -- the profile name wasn't, originally). Functions: `_cprof_aws_profile_region` (the one region rule,
  M2); `_cprof_aws_health_read`/`_cprof_aws_health_write` (cache I/O, `$reply`-convention reads matching
  `cprof.zsh`'s `_cprof_scalars`); `_cprof_aws_health_lookup` (fix-up pass A1: the one accessor the cache-hit and
  live-probe paths both call, used by `_cprof_aws_heal_profile` here and `_cprof_doctor_bedrock_env` in
  `cprof-auth.zsh`, closing a latent reply-arity drift risk between the two); `_cprof_aws_health_latest_good`;
  `_cprof_aws_is_credential_process` (`aws configure get credential_process --profile <p>`);
  `_cprof_aws_raw_sso_sibling` and `_cprof_aws_verify_identity` (fix-up pass B1, see below); `_cprof_aws_classify`
  (the text-matching rule above, isolated and independently testable); `_cprof_aws_bedrock_probe` (the bounded
  live call; classifies and caches `good`/`bad`, never `inconclusive`); and `_cprof_aws_find_substitute` (the
  search order above, shared by `new` and `doctor`).
- `tools/claude-profile/cprof-auth.zsh`: `_cprof_bedrock_snapshot` now runs the `AWS_PROFILE` candidate through a
  new orchestrator, `_cprof_aws_heal_profile` (cprof-auth-health.zsh), before writing it; `_cprof_doctor_bedrock_env`
  consults the cache via `_cprof_aws_health_lookup` (probing and caching on a miss) for each profile whose
  `AWS_PROFILE` already resolves in `aws configure list-profiles`, using that profile's own resolved region
  (`_cprof_aws_profile_region`, M2) rather than `profile.env`'s stored `AWS_REGION` -- WARNing when the
  cached/just-probed verdict is `bad`.
- `tools/claude-profile/cprof.zsh`: one new `source` line for `cprof-auth-health.zsh`; no change to `_cprof_new`'s
  call sequence (still calls `_cprof_bedrock_snapshot` right after writing `auth` = `bedrock`).
- Fix-up pass M4: four `[[ == / != ]]` comparisons in `cprof-auth-health.zsh` whose right-hand side is a profile
  name (a variable, not a literal pattern) now quote that side (`[[ $pn == "$p" ]]`, not `[[ $pn == $p ]]`) --
  unquoted, zsh treats the right-hand side as a glob pattern, so a profile name containing a glob metacharacter
  could have matched the wrong cached row or the wrong exclude check.

### Interfaces (exact messages)

- Substitution found: `cprof: WARN: ambient AWS_PROFILE '<bad>' is denied for Bedrock (<detail>); substituting
  '<good>' instead -- pass a different AWS_PROFILE before 'cprof new' to override`.
- Nothing found: `cprof: WARN: ambient AWS_PROFILE '<bad>' is denied for Bedrock (<detail>) and no working AWS
  profile was found to substitute; snapshotting '<bad>' anyway -- fix its AWS access, or export a working
  AWS_PROFILE, before 'cprof new <name> --auth bedrock'` (the profile is still created, exit 0 — a healing failure
  is a WARN, never a `new` failure).
- Inconclusive: `cprof: WARN: could not validate AWS profile '<name>' for Bedrock (<detail>); snapshotting it as-is
  -- run 'cprof doctor' to re-check later`.
- `doctor`, per bedrock profile whose cached/probed `AWS_PROFILE` verdict is `bad`: `WARN: <name>'s profile.env
  AWS_PROFILE ('<value>') is cached bad for Bedrock (<detail>); see <root>/.aws-profile-health` (plain `print`, no
  `cprof: ` prefix, matching the other `doctor` rows from the 2026-10-27 extension).

### Non-goals

1. No new flag or env var: healing is always-on for `--auth bedrock`, per the owner's "works out of the box"
   requirement.
2. No automated repair of a *stale cached* verdict beyond re-probing on a cache miss: a `good`/`bad` row is trusted
   until something (a later `new` or `doctor` run for a profile with no entry yet) happens to re-probe it. There is
   no TTL/expiry and no `cprof` subcommand to force-invalidate a row; deleting `.aws-profile-health` by hand clears
   it.
3. No change to oauth profiles, to the 2026-10-26 `_cprof_auth_apply` pass-through semantics, or to the tiered
   render's region source.
4. No attempt to suppress or pre-empt a `credential_process` profile's own `aws sso login` retry: a browser prompt
   during the probe is accepted exactly as the owner ruled, never raced or killed by the outer timeout bound.

### Verification

`tools/claude-profile/test_cprof-auth.zsh`: hermetic cases (own isolated `CPROF_ROOT`, a mock `aws` on its own
`PATH` entry answering `configure get credential_process`/`configure list-profiles`/`bedrock
list-inference-profiles` purely from profile-name prefix and env vars, with a call log asserting both which
profiles were live-probed and in what order) cover: a cached-`good` candidate snapshotting unchanged with no live
call; a cached-`bad` candidate with a cached-`good` already available substituting straight from the cache, also
with no live call; a cached-`bad` candidate with nothing cached `good` triggering a live search that tries
non-`credential_process` profiles first and stops at the first `good`, caching every candidate it actually tried;
every candidate exhausted with no `good` found falling back to the broken ambient profile with the unmissable WARN;
an unknown candidate validated live and cached on success; `_cprof_aws_classify` in isolation (`AccessDenied` +
SCP-deny text is `bad`; `ExpiredToken`/`UnauthorizedSSOTokenError`/no-credentials/anything else is `inconclusive`;
exit 0 is `good`); an inconclusive probe writing no cache row; and `cprof doctor` live-validating and caching a
bedrock profile's `AWS_PROFILE` that `cprof new` never touched, then trusting that cache (no re-probe) on a later
run. The full existing suite (`test_cprof.zsh`, `test_cprof-link.zsh`, `test_cprof-checks.zsh`,
`test_cprof-auth.zsh`) passes unchanged.

Fix-up pass additions: `h2c` proves a cached-`good` row under a different region is a cache miss, forcing a fresh
live probe instead of being trusted (M1). `h8`/`h8b`/`h8c` are shaped directly like the real `~/.aws/config` (an
excluded ambient candidate, a raw `-sso` profile that sorts first, and its `credential_process` sibling) and prove
the substitute search returns the sibling, that the raw profile is never itself live-probed (only its sibling is,
via `STUBLOG`), and that a matching `sso_account_id` produces no spurious mismatch WARN -- this is B1's hermetic
proof. `h8d` proves a candidate that fails live identity verification is skipped, not accepted, even though its
Bedrock probe alone said `good`.

A real end-to-end check against the owner's actual AWS setup (browser login explicitly authorized, though none was
needed -- the cached SSO token was still usable) forced `AWS_PROFILE=adx-dev` ambient and ran `cprof new --auth
bedrock` for a scratch profile: `adx-dev` was correctly classified `bad` (the real response was `AccessDeniedException
... User: arn:...assumed-role/AWSReservedSSO_SGWS-SBX-PowerUser_.../Xavier.Thomas@sgws.com is not authorized to
perform: bedrock:ListInferenceProfiles ... with an explicit deny in a service control policy: arn:...`, account
`202533503908`; the classifier matched on the full response, the 220-char-truncated cached detail cuts off before
the "explicit deny" phrase itself) and auto-substituted with `digital-foundations-nonprod-sso` (account
`194872823696` -- the first non-`credential_process` profile in `aws configure list-profiles` order that validated
good; this was the B1 bug a 7-agent pr-review panel later found Blocking -- see Fix-up pass below), with
`.aws-profile-health` afterward showing both verdicts. A second scratch profile created with
`digital-foundations-nonprod-sso` already ambient and cached `good` confirmed the no-op path: `aws` was removed
from `PATH` entirely for that run, and it still succeeded unchanged, proving no live call was made;
`.aws-profile-health`'s `checked_at` for that row was unchanged afterward. Both scratch profiles were removed
afterward; the two real cache rows were deliberately left in place at the time (accurate, useful information, not
test debris) -- the Fix-up pass below re-ran the same real check after the fix and records what changed.

### Fix-up pass (pr-review panel, 2026-10-28): raw-SSO substitution was not a lucky/unlucky coincidence

A 7-agent local pr-review panel (never posted to GitHub) reviewed this extension before merge and returned NOT
READY: 1 Blocking (unanimous), 7 Medium, 4 Advisory, 1 Process/Meta. All were applied in one fix-up commit.

**B1 (Blocking):** the real end-to-end run above wasn't a coincidence of alphabetical sort -- it was close to
deterministic. `_cprof_aws_find_substitute` had no concept of a primary profile vs. an internal raw SSO profile not
meant for direct use, and tried non-`credential_process` profiles before `credential_process` ones purely to avoid
popups; since `digital-foundations-nonprod` (the intended profile) is itself `credential_process`-fronted and
`digital-foundations-nonprod-sso` (its raw, internal-only backing profile, commented "Do NOT use this profile
directly" in `~/.aws/config`) is not, the raw profile was always going to be tried -- and accepted -- first. The
panel rejected a louder warning as sufficient; the fix needed to be structural. Reading the real `~/.aws/config`
confirmed config SHAPE alone cannot distinguish the two: a raw-internal profile (`digital-foundations-nonprod-sso`,
`adx-dev-sso`) and a normal, directly-usable `sso_session` profile (`digital-proofweb-sandbox`, and every
"Additional accounts" profile) have the IDENTICAL field set (`sso_session`, `sso_account_id`, `sso_role_name`,
`region`, `output`) -- there is no shape signal to key off, contrary to one of the panel's two hypotheses. The
signal this file's actual content does support: every raw-internal profile here is named `<base>-sso` with a
sibling profile literally named `<base>` also present in `aws configure list-profiles` (its credential_process
front door). `_cprof_aws_raw_sso_sibling` (cprof-auth-health.zsh) checks exactly that -- name ends `-sso` AND a
distinct `<base>` exists in the profile list -- and `_cprof_aws_find_substitute` now probes that sibling in the
raw profile's turn in the search order instead of the raw profile itself, so the sibling gets first crack at the
slot the raw profile used to win by sorting earlier. This alone is still only a naming-convention heuristic, so it
is paired with a second, independent check per the panel's requirement: `_cprof_aws_verify_identity` runs a live
`aws sts get-caller-identity` on any candidate the Bedrock probe calls `good` before it is accepted as the final
substitute -- a candidate that passes the narrow Bedrock check but fails identity resolution is skipped, not
returned. When the winner came from a sibling swap, the raw profile's own configured `sso_account_id` (a local
config read, not a live call) is compared against the sibling's live-resolved account purely as an informational
WARN if they disagree -- not a hard gate, since there is no general "expected" account id to gate on for an
arbitrary substitute search; this machine's case happens to have one only because the raw profile's own config
carries it. Verified live (not just in the hermetic mock suite -- see Verification below): re-running the exact
scenario above now substitutes `digital-foundations-nonprod`, not `-sso`.

**M1 (region-keyed cache)** and **M2 (one region rule)**: see the `What changes`/`Components` sections above --
the cache key is now `(profile, region)`, and probe/substitution-search/`doctor` all resolve a candidate's region
the same one way (`_cprof_aws_profile_region`).

**M3:** `_cprof_aws_health_write`'s profile-name parameter is now sanitized for tabs/newlines, matching the
existing `detail` sanitization.

**M4:** the four unquoted `[[ == / != ]]` profile-name comparisons in `cprof-auth-health.zsh` now quote the
right-hand side (see `Components` above) -- unquoted, it is a zsh glob match, not a literal string comparison.

**M5:** the `Verified finding` paragraph above already correctly states `digital-foundations-nonprod` IS
`credential_process`-fronted; the error was confined to the old `Known gap` paragraph this Fix-up pass replaces,
which had said the opposite ("Both are non-credential_process") -- corrected by B1's description above, which
states the real relationship and why it made the bad substitution close to deterministic rather than a coincidence.

**M6:** "hq's 300-line file-size guidance" above was previously "200-line" in this doc and in
`cprof-auth-health.zsh`'s own header comment -- corrected to 300, the limit `test_cprof-auth.zsh`'s `a14` assertion
actually enforces for every `cprof*.zsh` file.

**M7:** `tools/claude-profile/README.md` and `tools/onboarding.md` now describe the B1 fix (sibling preference +
live identity verification), not just the always-on substitution feature with no caveat, and no longer claim a
substitute profile has the same account/access as the original ambient one beyond what was actually verified
(Bedrock-list-level reachability, not full IAM parity).

**A1:** `_cprof_aws_health_lookup` is the one accessor both the cache-hit and live-probe paths now call (see
`Components` above), closing the latent reply-arity drift between `_cprof_aws_heal_profile` and
`_cprof_doctor_bedrock_env`.

**A2 (doc-only):** the outer wall-clock bound on the live probe only applies when `timeout`/`gtimeout` is on
PATH -- absent on a bare macOS install by default. Without either, an unbounded hang is theoretically possible;
install one (`brew install coreutils` for `gtimeout`) to get the bound. Noted in `cprof-auth-health.zsh`'s
`_cprof_aws_bedrock_probe` comment; no code change (panel: a doc callout is sufficient).

**A3 (doc-only):** `.aws-profile-health` stores up to 220 chars of raw AWS CLI error text in plaintext
indefinitely -- can include ARNs, SSO session names, account IDs, possibly an email address. Mitigated by
`umask 077` and no network transmission; this file should be excluded from any future log bundling or sharing.

**A4:** not changed -- the hardcoded 180s Bedrock-probe timeout may be tight for a slow SSO+MFA flow; worst case is
a graceful `inconclusive` classification, not a crash. The panel accepted leaving this as-is.

**Process/Meta:** the original commit message claimed "13 new hermetic test cases"; the diff actually added 11
distinct `ok()` assertions (h1, h2, h3, h3b, h4, h5, h6, h6b, h7, h7b, h7c). That commit is not amended (this Fix-up
pass is a new commit on top); no other doc or comment text in this extension repeated the miscount.
