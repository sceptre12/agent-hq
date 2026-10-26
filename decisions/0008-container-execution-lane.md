# 0008. Containerized full-auto execution lane on OrbStack

- **Status:** ACCEPTED (2026-07-03)
- **Date:** 2026-07-03
- **Context of:** workspace-wide (new execution lane; tooling under `tools/container-exec/`)
- **Amends (on adoption, not now):** extends `tools/git-hooks/pre-commit` secret content-scan
  with the Anthropic token family; appends INVARIANTS checks 20–23 and bumps the runner's
  `implemented=` count-parity constant. Does **not** supersede any ADR. Explicitly does **not**
  touch the frozen MCP list, host `CLAUDE.md`, host `~/.claude/settings.json`, or the
  Headroom/wrap config → ADR 0004's cache-verification standing rule is **not triggered**
  (see cross-check row 0004).

## Context

Some tasks are long, build-heavy, or network-heavy and stall an interactive host session on
permission prompts. The user has ratified a **containerized execution lane**: run Claude Code
inside an OrbStack container with `--dangerously-skip-permissions` (full-auto, no prompts) so
these tasks run unattended, then return results to the host session for review and push.

**The decision itself is settled by the user** — this ADR designs the *mechanism*, not the
*whether*. The lane is deliberately **bare**: no Headroom proxy, no agentmemory hooks/MCP, no
Serena, no host `~/.claude` mount. Learning and memory stay at the **host orchestration layer**;
container internals are disposable; results flow back to the host session which has the hooks.

### Environment facts (validated read-only on 2026-07-03, not assumed)

| Claim | Command run | Result |
|---|---|---|
| OrbStack 2.2.1 running | `orb version` | `Version: 2.2.1 (2020100)` ✔ |
| Docker daemon healthy | `docker version` / `docker context ls` | Engine 29.4.0 linux/arm64; context `orbstack` active ✔ |
| dev-toolkit images exist | `docker images` | `dev-toolkit:latest` (754MB), `dev-toolkit-dev-toolkit:latest` (813MB), `dev-{base,obs,ready}-{node,python,rust}`, `node:22-slim` (247MB), `node:20-bullseye` ✔ |
| Host Claude Code 2.1.199 | `claude --version` | `2.1.199 (Claude Code)` ✔ |
| Installed as npm global | `npm ls -g --depth=0` | `@anthropic-ai/claude-code@2.1.199` (registry name confirmed via `npm view`) ✔ |
| `setup-token` available | `claude setup-token --help` | "Set up a long-lived authentication token (requires Claude subscription)" ✔ |
| Host auth is Keychain-based | `ls ~/.claude/.credentials.json` | **absent**; `security dump-keychain` shows `Claude Code-credentials` genp item ✔ |
| `--bare` ignores the OAuth env var | `claude -p --help` | `--bare`: "Anthropic auth is strictly ANTHROPIC_API_KEY or apiKeyHelper… OAuth and keychain are never read" → **confirms brief; container must NOT use `--bare`** ✔ |
| Headless flags present | `claude --help` | `-p/--print`, `--output-format`, `--dangerously-skip-permissions`, `--permission-mode`, `--append-system-prompt`, `--add-dir`, `--model` ✔ |
| `docker run -e VAR` passthrough | `docker run --help` | `-e, --env list` — a bare name passes the value from the runner's environment (keeps it off the docker argv) ✔ |

**Validation limit stated honestly (Rule 1):** the exact live token string was **not** read —
doing so would print the user's real credential into logs. The `Claude Code-credentials`
Keychain item and Anthropic's documented key/token families give the shape used below
(`sk-ant-` + a family tag `oatNN`/`ortNN`/`apiNN`). The secret-gate regex is a *prefix* match,
so it is robust to the exact family tag without needing the live value. Executor confirms the
first characters against a freshly-minted token at build time (without logging the full value).

### Design constraints (from the user ruling + the existing stack)

- **Auth = subscription OAuth token**, produced by `claude setup-token` (1-year), injected at
  container start via `CLAUDE_CODE_OAUTH_TOKEN`. **Never** baked into an image, **never** on
  disk inside any repo, **never** committed. It is a **bearer credential** the dangerous-mode
  agent can read — this drives the egress and secret-gate design.
- **Bare containers:** no proxy, no memory hooks/MCP, no Serena, no host `~/.claude` mount.
  Headroom-in-container is **out of v1** (revisit only with measurements).
- **Host surfaces untouched:** frozen MCP list, host session config, Headroom/wrap config are
  not modified → ADR 0004 cache re-verification is not triggered.
- Honor ADR 0001 (lightweight): the runner is one plain-bash script; the only new "build" is an
  out-of-band, optional tooling image (not a build step for reading/editing hq or the memory
  stack) — tension noted and bounded in the cross-check.

### ADR cross-check (done before writing — no contradictions)

| ADR | Relevant rule | This lane |
|---|---|---|
| 0001 | Lightweight; no build step to read/edit hq | Runner is one POSIX bash script. Image build is out-of-band optional tooling, not a step to read/edit hq or run the memory stack. Bounded, not violated. |
| 0002 | Frozen stack; nothing indexes/crawls hq | Container is bare — no indexer, no stack service, no crawl of hq. ✔ |
| 0003 | One owner per fact; no mirroring | Memory/learning owned by the **host**; container is disposable; results are reviewed, not mirrored into a second store. ✔ |
| **0004** | **Prefix freeze; frozen MCP list; Phase-3 standing rule** | Lane touches **no** MCP server, **no** host `CLAUDE.md`, **no** `~/.claude/settings.json`, **no** Headroom/wrap config. Container has **zero** MCP. **The cache-verification-runbook re-run rule is NOT triggered.** ✔ (stated explicitly per brief) |
| 0005 | INVARIANTS as pass/fail self-check | Adds checks 20–23 the same way (adopt-time). ✔ |
| 0006 | Memory bytes outside hq; push is the only backup | Container never writes `~/.agentmemory`; results land in `/out` then host review → host push. Token never on repo disk. ✔ reinforces |
| 0007 | Minimal enforcement; host review is the enforcement point | Extends the pre-commit secret content-scan; **host-side review before push is the gate** (the gate-incident lesson: `core.hooksPath` does not travel with clones → the container clone has no in-repo gates *by design*). ✔ reinforces |

## Decision

Adopt a **bare, ephemeral, per-task container execution lane** driven by one host runner script
`tools/container-exec/hqx-run.sh`. Ten design points, each settled below; rejected alternatives
are tabled in the next section.

**D1 — Base image: fresh minimal Dockerfile from `node:22-slim`.**
Build `hqx-claude:latest` from `node:22-slim` (247MB, node major 22 = host parity) + `git`,
`ca-certificates`, `tini`, and `npm i -g @anthropic-ai/claude-code@2.1.199` (pinned to host
version). **Reject** deriving from `dev-toolkit:latest`: it is a *service-dev* image (754MB, env
wired to a `dev-mesh` with redis/postgres/traefik URLs) — carrying that surface into a bare
Claude runner is drift and dead weight. A pinned, single-purpose Dockerfile is reproducible and
auditable. Image is built once, out-of-band; rebuilt when the pinned claude version bumps.

**D2 — Token lifecycle (host): macOS Keychain, env-passthrough injection.**
Store the `setup-token` output as a **Keychain generic password**, not a file:
`security add-generic-password -U -s hqx-claude-oauth -a "$USER" -w` (`-w` **last, no value** →
interactive secure prompt, so the token never enters shell history or argv). The runner reads it
into its **own environment** with `security find-generic-password -w …` and passes it to the
container by **bare name** (`docker run -e CLAUDE_CODE_OAUTH_TOKEN`), so the value rides the
runner's environment, **not** the docker command line (invisible to `ps`/argv). Rotation: re-run
`claude setup-token`, re-`add` with `-U`. Revocation: invalidate setup-tokens from the Anthropic
console (kills the bearer credential immediately — this is the v1 blast-radius backstop).
**Secret-gate addition:** extend the ADR-0007 pre-commit content-scan alternation with the
Anthropic token family so the token can never be committed — pattern (safe to write; it does not
self-match): `sk-ant-(oat|ort|api)[0-9]{2}-`. Per the ADR-0007 defang convention and the
`enforcement-gates.md` incident, **this ADR never writes a contiguous literal token**: only the
regex form (above) and runtime-assembled examples appear here, so committing this very file does
not trip the gate.

**D3 — Repo-in: clone from a read-only host bind-mount (default); RW bind-mount is opt-in.**
Default = mount the host repo **read-only** at `/src-ro` and `git clone --no-hardlinks /src-ro
/work` into the container's own writable layer. A rogue `rm -rf` hits only `/work` (container
layer, discarded on `--rm`); the read-only mount makes destructive writes to the host repo
**fail at the kernel**. Clone captures **committed state only** — clean and reproducible, and it
matches "host reviews and pushes." If the task needs uncommitted working-tree changes, the human
commits them to a wip branch first, **or** opts into `--rw` (bind-mount the host worktree
read-write) — allowed only for explicitly human-approved fast-iteration runs, because under
`--dangerously-skip-permissions` a `--rw` mount lets the agent delete host files.

**D4 — Results-out: `git bundle` + diff to an output-only mount; host reviews and pushes.**
The container has **no push authority** to any real remote. It writes to the **only** writable
host mount `/out`: (a) `result.bundle` (a `git bundle` of just the new commits `BASE..HEAD`), (b)
`result.diff` (unified diff `BASE..HEAD`), (c) `session.stream.jsonl` (agent transcript), (d)
`usage/` (see D8). The host reviews the diff, `git fetch`es the bundle into the real repo,
merges, and **pushes** — the host is where in-repo gates (`core.hooksPath`) and human judgment
live. `core.hooksPath` does **not** travel with a clone, so the container clone has no gates **by
design**; review happens at the host (the gate-incident enforcement lesson).

**D5 — Network egress: pragmatic OPEN for v1, with named compensations and a tightening trigger.**
OrbStack defaults to open egress; Anthropic's reference devcontainer ships an allowlist firewall.
v1 = **open egress** (no allowlist). Honest trade-off: the token is a bearer credential readable
by the dangerous-mode agent, so **egress is the exfiltration surface** — a prompt-injected agent
(via a malicious repo/file) could POST the token or repo contents anywhere. Compensations that
make open acceptable for v1: (1) **inference-scoped token** — a subscription OAuth token
authorizes model inference, not broad account management; (2) **fast revocability** — one console
action kills it; (3) **single-user machine**, no untrusted co-tenants; (4) **ephemeral, single-
repo** containers. **Tighten to allowlist** (reuse Anthropic's `init-firewall.sh` allowing
`api.anthropic.com` + the repo host, run as the container's first step with `NET_ADMIN`) the
moment the lane runs **untrusted task specs or untrusted repos/data**. This is a genuine
risk-appetite call → surfaced in Open Questions (default: open-for-v1).

**D6 — Lifecycle: ephemeral per-task `docker run --rm`; no warm pool.**
One container per task, auto-removed on exit. Naming `hqx-<repo-slug>-<epoch>`. Labels
`hq.lane=container-exec`, `hq.repo=<slug>`, `hq.task=<slug>`. Stray cleanup:
`docker ps -aq --filter label=hq.lane=container-exec | xargs -r docker rm -f`. Logs are retained
by copy-out to `/out` before teardown (nothing durable lives in the container). **Reject** a warm
pool: state leakage between tasks defeats the disposability/isolation property and idles quota.

**D7 — Rate-limit guardrail: concurrency cap = 2 (default, user override — see Open questions Q2),
preflight-enforced.**
Host + N containers share **one** subscription quota pool (5h rolling + weekly). The runner
performs a **preflight**: count containers labelled `hq.lane=container-exec`; if
`≥ HQX_MAX_CONCURRENT` (default **2**), **refuse to start** (exit 6). Rationale: parallel
dangerous-mode agents can exhaust the weekly pool fast and there is no per-container quota meter
visible to the host (see D8). The designer's caution stands: default 1 was recommended as the
conservative choice because host + N containers still draw on the **same shared subscription quota
pool** — the user reviewed that trade-off and explicitly raised the default to 2; raise further via
`HQX_MAX_CONCURRENT`. (Ratified — see Open Questions Q2.)

**D8 — Usage-measurement blind spot: copy the container usage jsonl out, document the gap.**
Host `ccusage` reads `~/.claude/projects/**/*.jsonl` on the **host**; the container's session
jsonl is invisible to it. v1 = the entrypoint copies the container's `~/.claude/projects/` into
`/out/usage/` before exit, so the host can `ccusage --path /out/usage` after the fact (or inspect
manually). We **accept and document** that ccusage's default aggregation will not auto-include
container usage; the copy-out preserves the data for reconciliation.

**D9 — Runner ergonomics: one entry script, headless `claude -p`, no `--bare`.**
`tools/container-exec/hqx-run.sh` with an explicit flag surface (D-spec below). The task prompt
reaches Claude via **headless** mode: the task file is mounted read-only at `/task/spec.md` and
the entrypoint runs `claude -p "$(cat /task/spec.md)" --dangerously-skip-permissions --model
"$HQX_MODEL" --output-format stream-json --verbose | tee /out/session.stream.jsonl`.
**`--bare` is forbidden** — its help confirms it ignores the OAuth env var (auth would fall back
to `ANTHROPIC_API_KEY`, which we do not set). Plain (non-bare) `claude` reads
`CLAUDE_CODE_OAUTH_TOKEN`; the hooks/auto-memory/CLAUDE.md-discovery that non-bare mode would run
are **no-ops in the bare container** (none present), so plain mode costs nothing and is correct.

**D10 — Invariants: add checks 20–23 (adopt-time), continuing from 19.**
New safety properties, in INVARIANTS.md style, added **when the lane is built** (not now — see
"count-parity" note): 20 no Anthropic token material anywhere in hq; 21 runner script exists and
is executable; 22 base Dockerfile present; 23 Dockerfile/entrypoint never set the token.

## Rejected options and alternatives considered

| Design point | Candidate | Verdict | One-line reason |
|---|---|---|---|
| D1 base image | Fresh Dockerfile from `node:22-slim` + pinned claude | **ACCEPT** | Reproducible, minimal, single-purpose, host-version parity. |
| D1 | Derive from `dev-toolkit:latest` | **REJECT** | Service-dev image (754MB, dev-mesh env) → drift + dead weight in a bare runner. |
| D1 | `ubuntu`/`debian` + manual node install | **REJECT** | Reinvents `node:22-slim`; larger, more steps, more drift. |
| D2 token store | Keychain generic password + env passthrough | **ACCEPT** | Off-disk, off-argv, off-history; native macOS, revocable. |
| D2 | 0600 file (e.g. `~/.config/hqx/token`) | **REJECT (fallback only)** | Plaintext on disk; acceptable only if Keychain unavailable; must live outside every repo. |
| D2 | `docker run -e VAR="$token"` (value inline) | **REJECT** | Puts the token in docker argv → visible in `ps`. Use bare-name passthrough. |
| D2 | Bake token into image / `ENV` in Dockerfile | **REJECT (forbidden)** | Persists a bearer credential in image layers; violates the user ruling. |
| D3 repo-in | Clone from read-only bind-mount → container layer | **ACCEPT** | Blast-radius isolation; host repo kernel-protected from writes. |
| D3 | RW bind-mount of host worktree | **REJECT as default / allow opt-in** | Fast, but `rm -rf` under dangerous-mode reaches host disk; human-approved runs only. |
| D3 | Clone over network from GitHub | **REJECT** | Needs read credentials in-container; local RO clone needs none. |
| D4 results-out | `git bundle` + diff to `/out`; host pushes | **ACCEPT** | Portable, reviewable, zero push authority in container. |
| D4 | Container pushes a branch to a scratch remote | **REJECT** | Requires push creds in-container — the exact authority we withhold. |
| D4 | Plain diff on stdout only | **REJECT as sole channel** | Fine for tiny changes; loses binary/rename fidelity and history; keep as a `session.stream.jsonl` byproduct, not the transport. |
| D5 egress | Open egress for v1 + compensations | **ACCEPT (with trigger)** | Pragmatic on a single-user box; revocable inference token; tighten on untrusted inputs. |
| D5 | Allowlist firewall now (init-firewall.sh) | **DEFER** | Correct end-state; heavyweight for v1's trusted, self-authored tasks. Documented as the tightening path. |
| D6 lifecycle | Ephemeral `--rm` per task | **ACCEPT** | Disposable = isolation; no cross-task leakage. |
| D6 | Warm container pool | **REJECT** | State leakage defeats isolation; idles shared quota. |
| D7 rate-limit | Preflight concurrency cap (default 2, user override) | **ACCEPT** | One shared quota pool; conservative, adjustable. |
| D7 | No cap / unlimited parallel | **REJECT** | Can exhaust the weekly subscription pool with no host-visible meter. |
| D8 usage | Copy container usage jsonl to `/out` + document gap | **ACCEPT** | Preserves data for reconciliation; honest about ccusage blind spot. |
| D8 | Ignore the blind spot entirely | **REJECT** | Silent quota drift; the copy-out is nearly free. |
| D9 runner | Single bash script + `claude -p` stream-json | **ACCEPT** | One artifact, observable transcript, non-interactive. |
| D9 | `claude --bare` | **REJECT** | Ignores the OAuth env var (help-confirmed) → auth fails. |
| D9 | Interactive `claude` in a TTY | **REJECT** | Defeats unattended operation; no clean exit-code/transport. |
| D10 invariants | Add checks 20–23 at build time | **ACCEPT** | Mirrors ADR 0007's adopt-time 16–19 pattern; keeps count-parity in one edit. |

## Reasoning

- **Bare is the safety property, not a limitation.** Every omission (no proxy, no memory hooks,
  no Serena, no host `~/.claude` mount) shrinks both the prefix/cache blast radius (ADR 0004
  untouched) and the credential/attack surface. The container is a compute sandbox; all
  *knowledge* stays host-side.
- **Two credentials, two disciplines.** The OAuth token is protected by (a) Keychain-at-rest,
  (b) env-passthrough-in-flight (off argv), (c) a pre-commit content-gate against ever committing
  it, and (d) console revocability. Push authority is protected by *never granting it to the
  container* — results come out as an inert bundle the host inspects.
- **Isolation beats convenience by default; convenience is opt-in.** RO-clone default + RW opt-in
  puts the dangerous default on the safe side, exactly the ADR-0007 asymmetry (block the
  irreversible mistake; allow the reversible one on explicit request).
- **Open egress is a *stated* risk with *named* compensations, not an oversight.** The honest
  read: on a single-user machine running self-authored tasks against trusted repos, the residual
  risk is quota theft on a revocable token — acceptable for v1. The instant an input is untrusted,
  the allowlist path is pre-designed and ready. This is surfaced, not buried.
- **The host is the enforcement point** — the same lesson `enforcement-gates.md` records: gates
  that don't travel (clone hooks) or that an agent can bypass are not where safety lives; safety
  lives at the human-reviewed host push. The lane is built around that truth, not against it.

Continued in [0008-container-execution-lane-02.md](0008-container-execution-lane-02.md): implementation spec, rollback plan, acceptance tests, consequences, rulings and as-built deviations.
