# Spec Format — the `spec_root` contract

`spec_root` is a directory the **caller** supplies. This skill holds no domain
knowledge about what any wave does — it only defines the shape a wave bundle must
have so the generic orchestrator machinery in `SKILL.md` can run it.

## Layout (pick one)

**Option A — single file:**
```
spec_root/
  bundle.md         # optional bundle header (bundle-level fields)
  waves.md          # all waves, `## Wave N — <name>` sections in ascending order
```

**Option B — one file per wave:**
```
spec_root/
  bundle.md         # optional bundle header (bundle-level fields)
  waves/
    01-<name>.md
    02-<name>.md
    ...
```

Waves MUST be numbered contiguously starting at 1 — no gaps, no duplicates. In
Option A, `## Wave N` headers must appear in ascending numeric order; in Option B,
filenames must sort into that same order. In both options the bundle-level fields
(`dispatch_budget`, `session_id`, `output_topic`, `bus_endpoint`, `gates_command`) live in the optional
`bundle.md` at the `spec_root` root, the bundle header; a bundle without them needs no
`bundle.md`.

## Required fields per wave

Each wave (section or file) must declare all six:

| Field | Meaning |
|---|---|
| `goal` | One-sentence statement of what the wave achieves. |
| `inputs` | Where this wave's inputs come from — static files under `spec_root` and/or a named `outputs` entry from a prior wave. |
| `work_items` | The discrete tasks to dispatch — one per sub-agent, or a rule for generating them at runtime (e.g. "one per file found under `target_dir`"). |
| `agents` | How many sub-agents to dispatch and which model — a fixed count, or a rule (e.g. "one per work_item, sonnet"). |
| `exit_criteria` | The gate: verifiable pass/fail conditions checked against each dispatched agent's report before the wave counts as done. |
| `outputs` | Named artifacts/values this wave hands to later waves; `none` when it hands nothing on (the field itself stays non-empty, rule 5). |

## Optional fields

| Field | Meaning | Default when absent |
|---|---|---|
| `fix_loop_cap` | Iteration cap for this wave's fix loop, declared once per wave. It is counted per wave in a barrier wave and per work_item in a frontier wave (§ DAG-frontier mode). | 3 |
| `output_topic` | Bus topic this wave's agents post completion to. A bundle-level `output_topic` (§ Bundle-level and invocation values) overrides it, and a differing per-wave value is then `VALIDATION_FAILED` (rule 14). | `{SESSION_ID}-rendezvous` (a wave may instead declare a dedicated `{SESSION_ID}-wave-{N}-output` topic) |

## Gate and output-schema fields (optional — ADR 0023 grafts 3/4)

**Per-wave — richer gate types:**

| Field | Level | Values / shape | Default when absent |
|---|---|---|---|
| `gate_type` | per-wave | `exit_criteria` \| `adversarial_verify` \| `judge_panel` \| `step_complete` | `exit_criteria` (today's single check) |
| `skeptics` | per-wave | integer ≥ 1; required iff `gate_type: adversarial_verify` | — |
| `judges` | per-wave | integer ≥ 3, odd; required iff `gate_type: judge_panel` | — |

In the first three modes the caller's `exit_criteria` is supplied **verbatim as the rubric** — it
is never replaced, reworded, or supplemented by the gate machinery. `step_complete` is the one
exception (below): its rubric is the work_item's `done_condition` beside `exit_criteria`, both
verbatim, neither reworded:

- `exit_criteria` (default) — current behavior exactly: one gate agent checks the wave's
  reports against the caller's `exit_criteria`.
- `adversarial_verify` — dispatch `skeptics` agents tasked to actively falsify the wave's
  output against the same `exit_criteria` rubric; any sustained falsification fails the gate.
- `judge_panel` — dispatch `judges` agents that each post a pass/fail verdict against the
  rubric; majority rules.
- `step_complete` — dispatch one gate agent per work_item. Each walks that work_item's
  `done_condition` plus the wave's `exit_criteria`, both verbatim. The work_item passes only if
  the `done_condition.command` exits 0 and its last stdout line equals `done_condition.token`
  exactly, and the `exit_criteria` hold for that work_item's output. In a barrier wave the gate
  passes only when **every** work_item's gate agent returns pass (not a majority: each verdict
  judges a different work_item's done condition). In a frontier wave each work_item is gated on
  its own (§ DAG-frontier mode).

Gate agents post like any other work_item agent — to the bundle-level `output_topic` when one is
declared (it overrides every per-wave value), else the wave's declared `output_topic`, or the
default `{SESSION_ID}-rendezvous` if none declared; no new bus topic is introduced. Each
gate agent's post is a verdict payload: `{agent_id, verdict: pass | fail, rationale}`.

**Per-`work_item` — structured completion:**

| Field | Level | Values / shape | Default when absent |
|---|---|---|---|
| `output_schema` | per-`work_item` | a fenced ```json JSON Schema block | absent (free-text post) |

When a `work_item` declares an `output_schema`, that work_item's bus-post completion must
validate against it. A malformed or non-conforming post is treated as **incomplete** — a gate
failure for that agent, not a spec defect (a malformed *schema* in the spec itself is a spec
defect, caught by preflight rule 10 below).

## Persona, lane, done-condition and edge fields (optional — ADR 0054 A2-A5)

**Per-`work_item`** (declared on a work_item's listed entry in the wave; enumerating a wave's work_items is required only by rule 15, for a wave that declares `depends_on` edges, and by rule 9, for a `step_complete` wave):

| Field | Values / shape | Default when absent |
|---|---|---|
| `persona` | non-empty one-line token naming the persona brief the dispatched agent runs under. Passed verbatim in the brief, never interpreted; it does not override the `agents` model tier. | today's dispatch brief |
| `lane` | non-empty one-line token naming an exclusive-writer resource lane. Within one run (one invocation of the skill) at most one work_item per lane is live; the others wait. In a frontier wave a lane is busy from its work_item's dispatch until that work_item's per-item gate passes or it escalates (its gate and fix agents included); in a barrier wave until the holder posts its completion (`UNIT-VERDICT`) (INTERFACES 1.6.0 AM-6 C-4). The skill only serializes by lane name; leasing the lane's real resources (ports, browsers, devices) stays the caller's job. | no lane constraint |
| `depends_on` | list of work_item ids of the **same wave**: `depends_on: [<work_item>, ...]`. One edge (one listed id) anywhere in the wave makes it a frontier wave; `depends_on: []` declares no edge. | none (barrier wave) |
| `done_condition` | two-key object `{"token": "<str>", "command": "<str>"}`; both values non-empty, one-line strings; no other key. Required under `gate_type: step_complete`, otherwise ignored by the gate machinery. | absent |

`token` is the string `command` prints as its last stdout line on success. The `step_complete`
gate agent passes the work_item only when `command` exits 0 and that line equals `token`
exactly. `persona` and `lane` are validated inline (non-empty, one line), not by a numbered rule.
A work_item generated at runtime (from a `work_items` rule, or a fix agent) may carry `persona`
and `lane`, stated by the rule that generates it; absent, the defaults above apply. In a barrier
wave (one wave-level gate) a lane is released when its holder posts its completion (`UNIT-VERDICT`);
in a frontier wave when the holder's per-item gate passes or escalates (INTERFACES 1.6.0 AM-6 C-4, C1.1).

Entry shape: under the wave's `- **work_items:**` line, each work_item is a listed
`- **<id>**` entry whose fields are `- **<field>:**` sub-bullets (e.g. a `lane` value under its work_item).
Worked example: `example-spec/waves/04-build.md`.

## DAG-frontier mode (optional — ADR 0054 A5)

A **barrier wave** declares no `depends_on` edges: it runs as before, and the next wave starts
only after its wave gate passes. A wave with at least one edge (a work_item whose `depends_on`
names another work_item) is a **frontier wave**. Waves stay barriers to each other; frontiers exist only inside one wave, and
edges never cross waves (rule 15). A frontier wave enumerates its work_items, because an edge
cannot name an item generated at runtime.

| Aspect | Barrier wave | Frontier wave |
|---|---|---|
| Release | all work_items, subject to slot and lane admission | a work_item is released when every blocker's gate has passed, its `lane` is free, and fewer than `max_concurrent` agents are live (gate and fix agents included) |
| Gate | one wave gate on the collective output | one gate per work_item, the wave's `gate_type`, with `exit_criteria` read against that work_item's output only; a criterion over the wave's collective output is not checked inside a frontier wave (put it in a following barrier wave). The wave gate passes when every work_item's gate has passed |
| `fix_loop_cap` (declared once per wave) | counted per wave | counted per work_item |
| `step_complete` `gate_agents` | `work_items_count` | 1 per work_item |
| Exhaustion | wave escalates | `{SESSION_ID}-escalation` with `{halt_reason: "fix-loop-cap-exhausted", wave, work_item, iterations}`; that work_item's transitive dependents are never released, the others run on |

No passed gate is reopened within an invocation, so a failed or escalated work_item never has a
live dependent: non-release is the cancellation. The checkpoint records per-work_item gate
passes; the checkpoint alone decides on resume which work_items have passed. A dependency across
waves is expressed by wave order, never an edge; in a delivery run a dependent that needs a blocker
integrated declares `depends_on` on the blocker's Integrator work_item in its own wave (INTERFACES
1.8.0 AM-8 V13; `frontier-mode.md`).

## Bundle-level and invocation values (optional — ADR 0054 A0, A6, A7, A9)

**Bundle-level spec fields**, declared once in the bundle header beside `dispatch_budget`:
`bundle.md` at the `spec_root` root, for both layout options (§ Layout). They sit inside `spec_root`, so the `spec_root` content hash (the checkpoint key) covers
them:

| Field | Value | Effect |
|---|---|---|
| `session_id` | `^[a-z0-9-]+$` | Replaces the minted `wave-exec-<date>-<uuid>` and is the same value on every invocation, resume included, so every `{SESSION_ID}-*` topic is stable. Absent = minted per invocation as today. Two bundles differing only in `session_id` hash differently and keep two checkpoints. |
| `output_topic` | one literal topic, no placeholder | The one topic for completions and gate verdicts of every wave; overrides per-wave `output_topic`. `{SESSION_ID}-fix-loop-output` and `{SESSION_ID}-escalation` are unchanged. Absent = per-wave values work as before. |
| `bus_endpoint` | `$DELIVERY_ROOT`-relative path `<run-id>/<subtask>/bus.endpoint` (never absolute: the bundle is committed and hashed) | Attach to the caller-owned bus the file names. The file holds `key=value` lines `port, data_dir, pm2_app, pid, session_id, topic`; the port is read only from `$data_dir/port`, and `session_id=` and `topic=` must equal the bundle's; a mismatch or a missing key halts the run before any dispatch. Declared without a bundle `session_id` or `output_topic`, or invoked without `invocation`, it halts before any dispatch with the one line `BUNDLE-ERROR <field>` (INTERFACES 1.5.0 C1.1). The skill skips its own bus bootstrap (step 4) and `cleanup()` (step 8); the identity preflight, `start_session` (step 5) and the final result post still run. When declared, the skill also appends a dispatch record (`dirname(<resolved bus_endpoint>)/dispatch/<invocation>.jsonl`, one JSON line per agent before it is dispatched). Absent = today's bootstrap and teardown. No preflight rule. |
| `gates_command` | one non-empty line: the repo's gate command (in a delivery run copied from the repo profile `gates.command`) | The gate agent that gates a work_item runs it on that work_item's posted head, holding a lane lease like a worker, and is the single writer of `gate-runs/<head>.md`; the controller never runs it (`frontier-mode.md` § `gates_command` gate run; INTERFACES 1.8.0 AM-8 V14). Validated inline (non-empty, one line), not by a numbered rule. Absent = no gate command run. |

**Invocation arguments — not spec fields.** They are passed by the caller on each invocation,
never written in `spec_root`, so they never change the content hash and a resume still finds
its checkpoint:

| Argument | Shape | Effect |
|---|---|---|
| `max_concurrent` | integer >= 1, validated where it is passed; absent = unbounded | Applies to every wave of the invocation. The controller never has more agents live than this, work_item, gate and fix agents all counted; a gate or fix agent with no free slot waits for one. There is no per-wave `max_concurrent`. |
| `invocation` | `^[0-9]+$` | Names the dispatch record file `<invocation>.jsonl`; used only with `bus_endpoint`. |
| `tier_override` | `<work_item>=<tier>`, repeatable | Raises that work_item's tier for this invocation only; the overriding tier is recorded in that worker's dispatch-record `tier` field. A re-dispatch after a rollback is a fresh invocation carrying it, resuming at the unpassed work_items from the checkpoint. |

**Agent ids and accepted posts.** The controller gives every agent it dispatches a `from_agent`
id matching `^[a-z0-9-]+$` and carrying a nonce minted per invocation (`<work_item>-<nonce>`,
`<work_item>-gate<k>-<nonce>`, `<work_item>-fix<k>-<nonce>`), and records its role (worker, gate or fix), wave
and work_item. `<k>` is an index that keeps each id distinct within its work_item: the 1-based
count of agents of that role dispatched for the work_item in this invocation. The binding
constraint is only that each id is unique and matches the charset (ADR 0054 A7). A post counts only when its `from_agent` was assigned in this invocation; the
role decides whether it is a completion (checked against its `output_schema`) or a gate verdict.
With `bus_endpoint`, each dispatch-record line is
`{"agent_id","role":"worker|gate|fix","unit","persona","tier","backend":"agent-tool|claude-p","utc"}`,
with `unit` the served work_item id or `wave-<N>` for a wave-level gate agent and `persona`
`none` for a worker whose work_item declares none (INTERFACES 1.5.0 C1.1),
appended before that agent is dispatched; the caller accepts posts only from ids registered
there. The skill never reads a caller's `status/<agent-id>.verdict` fallback file.

## Dispatch-budget field (optional — ADR 0023 graft 2 / D4)

| Field | Level | Values / shape | Default when absent |
|---|---|---|---|
| `dispatch_budget` | bundle | integer max dispatch count | absent (no budget check) |

When declared, preflight rule 11 (below) computes the bundle's worst-case dispatch count
and refuses to run — `VALIDATION_FAILED`, halt before any dispatch — if that count exceeds
`dispatch_budget`. Rule 11 runs last, after rules 9–10, because it needs each wave's
`gate_type`-derived `gate_agents` count (rule 9) already validated, and the mode of each wave
(barrier or frontier, rule 15). A frontier wave uses the per-work_item term in rule 11.

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
9. `gate_type` validity. If present, must be one of the four enum values
   (`exit_criteria`, `adversarial_verify`, `judge_panel`, `step_complete`);
   `adversarial_verify` requires `skeptics ≥ 1`; `judge_panel` requires an odd
   `judges ≥ 3`. `step_complete` requires every work_item of the wave to be listed
   (enumerated) with `done_condition`, a two-key object `token` and `command`, both non-empty one-line
   strings, no other key. `gate_agents` mapping: `exit_criteria` 1, `adversarial_verify`
   `skeptics`, `judge_panel` `judges`, `step_complete` `work_items_count` in a barrier
   wave and 1 per work_item in a frontier wave. `exit_criteria` prose remains
   required in every mode — it is the rubric supplied verbatim to the three
   original gate modes, and beside `done_condition` for `step_complete`.
10. `output_schema` validity. Any `work_item`'s `output_schema` block must parse
    as a valid JSON Schema; a malformed schema is `VALIDATION_FAILED` — distinct
    from a runtime non-conforming post against a valid schema, which is a gate
    failure for that agent, not a preflight failure.
13. `session_id`, when declared, matches `^[a-z0-9-]+$`. As a bundle field it is in the
    `spec_root` content the checkpoint key hashes. Runs after rules 9-10.
14. A bundle-level `output_topic` is a literal: no `{SESSION_ID}` or other placeholder. When
    one is declared, no per-wave `output_topic` differs from it. With none declared,
    per-wave values are checked as before, `{SESSION_ID}-wave-{N}-output` included.
15. `depends_on` is acyclic, every edge names a work_item declared in the same wave (no
    cross-wave edge), and a wave that declares edges enumerates its work_items (lists every
    work_item; no part of its `work_items` is a runtime rule).
11. Dispatch-budget check. Runs **last**, after rules 9–10 and 13–15 (gate-agent counts,
    schema validity and each wave's barrier/frontier mode must be known first). When
    `dispatch_budget` is declared, compute the bundle's worst-case dispatch count as the sum
    over waves of:
    - barrier wave: `work_items_count + (fix_loop_cap + 1) × gate_agents`;
    - frontier wave: `work_items_count × (1 + (fix_loop_cap + 1) × g)`, `g` = gate agents
      per work_item (1 for `exit_criteria` and `step_complete`, else `skeptics` or `judges`);
    where `gate_agents` for a barrier wave is 1 for `exit_criteria` (the formula charges 1),
    `skeptics` for `adversarial_verify`, `judges` for `judge_panel`, or `work_items_count`
    for `step_complete` (per rule 9's mapping). If the sum exceeds `dispatch_budget`,
    `VALIDATION_FAILED` naming the projected count, the budget, and the remedy (split the
    bundle at a wave boundary) — halt before any dispatch.

Rule 12 is the deferred `spec_ref` rule of ADR 0023; the gap in the numbering is intended.
Rules execute in the order 1–10, 13–15, then 11 last.

Any failure is `VALIDATION_FAILED`, naming the specific failing check and wave
number; halt before any dispatch — the same halt-before-dispatch discipline
used across this corpus's validation-heavy skills, generalized from one spec
file to a directory of N wave specs.

## Worked example

See `references/example-spec/` for a complete, working bundle (audit → fix → verify, plus a
frontier wave with `depends_on`, `lane`, `persona` and `gate_type: step_complete`) that
satisfies every rule above — read it alongside this file rather than inferring the format from
prose alone.
