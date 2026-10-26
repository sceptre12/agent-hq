# 0035. agent-topology: STANDARDS §7 / ADR 0010 exception, `fable` tier, per-role skill install, and capability-token identity

> **Superseded 2026-09-07 by `decisions/0037-agent-topology-native-supersession.md`** —
> Decisions 1, 3, and 4 below are dissolved; Decision 2 (fable tier) is non-applicable
> (no schema exists any more). Retained as design record.

- **Status:** accepted (T6 ratification, 2026-09-02) — see
  `architecture/agent-topology-ratification.md`
- **Date:** 2026-09-02
- **Context of:** `tools/agent-topology/` (workspace-wide for the four sub-decisions below,
  since each touches a standing convention — STANDARDS §7, ADR 0010, ADR 0014, ADR 0009 —
  not just this one system)

## Context

The agent-topology build spec (Notion "Topology Tooling — Build Spec (Claude Code)") calls
for an executable MCP server: SQLite registry, 9 (now 10) tool handlers, and two role-scoped
skills. Building it surfaces four conflicts with existing hq convention, all resolved
together in the T6 architecture ratification of `architecture/agent-topology.md` and
`plans/agent-topology.md` (`architecture/agent-topology-ratification.md`). This ADR is the
durable record required by that ratification's amendment 9 (record item 9) and OQ2's
resolution.

## Decision

### 1. STANDARDS §7 / ADR 0010 exception: executable source lives inside hq

The orchestrator presented the owner with the STANDARDS §7 conflict, ADR 0010, and this
25-file counter-precedent, typed as free text into an AskUserQuestion prompt, 2026-09-02, in
this session. The owner's complete answer, recorded here **verbatim and without
embellishment**:

> "Keep this in hq the exceptn here is that i will port thsi over to my work environment "

This is the entire authorization — no further reasoning is attributed to the owner beyond
these words. The ratifier (Fable, T6) did not witness the owner's turn directly; provenance
is relayed by the orchestrator, and is recorded here per the relayed-authorization-provenance
convention (date, mechanism, verbatim selection).

**Ruling:** `tools/agent-topology/` is a recorded, one-off exception to STANDARDS §7 and ADR
0010, scoped to this system. It does not amend STANDARDS §7 or ADR 0010 themselves — a
future executable source proposal inside hq is not pre-authorized by this ADR and needs its
own ruling.

**Consequence promoted to a requirement, not just noted:** because the owner's stated reason
for the exception is that the system will be ported elsewhere, portability becomes
first-class for this build (rulings P1–P5, `architecture/agent-topology-02.md` part 2 §12): no
hardcoded paths, all locations env-driven via `config.js`, no runtime dependency on hq
tooling, and a documented lift-and-port procedure. An exception granted *because of* a
stated future move is only honored if that move is actually possible when the owner takes
it.

### 2. `fable` tier addition, reconciling the spec's ladder with ADR 0014

The spec's own 3-tier scheme (`light | default | strong`, Router Protocol Rule 2) has no
slot for Fable, which `decisions/0014-model-tier-operating-policy.md` places above Opus as a
dispatch-only apex tier (T1: two Opus failures → mandatory Fable, never a third Opus
attempt, `decisions/0014:55`).

**Ruling:** the `agents.tier` enum is `light | default | strong | fable`. **`fable` rows are
router-dispatch-only** — a worker row is never minted at `fable` directly; only the router's
own escalation path may hand a task to a Fable-tier dispatch, mirroring ADR 0014's rule that
Fable is dispatch-only, never a main seat. Ladder reconciliation: the spec's E3 ("escalate
one tier up" on a prior failure/bounce-back) governs the first hop (e.g. `default → strong`);
from `strong` (Opus) upward, ADR 0014 owns it unchanged — first Opus failure → one retry with
upgraded spec + verification rigour, second failure → mandatory Fable, never a third Opus
attempt. This ADR does not alter ADR 0014's trigger list, N=2 ladder, or assessor — it only
gives the agent-topology schema a value that maps onto ADR 0014's existing apex tier.

### 3. ADR 0009 exception: per-role skill install by COPY, not symlink, project-scoped

`decisions/0009-skills-authored-in-hq-symlink-installed.md` installs every hq skill by
**symlink** into the shared, global `~/.claude/skills/<name>`. The spec requires the
opposite for these two skills: "Install the router skill only in the router's environment
and the worker skill only in spawned worker environments" — a global symlink install would
make both role procedures visible to every agent, which is the exact leak Invariant 6 (a
worker's prompt never contains Router Protocol; the router's never contains the Worker
Preamble) exists to prevent.

**Ruling:** a recorded per-role exception to ADR 0009, on two points:
- **Authorship location (P1):** both `SKILL.md` files are authored **inside the portable
  root**, at `tools/agent-topology/skills/agent-topology-{router,worker}/SKILL.md`, not hq
  top-level `skills/`. Both checkers exclude `skills` as any path segment
  (`check-file-length.sh:22`; `check-doc-length.sh:71,141` `-not -path "*/skills/*"`), so
  the cap exemption survives the relocation.
- **Install mechanism:** the router skill installs project-scoped in the router's own
  environment; `provision.js` installs the worker skill project-scoped into each spawned
  worker's working directory, **by COPY from the package root, not symlink** — so installs
  survive relocation of the source tree when the system is ported (Decision 1's portability
  requirement). Neither skill is ever globally symlink-installed into
  `~/.claude/skills/`.

Enforceable form: (a) a build-time grep that neither SKILL.md contains the other role's
marker strings (acceptance test A7); (b) a check that no `agent-topology-*` symlink exists
in `~/.claude/skills/`. Invariant 6 stays defense-in-depth — the middleware role gate, not
skill visibility, is the hard authority boundary; these tests catch a provisioning-time
regression, not a runtime bypass.

### 4. Capability-token identity model, deviating from the spec's wording

The spec requires: "Resolve caller identity for `whoami`/permission checks from the
session/thread ID mapping in the runtime — **never from a self-reported `agent_id`
parameter**." No such runtime identity channel exists on this transport: `server.js` runs
`sessionIdGenerator: undefined` (stateless mode), and the one working local precedent — the
swarm-communication-layer bus — does the forbidden thing (`send_message.js:26`,
`from_agent: z.string(...)`, required and self-reported).

**Ruling:** `spawn_agent` mints an unguessable **≥128-bit capability token** per agent at
spawn time, stores a **hash** of it in the registry row, and injects the raw token into the
Worker Preamble; every subsequent tool call carries `auth_token`, and `middleware.js`
resolves token → row by hash lookup. The router's own token is minted at server init and
written to a **mode-600 file** under `$DATA_DIR`.

The spec's clause is **amended**, and the amendment is recorded here rather than silently
substituted: identity is never self-**asserted** (a plain `agent_id` string is never
accepted as proof of who is calling); a bearer token is caller-supplied but **unforgeable**.
This is a **downgrade from true runtime identity to unforgeability** — the record states
this plainly rather than overclaiming that the spec's requirement was met as written.
**Tokens are never printed** — no tool logs, error message, or transcript may echo a raw
token, and every brief touching `identity.js`, `spawn_agent`, or a tool handler carries this
redaction clause. Consequence if violated: a token that leaks into a transcript enables
impersonation of that agent, which is the entire point of the redaction requirement.

**Amended, scoped form (F4, T2 addendum, 2026-09-02):** the Worker Preamble gains a fourth
interpolation slot, `{auth_token}` — the preamble IS the token's delivery channel to the
worker, so the "never echo a raw token" clause above is scoped, not dropped: it bans raw
tokens from *server-side* surfaces (tool results, logs, error messages) and from any
router-side or orchestrator transcript. It does not and cannot ban the token from the
worker's own session context, which necessarily carries what the preamble carries — that
local JSONL sits inside the same same-user trust boundary that already holds the mode-600
router token file. Threat model, stated plainly: the token defends against cross-agent
leakage through shared and relayed surfaces, not against a same-user process reading its own
local files (an adversary in that position could read the router's token file too).

## Reasoning

Each of the four rulings above resolves a genuine conflict between the spec (or an existing
ADR) and ground truth on this machine, verified independently at ratification rather than
taken on the author's word (see `architecture/agent-topology-ratification.md`,
"Independent verification of author claims"). None of the four is a general policy change:
each is scoped to `tools/agent-topology/` and does not authorize a future system to claim
the same exception by citing this one.

## Consequences

- Easier: the build proceeds without inventing an ad-hoc identity mechanism or silently
  ignoring the spec's provisioning instructions; the schema has a real slot for Fable
  without contradicting ADR 0014.
- Revisit if: the owner's stated port to a separate work environment does not happen — the
  reason the exception was granted evaporates, and STANDARDS §7 / ADR 0010 compliance
  should be revisited at that point.

## Alternatives considered

- **Build at `~/projects/agent-topology` as a sibling repo, keep only the design record +
  skills in hq** — this was the architecture author's option (ii) under the original OQ2.
  Rejected by the owner in favor of keeping it inside hq, on the stated portability
  rationale above; not chosen by the ratifier or this ADR.
- **True per-agent OS process for identity (option a under OQ1)** — rejected: costs the
  shared SQLite registry that the write-asymmetry model depends on, for no gain over an
  unforgeable token.
- **Accept self-reported identity as honour-system (option c under OQ1)** — rejected:
  directly contradicts the spec's central design principle ("role identity must be enforced
  by tool access... not by prompt text alone") and the whole reason the registry exists.
- **Relax Invariant 6 to "the preamble omits the other role's rules" while both skills stay
  globally visible** — rejected: a global install still leaks both procedures to every
  session at the skill-description level, which is the leak Invariant 6 exists to prevent.
- **Leave `tier` at the spec's original three values, treat `fable` escalation as an
  out-of-band ADR 0014 event with no schema representation** — rejected: `check_status` and
  `registry_write` need a value to write when a row is actually dispatched at Fable tier;
  an out-of-band event with no row state reopens the drift bug the registry exists to kill.

## Links

- `architecture/agent-topology.md` — the design record this ADR settles the open questions
  for (§4 enums/ladder, §5 identity, part 2 §7 skill install, §9 OQ1-OQ8, part 2 §12
  portability).
- `plans/agent-topology.md` — the dispatch plan built against these rulings.
- `architecture/agent-topology-ratification.md` — the T6 ratification record; rulings OQ1,
  OQ2 + P1-P5, OQ3, OQ6 are the source of Decisions 4, 1, 2, 3 respectively.
- `STANDARDS.md:84` — the §7 sibling rule this ADR grants a one-off exception to.
- `decisions/0010-direct-port-of-work-skill-corpus.md` — restates the same rule for the bus;
  not amended, exception recorded alongside it.
- `decisions/0014-model-tier-operating-policy.md` — the tier/escalation ladder `fable`
  reconciles with; not amended.
- `decisions/0009-skills-authored-in-hq-symlink-installed.md` — the global-symlink-install
  convention this ADR grants a per-role exception to.
- `decisions/0016-source-file-length-limit.md`, `tools/check-file-length.sh`,
  `tools/check-doc-length.sh` — the cap-exemption mechanics that survive the skills'
  relocation into `tools/agent-topology/skills/`.
