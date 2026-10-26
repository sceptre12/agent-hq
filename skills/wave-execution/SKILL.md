---
name: wave-execution
version: 1.1.0
description: >
  Pure orchestrator that runs a caller-defined spec_root of N sequential waves of
  work to completion: validates the wave-bundle spec, bootstraps (or attaches to)
  the swarm bus, dispatches each wave's work as sub-agents, rendezvous over the
  bus, gates each wave against its own exit criteria, and fix-loops on gate
  failure up to an iteration cap before escalating. Domain-agnostic — the
  spec_root, not this skill, defines what each wave does. Optional extensions:
  a caller-pinned session and topic, a caller-owned bus, a concurrency cap,
  per-work_item persona/lane/done condition, and DAG-frontier waves. Use when a
  caller has (or wants to author) a spec_root describing staged, heterogeneous
  work — e.g. "run my N-wave audit/migration/release spec" — and needs it
  executed wave by wave with gates between stages and fix-loop recovery on
  failure. Not for iterating one artifact against a single rubric to
  convergence — that's loop-controller/the loop-system (see Disambiguation below).
---

## Trigger

Use when something needs to run a `spec_root`-defined bundle of N waves to
completion: dispatching each wave's work agents, gating against the wave's own
declared exit criteria, fix-looping on failure, and escalating on cap exhaustion.
The controller is a pure state machine — it holds no domain knowledge; what
any work item does is entirely the spec bundle's job (`references/spec-format.md`).

**Inputs.** `spec_root` (required). Invocation arguments, never spec fields and
outside the `spec_root` hash: `max_concurrent` (integer >= 1, the caller's free
slots; absent = unbounded), `invocation` (`^[0-9]+$`), `tier_override`
(`<work_item>=<tier>`, repeatable: raises that work_item agent's tier for this
invocation only; recorded as `tier` in its dispatch record line). Optional bundle fields: `session_id`, `output_topic`,
`bus_endpoint`; optional per-work_item fields: `persona`, `lane`, `depends_on`,
`done_condition` (`spec-format.md`). A bundle that declares none of them runs
exactly as version 1.0.0 did.

## Operating Mode Gate (determine this FIRST)

1. Check whether the Agent tool is present in your available toolset.
2. **If yes** — dispatch every sub-agent via the Agent tool.
3. **If no** — dispatch every sub-agent via Bash (`claude -p`).

Establish this before doing anything else — it decides every dispatch call below.

## Steps

1. **Resolve `spec_root`.** Take the caller-supplied absolute path; resolve with
   `realpath`. Hash `spec_root`'s content and look for the checkpoint
   (§ Resume / Checkpoint). Absent or mismatched → run from wave 1. A match →
   note the waves and work_items it records as gate-passed (step 6); if it
   records **every** wave gate-passed, report the run already complete and exit
   now, before touching the bus or dispatching anything.

2. **Preflight-validate** the bundle against every rule in `spec-format.md`
   § Preflight validation rules, in order 1-10, 13-15, then rule 11 last; also
   validate the invocation arguments as passed (`max_concurrent`, `invocation`,
   `tier_override`). Any failure is `VALIDATION_FAILED`, naming the check and
   wave; halt before any dispatch. A declared `bus_endpoint` with no bundle
   `session_id` or `output_topic`, or no `invocation` argument, halts here
   before any dispatch with the one line `BUNDLE-ERROR <field>` (INTERFACES
   1.5.0 C1.1).

3. **Derive `SESSION_ID`** before the bus step. If the bundle declares
   `session_id`, use it verbatim — the same value on every invocation, resume
   included. Otherwise mint a fresh one per invocation:
   `SESSION_ID="wave-exec-$(date +%Y%m%d)-$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)"`.
   Also mint `NONCE` (same recipe, `cut -c1-6`) once per invocation for agent
   ids (step 6.2). Pass `SESSION_ID` explicitly to every agent and bus call.

4. **Bus.** **If `bus_endpoint` is declared — attach, skip this bootstrap.**
   Resolve the value against `$DELIVERY_ROOT`, read `data_dir` and `pm2_app`
   from the file as `DATA_DIR` and `APP_NAME`, and the port only from
   `$DATA_DIR/port`. Its `session_id=` and `topic=` must equal the bundle
   `session_id` and `output_topic`; a mismatch or missing key halts before any
   dispatch. Never start, restart or delete the caller's bus and define no
   `cleanup()` — the bus lifecycle and its recovery are the caller's.
   **Otherwise bootstrap** — source nvm, resolve `pm2`, set
   `DATA_DIR=/tmp/${SESSION_ID}` and `APP_NAME=swarm-mcp-${SESSION_ID}`, `cd` to
   the bus repo. If `pm2` already lists `APP_NAME` (left by a crashed
   invocation under a pinned `session_id`), recover it with `pm2 restart` —
   never a second `pm2 start`, never `reload`; else `pm2 start
   ecosystem.config.cjs` (a leftover `DATA_DIR` without its app is reused).
   Poll for `${DATA_DIR}/port` (max 30 × 0.3s) and read the port **only** from
   it. Define `cleanup()`: `end_session({session_id: SESSION_ID})` first,
   **then** `pm2 delete` the app, then `rm -rf "${DATA_DIR}"`. Register
   `trap cleanup EXIT SIGINT SIGTERM` immediately, before acquiring anything.
   The trap is best-effort only (`SIGKILL` and a fresh Bash tool call both
   escape it), so step 8 also calls `cleanup()` explicitly. Either path: run
   the identity preflight (§ Bus Rules) before the first dispatch.

5. **Start the session** — `start_session({session_id: SESSION_ID})`
   (idempotent, also on an attached bus) once the identity preflight passed and
   before any wave is dispatched.

6. **Run the waves in order, 1..W**, skipping waves the checkpoint records as
   gate-passed. A wave whose work_items declare no `depends_on` edge is a
   **barrier wave** (below, as in 1.0.0; `depends_on: []` declares none); a
   wave with at least one edge is a **frontier wave**, run per `references/frontier-mode.md`. Declared waves are always
   barriers to each other. For every wave:
   1. Read wave N's spec (goal, inputs, work_items, agents, exit_criteria,
      outputs). Resolve `inputs` that reference a prior wave's `outputs` from
      what that wave actually produced — never invent a value.
   2. **Dispatch** one agent per work_item (or per the wave's `agents` rule).
      Give each agent its own `from_agent` id matching `^[a-z0-9-]+$` and
      carrying `NONCE` (shapes in `references/frontier-mode.md`) and record its
      role (`worker`, `gate` or `fix`), wave and work_item; no id is reissued
      under one `session_id`, so two agents never share one. When `bus_endpoint` is declared, append the dispatch record
      line for the agent to `dirname(<resolved bus_endpoint>)/dispatch/<invocation>.jsonl`
      **before** dispatching it (fields in `references/frontier-mode.md`). The
      brief carries `session_id`, its `from_agent` id, the wave number, its
      `inputs`, the topic, the wave's `exit_criteria` verbatim, and the
      work_item's `persona` verbatim when declared (never interpreted; it does
      not change the `agents` tier). Admission, for work_item, gate and fix
      agents alike: never more than `max_concurrent` agents live at once — an
      agent with no free slot waits for one; at most one live work_item per
      `lane` within one run (one invocation of the skill) — the others wait. The
      lane stays busy from dispatch until, in a barrier wave (one wave-level
      gate), the holder posts its completion (`UNIT-VERDICT`), or, in a
      frontier wave, the holder's per-item gate passes or escalates
      (INTERFACES 1.6.0 AM-6 C-4, C1.1; `references/frontier-mode.md`).
   3. **Rendezvous:** poll the topic — the bundle `output_topic` when declared
      (it overrides every per-wave value), else the wave's `output_topic`, else
      `{SESSION_ID}-rendezvous`. The bus post is the sole completion signal.
      A post counts only when its `from_agent` was assigned in this invocation
      (with `bus_endpoint`: registered in the dispatch record); the recorded
      role says whether it is a completion for that work_item or a gate
      verdict. Posts of other waves, work_items or earlier invocations never
      match.
   4. **Gate:** evaluate the wave's `gate_type` (default `exit_criteria`) with
      the caller's `exit_criteria` **verbatim as the rubric**:
      - `exit_criteria` (default) — one gate agent checks the wave's reports.
      - `adversarial_verify` — `skeptics` agents actively try to falsify the
        output against the same rubric; a sustained falsification the fix loop
        cannot resolve fails the gate.
      - `judge_panel` — `judges` agents each post pass/fail; majority rules.
      - `step_complete` — one gate agent per work_item walks that work_item's
        `done_condition` plus the wave's `exit_criteria`, both verbatim; this is
        the only case where the rubric has a second part, and neither is
        reworded. The agent passes the work_item only when `command` exits 0,
        its last stdout line equals `token`, and the `exit_criteria` hold for
        that work_item's output. Which output it reads is the
        caller's brief. A barrier wave passes only when **every** gate agent
        passes (no majority).
      If a work_item declared an `output_schema`, validate its post against it
      here; a malformed post makes that agent's completion incomplete (a gate
      failure, not a spec defect). All pass → capture the wave's `outputs`,
      write the checkpoint with each work_item's gate verdict, go to wave N+1.
      Any failure → Fix Loop (step 7) before proceeding.

7. **Fix loop (on gate failure):** dispatch fix agent(s) scoped to the failing
   items only (they wait for a free slot like any agent), re-run the gate
   after each attempt, and post to `{SESSION_ID}-fix-loop-output`. Cap: the
   wave's `fix_loop_cap` (declared once per wave, default 3), counted per wave
   in a barrier wave and per work_item in a frontier wave. On exhaustion post `{SESSION_ID}-escalation` with
   `{ halt_reason: "fix-loop-cap-exhausted", wave: N, iterations: <cap> }`
   (plus `work_item: <id>` in a frontier wave) — never retry past the cap.
   A barrier wave then stops the run; a frontier wave never releases that
   work_item's transitive dependents and runs the rest on
   (`references/frontier-mode.md`).

8. **After the final wave's gate passes, or on any halt/escalation path:**
   write the checkpoint, post the final result to the completion topic (the
   bundle `output_topic` when declared, else `{SESSION_ID}-rendezvous` or a
   spec-declared completion topic), then — **only when `bus_endpoint` is
   absent** — run `cleanup()` explicitly as the last action. With
   `bus_endpoint`, skip `cleanup()` entirely: session close and teardown are
   the caller's. Only the checkpoint persists across invocations.

## Bus Rules

Match the idiom of `skills/loop-controller/SKILL.md`:

- **Identity preflight:** sample `/health` 2-3 times before the first dispatch;
  every response must show `status: ok`, `db_ok: true` when present, **and**
  `app_name`/`data_dir` matching `APP_NAME`/`DATA_DIR` — this session's own
  values, or the `bus_endpoint` values under attach. A single `ok` is not proof
  the port is yours; `degraded` is not-ready.
- **Recovery:** `pm2 restart`, **never** `pm2 reload` (it overlaps workers on the
  shared state file) — and only on a bus this skill started. An attached bus is
  recovered by the caller only.
- **Explicit `session_id`** on every send/broadcast call.
- **Port discovery:** only from `$DATA_DIR/port` — never guessed or reused.
- **No port claim:** this skill adds no claim step; a caller that binds ports
  claims them and passes `bus_endpoint`.
- **Canonical reference:** bus mechanics (tool schemas, `from_agent`, health,
  recovery) are in `skills/swarm-communication/SKILL.md` — do not re-derive.

## Resume / Checkpoint

- **Location:** `<parent-directory-of-spec_root>/.wave-execution-state/<spec_root-content-hash>.json`
  — a sibling of `spec_root`. Bundle fields (`session_id` included) are in the
  hash, so two bundles differing only in `session_id` keep two checkpoints;
  invocation arguments are not, so a changed `max_concurrent` still resumes.
- **Bootstrap (step 1):** absent or mismatched hash → start at wave 1.
- **Matching checkpoint:** skip every wave it records as gate-passed and, in a
  frontier wave, every work_item it records as gate-passed; resume at the
  unpassed ones. Unpinned run: a **brand-new** `SESSION_ID` (step 3). Pinned
  run: the same `session_id`, so every `{SESSION_ID}-*` topic is stable.
- **The checkpoint is the only authority** for what has passed. A completion
  post for a work_item it does not record is re-gated, never taken as passed;
  gate verdicts and escalations of an earlier invocation never count.
- **All passed:** report complete and exit without bus or dispatch.
- **Writes:** on each wave gate pass (step 6.4), on each work_item gate pass in
  a frontier wave, and at step 8 — per-work_item entries with their verdicts.
- **Teardown unchanged:** step 8's `cleanup()` when the bus is the skill's own.

## Constraints

- One `spec_root` drives one run; concurrent runs against it are not
  coordinated. Sequential resumed runs are, via the checkpoint.
- The skill never reads a wave's target files — domain access belongs to the
  dispatched agents (the checkpoint is the skill's own state). It never reads a
  caller's fallback file (`status/<agent-id>.verdict`); the caller posts that
  record under the agent's id.
- `persona` and `lane` are names only: the brief carries `persona`; leasing a
  lane's real resources is the caller's.

## Prohibited Side Channels

The controller MUST NOT determine an outcome from: stdout/stderr of a `claude -p`
process, its exit code (never branch on `$?`), exported env vars, task output
files, sibling-agent files in `data_dir`, fallback status files, or named pipes.
The bus post to the topic is the sole valid signal; a dispatch that returns with
no new topic message is a gate failure for that agent.

**Exception — dispatch stalled/killed with no bus post:** still a gate failure,
but the fix agent's scope may be "verify ground truth for the missing item and
post the completion/verdict to the topic"; the controller still never reads
domain files.

## Topic Naming

`{SESSION_ID}` is the pinned `session_id` when declared.

| Topic | Written by | Purpose |
|---|---|---|
| bundle `output_topic` (literal) | every wave's agents and gate agents; controller final result | When declared, the one topic for the whole spec, overriding per-wave values. |
| `{SESSION_ID}-wave-{N}-output` | wave N's agents | A wave's own output topic when declared (no bundle topic). |
| `{SESSION_ID}-rendezvous` | any wave's agents (default) | Default completion topic. Gate agents (any `gate_type`) post here too — verdict payload `{agent_id, verdict: pass \| fail, rationale}`. |
| `{SESSION_ID}-fix-loop-output` | fix agents | Fix-loop iteration results. |
| `{SESSION_ID}-escalation` | controller | Halt signal on fix-loop cap exhaustion; written, not polled. |

## Disambiguation vs the loop system

`wave-execution` is **not** `loop-controller`. The `loop-*` family
(`architecture/loop-system.md`) converges **one artifact** on **one rubric** — a
single runner→grader→fixer cycle with the same criteria every iteration.
`wave-execution` runs **staged, heterogeneous waves**, each with its own goal,
work items and exit criteria, one wave's output feeding the next.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "The wave's agents all returned, so the wave is done." | Only a bus post to the topic counts — a returned dispatch with no new message is a gate failure (Prohibited Side Channels). |
| "The spec doesn't say what 'exit_criteria' means here, I'll use my own judgment." | Halt at preflight (`spec-format.md` rule 8) — vague criteria are the caller's defect. |
| "One fix attempt failed, let me just try a few more times past the cap." | The cap is non-negotiable — escalate at `fix_loop_cap` exhaustion. |
| "I'll skip the `/health` identity check, the bus was clearly just started by me (or the caller handed it over)." | Sample 2-3x and compare `app_name`/`data_dir` anyway — a stale port file looks identical to a fresh one. |
| "This looks like a loop-controller job since it's iterating." | One artifact/one rubric is the loop; staged different-goal stages are wave-execution. |
| "I'll hardcode this caller's wave count/paths into the skill to save a step." | Wave count, goals and paths come from `spec_root` only. |
| "A blocker passed, so release its dependents before their lane is free." | Release only when every blocker passed, the lane is free and a slot is free (`max_concurrent`, gate and fix agents included). |
| "There's a completion post for this work_item on the pinned topic, so it passed." | Only the checkpoint says what passed; an unrecorded post is re-gated. |

## Exit criteria

- [ ] Preflight passed every rule (1-10, 13-15, 11 last) and the invocation
      arguments validated before any dispatch, or the run stopped at
      `VALIDATION_FAILED` naming the check and wave.
- [ ] `SESSION_ID` was the pinned `session_id` when declared, else minted fresh;
      passed explicitly to every agent and bus call.
- [ ] `/health` was sampled 2-3 times with `app_name`/`data_dir` matching (the
      endpoint values under `bus_endpoint`), none `degraded` or `db_ok: false`.
- [ ] `start_session` ran before the first dispatch. Without `bus_endpoint`,
      `cleanup()` ran as the explicit final step with `end_session` before
      `pm2 delete` (no dangling PM2 process or session); with it, no bootstrap,
      `cleanup()` or restart touched the caller's bus.
- [ ] Every gate used only its wave's own `exit_criteria` (plus the work_item's
      `done_condition` under `step_complete`), under the declared `gate_type`,
      never downgraded; a barrier `step_complete` wave passed only when every
      gate agent passed.
- [ ] Every `output_schema` post was validated at the gate.
- [ ] Live agents (work_item, gate, fix) never exceeded `max_concurrent`; no
      lane ever had two live work_items; with `bus_endpoint`, every agent had
      its dispatch record line before it was dispatched.
- [ ] Every counted post came from a `from_agent` id assigned in this
      invocation; no outcome was read from stdout, exit code, env vars or a file.
- [ ] Frontier waves gated each work_item on its own output, never released a
      dependent of an unpassed work_item, and reopened no passed gate.
- [ ] Fix loops stayed within the wave's `fix_loop_cap` (counted per wave, or
      per work_item in a frontier wave) and posted `{SESSION_ID}-escalation` on exhaustion.
- [ ] A resumed run skipped exactly what the checkpoint records as passed and
      re-gated anything else; with `dispatch_budget`, rule 11 held.

## References

- [references/spec-format.md](references/spec-format.md) — the `spec_root`
  contract: layout, fields, preflight validation rules.
- [references/frontier-mode.md](references/frontier-mode.md) — DAG-frontier
  release loop, per-work_item gate and fix loop, halt, the dispatch record.
- [references/example-spec/](references/example-spec/) — a working example
  bundle with barrier and frontier waves, and its tests.
- `architecture/wave-execution.md` — components, contract, settled decisions.
- `architecture/loop-system.md` — the loop family disambiguated above.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (2026-07-04 entry, "Skills have no
standardized export path")
Lineage: X-context-docs skills/wave-execution@0e9281e (heavily refit —
generalized from an employer-specific 7-wave release pipeline to a
caller-defined N-wave orchestrator per user ruling 2026-07-05; spec_root is
caller-supplied, this skill ships only the format contract and one illustrative
example)
Extended (1.1.0): ADR 0054 (`decisions/0054-adr-0023-amendment-delivery-workflow.md`,
A0-A9, owner answers Q1-Q11, 2026-10-26), delivery workflow W1 item 9; contracts per
`architecture/delivery-workflow/INTERFACES.md` part C (C1.1-C1.3).
