# 0023. wave-execution — five Workflow-inspired grafts (resume, dispatch budget, gate types, output schema; nesting deferred)

- **Status:** accepted (2026-07-25) — retroactively ratified via Fable dispatch, ADR 0014 T6, after build+merge; process finding: dispatch plan wrongly asserted "already-ratified" pre-ratification, see follow-up learning.
- **Date:** 2026-07-20
- **Context of:** the `wave-execution` skill (`architecture/wave-execution.md`, ADR 0011
  design record). Motivated by architecture assessment(s) of
  wave-execution against Claude Code's built-in Workflow tool, conducted for this decision
  (see `learnings/wave-execution-independent-review.md` § "2026-07-20/21 — grafting
  Workflow-inspired capabilities into wave-execution" — the session write-up documenting
  this ADR's authorship, review, and dogfooded implementation).
  Amends the skill's design record; does not change the global rules.

## Context

Claude Code ships a built-in **Workflow** tool (JS-like `agent()` / `pipeline()` /
`parallel()` / `phase()` / `workflow()` script primitives, resume-by-cache via a journal,
a token-budget object, concurrency caps of 16-concurrent / 1000-lifetime, gated behind an
explicit "ultracode" opt-in). The owner's `wave-execution` skill (a caller-authored
`spec_root` of Markdown wave files, sequential waves, one sub-agent per `work_item`,
swarm-bus-only rendezvous, per-wave `exit_criteria` gate + fix-loop capped at
`fix_loop_cap`) solves an adjacent job. Two architecture assessments (conducted for this
decision; see `learnings/wave-execution-independent-review.md` § "2026-07-20/21 —
grafting Workflow-inspired capabilities into wave-execution" for the session write-up)
examined whether the two mechanisms conflict and what, if anything, is worth porting.

**Assessment 1 — no conflict.** Workflow and wave-execution solve adjacent, not
overlapping, jobs: wide / homogeneous / resumable sweeps vs. staged / heterogeneous /
gated builds. Convergence was explicitly rejected — Workflow is a **closed built-in
The owner cannot modify**, so any graft only ever flows in wave-execution's direction. The
assessment identified two proven, load-bearing gaps in wave-execution from real
production evidence (see Evidence below): a missing resume/checkpoint contract and a
missing dispatch-budget preflight.

**Assessment 2 — what else is portable to make wave-execution more general.** Went
through every Workflow primitive against wave-execution's contract and found two more
grafts worth doing now (richer gate types; per-`work_item` output schema), one worth
deferring until a real need appears (declarative nesting + a concurrency cap), and four
things explicitly **not** portable (recorded below so they are not re-litigated).

## Decision (proposed — the owner ratifies)

Document five capabilities on wave-execution's design record. This ADR records the
decision and rationale; `architecture/wave-execution.md` gains the corresponding contract
detail. **No skill/code changes are made by this ADR** — the `SKILL.md` and
`references/spec-format.md` edits that implement these fields are a later, separately
dispatched build unit (Rule 5: architecture → dispatch plan → execution, in that order).

New field names are chosen to slot cleanly into the current contract
(`references/spec-format.md`): 6 required fields (`goal`, `inputs`, `work_items`,
`agents`, `exit_criteria`, `outputs`), 2 optional fields (`fix_loop_cap`, `output_topic`),
and preflight rules 1–8. Every new field is **optional with a default that preserves
today's behavior**, and new preflight rules are numbered 9+ to follow the existing 8.

### Priority tier A — build now

**D1 — Graft 3: `gate_type` as a first-class per-wave field (highest priority).**
Today every wave's gate is a flat single-agent check against the caller's `exit_criteria`
prose — a single-perspective verdict. Add an optional per-wave field:

```
gate_type: exit_criteria | adversarial_verify | judge_panel   # default: exit_criteria
skeptics: N     # required when gate_type = adversarial_verify (N ≥ 1)
judges:   N     # required when gate_type = judge_panel (N ≥ 3, odd, for tie-break)
```

- `exit_criteria` (default) — current behavior exactly: one gate agent checks the wave's
  reports against the caller's `exit_criteria`.
- `adversarial_verify` — dispatch `skeptics` agents tasked to actively falsify the wave's
  output against the same `exit_criteria` rubric; any sustained falsification = gate fail.
- `judge_panel` — dispatch `judges` agents that each post a pass/fail verdict against the
  rubric; majority rules.

In all three modes the caller's `exit_criteria` is supplied **verbatim as the rubric** —
this ports Workflow's documented-but-optional quality-pattern library (adversarial verify,
judge panel) as *enforced gate machinery* instead of leaving the caller to hand-approximate
it in prose. Gate agents still just post verdicts to the bus like any `work_item` — the
wave's declared `output_topic`, or the default `{SESSION_ID}-rendezvous` if none — matching
`SKILL.md`'s Topic Naming table exactly (no new topic introduced); the bus-rendezvous model
is untouched. Each verdict payload is `{agent_id, verdict: pass | fail, rationale}`. Biggest
generality gain for the least structural risk.

**D2 — Graft 4: `output_schema` per `work_item` (second priority).**
Add an optional JSON Schema — authored as a fenced ```json block attached to a `work_item`
in the Markdown spec — that the `work_item`'s bus-post completion must validate against. A
malformed or non-conforming post is treated as **incomplete** (a gate failure for that
agent, not a spec defect). Makes gate checks mechanical where the caller wants that; stays
optional (free-text prompts and posts) where prose is fine. Cheap, and compounds with D1
by giving gate agents structured data to judge instead of parsing prose.

### Priority tier A — the original fixes (build now, alongside D1/D2)

**D3 — Graft 1: resume / checkpoint contract.**
`SESSION_ID` is generated fresh per invocation (`wave-exec-$(date)-$(uuid)`) and its bus
data (`DATA_DIR=/tmp/${SESSION_ID}`) is torn down by the controller's own cleanup at the end
of a run, so a genuinely fresh session has no defined path back to a prior run's bus state
— resume cannot be keyed on `SESSION_ID` reconciliation. Instead, persist a checkpoint file
**outside** the volatile per-session bus directory, at the canonical location
`<parent-directory-of-spec_root>/.wave-execution-state/<spec_root-content-hash>.json` — a
sibling directory to `spec_root`, not nested inside it — updated each time a wave's gate
passes with that wave's `work_items` and their gate verdicts. On bootstrap, a resumed
invocation hashes its `spec_root`, reads the matching checkpoint file if one exists, skips
every wave already recorded as gate-passed, and starts a **brand-new bus session** (a new
`SESSION_ID`) at the first incomplete wave. This is machinery, not a new caller-facing field,
and it is a separate, deliberately-persistent artifact from the per-run bus instance — a
normal successful run still tears down its bus instance exactly as before; only the
checkpoint file survives across invocations. A mismatched or absent content hash means "no
valid checkpoint," so the run starts at wave 1 — the `spec_root` hash guards against
resuming a bundle whose spec changed underneath a prior run. If a resumed invocation's
checkpoint already shows every wave gate-passed, wave-execution reports the run as already
complete and exits without dispatching or bootstrapping a new bus session.

**D4 — Graft 2: `dispatch_budget` preflight rule.**
Add an optional bundle-level `dispatch_budget` field (an integer max dispatch count),
enforced as an **11th preflight rule** (it runs last, after `gate_type` validity — rule 9 —
and `output_schema` validity — rule 10). This converts ADR 0022's manual remedy into enforced
machinery:

- **Preflight rule 11 (new) — dispatch-budget check.** When `dispatch_budget` is declared,
  compute the bundle's worst-case dispatch count and refuse (or require a split) when it
  exceeds the budget. Worst-case per wave =
  `work_items_count + (fix_loop_cap + 1) × gate_agents`, where `gate_agents` = 1 for
  `exit_criteria` (exit_criteria gates dispatch 0 additional agents in practice; the formula
  charges 1 as conservative padding), `skeptics` for `adversarial_verify`, `judges` for
  `judge_panel` (this is why dispatch-budget, rule 11, must be computed after D1's gate type
  — rule 9 — is known). Sum across all waves; if the sum exceeds `dispatch_budget`,
  `VALIDATION_FAILED` naming the projected count and the budget, with the remedy (split the
  bundle at a wave boundary) — halt before any dispatch.

### Priority tier B — deferred, do when a real need appears (NOT scheduled)

**D5 — Graft 5: `spec_ref` nesting + `max_concurrent`.**
wave-execution already has ~90% of Workflow's one-level `workflow(nameOrRef)` nesting via
its existing `is_subagent → claude -p` dispatch switch: a `work_item` whose instruction is
"invoke wave-execution on `spec_root` X" already works today — the child bootstraps its own
bus session. What is missing is:

- A declarative `spec_ref:` `work_item` field so preflight can validate the child bundle
  too — **preflight rule 12 (future)**: recursively apply rules 1–11 one level deep,
  refuse cycles, and roll the child's worst-case dispatch count into the *parent's*
  `dispatch_budget` (D4) across the nesting boundary.
- A per-wave `max_concurrent` field, a two-line graft mirroring Workflow's `min(16, cpu-2)`
  cap. wave-execution states no per-wave concurrency limit today, so an N-item wave fans out
  unbounded. (Validated inline where it is used — an integer ≥ 1 — not as its own preflight
  rule; the authoritative rule 9–12 numbering lives in `architecture/wave-execution.md`.)

Deferred deliberately: neither has a proven production need yet (unlike D1–D4), and
building nesting/cancellation semantics speculatively is exactly the kind of ahead-of-need
complexity hq avoids. Documented now so a future reader knows the design was considered and
where it slots.

## Considered and rejected (NOT portable — recorded so this is not re-litigated)

- **Pipelined / no-barrier waves (Workflow's `pipeline()` semantics)** — rejected. The
  wave gate is a predicate over the wave's *collective* output; a barrier-free mode would
  gut the gate's meaning. If ever needed, it is opt-in per-`work_item` `depends_on` edges
  (not a global flag), and that requires real cancellation / invalidation-on-gate-failure
  semantics not worth building speculatively. Low priority, do not build now.
- **`parallel()` fan-out** — nothing to port. Already equivalent to wave-execution's
  existing per-wave one-sub-agent-per-`work_item` dispatch with bus rendezvous as the
  barrier.
- **Workflow's loop-until-dry / count / budget iteration patterns** — do not port. These
  belong to `loop-controller`'s job by wave-execution's own existing disambiguation
  (`SKILL.md` § Disambiguation vs the loop system): staged heterogeneous waves vs. an
  iterative grade-fix loop on one artifact to convergence. Porting iteration-until-
  convergence into wave-execution would blur a line hq drew on purpose
  (`architecture/loop-system.md`).
- **Per-`agent()` model / effort override** — nothing to change. Already equivalent:
  wave-execution's `agents` field already assigns per-task model tiers (haiku / sonnet /
  opus), and global Rule 3 already forces explicit model pinning on every dispatch
  regardless. Cosmetic.

## Reasoning

- **Why graft at all, and only one direction:** Workflow is a closed built-in the owner
  cannot modify (Assessment 1). The only actionable output of comparing the two is to move
  proven-useful ideas *into* the skill the owner controls. Grafts 1–2 close measured
  production gaps; grafts 3–4 raise the skill's generality with low
  structural risk; graft 5 is real but not yet needed.
- **Why D1/D2 are highest priority despite D3/D4 being the incident fixes:** Assessment 2
  ranked gate-type richness the single biggest generality gain for the least structural
  risk — it changes what the gate *can be* without touching the bus model. D3/D4 are
  equally must-do (they are the incident remedy), so both live in tier A; the tiering is
  about generality reach, not urgency.
- **Why every new field is optional-with-a-behavior-preserving-default:** a caller's
  existing bundle must keep validating and running identically. `gate_type` defaults to
  `exit_criteria` (today's single check); `output_schema`, `dispatch_budget`,
  `max_concurrent`, and `spec_ref` are all absent-by-default. No existing spec breaks.
- **Why the bus model is deliberately untouched:** every graft expresses itself as more
  (or differently-briefed) agents posting verdicts to the same bus topics. Prohibited Side
  Channels, identity preflight, and the pm2-per-session idiom all stand unchanged — the
  grafts add contract surface, not a new coordination substrate.

## Consequences

- Easier: a capped build refuses at preflight instead of degrading unsafely mid-wave
  (D4); an interrupted or split build resumes at a wave boundary with passed gates honored
  instead of re-running from wave 1 (D3); callers get adversarial / panel gates and
  structured completion as declarative fields instead of hand-rolled prose (D1/D2).
- Harder / accepted: the spec contract grows (4 new fields now, 2 more when D5 lands) and
  preflight gains rules 9–11 (12 deferred). Accepted because each is optional and the
  worst-case-dispatch math (rule 11) is the machinery ADR 0022 explicitly asked for. Gate
  types multiply gate-agent count, which is exactly why rule 11's formula folds
  `gate_agents` in — richer gates cost budget, and the budget check now sees that cost.
- Revisit if: a real nesting or concurrency-cap need appears (build D5 then, not before);
  or the resume-hash reconciliation proves unreliable against a mutated `spec_root` (tighten
  the hash/skip logic by amendment); or a capped build still slips past rule 11 (the formula
  under-counts some path — fix the formula, do not drop the rule).

## Alternatives considered

- **Converge wave-execution and Workflow into one mechanism** — rejected (Assessment 1):
  Workflow is a closed built-in; convergence is impossible and the jobs are adjacent, not
  identical.
- **Do only grafts 1–2 (the incident fixes), skip 3–5** — rejected: Assessment 2 showed
  3–4 are high-value / low-risk generality wins that compound with the budget math (gate
  types feed rule 11; output schema feeds gate types). Skipping them leaves obvious value on
  the table for no saving.
- **Build graft 5 now for completeness** — rejected: no proven need, and nesting/
  cancellation semantics are real complexity; deferring matches hq's avoid-ahead-of-need
  posture. Documented as the amendment path when a need appears.
- **Raise `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` instead of adding rule 11** — rejected as
  the primary fix for the same reason ADR 0022 D-alternatives rejected it: a higher cap
  moves the cliff without making the degradation at the cliff safe. Rule 11 makes the build
  refuse cleanly; the env var stays available as an orthogonal valve.

**Links:** ADR 0011 (architecture-folder / design-record convention this amends),
ADR 0014 (model-tier policy),
`architecture/wave-execution.md` (design record gaining the contract detail),
`architecture/loop-system.md` (the boundary the rejected iteration-patterns would blur),
`architecture/swarm-communication-layer.md` (the bus design Graft 1's per-invocation
`SESSION_ID` and cleanup teardown build on),
`skills/wave-execution/references/spec-format.md` (the contract these fields extend —
edited in the later build unit, not by this ADR),
`skills/wave-execution/SKILL.md` (the Topic Naming table the gate-verdict bus flow, D1,
must stay consistent with — also edited in the later build unit, not by this ADR).
