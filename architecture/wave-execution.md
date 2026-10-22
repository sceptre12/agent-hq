# wave-execution — skill design record (ADR 0011)

One-line summary: a generic N-wave work orchestrator — the caller supplies a
`spec_root` describing staged, heterogeneous waves of work; this skill dispatches
each wave's agents, rendezvous over the swarm bus, gates each wave against its
own exit criteria, and fix-loops on failure up to an iteration cap before
escalating.

**Amendment (2026-07-20, ADR 0023):** the spec contract is documented to gain five
Workflow-inspired capabilities — resume/checkpoint, a `dispatch_budget` preflight, richer
`gate_type`s, per-`work_item` `output_schema` (all build-now), and `spec_ref` nesting +
`max_concurrent` (deferred). These are **documented design, not yet implemented** — the
`SKILL.md` / `references/spec-format.md` edits are a separate build unit. See § Proposed
capabilities (ADR 0023) below.

## What This Is

**Headline decision (user ruling 2026-07-05):** generalized from an
employer-specific 7-wave package-release pipeline to a domain-agnostic N-wave
orchestrator. The source skill (`X-context-docs skills/wave-execution@0e9281e`)
was a thin orchestrator shell whose real content — 7 hardcoded release waves,
CMD_* token bindings, an instantiation profile for one monorepo — lived in
~1,700 lines of employer-specific spec files in a separate domain-spec
directory in the source repo that is **out of scope** and was not read for
domain content during this port. Only the generic machinery was kept: bus rendezvous, gate/exit
criteria, fix-loop with iteration cap, escalation channel, the `is_subagent`
dispatch gate, and Prohibited Side Channels. What used to be "Wave 1 through
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
  `exit_criteria`, `outputs`), two optional fields (`fix_loop_cap`,
  `output_topic`), and the 8 preflight validation rules the skill enforces
  before any dispatch.
- `skills/wave-execution/references/example-spec/` — a small, from-scratch
  3-wave bundle (audit → fix → verify a directory of Markdown docs) proving the
  format end to end. Authored fresh for this port; carries no source-repo
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
`spec_ref` + `max_concurrent`) and preflight rules 9–12, detailed in § Proposed
capabilities below. Every added field is optional with a behavior-preserving default.

## Bus interfaces / topics

Coordination is entirely over swarm-communication-layer
(`architecture/swarm-communication-layer.md`), one PM2 instance per run
(`APP_NAME=swarm-mcp-${SESSION_ID}`, `DATA_DIR=/tmp/${SESSION_ID}`), torn down by
the controller's cleanup trap (registered immediately after `cleanup()` is
defined, before any resource is acquired — `SIGKILL` cannot be trapped).
`SESSION_ID = wave-exec-$(date)-$(uuid)`.

| Topic | Written by | Read by |
|---|---|---|
| `{SESSION_ID}-wave-{N}-output` | wave N's agents (when the wave declares a dedicated output topic) | controller |
| `{SESSION_ID}-rendezvous` | any wave's agents (default topic) | controller |
| `{SESSION_ID}-fix-loop-output` | fix agents | controller |
| `{SESSION_ID}-escalation` | controller | the caller that dispatched wave-execution |

Bus rules match `skills/loop-controller/SKILL.md`'s idiom exactly: identity
preflight samples `/health` 2-3 times requiring both `status: ok` and
`app_name`/`data_dir` matching this session's own `APP_NAME`/`DATA_DIR`; `pm2
restart` is the only safe recovery verb (never `reload`); `session_id` is passed
explicitly on every send/broadcast; the port is read only from `$DATA_DIR/port`.
The bus post to a wave's topic is the sole valid completion signal — the same
Prohibited Side Channels list as `loop-controller` (no branching on stdout, exit
code, env vars, task files, sibling files, or named pipes).

## Constraints

- Sandboxing is prompt-only — no OS-level isolation stops a dispatched agent
  from writing outside its intended scope.
- One `spec_root` bundle drives one run; concurrent runs against the same
  `spec_root` are not coordinated by this skill. Sequential *resumed* runs
  against the same `spec_root` **are** coordinated, via the checkpoint file
  (see § Proposed capabilities (ADR 0023) → Resume / checkpoint below) — only
  true concurrency remains uncoordinated.
- `fix_loop_cap` (default 3) is enforced per wave, not globally — a bundle with
  many waves can still exhaust many fix-loop iterations in total; the cap bounds
  each wave's own retries, not the run as a whole.
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
  verify bundle) to keep the port domain-neutral.
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

## Proposed capabilities (ADR 0023 — Workflow grafts)

Documented design from ADR 0023, motivated by the ADR 0022 200-sub-agent-cap incident and
architecture assessment(s) of wave-execution against Claude Code's closed built-in Workflow
tool, conducted for this decision (see session record / conversation history — not
separately filed as an hq artifact) (the grafts flow one direction only — into the skill
the owner controls). **Not yet
implemented**: the `SKILL.md` / `references/spec-format.md` edits are a separate build unit
(Rule 5). Every field below is optional; every default preserves current behavior; new
preflight rules are numbered 9+ to follow the existing 8. This section is the authoritative
record of the new field names and rule numbering.

### New spec fields

| Field | Level | Values / shape | Default when absent | Graft |
|---|---|---|---|---|
| `gate_type` | per-wave | `exit_criteria` \| `adversarial_verify` \| `judge_panel` | `exit_criteria` (today's single check) | 3 (D1) |
| `skeptics` | per-wave | integer ≥ 1; required iff `gate_type: adversarial_verify` | — | 3 (D1) |
| `judges` | per-wave | integer ≥ 3, odd; required iff `gate_type: judge_panel` | — | 3 (D1) |
| `output_schema` | per-`work_item` | a fenced ```json JSON Schema block | absent (free-text post) | 4 (D2) |
| `dispatch_budget` | bundle | integer max dispatch count | absent (no budget check) | 2 (D4) |
| `spec_ref` *(deferred)* | per-`work_item` | path to a child `spec_root` | absent (no nesting) | 5 (D5) |
| `max_concurrent` *(deferred)* | per-wave | integer ≥ 1 | unbounded (today's behavior) | 5 (D5) |

In all three `gate_type` modes the caller's `exit_criteria` is supplied verbatim as the
rubric — `adversarial_verify` dispatches `skeptics` agents to actively falsify the wave's
output against it (any sustained falsification = fail); `judge_panel` dispatches `judges`
agents that each post a pass/fail verdict, majority rules. Gate agents post to the bus like
any `work_item` — the wave's declared `output_topic`, or the default
`{SESSION_ID}-rendezvous` if none — matching `SKILL.md`'s Topic Naming table exactly (no new
topic introduced); the bus-rendezvous model is unchanged. Each gate agent's post is a
verdict payload: `{agent_id, verdict: pass | fail, rationale}`. An `output_schema` a post
fails to validate against makes that agent's completion **incomplete** (a gate failure, not a
spec defect — a *malformed* schema in the spec is a spec defect, caught by rule 10).

### Preflight rules 9–12 (extend the existing 1–8)

9. **`gate_type` validity** (Graft 3 / D1). If present, must be one of the three enum
   values; `adversarial_verify` requires `skeptics ≥ 1`; `judge_panel` requires an odd
   `judges ≥ 3`. `exit_criteria` prose remains required in every mode (it is the rubric).
10. **`output_schema` validity** (Graft 4 / D2). Any `work_item` `output_schema` block must
    parse as a valid JSON Schema; a malformed schema is `VALIDATION_FAILED` (distinct from a
    runtime non-conforming post, which is a gate failure per above).
11. **Dispatch-budget check** (Graft 2 / D4). When `dispatch_budget` is declared, compute
    worst-case dispatch count = Σ over waves of `work_items_count + (fix_loop_cap + 1) ×
    gate_agents`, where `gate_agents` = 1 (`exit_criteria` — this mode dispatches 0
    additional agents in practice; the formula charges 1 as conservative padding),
    `skeptics` (`adversarial_verify`), or `judges` (`judge_panel`). If the sum exceeds
    `dispatch_budget`, `VALIDATION_FAILED` naming the projected count, the budget, and the
    remedy (split the bundle at a wave boundary) — halt before any dispatch. Computed last,
    after rules 9–10, so gate-agent counts and schema validity are both known.
12. **`spec_ref` recursion** *(deferred, Graft 5 / D5)*. A `work_item` with `spec_ref`
    validates the child bundle by applying rules 1–11 one level deep, refuses cycles, and
    rolls the child's worst-case dispatch count into the parent's `dispatch_budget` across
    the nesting boundary.

### Resume / checkpoint (Graft 1 / D3 — machinery, no new field)

`SESSION_ID` is generated fresh per invocation (see Bus interfaces / topics above) and its
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
instance exactly as described above; only the checkpoint file survives across invocations. A
mismatched or absent content hash means "no valid checkpoint," so the run starts at wave 1;
the hash also refuses resuming a bundle whose spec changed underneath a prior run. If a
resumed invocation's checkpoint already shows every wave gate-passed, wave-execution reports
the run as already complete and exits without dispatching or bootstrapping a new bus session.

### Priority

- **Tier A (build now):** Graft 3 (`gate_type`) and Graft 4 (`output_schema`) — highest
  generality gain, lowest structural risk — **alongside** Grafts 1 (resume) and 2
  (`dispatch_budget`), the original ADR-0022-motivated gap fixes.
- **Tier B (deferred, not scheduled):** Graft 5 (`spec_ref` + `max_concurrent`) — real but
  no proven production need yet; build when one appears, not speculatively.

### Considered and rejected (not portable)

Recorded so a future reader does not re-litigate — full reasoning in ADR 0023:

- **Pipelined / no-barrier waves** (`pipeline()`): would gut the wave gate, a predicate over
  collective output. If ever needed, opt-in per-`work_item` `depends_on` edges, not a global
  flag — and that needs cancellation semantics not worth building speculatively.
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
