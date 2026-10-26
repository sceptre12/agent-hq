# permission-tiers — executor profiles in bypass, research desks in auto (design record)

One-line summary: every *new* Claude Code profile the owner creates with `cprof` is born into a
tier — **executor** (`bypassPermissions` + a hard deny list + an OS sandbox with a strict
network allowlist; no web tools, no new-dependency installs) or **desk** (`auto` mode; the only
tier that fetches the web, installs new dependencies and plugins, and scans them once) — so
planned work runs unattended without classifier blocks, while prompt-injection exposure is
confined to classifier-guarded seats.

- **Status:** RATIFIED (owner R-3, 2026-10-14: OQ-R option 1 — ratified as written, with the
  Phase-0-driven edits folded in; the option text was the orchestrator's, the owner's words are
  in §Owner rulings). Authored by Fable in the main seat at the owner's instruction (2026-10-12);
  independent doc-reviewer pass 2026-10-12 (0B/5M/6A, applied); Phase-0 measurements
  P0-a/b/c/e/f/g/g2 applied 2026-10-14 — Phase 0 complete, no open measurements. Facts are
  CITED (docs page) or MEASURED (date + evidence file). Amendments go through the ADR (plan P6).
- **Date:** 2026-10-12 (drafted) / 2026-10-14 (ratified)
- **Project record:** `projects/permission-tiers.md`
- **Part 2:** `architecture/permission-tiers-02.md` — the executor deny-list and sandbox
  contract, the desk request grammar, the scan procedure, the ledger format, the Phase-0
  evidence and the template outlines. Split under STANDARDS §13 (~500-line soft default, ADR
  0021); this header governs both parts.
- **Scope ruling (owner, 2026-10-12, verbatim):** "the general architecture for this doesn't
  change what i'm running today its how i'll have new things operate" — binds **new profiles
  only**.
- **Lineage (ADR 0011):** owner direction in session 2026-10-12→14; Claude Code docs
  `permission-modes`, `sub-agents`, `hooks`, `permissions`, `sandboxing`, `security`,
  `cli-reference`, `settings` (fetched 2026-10-12/14; local `claude --version` 2.1.296 →
  2.1.299 on 2026-10-14); brain-group R-ci (`tools/brain/templates/member-CLAUDE.md`,
  `## Web research (owner rule R-ci)` section);
  `architecture/claude-profile.md`, `tools/claude-profile/cprof.zsh`;
  `learnings/unattended-agent-sandbox.md`. Phase-0 evidence files: session scratchpad
  `p0a/P0A-RESULT.md`, `p0b/P0B-RESULT.md`, `p0c/P0C-RESULT.md`, `p0e/P0E-RESULT.md`,
  `p0f/P0F-RESULT.md` (summarised in part 2 §5; copied into hq at P6).

## What This Is

The owner, 2026-10-12 (verbatim): "I want to be able to make having these agents run
autonomously in dangerously skip permission mode while also having other agents that can be used
that can handle the more dangerous and suceptable commands" / "the agents that are essentially
executing on the plans to run in dangerous appproved mode. But any agent that needs to reach out
to the internet for research that should run in auto mode since thats where there is more likely
to be exposed to prompt injections" / "libraries that are loaded locally could have prompt
injected commands so the first time they are downlaoded the agent with auto mode should do that
security scan but after that it should be safe for the other agents to work on in dangerous
execute mode. Additionally we can assume the libraries already on the system are safe" / "i do
have the ability to use the tool cprof that can create new profiles for work. So that should
also be factored since thats whats used when i'm going to create a new agent".

| Tier | Permission mode | Web tools | New-dependency installs | Network | Who |
|---|---|---|---|---|---|
| **executor** | `bypassPermissions` | removed (`permissions.deny`) | denied (`permissions.deny`) | sandbox strict allowlist: localhost + `api.anthropic.com` (+ overlay) | every new work profile and every subagent it spawns |
| **desk** | `auto` (classifier-gated) | present | performs them, scans once, writes the trust ledger | unrestricted (classifier + tool-result probe) | generic `desk` + specialised `desk-<domain>` (R-1) |

The owner's own interactive seat is outside the tiers.

## Why the split must be at the process level (CITED `sub-agents`, `permission-modes`)

- A subagent spawned with the Agent tool cannot run `bypassPermissions` unless the main
  conversation already does; a bypass/`acceptEdits`/`auto` parent forces its mode on every
  subagent and frontmatter `permissionMode` is ignored.
- So the tier is a property of the **process** (`claude` invocation + `CLAUDE_CONFIG_DIR`); a
  cprof profile is exactly one `CLAUDE_CONFIG_DIR` (`cprof.zsh:129`). The profile *is* the tier
  boundary, which is why cprof is the enforcement point.
- `permissions.deny` binds in every mode including bypass (CITED; MEASURED P0-c R1/R2/R4).
  `allow` has no effect in bypass. The executor contract is a deny list, never an allow list.
- Deny rules and the sandbox are session-wide; an executor's subagents inherit both. The whole
  tree is executor-tier.

## Components

1. **Tier fragments** — `config/tiers/executor.json`, `config/tiers/desk.json` (hq,
   versioned): partial settings objects (`permissions.deny`, `sandbox`,
   `skipDangerousModePermissionPrompt`, `_tier`). Part 2 §1 is the executor contract.
2. **Tier overlays (optional, per project)** — `config/tiers/overlays/<project>.json` + README:
   extra denies and extra sandbox allowances a project needs (e.g. the brain members'
   `mcp__supabase` + `Bash(supabase:*)` denies at
   `~/claude-profiles/<brain-profile>/config/settings.json:155-156`; `allowMachLookup` for iOS
   Simulator work; extra `allowedDomains` for a local Supabase).
3. **cprof tier verbs** (`tools/claude-profile/cprof.zsh`; Rule 10: PR + mapped tests,
   `test_cprof.zsh`, `tools/code-gate/test-map.tsv:8-9`):
   - `cprof new <name> --tier executor|desk [--overlay <project>]` — keeps today's hidden token
     prompt (R-2); renders `config/settings.json` = jq-merge(`hq/config/settings.json`, tier
     fragment, overlay, `claudeMdExcludes`); writes `<profile>/tier` and `<profile>/tier.src`
     (sha256 of each input); installs the tier's `CLAUDE.md` template into `workspace/`.
     `--tier executor` renders `<owner>` from `CPROF_OWNER` (a GitHub account name, `[A-Za-z0-9-]`); it fails closed if `CPROF_OWNER` is unset, empty or malformed.
   - `cprof launch <name> [-- <claude args>]` — the `use` environment (`cprof.zsh:128-135`)
     plus the tier flag: executor → `--dangerously-skip-permissions`; desk →
     `--permission-mode auto`; plus `--settings '{"crossSessionInbound":"accept"}'` (MEASURED in
     brain-group: `brain.zsh:31` defines `ACCEPT`, `:231-234` pass it); then `exec claude`.
     Refuses the opposite tier's flag in `-- args`. Headless: `-- -p "<prompt>"`.
   - `cprof sync <name>` — re-renders; refuses on hash mismatch unless `--force`.
   - `cprof doctor` — tier row: tier file, render hash, executor deny + sandbox present.
   - `cprof trust ls|baseline` — the trust ledger (part 2 §4).
4. **Desk profiles** — generic `desk` (created once, `cprof new desk --tier desk`) plus
   specialised `desk-<domain>` (R-1); long-lived interactive sessions, one tab each (shape of
   brain-router, `architecture/brain-group.md` §Components). `workspace/CLAUDE.md` from
   `tools/claude-profile/templates/desk-CLAUDE.md` (seeded from
   `tools/brain/templates/router-CLAUDE.md:66-68`) with a `## Specialisation` section. A desk
   answers `RESEARCH` and `INSTALL` requests and a `STATUS` probe (part 2 §2).
5. **Executor CLAUDE.md template** — `tools/claude-profile/templates/executor-CLAUDE.md`
   (seeded from the token-rule, stall-watchdog and R-ci sections of `member-CLAUDE.md`, cited
   by heading — that file's line numbers moved between 2026-10-12 and 10-14); outline part 2 §6.
6. **Trust ledger** — `~/claude-profiles/_trust/ledger.jsonl` (machine-local, outside hq,
   append-only; part 2 §4; documented in `tools/trust/README.md`). One `BASELINE` row records
   the owner's "already on the system is safe" ruling.
7. **Scan procedure — a desk-executed checklist (part 2 §3), not a tool (R-6)** — fetch with
   lifecycle scripts disabled → advisory (`osv-scanner`, `pip-audit`, R-4) → lifecycle-script
   review → tool-less content pass → real install → ledger rows.

## Interfaces

### Settings render (D2)

```
hq/config/settings.json          (shared allow/hooks/autoMode — unchanged by this work)
  + hq/config/tiers/<tier>.json  (deny, sandbox, skipDangerousModePermissionPrompt)
  + hq/config/tiers/overlays/<project>.json   (optional extra denies / sandbox allowances)
  + claudeMdExcludes             (existing _cprof_apply_excludes, cprof-checks.zsh:7-34)
  = <profile>/config/settings.json   (regular file; input hashes in <profile>/tier.src)
```

Merge: scalars — later wins; `permissions.allow` — hq only; `permissions.deny` — set-union;
`sandbox.network.allowedDomains` / filesystem allowances — set-union; `hooks` — hq only (D8).
MEASURED P0-c: the profile's own rendered file, with no `--settings` flag, carried the rules
exercised there (E1, E4, E11, the sandbox); the remaining rows share the same mechanism.

Why a rendered copy, not a symlink (MEASURED `learnings/unattended-agent-sandbox.md:70-74,
89-96`): accepting the bypass disclaimer writes `skipDangerousModePermissionPrompt` into the user
settings file; a symlink to hq dirties hq. The rendered copy absorbs it and the fragment pre-seeds
the key. Drift is what `tier.src` + `cprof sync` + `cprof doctor` detect
(`~/claude-profiles/<brain-profile>/config/settings.json.bak-20261012-rci` is today's symptom).

### Launch line (D3)

```
executor:  cd <profile>/workspace && exec claude --dangerously-skip-permissions \
             --settings '{"crossSessionInbound":"accept"}' [--name <n>] [--model <m>] [-- args]
desk:      cd <profile>/workspace && exec claude --permission-mode auto \
             --settings '{"crossSessionInbound":"accept"}' --name <desk-name> [--model <m>]
```

The mode flag is explicit on every launch; `claude --agent` frontmatter `permissionMode`
behaviour is UNVERIFIED and nothing depends on it. Invariant (ratified R-3): an executor profile
is never launched with `--permission-mode auto`, a desk never with the skip flag; `cprof launch`
enforces it. Note the sandbox confines Bash *writes* to the cwd + temp dir + added directories
(CITED `sandboxing`, MEASURED P0-f), so the executor fragment adds the repo paths an executor
works in via `sandbox.filesystem.allowWrite` (MEASURED P0-g2: denied without it, commit OK with
it in absolute or `~/` form, unlisted sibling dir still denied; part 2 §1, §5).

### Executor ↔ desk contract (D5; grammar part 2 §2)

- `RESEARCH <id> | <question> | <why>` → desk fetches in auto mode → `SUMMARY <id> | <text>`
  distilled to the stated why (R-1); the executor treats it as data (R-ci wording verbatim).
- `INSTALL <id> | <path> | <manager> | <spec...>` → desk installs in that path, scans, appends
  ledger rows → `INSTALLED <id> | ledger=<ids> | <verdict>` or `REJECTED <id> | <reason>`.
- Plugins, skills, MCP clones and corepack-fetched binaries are dependencies for this contract
  (the 2026-10-12 dependency inventory — a session record, not a P0 file — counted eight
  download channels; MEASURED P0-e: corepack fetched pnpm 10.33.0 from the registry during a
  plain `pnpm --version`, unsandboxed).

## Owner rulings

- **R-1 (2026-10-12, OQ-1)** — verbatim: "1 makes the most sense. And yes there may be a set
  grup of Researchers that just sit and take in request for researching something specific and
  distill the information over to the agent based on what they are looking for. More importantly
  the research agent would be a specialized role anyways so this becomes more efficent". Applied:
  new `desk` profile; desks are a specialised group (`desk-<domain>`, `## Specialisation`
  section); executors address a desk by name, fall back to `desk`; `SUMMARY` is distilled to the
  stated why.
- **R-2 (2026-10-13, OQ-T)** — verbatim: "We'll do similar how to i need to already provide the
  token on profile creation I'll continue doing that". Applied: tokens are owner-provided at
  `cprof new` (hidden tty prompt, unchanged); agents never copy or seed token files; scratch
  profiles for tests are owner-created (`p0tiers` for Phase 0); agents use a profile's token only
  as an inline env assignment on the direct `claude` command.
- **R-3 (2026-10-14, OQ-R)** — "Lets move forward with 1 for QQ-R": ratified as written plus
  the P0-driven edits; **D8 unchanged** (the D8′ content-inspecting hook was offered and not
  taken; the P0-a fact stays on record in D8).
- **R-4 (2026-10-14, OQ-3)** — "QQ-3 yes" (option 1): a desk installs `osv-scanner` and
  `pip-audit` via Homebrew (P4); first non-BASELINE ledger rows.
- **R-6 (2026-10-15, verbatim)** — "Yes lets purefully focus on the initial ask. And we have to stop expanding scope that continually causes drifts waste time and money and ends up causing more issues." Applied: scan descoped to a desk procedure; PR #52 closed unmerged; no further scope additions to this campaign without an owner ruling.
- **R-7 (2026-10-17, verbatim)** — "an EWxecutor should be able to push to github and read only from approved github accounts and i can modify that approval list in the executors chat" [sic]. (i) Panel finding F5 is answered: `github.com` joins the executor base `allowedDomains` (`config/tiers/executor.json`; part 2 §1). (ii) The account-level read restriction and where the approval list lives are OPEN: enforcement mechanism pending owner choice (OQ-5 — closed by R-9, 2026-10-21): sandbox allowlist is host-level, so account restriction needs either a PreToolUse hook (would amend D8) or a template rule. CITED facts (2026-10-17, docs: https://code.claude.com/docs/en/sandboxing, https://code.claude.com/docs/en/settings-reference): `allowedDomains` is host-level only (the proxy enforces by requested hostname and by default does not terminate or inspect TLS), so `github.com` admits every GitHub account; the docs' "plain `ssh`/`scp`/`rsync` over SSH fail" sentence is STALE: measured 2026-10-21 (P5 probes 3 and C2, 2.1.306) SSH works to an allowlisted host and is refused for a non-allowlisted one (part 2 §1).
- **R-8 (2026-10-21, verbatim)** — "What was this trying to accomplish? because the goal is to have two seperate profiles where the profile with the bypass mode does all the work without needing to ping me everytime for the ability to do work based on a plan.

The profile with auto mode is allowed to search the internet but it pings me on things it things are dangerous but the bypass persmission agent is able to talk to the auto mode agent and they can go back and forth with each other... Thats it" [sic]. Context (facts): P5 e2e 2026-10-21 — the desk's step-4 nested `claude -p --tools "" --model claude-haiku-5-5` content read failed inside the desk session ("Not logged in"); the desk's auto-mode classifier then denied both an env credential count and a `cprof use desk`-wrapped retry as "[Credential Exploration]", also when the owner instructed it in the tab. Consequence ruled: step 4 is the desk's OWN read, no nested CLI, no subagent, no credentials (part 2 §3).
- **R-9 (2026-10-21, verbatim)** — "We dont need to over enforce that part and I want us to stay within scope" → OQ-5 closed: the approved-accounts list is a line in the executor template (`tools/claude-profile/templates/executor-CLAUDE.md`), obeyed by the executor and edited by the owner in the executor's chat; no hook, D8 unchanged.
- **R-10 (2026-10-21, verbatim)** — "qq-6 1" (OQ-6, option 1) → `Bash(npm install *)`, `Bash(npm i *)`, `Bash(pnpm install *)` dropped from the executor tier; executors restore lockfiles from local cache; the sandbox allowlist stays the hard line against new downloads; `add`/`dlx` denies kept.
- **OQ-2** closed by evidence (P0-b/P0-c): egress control works in bypass; E3 dropped.

## Decisions D1–D10 (ratified R-3)

### D1 — Two tiers, not three
Executor + desk. An owner-facing auto orchestrator is prior art; a new one is a
desk-tier profile with an overlay.

### D2 — Tier lives in cprof, as a rendered settings file with a provenance hash
As §Interfaces. Rejected: `--settings`-file layering on a symlinked profile (symlink-dirties-hq
stays); hand-copied settings (no drift detection).

### D3 — Launch flag comes from the tier file, never typed by hand
`cprof launch` is the sanctioned launch for tiered profiles; `cprof use` stays for shells that
need the environment. `tools/brain/brain.zsh:193-194` keeps its own flags (not migrated).

### D4 — Executor enforcement: deny rules + OS sandbox with strict network allowlist (MEASURED)
- Deny rules bind in bypass: `WebFetch` absent from the tool list (P0-c R1); `cd … && pnpm add`
  denied (R2); path-scoped `Edit` denied (R4).
- Bash pattern denies are evaded by wrapping: `zsh -c 'pnpm add left-pad'` matched no rule
  (P0-c R3) — and the sandbox blocked it: `deny network-outbound registry.npmjs.org:443`.
- Sandbox keys (CITED `sandboxing`, MEASURED P0-b): `sandbox.enabled`,
  `network.allowedDomains`, `network.strictAllowlist: true` (CITED: refuses in every mode;
  MEASURED in bypass — P0-b run 2),
  `permissions.deny: ["Bash(dangerouslyDisableSandbox:true)"]` (harness-denied the retry hatch
  in bypass, no prompt — run 5), `allowUnsandboxedCommands: false` (belt-and-braces — run 4 was
  model-declined, not harness-isolated), `network.allowLocalBinding: true` (P0-f: without it
  `bind()` is EPERM; with it a local server bound and served under the strict allowlist).
- Without `strictAllowlist` an allowlist is advisory in bypass (run 1 reached example.com); the
  hatch "runs without a prompt" (run 3). Both are why the three keys ship together.
- E3 (`curl`/`wget` pattern deny) is dropped: the network layer does the job without breaking
  local curls. Sandbox covers shell commands only; file tools, MCP servers and hooks run outside
  it (CITED) — hence the deny rules remain the enforcement for those.

### D5 — Desks are a group; `desk` is the default
Ruled by R-1. brain-router keeps serving brain members (R-ci).

### D6 — First-download scan: a desk procedure (R-6)
v1 is the procedure in part 2 §3, executed by the desk by hand; there is no scan tool (R-6,
2026-10-15). The Fable finding (T1/T2 verdict REDESIGN) was that install-then-scan runs the
hazard first, hence fetch-first (lifecycle scripts disabled) is step 1. MEASURED P0-e: npm 10.9.2
runs `postinstall` by default; pnpm 11 does not (no warning); pnpm 9.x repos have no protection.

### D7 — Trust ledger is an audit record, not an enforcement input
Executors cannot install (D4); the ledger records what a desk cleared and the BASELINE row.
Outside hq. Amended for the ledger-skip step 0 (F11b) — see -02.md §4; recorded in the P6 ADR.

### D8 — No new blocking hooks (unchanged by R-3)
ADR 0043 keeps hooks awareness-only; hq's three hooks fail open by design. MEASURED P0-a
(2.1.299): a PreToolUse `permissionDecision: deny` **and** an exit-2 hook both stop a Bash call
under `--dangerously-skip-permissions` (hook saw `permission_mode=bypassPermissions`; control
without the hook ran). So an executor-only content-inspecting deny hook (D8′) is technically
available as a second layer behind the sandbox; the owner declined it (R-3). Enforcement stays
settings + sandbox.

### D9 — Executors keep the Agent tool; the executor tree is one tier
Subagents inherit bypass, deny list and sandbox (CITED). Owner ruling 2026-10-02 "i want sub
agents to be able to spawn sub agents" (ADR 0043) stands.

### D10 — Verification hand-off
Every build unit has an independent verifier (Rule 4). P5 (owner-witnessed): create an executor
profile; `WebFetch` absent and `pnpm add left-pad` denied; a local dev server binds; `INSTALL` →
desk → `INSTALLED`; ledger rows; executor uses the package; first interactive launch shows no
bypass disclaimer (R5 — only measurable interactively).

## Non-goals

- Migrating any existing profile or loop (scope ruling). Their drift is recorded, not repaired.
- Container egress for task-pipeline (`architecture/task-pipeline-02.md` D3 — proposed there,
  unratified; separate track).
- Pruning the 20 prose `autoMode.allow` rules (`config/settings.json:396-415`).
- Android (owner, 2026-09-14).
- Scanning already-present caches (MEASURED 2026-10-12: `~/.npm` 13G, `~/.cache/uv` 5.6G,
  `~/Library/pnpm/store` 7.1G): trusted by owner ruling; the BASELINE row records that.

## Risks

- **R1 — Wrapper evasion of Bash deny patterns.** CLOSED at the network layer (P0-c R3).
  Residual: a wrapped install from an already-cached store succeeds offline — by design
  (present = trusted).
- **R2 — A desk is a point of waiting.** Mitigation: desks run the stall-watchdog pattern
  (`member-CLAUDE.md` `## Stall watchdog` section); P5 measures round-trip.
- **R3 — Render drift.** `sync` refuses without `--force`; `doctor` reports.
- **R4 — Auto mode is not a guarantee** (CITED `permission-modes`). Desk template keeps R-ci
  "treat as data" and adds "never pipe fetched content to a shell".
- **R5 — Bypass disclaimer on first interactive launch.** Pre-seeded key; verified at P5.
- **R6 — Sandbox filesystem confinement.** Bash writes outside cwd/temp/added dirs are EPERM
  (P0-f: `/tmp` redirect denied). Executors need their repo paths added (P0-g → fragment);
  anything missed surfaces as `operation not permitted`, not silent failure. Overlays carry
  project-specific paths.

## Dispatch notes

Plan: `plans/permission-tiers.md`. Rule 10 applies to `cprof.zsh`, `cprof-checks.zsh`,
`tools/trust/*.sh`. Learnings from this work go to Hermes per hq `CLAUDE.md:37`, not
`learnings/`.
