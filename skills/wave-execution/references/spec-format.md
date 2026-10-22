# Spec Format — the `spec_root` contract

`spec_root` is a directory the **caller** supplies. This skill holds no domain
knowledge about what any wave does — it only defines the shape a wave bundle must
have so the generic orchestrator machinery in `SKILL.md` can run it.

## Layout (pick one)

**Option A — single file:**
```
spec_root/
  waves.md          # all waves, `## Wave N — <name>` sections in ascending order
```

**Option B — one file per wave:**
```
spec_root/
  waves/
    01-<name>.md
    02-<name>.md
    ...
```

Waves MUST be numbered contiguously starting at 1 — no gaps, no duplicates. In
Option A, `## Wave N` headers must appear in ascending numeric order; in Option B,
filenames must sort into that same order.

## Required fields per wave

Each wave (section or file) must declare all six:

| Field | Meaning |
|---|---|
| `goal` | One-sentence statement of what the wave achieves. |
| `inputs` | Where this wave's inputs come from — static files under `spec_root` and/or a named `outputs` entry from a prior wave. |
| `work_items` | The discrete tasks to dispatch — one per sub-agent, or a rule for generating them at runtime (e.g. "one per file found under `target_dir`"). |
| `agents` | How many sub-agents to dispatch and which model — a fixed count, or a rule (e.g. "one per work_item, sonnet"). |
| `exit_criteria` | The gate: verifiable pass/fail conditions checked against each dispatched agent's report before the wave counts as done. |
| `outputs` | Named artifacts/values this wave hands to the next wave (empty for the terminal wave). |

## Optional fields

| Field | Meaning | Default when absent |
|---|---|---|
| `fix_loop_cap` | Iteration cap for this wave's fix loop. | 3 |
| `output_topic` | Bus topic this wave's agents post completion to. | `{SESSION_ID}-rendezvous` (a wave may instead declare a dedicated `{SESSION_ID}-wave-{N}-output` topic) |

## Gate and output-schema fields (optional — ADR 0023 grafts 3/4)

**Per-wave — richer gate types:**

| Field | Level | Values / shape | Default when absent |
|---|---|---|---|
| `gate_type` | per-wave | `exit_criteria` \| `adversarial_verify` \| `judge_panel` | `exit_criteria` (today's single check) |
| `skeptics` | per-wave | integer ≥ 1; required iff `gate_type: adversarial_verify` | — |
| `judges` | per-wave | integer ≥ 3, odd; required iff `gate_type: judge_panel` | — |

In all three modes the caller's `exit_criteria` is supplied **verbatim as the rubric** — it
is never replaced, reworded, or supplemented by the gate machinery:

- `exit_criteria` (default) — current behavior exactly: one gate agent checks the wave's
  reports against the caller's `exit_criteria`.
- `adversarial_verify` — dispatch `skeptics` agents tasked to actively falsify the wave's
  output against the same `exit_criteria` rubric; any sustained falsification fails the gate.
- `judge_panel` — dispatch `judges` agents that each post a pass/fail verdict against the
  rubric; majority rules.

Gate agents post like any other work_item agent — to the wave's declared `output_topic`, or
the default `{SESSION_ID}-rendezvous` if none declared; no new bus topic is introduced. Each
gate agent's post is a verdict payload: `{agent_id, verdict: pass | fail, rationale}`.

**Per-`work_item` — structured completion:**

| Field | Level | Values / shape | Default when absent |
|---|---|---|---|
| `output_schema` | per-`work_item` | a fenced ```json JSON Schema block | absent (free-text post) |

When a `work_item` declares an `output_schema`, that work_item's bus-post completion must
validate against it. A malformed or non-conforming post is treated as **incomplete** — a gate
failure for that agent, not a spec defect (a malformed *schema* in the spec itself is a spec
defect, caught by preflight rule 10 below).

## Dispatch-budget field (optional — ADR 0023 graft 2 / D4)

| Field | Level | Values / shape | Default when absent |
|---|---|---|---|
| `dispatch_budget` | bundle | integer max dispatch count | absent (no budget check) |

When declared, preflight rule 11 (below) computes the bundle's worst-case dispatch count
and refuses to run — `VALIDATION_FAILED`, halt before any dispatch — if that count exceeds
`dispatch_budget`. Rule 11 runs last, after rules 9–10, because it needs each wave's
`gate_type`-derived `gate_agents` count (rule 9) already validated.

## Preflight validation rules (enforced before any dispatch)

1. `spec_root` resolves via `realpath` and exists as a directory.
2. Exactly one of `waves.md` or `waves/` is present — not both, not neither.
3. Wave count W ≥ 1.
4. Waves are numbered 1..W contiguously — no gaps, no duplicates.
5. Every wave has all six required fields present and non-empty.
6. Every `inputs` reference to a prior wave's `outputs` names an entry that wave
   actually declares (dangling-reference check).
7. No unresolved placeholder tokens (`FILL_IN`, `TODO`, `TBD`, or similar) anywhere
   in the spec bundle.
8. `exit_criteria` reads as verifiable conditions, not aspirations — a wave whose
   only stated criterion is "looks good" / "done" fails this check and is flagged
   for caller review rather than silently accepted. Heuristic: each criterion
   must name an artifact, command, or check a reviewer could actually run or
   inspect (a file path, a test/command invocation, a specific field to read) —
   reject any bundle where a criterion names none of these.
9. `gate_type` validity. If present, must be one of the three enum values
   (`exit_criteria`, `adversarial_verify`, `judge_panel`); `adversarial_verify`
   requires `skeptics ≥ 1`; `judge_panel` requires an odd `judges ≥ 3`.
   `exit_criteria` prose remains required in every mode — it is the rubric
   supplied verbatim to whichever gate machinery runs.
10. `output_schema` validity. Any `work_item`'s `output_schema` block must parse
    as a valid JSON Schema; a malformed schema is `VALIDATION_FAILED` — distinct
    from a runtime non-conforming post against a valid schema, which is a gate
    failure for that agent, not a preflight failure.
11. Dispatch-budget check. Runs **last**, after rules 9–10 (gate-agent counts and
    schema validity must be known first). When `dispatch_budget` is declared,
    compute the bundle's worst-case dispatch count as:
    Σ over waves of `work_items_count + (fix_loop_cap + 1) × gate_agents`,
    where `gate_agents` = 1 for `exit_criteria` (this mode dispatches 0
    additional agents in practice; the formula charges 1 as conservative
    padding), `skeptics` for `adversarial_verify`, or `judges` for
    `judge_panel` (per rule 9's gate_agents mapping). If the sum exceeds
    `dispatch_budget`, `VALIDATION_FAILED` naming the projected count, the
    budget, and the remedy (split the bundle at a wave boundary) — halt before
    any dispatch.

Any failure is `VALIDATION_FAILED`, naming the specific failing check and wave
number; halt before any dispatch — this mirrors loop-controller's pre-flight
discipline (`skills/loop-controller/SKILL.md` Steps §2), generalized from one
`loop.yaml` to a directory of N wave specs.

## Worked example

See `references/example-spec/` for a complete, working 3-wave bundle (audit → fix →
verify) that satisfies every rule above — read it alongside this file rather than
inferring the format from prose alone.
