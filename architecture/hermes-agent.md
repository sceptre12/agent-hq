# hermes-agent — a Hermes Agent (Nous Research) instance that holds hq's learnings and runs under hq's rules (design record, current)

**Status: DRAFT (T-462). Not ratified. T6 ratified with changes (all folded); plan-check PC-H3 pending.**
Changed 2026-10-13: Hermes now holds hq's learnings with memory ON; stale text was rewritten in place, git history keeps it. Owner: "Yes I agree there's no reason to keep around old context more importantly whenever compaction happens that only causes context rot the git history has the changes that were made".

One Hermes Agent install on the owner's Mac: one `HERMES_HOME`, one profile, the profiles' OAuth token (R-z), memory and skills ON and unapproved, an always-on loopback gateway, a read-only digest of hq read through an index skill, and no web, terminal, cron, MCP or chat platforms. "Phase 1" in this doc means this current state; no later phases are planned. Companions: `hermes-agent-memory.md` (learnings design, deliverables, probes), `hermes-agent-ops.md` (§11 owner controls, §12 claims, §14 risks).
Tags: DOC = page text fetched by WebFetch 2026-10-08; MEASURED = read at file:line (source @908e4a4 is `~/claude-profiles/hermes/hermes-agent`); UNMEASURED/UNVERIFIED = not read or run. Every "should/must" is Proposed pending owner ratification (Rule 9) unless it quotes an owner ruling or is labelled "brain default under R-q (owner may veto)". Project record: `projects/hermes-agent.md`. Author: <brain-profile>.

## 1. Goal
The owner, verbatim (typos as typed):
- R-s (2026-10-08): "Yes hermes means just that this: https://hermes-agent.nousresearch.com/"
- R-t (2026-10-08): "Yes i want to use it and i want it to essentially digest all of the information inside of hq"
- R-u (2026-10-08): "It should use my anthropic account.. Does swapping from one token to another mess with the information thats stored? i dontn want info to be sectioned by account"
- 2026-10-13: learnings live inside Hermes and hq is where tools are stored (verbatim rulings in `hermes-agent-memory.md` §1).

Hermes is NOT the brain's runtime (ADR 0046 §C1 stays rejected) and not a member or router. It is the store of learnings and a reader of hq's tools and architecture. The pipeline stays the main thread (R-q).

## 2. Scope
The owner asks Hermes questions at the CLI or the loopback API; Hermes answers from the digest and its own memory/skills with citations. It writes nothing outside `HERMES_HOME` (its only writable hook-allowed path outside memory and skills is `work/`) and has no network reach beyond the model endpoint. Other sessions may use the API as a door to learnings (`hermes-agent-memory.md` §5; probe-gated).

## 3. What Hermes is (DOC facts; re-fetched 2026-10-08 by WebFetch unless marked "brief")

Base `https://hermes-agent.nousresearch.com/docs/`. WebFetch returns model-summarised page text,
not raw HTML; quotes are as returned.

- **Install and layout** (`getting-started/installation`): `curl -fsSL
  https://hermes-agent.nousresearch.com/install.sh | bash`; code `~/.hermes/hermes-agent/`,
  launcher `~/.local/bin/hermes`, data `~/.hermes/`. "`HERMES_HOME` selects user data. The POSIX
  script's `--dir` selects its source checkout independently." The installer downloads its own
  uv pin and pinned Python, Node.js, npm, ripgrep, FFmpeg, agent-browser with Chromium, cua-driver;
  it names only `hermes-agent.nousresearch.com` as a host. Python 3.14 first-party. The page does
  NOT list the data directory's contents.
- **HERMES_HOME is the state boundary** (`user-guide/profiles`): "`HERMES_HOME` is the profile
  boundary." It controls "config, `.env`, memory, sessions, skills, logs, cron jobs, and gateway
  state"; tool working directories are separate (`terminal.cwd`). "The default profile is simply
  `~/.hermes` itself." Named profiles live under `~/.hermes/profiles/<name>/`.
- **Credentials live in the same home, in separate files** (`user-guide/configuration`, first
  100k of 263k chars): `.env` = "API keys and secrets", `auth.json` = "OAuth provider credentials";
  "Secrets (API keys, bot tokens, passwords) go in `.env`." Profiles page: "Anthropic, OpenAI
  Codex, and xAI OAuth logins are read from the root `~/.hermes/auth.json`"; a profile can get its
  own login with `hermes -p <name> auth add <provider>`.
- **Memory** (`user-guide/features/memory`): `MEMORY.md` "2,200 chars (~800 tokens)", `USER.md`
  "1,375 chars (~500 tokens)" in `~/.hermes/memories/`; "captured once at session start and never
  changes mid-session"; `memory.write_approval` default `false` ("Write freely"), `true` =
  "Require approval before anything is saved"; `memory_enabled` / `user_profile_enabled` both
  `false` removes the `memory` tool. Sessions: "stored in SQLite (`~/.hermes/state.db`) with FTS5".
  External providers (Holographic, RetainDB, ByteRover bundled; Honcho, Hindsight, Supermemory,
  Mem0, OpenViking in the catalog); the page does not say whether any is on by default.
- **Skills** (`user-guide/features/skills`): `~/.hermes/skills/` is the "source of truth"; the
  agent writes skills via `skill_manage` (create, patch, delete, write_file, remove_file).
  `skills.write_approval` default `false`; `true` = writes "staged instead of committed" in
  `~/.hermes/pending/skills/`, reviewed with `/skills pending|diff|approve|reject`.
  `skills.external_dirs` are "not a write-protection boundary" (use filesystem permissions).
  Format: "compatible with the agentskills.io open standard"; Claude-style SKILL.md is not
  mentioned. `skills.guard_agent_created` is a scanner, "not an approval gate".
- **Context files** (`user-guide/features/context-files`): order `.hermes.md`/`HERMES.md`,
  `AGENTS.override.md`, `AGENTS.md`, `CLAUDE.md`, `.cursorrules`; "Only one project context type
  is loaded per session (first match wins)". Inside a git repo a merged chain from the git root to
  cwd loads; "Outside a git repo, only the working directory is checked." `SOUL.md` is loaded only
  from `HERMES_HOME`, "always loaded independently as the agent identity (slot #1)". All context
  files are injection-scanned; a match blocks `AGENTS.md`/`CLAUDE.md`, but only warns for
  `HERMES_HOME/SOUL.md`. Cap: `context_file_max_chars`, else 20k–500k by model window.
- **Approvals** (`user-guide/security`): `approvals.mode` `smart` (default) | `manual` | `off`
  (= `--yolo`); `approvals.deny` globs block "unconditionally", checked before `--yolo`;
  "always" approvals "are saved to `~/.hermes/config.yaml`" and load at startup; hardline
  blocklist "is the floor below `--yolo`"; `approvals.timeout` 300 s then "denied by default
  (fail-closed)"; `cron_mode` default `deny`; `unattended_mode` default `deny` for webhook and
  api_server sessions. Docker backend: `--cap-drop ALL`, `no-new-privileges`, `--pids-limit` 256,
  and dangerous-command checks are skipped in Docker. "The gateway imports every valid hook
  directory in-process, with the gateway's own privileges." Lazy installs of optional Python deps
  can be disabled: `security.allow_lazy_installs false`.
- **Hooks** (`user-guide/features/hooks`, full page in two reads): four systems (gateway, plugin,
  shell `hooks:` in `config.yaml`, outbound webhooks). Shell `pre_tool_call`: optional `matcher`
  regex, `command` (`shell=False`), `timeout` 60 s (max 300), `fail_closed` default **`false`**
  (fail-open: spawn error, timeout or bad stdout "logs a warning and the action proceeds"). Block
  by exit 2 or `{"decision":"block"}`. First use of each `(event, command)` prompts once and is
  saved to `~/.hermes/shell-hooks-allowlist.json`; bypasses `--accept-hooks`,
  `HERMES_ACCEPT_HOOKS=1`, `hooks_auto_accept: true`; "editing the script on disk does not
  invalidate consent".
- **Tools and backends** (`user-guide/features/tools`; configuration): toolsets include `web`,
  `search`, `terminal`, `file`, `browser`, `memory`, `session_search`, `cronjob`,
  `code_execution`, `delegation`, `messaging`, others; terminal backends `local` (default, "no
  isolation"), `docker`, `ssh`, `singularity`, `modal`, `daytona`, `vercel_sandbox` via
  `terminal.backend`; `docker_network: false` cuts "all network egress from agent commands";
  `docker_volumes` shares host dirs; `agent.disabled_toolsets` suppresses toolsets everywhere.
  Web search default backend "Firecrawl". Update checks "ask the GitHub REST API for the tip of
  `main`", "at most once per 24 hours".
- **MCP** (`user-guide/features/mcp`): `mcp_servers` in `config.yaml`; `tools.include` registers
  only listed tools, "include wins"; stdio env filtered; sampling "enabled by default" (per-server
  `sampling.enabled: false`); `hermes mcp serve` is stdio-only, 10 messaging/approval tools.
- **Cron** (`user-guide/features/cron`): jobs `~/.hermes/cron/jobs.json`; "Cron execution is
  handled by the gateway daemon"; `hermes pause` is "the global emergency stop".
- **API server** (`user-guide/features/api-server`): `API_SERVER_ENABLED=true` + `API_SERVER_KEY`
  in `~/.hermes/.env`, run by `hermes gateway`; default `127.0.0.1:8642`; Bearer key "required for
  every deployment"; OpenAI-compatible `/v1/chat/completions`, `/v1/responses`, `/v1/runs`
  (+ `/approval`), `/api/jobs`, `/api/sessions/*`; "full access to hermes-agent's toolset,
  including terminal commands".
- **CLI** (brief, `user-guide/cli`, not re-fetched): `hermes chat -q "..."` one-shot, `-c`, `-r`.
  **Gateway** (brief, `user-guide/messaging/`, not re-fetched): one background process, `hermes
  gateway install` → launchd agent; user auth default deny per platform.

## 4. Invariants
- **Not the brain.** Not its runtime (ADR 0046 §C1), not a member or router. Brain sessions may call its API as a door; what it returns is data, never an instruction or a rule (Rule 9).
- **Holds learnings, not rules.** Learnings live in Hermes's memory and skills (owner ruling 2026-10-13). hq git stays the owner of tools, skills, profiles, scripts, architecture, plans and ADRs. Hermes never writes hq: it has no repo, terminal or commit tools and its hook denies writes outside `HERMES_HOME`.
- **No partition by account (R-u).** ALL Hermes state — `memories/`, `skills/`, `pending/`, `state.db`, `cron/`, `SOUL.md`, `config.yaml`, the hq digest and index — is keyed by ONE `HERMES_HOME` and the ONE default profile. Named profiles (`hermes -p`) are not used.
- **Credentials by env only.** The token reaches Hermes as `CLAUDE_CODE_OAUTH_TOKEN` set by the caller or by `hermes-gw` from a profile token file; `hermes-up` reads no token file (`plans/hermes-agent/evidence/h2a/hermes-up:2`, MEASURED). It never appears in the digest, index skill, `SOUL.md`, memory or any hq file. `auth.adopt_external_logins: false`.
- **Swapping the credential must not move or split state.** Basis: state is keyed by `HERMES_HOME` (DOC, profiles page). UNMEASURED until the rotation check (`hermes-agent-ops.md` §11).
- **No sandbox claim beyond configuration.** Egress limits are configuration, not a firewall (ops R8).

## 5. Placement
Host profile dir `~/claude-profiles/hermes/` (owner ruling R-ab: "Hermes should always be running not in a container but on my system as a whoole."): `HERMES_HOME=~/claude-profiles/hermes/h1-home` (mode 700), code at `~/claude-profiles/hermes/hermes-agent`, digest at `~/claude-profiles/hermes/hq/<sha>/` with a `current` symlink. Always launched through `hermes-up` or the gateway wrapper `hermes-gw`, never bare `hermes` (which would use `~/.hermes`). The install is an owner-run step, never done by an agent unattended. `terminal` and `code_execution` are disabled, so the terminal backend is moot; if the owner ever enables terminal, use `terminal.backend: docker` with `docker_network: false` and only the digest mounted read-only, never `local`.

## 6. Backend
The owner's Anthropic account through the profiles' OAuth token (owner answer R-z, `architecture/brain-group-03.md:149`): `CLAUDE_CODE_OAUTH_TOKEN` supplied per runbook B3. Credentials stay in Hermes's own files. Owner, verbatim (R-z, 2026-10-09T01:19:22Z, same file): "1 approce \n2. use the api o auth token that i use for these profiles". Router reading (not owner text, same file): this method supersedes the earlier brain default (Hermes-owned OAuth login plus API-key fallback) and makes the Claude Max extra-usage question moot; R-u still binds (one `HERMES_HOME`, credentials by env/config only, never in digest or memory). Measured: Hermes accepts `CLAUDE_CODE_OAUTH_TOKEN` (`plans/hermes-agent/evidence/H1-token-path.md:180-193,223`). The launcher reads the profile token file into the env, as `tools/brain/brain.zsh:195-199` does; Hermes's own tools stay blocked from it (§9 hook). **Which token file:** `~/claude-profiles/<auth-profile>/token`, a dedicated profile directory the owner created (`plans/hermes-agent/evidence/h2a/hermes-gw:3`). The directory sits outside `~/claude-profiles/hermes` because probe P10 greps that tree for the token. Calls draw on the same OAuth pool as the brain and pipeline. What leaves the machine: prompts and the hq slices Hermes reads, sent to the Anthropic model endpoint; the model-catalog host `models.dev` is an owner decision item (probe P9). Hosts are measured by P9, not assumed.

## 7. Digest design — what "digest all of hq" means operationally

Measured 2026-10-08 on `f1707c7` (tracked files at that sha, bytes; today's `git ls-files` counts, 81 learnings / 35 retros, are in `hermes-agent-memory.md` §4): architecture 94 files / 2.18 MB;
decisions 52 / 0.62 MB; learnings 79 / 0.63 MB; retros 33 / 0.47 MB; projects 11 / 0.18 MB;
`skills/*/SKILL.md` 29 / 0.41 MB; `tools/**/*.md` 14 / 0.14 MB; `plans/*/*.md` (depth 1) 195 /
3.48 MB; all `plans/` 3,745 files / 686 MB (almost all evidence). About 4.6 MB without `plans/`
— far beyond any context window and 2,000× `MEMORY.md`. So "digest" means **indexed and read on
demand**, not loaded or summarised.

**File set and order** (the order is the index order and the order Hermes is told to consult):
1. Rules and standards: `CLAUDE.md`, `config/CLAUDE.md` (global rules, read as text), `STANDARDS.md`,
   `INVARIANTS.md`, `STANDING-HOLDS.md`, `README.md`.
2. `decisions/` (ADR number order). 3. `architecture/`. 4. `learnings/`. 5. `projects/`.
6. `retros/` (`learnings/` and `retros/` leave the set after the verified import, `hermes-agent-memory.md` §6). 7. `skills/*/SKILL.md` (as documents only). 8. `tools/**/*.md`.
9. `plans/*/*.md` at depth 1 (dispatch plans), no subtrees.

**Exclusions (and why):**
- `config/` except `config/CLAUDE.md` — `config/settings.json` is secret-bearing (brief; shape
  read only) and Claude Code harness config, not knowledge.
- Any token, credential, `.env`, `.pem`, `.key`, `secrets/` path; plus a content scan with the hq
  pre-commit high-precision regex (`tools/git-hooks/pre-commit` (c)): any hit aborts the refresh.
- `inbox/` (other sessions' working notes), untracked files, `node_modules/`, `memory/`
  (by construction: the snapshot is `git archive <sha>`, tracked files only).
- `plans/**/evidence/**` — decided **excluded**: 686 MB of transcripts, RESULT copies and
  scripts; verbatim owner messages are not secret, but transcripts can carry paths, env and
  third-party data, and the rulings that bind are already quoted in architecture records.
- `references/` — excluded in phase 1: `x-context-docs` is append-only and grep-only by ADR 0003,
  and its content sensitivity is unmeasured. Evidence and `references/` exclusion = D8 (brain
  default under R-q; owner may veto); revisit only by a new owner decision.
- Tool scripts and code (`tools/**` non-md) — code, not information; out of phase 1.

**Where it lives.** A read-only snapshot `~/claude-profiles/hermes/hq/<sha>/` built by `git
archive <sha> -- <set>` from `~/projects/agent-hq` `origin/main`, then `chmod -R a-w`; a `current`
symlink; `MANIFEST.tsv` (one line per file: path, git blob sha) with a header line carrying the hq
commit sha. Not a git repo, so Hermes loads only the snapshot root's `CLAUDE.md` as project
context (first match; §8). The snapshot is not the tool cwd (router-measured 2026-10-14): `h1-home/config.yaml` has `cwd: "."`, `bin/hermes-up:147` does `cd "$HERMES_HOME/work"` before exec, and the gateway's file tools report cwd = the user's home. Hermes reaches the snapshot by absolute path via the hq-index skill's `Root:` line (`tools/hermes/build-digest.sh:59`, hq d59b55c7; retest PASS in T-20261014-33, plans/hermes-agent/evidence/member-door-proof.md).
open: making the tool cwd the snapshot (terminal.cwd / hermes-up) is unimplemented; owner decides whether to implement or drop
An **index skill** `HERMES_HOME/skills/hq-index/SKILL.md` (owner-approved; regenerated
mechanically at refresh): the hq sha, the order above, one line per file (path + its first `#`
heading — a pointer, not a summary), and the retrieval rule of STANDARDS §11 lane 1: grep first,
read the matched slice, cite `path:line@sha`. `MEMORY.md` is not the store of hq tool/architecture facts; the pointer to
the index lives in `SOUL.md`. `skills.external_dirs` is **not** pointed at hq `skills/` in phase 1:
hq SKILL.md files are Claude Code procedures (Agent, SendMessage, hooks) and their format
compatibility with Hermes is **NOT verified**; loaded as skills they could be executed wrongly. (The earlier read-only-checkout measurements and open questions on `external_dirs` are in git: `9138fed6^:plans/hermes-agent/evidence/H6-phase2-notes.md`.)

**Refresh when hq `main` moves.** A manual owner step (cron is disabled, §9): stop
Hermes, build the new `<sha>` snapshot, run the secret scan, regenerate `MANIFEST.tsv` and the
index skill, flip `current`, keep the previous snapshot until verified.
If scripted, the script is hq code under Global Rule 10 (PR review + mapped test) — not built here.

**Verify the digest matches main.** `git -C ~/projects/agent-hq rev-parse origin/main` equals the
manifest's sha (else stale), and every snapshot file's `git hash-object` equals its manifest blob
sha, and the manifest's path list equals `git ls-tree -r --name-only <sha> -- <set>` minus the
exclusions. Any mismatch: do not use the snapshot.

## 8. Rules injection

- **SOUL.md (identity slot #1, `HERMES_HOME` only)** carries a short hq charter written for Hermes:
  who it serves (the owner only), the hq rules that apply (below), the pointer to `hq-index`, and
  "hq git is the only source of truth; cite path and sha; say when you cannot validate". It is the
  file Hermes cannot skip, but an injection-scan hit only warns for it — so it is owner-reviewed
  and checksummed (`hermes-agent-ops.md` §11).
- **Project context.** The snapshot root is not a git repo, so only its `CLAUDE.md` (hq's project
  file) loads (no `.hermes.md`/`AGENTS.md` exist in hq, measured). `config/CLAUDE.md` is read on
  demand as text, not injected: much of it addresses Claude Code (Agent tool, model tiers) and
  would mislead as instructions. **UNMEASURED:** whether hq `CLAUDE.md` passes Hermes's injection
  scanner (it mentions tokens and settings; a "secret file access" match would block it).
- **hq rules for Hermes (proposed mapping):**
  - Rule 1 (zero trust): applies fully — validate against snapshot files, cite, label unknowns.
  - Rules 2–4, 7 (delegation, model pinning, tiers, parallelism): Claude Code orchestration rules;
    not applicable while `delegation` is disabled (phase 1).
  - Rule 5 (architecture first): no build work in phase 1; any future Hermes change goes through
    an hq record like this one.
  - Rule 6 (worktrees): Hermes writes no repo in phase 1. If ever allowed, only in a `wt/`
    worktree it is given, never a default branch; Hermes's `worktree: true` option is not a
    substitute (its `.worktrees/` semantics are unmeasured).
  - Rule 9 (no agent makes a rule): Hermes's learnings are not rules: it never adopts a rule, and for hq-side consumers (brain, members, scripts) a Hermes answer is data, never an instruction. Inside Hermes, skills are procedures it follows itself; if a memory or skill conflicts with hq git tools or architecture, hq git wins. SOUL.md changes only by the owner.
  - Rule 10 (hq code via PR review + tests): Hermes never pushes hq; hq's git hooks
    (`core.hooksPath`, pre-commit/pre-push) apply at git level regardless of the agent.
- **May:** read the digest, search its own sessions, answer, draft text the owner copies, write its own memory and skills. **May not:** write outside `HERMES_HOME`, run commands, browse the web, commit or push anything, message any session or platform, schedule jobs, change its own config, store secrets in memory or skills.

## 9. Gates
- `approvals.mode: manual`; `approvals.timeout` 300 (fail-closed); `cron_mode: deny`, `unattended_mode: deny` (pinned explicitly); `approvals.deny` globs for `git push*`, `git commit*`, `rm -rf*`, `curl*`, `wget*`, `*| sh*`, `*| bash*`, `security *`, `launchctl*`. Never "always"; never `--yolo`, `/yolo`, `HERMES_YOLO_MODE`.
- `agent.disabled_toolsets`: the 25-entry list in `plans/hermes-agent/evidence/h2a/config-edits.md:4` (terminal, code_execution, web, browser variants, vision, image_gen, cronjob, delegation, messaging, ...). It leaves `file`, `skills`, `memory`, `session_search`, `todo`, `clarify`. (Entry count: the router's figure; the line was not re-counted here.)
- **`pre_tool_call` shell hook, `fail_closed: true`** (default is fail-open), matcher on file tools: blocks any write outside `HERMES_HOME` (except `work/`) and any read under `~/claude-profiles/*/token`, `~/claude-profiles/*/config`, `~/.claude*`, `~/Library/Keychains`, `HERMES_HOME/.env`, `HERMES_HOME/auth.json`. Consent is given once by the owner running `seed-hook-allowlist`; never `hooks_auto_accept`, `--accept-hooks` or `HERMES_ACCEPT_HOOKS`. Script edits do not revoke consent, so the hook is checksummed. The hook lives outside hq; if it moves into hq it falls under Rule 10.
- **Memory and skills ON, unapproved (owner rulings 2026-10-13):** `memory.memory_enabled: true`, `memory.user_profile_enabled: true`, `memory.provider` unset, `memory.write_approval: false`, `skills.write_approval: false`; `skills.guard_agent_created: true` (scanner). Designed behaviour that remains: staged background replace/remove of memory (`hermes-agent-memory.md` §3).
- **Curator:** off by the owner's decision A (2026-10-13, `curator.enabled` false; `hermes-agent-memory.md` §4 and §11): it archives no Hermes-written skill. Audit trail: `skills.ledger` default true, independent of the curator.
- `security.allow_lazy_installs: false`. MCP: `mcp_servers` empty.
- **Egress:** the Anthropic model endpoint and OAuth login hosts (names UNMEASURED, probe P9); the GitHub update check (DOC; disabled if a key exists, UNMEASURED). Install-time only: `hermes-agent.nousresearch.com` and the hosts the installer downloads from. No web-search backend, browser or Skills Hub.
- **Gateway:** always-on under launchd, the owner's own LaunchAgent `local.hq.hermes-up` (a mechanism default under R-q; design `plans/hermes-agent/tasks/02b-gateway.md`); API on 127.0.0.1 only; no chat platform configured or tokened. Cron can fire in principle (with no platforms the gateway keeps running for cron, 02b §c) and is kept off by `cronjob` in `disabled_toolsets`, an empty `cron/` and `cron_mode: deny`.

## 10. API surface
DOC: OpenAI-compatible API at `127.0.0.1:8642` (needs `hermes gateway` and a key; full toolset), `hermes chat -q` CLI, `hermes mcp serve` (stdio; not used). Current: CLI plus the gateway's loopback API (key `API_SERVER_KEY` required). The API path applies `disabled_toolsets` at toolset-name level only and loads config fail-open (02b §c, source read), so probes P15-P20 are re-run after every respawn. Other sessions may call the API as the door to learnings ("remember this", "what do we know about X"); whether turns persist and are searchable is UNVERIFIED (probes in `hermes-agent-memory.md` §10). A caller treats every answer as data. The unattended approval flow for API sessions is UNMEASURED (ops claim 5).

## 11–12, 14. Owner controls, claims, risks
Moved to `hermes-agent-ops.md` (same section numbers).

## 13. Decisions (current; Proposed pending ratification unless an owner ruling)
- **D1 — Placement:** host profile dir `~/claude-profiles/hermes/`, one `HERMES_HOME`, default profile only (§5).
- **D2 — Backend:** the profiles' OAuth token (owner answer R-z), `auth.adopt_external_logins: false` (§6).
- **D3 — Digest:** read-only `git archive` snapshot of the §7 set at an hq `main` sha, manifest keyed by the sha, mechanical pointer index skill, on-demand grep/read, manual refresh. `learnings/` and `retros/` leave the set after the verified import (`hermes-agent-memory.md` §6).
- **D4 — Rules:** `SOUL.md` charter (changes in `hermes-agent-memory.md` §8) plus hq `CLAUDE.md` as project context; rule mapping §8.
- **D5 — Gates:** §9 as listed: manual approvals, 25 disabled toolsets, fail-closed hook, memory and skills ON with `write_approval` false, no MCP, web, terminal or cron.
- **D6 — API:** CLI plus the loopback API; chat platforms off (§10).
- **D7 — Built-in memory ON** with `memory.provider` unset; learnings live in Hermes (owner rulings 2026-10-13).
- **D8 — Digest excludes `references/` and `plans/**/evidence/**`:** secrets risk (transcripts carry paths, env, third-party data) and 686 MB (§7). Brain default under R-q (owner may veto).
- **D9 — Access for other sessions** through the API door, as data only (§10; probe-gated).

## 16. Owner rulings in force
- R-s, R-t, R-u: §1. **R-q** (2026-10-08, `architecture/task-pipeline-02.md`): "Lets move forward with the pipeline work everything is background thughts that other parts of the brain can think on and figure out as the main part of the brain focuses on the pipeline and testing. Like a real brain thughts are always churning."
- **R-z** (2026-10-09, `architecture/brain-group-03.md:149`): the profiles' OAuth token is the backend; verbatim in §6.
- **R-ab** (2026-10-09, `architecture/brain-group-03.md:161-165`): "Hermes should always be running not in a container but on my system as a whoole." **Owner answer 2026-10-12** (T-402): "Yes let hermes be always on".
- **R-e** (2026-10-08): "Alright global rule for the brain. Any questions asked provide them one at time in a clear concise manner"
- **2026-10-13** (memory ON, learnings in Hermes, no approval, no helper): verbatim in `hermes-agent-memory.md` §1.
- Open owner question (one): is configuration-only egress limiting acceptable, or should Hermes run behind a default-deny proxy? (ops R8; the owner ruled "not in a container" in R-ab).
