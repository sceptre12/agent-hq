# wave-execution — skill design record (ADR 0011)

One-line summary: a generic N-wave work orchestrator — the caller supplies a
`spec_root` describing staged, heterogeneous waves of work; this skill dispatches
each wave's agents, rendezvous over the swarm bus, gates each wave against its
own exit criteria, and fix-loops on failure up to an iteration cap before
escalating.

**Amendment (2026-07-20, ADR 0023):** five Workflow-inspired capabilities — resume/checkpoint,
a `dispatch_budget` preflight, richer `gate_type`s, per-`work_item` `output_schema` (Tier A,
built: in `SKILL.md` / `references/spec-format.md` with rules 9-11), and `spec_ref` nesting
(deferred, Tier B). See § Capabilities (ADR 0023, ADR 0054) below.

**Amendment (2026-10-26, ADR 0054, `decisions/0054-adr-0023-amendment-delivery-workflow.md`):**
skill version 1.1.0 adds bundle `session_id`, `output_topic`, `bus_endpoint`; per-work_item
`persona`, `lane`, `depends_on`, `done_condition`; `gate_type: step_complete`; DAG-frontier
waves; invocation arguments `max_concurrent`, `invocation`, `tier_override`; rules 13-15. All
optional: a bundle declaring none of them runs exactly as 1.0.0.

## What This Is

**Headline decision (user ruling 2026-07-05):** generalized from an
employer-specific 7-wave package-release pipeline to a domain-agnostic N-wave
orchestrator. The source skill (`X-context-docs skills/wave-execution@0e9281e`)
was a thin orchestrator shell whose real content — 7 hardcoded release waves,
CMD_* token bindings, an instantiation profile for one monorepo — lived in
~1,700 lines of employer-specific spec files in a separate domain-spec
directory in the source repo that is **out of scope** and was not read for
domain content during this port. Only the generic machinery was kept: bus rendezvous, gate/exit
criteria, fix-loop with iteration cap, escalation channel, the dispatch-mode
gate (`SKILL.md`'s Operating Mode Gate), and Prohibited Side Channels. What used to be "Wave 1 through
Wave 7, each hardcoded" is now "waves 1 through N, each defined by the caller's
`spec_root`."

## Components

- `skills/wave-execution/SKILL.md` — frontmatter (name/description with a "Use
  when" trigger), Operating Mode Gate, Steps (resolve spec_root → preflight
  validate → derive SESSION_ID → bootstrap bus → run waves 1..W → fix loop →
  finalize), Bus Rules, Prohibited Side Channels, Topic Naming, a Disambiguation
  section against the loop system, Red flags, Exit criteria, Provenance/Lineage.
- `skills/wave-execution/references/spec-format.md` — the `spec_root` contract:
  accepted layouts (`waves.md` single-file or `waves/NN-<name>.md`), the six
  required per-wave fields (`goal`, `inputs`, `work_items`, `agents`,
  `exit_criteria`, `outputs`), the optional fields (ADR 0023, ADR 0054), the
  optional `bundle.md` bundle header, and preflight rules 1-11 and 13-15 the
  skill enforces before any dispatch.
- `skills/wave-execution/references/frontier-mode.md` — DAG-frontier release
  loop, admission (`max_concurrent`, `lane`), per-work_item gate and fix loop,
  agent ids and the dispatch record (ADR 0054).
- `skills/wave-execution/references/example-spec/` — a small, from-scratch
  bundle (audit → fix → verify a directory of Markdown docs, then a frontier
  build wave) proving the format end to end, with `tests/run.sh` (static rule
  checker over the example and `tests/fixtures/`). Authored fresh for this port; carries no source-repo
  content.

## Spec contract (summary — full detail in `references/spec-format.md`)

`spec_root` is caller-supplied and entirely external to this skill: the skill
ships the format and one illustrative example, never a domain spec. A wave
bundle is valid only if every wave 1..W declares all six required fields, wave
numbers are contiguous with no gaps/duplicates, every `inputs` reference to a
prior wave's `outputs` resolves to something that wave actually declares, and no
unresolved placeholder tokens remain. `exit_criteria` must read as verifiable
conditions — a wave whose only criterion is an aspiration ("looks good") fails
preflight rather than being silently accepted.

ADR 0023 extends this contract with optional fields (`gate_type` + `skeptics`/`judges`,
per-`work_item` `output_schema`, bundle-level `dispatch_budget`, and — deferred —
`spec_ref`) and preflight rules 9–12. ADR 0054 (A0-A9) adds bundle fields `session_id`,
`output_topic`, `bus_endpoint` (in `bundle.md`), per-work_item `persona`, `lane`,
`depends_on`, `done_condition`, `gate_type: step_complete`, and rules 13-15; `max_concurrent`,
`invocation` and `tier_override` are invocation arguments, outside `spec_root` and its hash.
Rules run 1-10, 13-15, then 11 last; details in § Capabilities below. Every added field is
optional with a behavior-preserving default.

## Bus interfaces / topics

Coordination is entirely over swarm-communication-layer
(`architecture/swarm-communication-layer.md`), one PM2 instance per run
(`APP_NAME=swarm-mcp-${SESSION_ID}`, `DATA_DIR=/tmp/${SESSION_ID}`), torn down by
the controller's cleanup trap (registered immediately after `cleanup()` is
defined, before any resource is acquired — `SIGKILL` cannot be trapped) —
**unless** the bundle declares `bus_endpoint` (ADR 0054 A9): the skill then
attaches to the caller-owned bus the file names (`port, data_dir, pm2_app, pid,
session_id, topic`; port only from `$data_dir/port`), skips its own bootstrap
and `cleanup()`, still runs the identity preflight and `start_session`, and halts
before any dispatch if the file's `session_id=`/`topic=` differ from the bundle's
or a key is missing. It adds no port-claim step; the caller claims and recovers
its bus. An unattached run under a pinned `session_id` recovers a leftover
`swarm-mcp-<session_id>` with `pm2 restart` only.
`SESSION_ID` is the bundle's pinned `session_id` when declared (ADR 0054 A6),
else `wave-exec-$(date)-$(uuid)` minted per invocation.

| Topic | Written by | Read by |
|---|---|---|
| bundle `output_topic` (literal, ADR 0054 A7) | every wave's agents and gate agents; controller final result | controller; the caller |
| `{SESSION_ID}-wave-{N}-output` | wave N's agents (when the wave declares a dedicated output topic) | controller |
| `{SESSION_ID}-rendezvous` | any wave's agents (default topic) | controller |
| `{SESSION_ID}-fix-loop-output` | fix agents | controller |
| `{SESSION_ID}-escalation` | controller | the caller that dispatched wave-execution |

Bus rules match `skills/loop-controller/SKILL.md`'s idiom exactly: identity
preflight samples `/health` 2-3 times requiring both `status: ok` and
`app_name`/`data_dir` matching this session's own `APP_NAME`/`DATA_DIR`; `pm2
restart` is the only safe recovery verb (never `reload`); `session_id` is passed
explicitly on every send/broadcast; the port is read only from `$DATA_DIR/port`.
A bundle `output_topic` overrides every per-wave value. On that shared topic the
discriminator is the `from_agent` id (ADR 0054 A7): each agent gets a
nonce-bearing id (`<work_item>-<nonce>`, `<work_item>-gate<k>-<nonce>`,
`<work_item>-fix<k>-<nonce>`; `<k>` as defined in `references/spec-format.md`) with a recorded role, and a post counts only from
an id assigned in this invocation — with `bus_endpoint`, registered in
`dirname(<resolved bus_endpoint>)/dispatch/<invocation>.jsonl` before dispatch (fields
`agent_id, role, unit, persona, tier, backend, utc`). The skill never reads a
caller's `status/<agent-id>.verdict` fallback file.
The bus post to a wave's topic is the sole valid completion signal — the same
Prohibited Side Channels list as `loop-controller` (no branching on stdout, exit
code, env vars, task files, sibling files, or named pipes).

## Constraints

- Sandboxing is prompt-only — no OS-level isolation stops a dispatched agent
  from writing outside its intended scope.
- One `spec_root` bundle drives one run; concurrent runs against the same
  `spec_root` are not coordinated by this skill. Sequential *resumed* runs
  against the same `spec_root` **are** coordinated, via the checkpoint file
  (see § Capabilities → Resume / checkpoint below) — only true concurrency
  remains uncoordinated. A pinned resume reuses the same `SESSION_ID`.
- `fix_loop_cap` (default 3) is declared once per wave and enforced per wave in
  a barrier wave and per work_item in a frontier wave (ADR 0054 A5), not globally — the cap bounds each
  scope's own retries, not the run as a whole.
- The skill never reads a wave's target files itself — all domain-level file
  access is delegated to the dispatched wave agents, matching the source's own
  "pure orchestrator, no domain logic" framing (kept unchanged by this port).
  This excludes the skill's own `.wave-execution-state/` checkpoint
  bookkeeping (§ Resume / checkpoint below), which is not domain data.

## Settled decisions (this port's refits)

- **Generalized from 7 hardcoded release waves to N caller-defined waves** — the
  headline decision above. Wave count, goals, work items, and gates all moved
  from the skill into `spec_root`.
- **Instantiation profile / CMD_* token registry dropped entirely.** Source
  resolved tool commands (`CMD_BUILD`, `CMD_PUBLISH`, etc.) through a
  per-project instantiation profile. Out of scope for a domain-agnostic skill —
  a wave's `work_items`/`agents` fields now say what to dispatch; how a
  dispatched agent runs its own tools is that agent's own concern, not a token
  this skill resolves.
- **7 fixed wave names (PRE-WAVE a/b, Wave 1-7 with fixed roles like "Local Pack
  + Consumer Simulation") replaced by a generic numbered-wave contract.** No
  wave role is baked into the skill; `references/spec-format.md` and
  `references/example-spec/` carry the only wave-shaped content, and the
  example is intentionally unrelated to package releases (a docs audit/fix/
  verify bundle plus a frontier build wave) to keep the port domain-neutral.
- **Multi-file source (`SKILL.md` + `SKILL-02/03/04.md`, ~600 lines, heavy
  cross-file "read before proceeding" chaining) consolidated to one `SKILL.md`
  body + `references/`,** matching the Gate-2 restructuring expectation recorded
  in `plans/dev-workspace-base-skills.md`'s wave-execution row and the same
  shape already used by `loop-controller`.
- **Two work-path examples scrubbed to generic placeholders** — source
  `SKILL.md`'s `spec_root` example and `SKILL-04.md`'s `PROJECT_ROOT` example
  each carried a literal work-machine path; both are now
  `/abs/path/to/spec-bundle` / `/abs/path/to/project`-style placeholders.
- **Mandatory Brief Fields table, Fix Loop Re-entry Map, CYCLE COMPLETE/CYCLE
  DONE criteria, and the Validators-reproduced-verbatim-in-every-brief rule all
  dropped.** These were mechanics of the specific 7-wave release pipeline
  (package/consumer-repo fields, publish-registry propagation, PR-merge
  polling) — out of scope for a domain-agnostic contract. A caller's own
  `spec_root` may reintroduce equivalent per-wave brief fields if its domain
  needs them; this skill does not prescribe a fixed field set.
- **Bus rules restated in this skill's own idiom rather than pointed-to only**
  — matches `loop-controller`'s pattern of each bus-posting skill restating the
  identity-preflight/pm2-restart/explicit-session_id/port-discovery rules
  inline, not solely by reference.
- **Disambiguation section against the loop system added** — did not exist in
  source (source predates hq's loop-system entirely). See
  `architecture/loop-system.md`: `loop-*` converges one artifact against one
  rubric; `wave-execution` runs staged, heterogeneous waves each with its own
  gate. The two systems share the bus idiom but not a controller.
- **Red flags / Exit criteria / Provenance sections added** — absent upstream,
  added per `tools/skill-authoring.md`'s required anatomy (same convention
  already applied to sibling ports `loop-controller`, `swarm-communication`).

## Capabilities (ADR 0023 Workflow grafts; ADR 0054)

Design from ADR 0023, motivated by
architecture assessment(s) of wave-execution against Claude Code's closed built-in Workflow
tool, conducted for this decision (see session record / conversation history — not
separately filed as an hq artifact) (the grafts flow one direction only — into the skill
the owner controls), extended by ADR 0054 for the delivery workflow. **Built:** Tier A
(`gate_type`, `output_schema`, `dispatch_budget`, rules 9-11, resume/checkpoint) and the
ADR 0054 fields and rules 13-15 are in `SKILL.md` / `references/spec-format.md` /
`references/frontier-mode.md`; only `spec_ref` (rule 12) is deferred. Every field below is
optional; every default preserves 1.0.0 behavior. `references/spec-format.md` is the
authoritative record of field shapes and rule text.

### Spec fields and invocation arguments

| Field | Level | Values / shape | Default when absent | Graft |
|---|---|---|---|---|
| `gate_type` | per-wave | `exit_criteria` \| `adversarial_verify` \| `judge_panel` \| `step_complete` | `exit_criteria` (today's single check) | 3 (D1); 0054 A4 |
| `skeptics` | per-wave | integer ≥ 1; required iff `gate_type: adversarial_verify` | — | 3 (D1) |
| `judges` | per-wave | integer ≥ 3, odd; required iff `gate_type: judge_panel` | — | 3 (D1) |
| `output_schema` | per-`work_item` | a fenced ```json JSON Schema block | absent (free-text post) | 4 (D2) |
| `dispatch_budget` | bundle | integer max dispatch count | absent (no budget check) | 2 (D4) |
| `spec_ref` *(deferred)* | per-`work_item` | path to a child `spec_root` | absent (no nesting) | 5 (D5) |
| `max_concurrent` | invocation argument (not a spec field, no per-wave value) | integer ≥ 1; counts work_item, gate and fix agents | unbounded (today's behavior) | 0054 A0, A1 |
| `invocation` | invocation argument | `^[0-9]+$`; names `dispatch/<invocation>.jsonl` | — | 0054 A0 |
| `tier_override` | invocation argument | `<work_item>=<tier>`, repeatable; recorded as `tier` in the dispatch record | none | 0054 A0 |
| `persona` | per-`work_item` | one-line token, passed verbatim in the brief; does not change the `agents` tier | today's brief | 0054 A2 |
| `lane` | per-`work_item` | one-line token; one live work_item per lane within one run; busy until the holder posts its completion (`UNIT-VERDICT`) in a barrier wave, or until its per-item gate passes or escalates in a frontier wave (INTERFACES 1.6.0 AM-6 C-4, C1.1); runtime-generated work_items and fix agents may carry `persona` and `lane` | no lane constraint | 0054 A3 |
| `depends_on` | per-`work_item` | list of same-wave work_item ids; one edge makes the wave a frontier wave (`[]` declares none) | none (barrier wave) | 0054 A5 |
| `done_condition` | per-`work_item` | `{"token", "command"}`, both non-empty one-line, no other key; required under `step_complete` | absent | 0054 A4 |
| `session_id` | bundle | `^[a-z0-9-]+$`; pinned, stable on resume, in the content hash | minted per invocation | 0054 A6 |
| `output_topic` | bundle | one literal topic, no placeholder; overrides per-wave values | per-wave values | 0054 A7 |
| `bus_endpoint` | bundle | `$DELIVERY_ROOT`-relative `<run-id>/<subtask>/bus.endpoint`; declared without bundle `session_id`/`output_topic` or the `invocation` argument it halts before any dispatch with `BUNDLE-ERROR <field>` (INTERFACES 1.5.0 C1.1) | own bus bootstrap and teardown | 0054 A9 |
| `gates_command` | bundle | one non-empty line (delivery run: repo profile `gates.command`); the gate agent that gates a work_item runs it on the posted head under a lane lease and is the single writer of `gate-runs/<head>.md` | no gate command run | INTERFACES 1.8.0 AM-8 V14 |

Bundle fields live in `bundle.md` at the `spec_root` root (both layouts). With `bus_endpoint` the
dispatch record line per agent carries `unit` = the served work_item id, or `wave-<N>` for a
wave-level gate agent, and `persona` = the work_item's persona, `none` when undeclared
(INTERFACES 1.5.0 C1.1).

In the first three `gate_type` modes the caller's `exit_criteria` is supplied verbatim as the
rubric — `adversarial_verify` dispatches `skeptics` agents to actively falsify the wave's
output against it (any sustained falsification = fail); `judge_panel` dispatches `judges`
agents that each post a pass/fail verdict, majority rules. Gate agents post to the bus like
any `work_item` — the bundle-level `output_topic` when declared (it overrides every per-wave
value, ADR 0054 A7), else the wave's declared `output_topic`, or the default
`{SESSION_ID}-rendezvous` if none — as in `SKILL.md`'s Topic Naming table (no new topic
introduced); the bus-rendezvous model is unchanged. Each gate agent's post is a
verdict payload: `{agent_id, verdict: pass | fail, rationale}`. An `output_schema` a post
fails to validate against makes that agent's completion **incomplete** (a gate failure, not a
spec defect — a *malformed* schema in the spec is a spec defect, caught by rule 10).

`step_complete` (ADR 0054 A4) is the one rubric exception: one gate agent per work_item
walks that work_item's `done_condition` beside the wave's `exit_criteria`, both verbatim,
and passes it only if `command` exits 0, its last stdout line equals `token`, and the
`exit_criteria` hold for that work_item's output. In a
barrier wave every gate agent must pass (no majority).

**Barrier and frontier waves (ADR 0054 A5).** A wave whose work_items declare no
`depends_on` edge is a barrier wave and runs as in 1.0.0 (`depends_on: []` declares none).
A wave with at least one edge is a frontier wave: it enumerates its work_items; a work_item is released when every blocker's gate has
passed, its lane is free and a `max_concurrent` slot is free; each work_item is gated on its
own output, the wave's `fix_loop_cap` counted per work_item; on exhaustion the controller posts
`{halt_reason: "fix-loop-cap-exhausted", wave, work_item, iterations}` to
`{SESSION_ID}-escalation` and never releases that work_item's transitive dependents, while
the others run on. No passed gate is reopened, so cancellation is non-release (never a
`TaskStop`). When nothing is live or releasable the wave passes if every work_item passed,
else the run halts. Declared waves stay barriers to each other; there is no cross-wave
edge and no global barrier-free flag.

### Preflight rules 9–15 (extend the existing 1–8; order 1-10, 13-15, 11 last)

9. **`gate_type` validity** (Graft 3 / D1; ADR 0054 A4, A8). If present, must be one of the
   four enum values; `adversarial_verify` requires `skeptics ≥ 1`; `judge_panel` requires an
   odd `judges ≥ 3`; `step_complete` requires every work_item of the wave to be listed (enumerated) with a two-key `done_condition`.
   `gate_agents`: 1, `skeptics`, `judges`, and for `step_complete` `work_items_count`
   (barrier) or 1 per work_item (frontier). `exit_criteria` prose remains required in every
   mode (it is the rubric).
10. **`output_schema` validity** (Graft 4 / D2). Any `work_item` `output_schema` block must
    parse as a valid JSON Schema; a malformed schema is `VALIDATION_FAILED` (distinct from a
    runtime non-conforming post, which is a gate failure per above).
11. **Dispatch-budget check** (Graft 2 / D4). When `dispatch_budget` is declared, compute
    worst-case dispatch count = Σ over waves of `work_items_count + (fix_loop_cap + 1) ×
    gate_agents`, where `gate_agents` = 1 (`exit_criteria`; the formula charges 1),
    `skeptics` (`adversarial_verify`), `judges` (`judge_panel`), or
    `work_items_count` (`step_complete`, rule 9). If the sum exceeds
    `dispatch_budget`, `VALIDATION_FAILED` naming the projected count, the budget, and the
    remedy (split the bundle at a wave boundary) — halt before any dispatch. A frontier wave's
    term is `work_items_count × (1 + (fix_loop_cap + 1) × g)`, `g` = gate agents per
    work_item (ADR 0054 A5). Computed last, after rules 9–10 and 13–15, so gate-agent counts,
    schema validity and each wave's mode are known.
12. **`spec_ref` recursion** *(deferred, Graft 5 / D5)*. A `work_item` with `spec_ref`
    validates the child bundle by applying rules 1–11 and 13–15 one level deep, refuses cycles, and
    rolls the child's worst-case dispatch count into the parent's `dispatch_budget` across
    the nesting boundary.
13. **`session_id`** (ADR 0054 A6, A8). When declared, matches `^[a-z0-9-]+$`.
14. **`output_topic`** (ADR 0054 A7, A8). A bundle `output_topic` is a literal with no
    placeholder, and no per-wave `output_topic` differs from it.
15. **`depends_on`** (ADR 0054 A5, A8). Acyclic; every edge names a work_item of the same
    wave; a wave with edges enumerates its work_items.

### Resume / checkpoint (Graft 1 / D3 — machinery, no new field)

Unless the bundle pins `session_id`, `SESSION_ID` is generated fresh per invocation (see Bus interfaces / topics above) and its
bus data is torn down by the controller's cleanup trap at the end of a run, so a genuinely
fresh session has no defined path back to a prior run's bus state — resume cannot be keyed
on `SESSION_ID` reconciliation. Instead, persist a checkpoint file **outside** the volatile
per-session bus directory, at the canonical location
`<parent-directory-of-spec_root>/.wave-execution-state/<spec_root-content-hash>.json` — a
sibling directory to `spec_root`, not nested inside it — updated each time a wave's gate
passes with that wave's `work_items` and their gate verdicts. On bootstrap, a resumed
invocation hashes its `spec_root`, reads the matching checkpoint file if one exists, skips
every wave already recorded as gate-passed, and starts a **brand-new bus session** (a new
`SESSION_ID`) at the first incomplete wave. This is a separate, deliberately-persistent
artifact from the per-run bus instance — a normal successful run still tears down its bus
instance when the skill started the bus (no `bus_endpoint`) exactly as described above; only the checkpoint file survives across invocations. A
mismatched or absent content hash means "no valid checkpoint," so the run starts at wave 1;
the hash also refuses resuming a bundle whose spec changed underneath a prior run. If a
resumed invocation's checkpoint already shows every wave gate-passed, wave-execution reports
the run as already complete and exits without dispatching or bootstrapping a new bus session.

ADR 0054 A6: a pinned `session_id` is the exception — a resume reuses it, so every
`{SESSION_ID}-*` topic is stable (bundles differing only in `session_id` hash differently).
The checkpoint carries per-work_item entries with their gate verdicts (written on each
work_item gate pass in a frontier wave) and is the only authority for what has passed: a
completion post for a work_item it does not record is re-gated.

### Priority

- **Tier A (built):** Graft 3 (`gate_type`) and Graft 4 (`output_schema`) **alongside**
  Grafts 1 (resume) and 2 (`dispatch_budget`).
- **Built by ADR 0054:** `max_concurrent` (moved from Tier B, as an invocation argument),
  `depends_on` frontier waves and the other A0-A9 fields.
- **Tier B (deferred, not scheduled):** `spec_ref` (rule 12) — real but no proven
  production need yet; build when one appears, not speculatively.

### Considered and rejected (not portable)

Recorded so a future reader does not re-litigate — full reasoning in ADR 0023:

- **Pipelined / no-barrier waves** (`pipeline()`): would gut the wave gate, a predicate over
  collective output. The opt-in per-`work_item` `depends_on` edges are now built (ADR 0054
  A5, within one wave, cancellation = non-release); a global barrier-free flag stays out.
- **`parallel()` fan-out:** already equivalent to the existing per-wave
  one-agent-per-`work_item` dispatch with bus rendezvous as the barrier. Nothing to port.
- **Loop-until-dry / count / budget iteration:** belongs to `loop-controller`
  (`architecture/loop-system.md`) by wave-execution's own disambiguation; porting it would
  blur a deliberate line.
- **Per-`agent()` model/effort override:** already equivalent — the `agents` field assigns
  per-task tiers and global Rule 3 forces explicit pinning regardless. Cosmetic.

## Source lineage

Lineage: X-context-docs `skills/wave-execution@0e9281e` (heavily refit — read
for its generic orchestrator machinery only; the ~1,700 lines of employer-
specific domain spec in a separate directory of that source repo were
deliberately not read for domain content and are not reflected anywhere in this
port). Bus design and its own decision record:
`architecture/swarm-communication-layer.md`. Sibling ported skill for
comparison of idiom: `architecture/loop-system.md` / `skills/loop-controller/`.
