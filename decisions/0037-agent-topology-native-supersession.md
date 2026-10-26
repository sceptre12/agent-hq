# 0037. agent-topology superseded by native-primitive markdown artifacts

- **Status:** accepted
- **Date:** 2026-09-07
- **Context of:** `tools/agent-topology/` (workspace-wide, since it dissolves parts of
  ADR 0035, ADR 0009, and ADR 0010's exception scope)

## Context

The owner's directive (2026-09-07): the agent-topology MCP system does too much — a
SQLite registry, 10 tool handlers, capability-token identity, a bespoke bus — for what the
harness's own native primitives (the `Agent` tool, `ListAgents`, `SendMessage`, `TaskStop`)
now cover directly. Scale it back to native primitives: plain markdown agent definitions
plus one orchestrator-side skill, no executable server.

## Decision

Delete `tools/agent-topology/` in full and replace it with:

- **`agents/topology-worker-{light,default→topology-worker,strong}.md`** — three native
  Claude Code agent definitions (frontmatter `name`, `description`, `model:
  haiku|sonnet|opus`, `disallowedTools: ["Agent"]`; no `background:`, no `skills:`). Body
  is the worker's system prompt: escalate-immediately on out-of-scope/out-of-tier work
  (report ESCALATE, never attempt a partial fix first), exactly one success exit (final
  report if foreground, one `RESULT:`-prefixed SendMessage if background — the spawn
  prompt says which), never expand scope (name adjacent defects, don't fix them), cannot
  spawn agents structurally (`Agent` excluded from tools — needing to spawn IS an
  escalation signal), and re-read the spawn prompt rather than guess identity.
- **`skills/agent-topology-router/SKILL.md`** — orchestrator-only procedure: topology
  state lives in `ListAgents`, never memory; per-message DECISION-then-`ListAgents`-then-
  scope-match-or-spawn procedure; spawn-mode choice (foreground default, background only
  when follow-up is expected); scope dedup; escalate-up-never-retry-same-tier; `TaskStop`
  replaces "mark dead". Contains no worker-protocol text.
- **This ADR** — the durable record of what changed and what was accepted as lost.

### What replaces what

| Old (tools/agent-topology/) | New |
|---|---|
| SQLite `agents` registry | `ListAgents` (harness-native, ephemeral) |
| `spawn_agent` MCP tool | `Agent` tool, spawning `topology-worker-<tier>` |
| `route_message` / bus | `SendMessage` |
| `registry_write(status:"dead")` | `TaskStop` |
| Capability-token `auth_token` per agent | Prompt convention + `disallowedTools` |
| `agent-topology-router` / `agent-topology-worker` skills (paired, portable root) | `skills/agent-topology-router/SKILL.md` (orchestrator-only) + `agents/topology-worker-*.md` (worker defs, no skill needed) |
| Port 9000, range 9000-9999 | Released (`tools/ports.tsv`) |

### Standing exceptions dissolved

- **ADR 0035 Decision 1** (STANDARDS §7 / ADR 0010 exception: executable source inside hq)
  is **dissolved per its own revisit clause** — that clause said to revisit "if the
  owner's stated port to a separate work environment does not happen." It did not happen;
  the system is deleted instead. The replacement is pure markdown (agent defs + one
  skill), so no executable-source exception is needed going forward.
- **ADR 0035 Decision 3** (ADR 0009 per-role copy-install exception) is **dissolved**.
  Symlink install (ADR 0009's default) returns: the router skill, like every other hq
  skill, installs by symlink into `~/.claude/skills/agent-topology-router`. There is no
  worker skill to install per-role any more — worker identity now lives in `agents/*.md`
  agent definitions, which are a different install surface (see below).
- **ADR 0035 Decision 4** (capability-token identity) is **retired**. Identity is now
  prompt-layer convention plus each worker's `disallowedTools` allowlist — stated
  honestly as a downgrade, not dressed up as equivalent: there is no unforgeable token, no
  hash-checked bearer credential, no server-side enforcement point. A worker cannot spawn
  agents because the tool is absent from its definition, which is real enforcement for
  that one behavior; everything else (scope discipline, single exit, escalate-not-partial)
  is prompt convention the same way any other agent instruction is.
- **ADR 0035 Decision 2** (`fable` tier reconciliation with ADR 0014) is **not** carried
  forward as a schema value — there is no schema. Fable stays dispatch-only per ADR 0014
  exactly as before; this ADR does not define a `topology-worker-fable` agent, matching
  ADR 0014's rule that Fable never holds a spawnable main-seat slot. Above `strong`
  (Opus), the session's own ADR 0014 escalation ladder governs unchanged.

### New convention: top-level `agents/`

`agents/` is now a canonical hq location for native Claude Code agent definitions,
parallel to `skills/`. Agent defs authored here are canonical; installed to
`~/.claude/agents/` by **symlink** (matching ADR 0009's skill-install convention, not the
copy-install this ADR just dissolved).

## Reasoning

The MCP server existed to enforce role identity and topology state server-side because no
native equivalent existed at build time. The harness has since grown native primitives
(`Agent`, `ListAgents`, `SendMessage`, `TaskStop`) that cover the same ground for hq's
actual usage pattern, at a fraction of the moving parts: no server process, no port claim,
no SQLite file, no token lifecycle to protect from leaking into transcripts. The owner's
directive is explicit that this trade is wanted even knowing what is given up (below) —
scale back is the goal, not a side effect.

## Consequences

- Easier: no server to run, no port to claim or collide on, no token-redaction discipline
  to carry into every brief touching the system, three short markdown files instead of a
  10-tool-handler codebase to maintain.
- Harder / accepted losses (recorded honestly, not minimized):
  - **Nothing survives lead-session restart.** The old registry persisted agent state
    across restarts; `ListAgents` reflects only the current session's live agents.
  - **No enforced authority.** The old middleware rejected a worker's attempt to spawn or
    write the registry at the server. The new mitigation is `disallowedTools: ["Agent"]`
    on worker definitions — real for that one action, but there is no equivalent for
    scope/exit discipline, which is prompt-layer only.
  - **No durable message log.** The bus persisted routed messages; `SendMessage` does not
    give the orchestrator a queryable history.
  - **Acceptance tests A1–A7 no longer apply** (they graded the deleted server/skill-pair
    isolation and identity mechanism). They are replaced by a manual verification
    protocol: after any change to `agents/*.md` or the router skill, a human or reviewing
    agent re-runs the isolation grep (no router-procedure text in agent defs, no
    worker-protocol text in the router skill) and confirms no `disallowedTools` regression
    by reading the frontmatter directly — there is no automated gate.
  - **Revisit if:** a future need reappears for cross-restart topology state, enforced
    role separation, or a durable message log — that need should be evaluated fresh
    against whatever native primitives exist at that time, not by reviving this system,
    since the reason it was retired (doing too much for the actual usage pattern) would
    need to have changed too.
- The design record is **retained, not deleted** — `architecture/agent-topology.md`,
  `architecture/agent-topology-02.md`, and the ratification docs
  (`architecture/agent-topology-ratification*.md`) stay in place with a superseded banner.
  They document a real design exercise (T6 ratification, empirical-verification risk
  records, OQ1-OQ8 rulings) that remains useful history even though the system it
  describes is gone.

## Alternatives considered

- **Keep the server, just simplify its tool count** — rejected: the owner's directive was
  explicitly to move to native primitives, not to trim the existing bespoke one; a
  smaller bespoke server still carries a port claim, a process to keep alive, and a
  registry file with no cross-restart guarantee anyway (workers are process-ephemeral
  per the OQ4 branch-(iii) ruling already in `architecture/agent-topology.md` §6).
- **Port to the owner's separate work environment as originally planned (ADR 0035
  Decision 1's stated rationale)** — rejected: that move did not happen; ADR 0035's own
  revisit clause anticipated exactly this case, and the owner's fresh 2026-09-07
  directive supersedes the earlier portability plan rather than waiting on it.
- **Keep capability-token identity as a prompt-only convention with no schema behind it**
  — rejected as pointless: a token with nothing to check it against server-side is not an
  unforgeability guarantee, it's a string in a prompt; naming the loss plainly (no
  identity guarantee beyond `disallowedTools`) is more honest than keeping token-shaped
  scaffolding that no longer does anything.
- **Define a `topology-worker-fable` agent for schema symmetry** — rejected: ADR 0014
  keeps Fable dispatch-only and never a spawnable main seat; a static agent definition
  file spawnable like any other tier would contradict that, not merely fail to enforce it.

## Links

- `decisions/0035-agent-topology-hq-exception.md` — the four rulings this ADR dissolves
  (1, 3, 4) or leaves non-applicable (2); superseded-by banner added there.
- `decisions/0009-skills-authored-in-hq-symlink-installed.md` — the symlink-install
  convention that returns for the router skill and now extends to `agents/`.
- `decisions/0010-direct-port-of-work-skill-corpus.md`,
  `decisions/0014-model-tier-operating-policy.md` — unchanged; referenced above.
- `architecture/agent-topology.md`, `architecture/agent-topology-02.md`,
  `architecture/agent-topology-ratification*.md` — retained design record, superseded
  banners added.
- `plans/agent-topology.md` — retained, superseded banner added.
- `tools/ports.tsv` — port 9000 / range 9000-9999 rows removed.
- `agents/topology-worker-light.md`, `agents/topology-worker.md`,
  `agents/topology-worker-strong.md`, `skills/agent-topology-router/SKILL.md` — the
  replacement artifacts.
