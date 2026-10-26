---
name: wave-execution
description: >
  Pure orchestrator that runs a caller-defined spec_root of N sequential waves of
  work to completion: validates the wave-bundle spec, bootstraps the swarm bus,
  dispatches each wave's work as sub-agents, rendezvous over the bus, gates each
  wave against its own exit criteria, and fix-loops on gate failure up to an
  iteration cap before escalating. Domain-agnostic — the spec_root, not this
  skill, defines what each wave does; this skill supplies only the generic
  wave-running machinery (dispatch, rendezvous, gate, fix-loop, escalate). Use
  when a caller has (or wants to author) a spec_root describing staged,
  heterogeneous work — e.g. "run my N-wave audit/migration/release spec" — and
  needs it executed wave by wave with gates between stages and fix-loop recovery
  on failure. Not for iterating one artifact against a single rubric to
  convergence — that's loop-controller/the loop-system (see Disambiguation below).
---

## Trigger

Use when something needs to run a `spec_root`-defined bundle of N waves to
completion: dispatching each wave's work agents, gating the wave against its own
declared exit criteria, fix-looping on failure, and escalating on cap exhaustion.
The controller is a pure state machine — it holds no domain knowledge and never
knows what any wave's work items actually do; that is entirely the spec bundle's
job (`references/spec-format.md`).

## Operating Mode Gate (determine this FIRST)

1. Check whether the Agent tool is present in your available toolset.
2. **If yes** — dispatch every sub-agent via the Agent tool.
3. **If no** — dispatch every sub-agent via Bash (`claude -p`).

Establish this before doing anything else — it decides every dispatch call below.

## Steps

1. **Resolve `spec_root`.** Take the caller-supplied absolute path (e.g.
   `/abs/path/to/spec-bundle`); resolve with `realpath` before use. Then check
   for a resume checkpoint (§ Resume / Checkpoint below): hash `spec_root`'s
   content and look for
   `<parent-directory-of-spec_root>/.wave-execution-state/<spec_root-content-hash>.json`.
   A mismatched or absent hash means no valid checkpoint — proceed to step 2
   and run from wave 1. If a matching checkpoint exists, note which waves it
   already records as gate-passed (used in step 6); if it already shows
   **every** wave gate-passed, report the run already complete and exit now —
   before bootstrapping the bus or dispatching anything.

2. **Preflight-validate the spec bundle** against every rule in
   `references/spec-format.md` § Preflight validation rules. Any failure is
   `VALIDATION_FAILED`, naming the specific failing check and wave number; halt
   before any dispatch.

3. **Derive `SESSION_ID`** before bootstrapping the bus:
   `SESSION_ID="wave-exec-$(date +%Y%m%d)-$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)"`.
   Pass it explicitly to every wave agent and every bus call. This is a
   **brand-new** `SESSION_ID` even on a resumed run (§ Resume / Checkpoint) —
   resume is never keyed on reusing a prior run's bus session.

4. **Bootstrap the bus** — source nvm, resolve `pm2`, set
   `DATA_DIR=/tmp/${SESSION_ID}` and `APP_NAME=swarm-mcp-${SESSION_ID}`, `cd` to
   the bus repo, start it (`pm2 start ecosystem.config.cjs`), poll for
   `${DATA_DIR}/port` (max 30 × 0.3s), read the port **only** from
   `${DATA_DIR}/port`. Define `cleanup()` as: `end_session({session_id:
   SESSION_ID})` first, **then** `pm2 delete` the app, then
   `rm -rf "${DATA_DIR}"` — session close must happen before the bus that
   backs it is torn down. Register `trap cleanup EXIT SIGINT SIGTERM`
   immediately after defining it, before any resource is acquired —
   `SIGKILL` cannot be trapped, and **so is a fresh Bash tool invocation**:
   in an agent harness, an `EXIT` trap does not carry over from one Bash
   call to the next, so it is best-effort only, not a guarantee. Treat
   `cleanup()` as something this skill must also invoke as an explicit final
   step (§ step 8) rather than relying on the trap firing. See § Bus Rules
   below before the first dispatch.

5. **Start the session** — call `start_session({session_id: SESSION_ID})`
   (idempotent) once the bus readiness/identity preflight (§ Bus Rules) has
   passed, and before any wave is dispatched. Pass `SESSION_ID` in every
   wave agent's brief from this point on.

6. **Run the waves in order, 1..W** — skipping any wave step 1 found already
   recorded as gate-passed in a matching checkpoint, and starting at the first
   incomplete wave (§ Resume / Checkpoint):
   1. Read wave N's spec (goal, inputs, work_items, agents, exit_criteria,
      outputs) per `references/spec-format.md`. Resolve any `inputs` referencing
      a prior wave's `outputs` from what that wave actually produced — never
      invent a value the spec doesn't declare.
   2. **Dispatch** one sub-agent per work_item (or per the wave's `agents` rule),
      passing `session_id`, wave number, its `inputs`, and the wave's
      `exit_criteria` text verbatim — a dispatched agent is judged against the
      spec's own criteria, not a criterion this skill improvises.
   3. **Rendezvous:** poll the wave's topic — its declared `output_topic`, else
      the default `{SESSION_ID}-rendezvous` — for each dispatched agent's
      completion post. The bus post is the sole completion signal (§ Prohibited
      Side Channels).
   4. **Gate:** evaluate the wave's declared `gate_type` (default `exit_criteria`
      when absent) against the caller's `exit_criteria`, supplied **verbatim as
      the rubric** in every mode:
      - `exit_criteria` (default) — current behavior exactly: one gate agent
        checks the wave's reports against `exit_criteria`.
      - `adversarial_verify` — dispatch `skeptics` agents briefed to actively
        falsify the wave's output against the same `exit_criteria` rubric; any
        sustained falsification the fix loop cannot resolve fails the gate.
      - `judge_panel` — dispatch `judges` agents, each posting its own pass/fail
        verdict against the rubric; majority rules.
      If any work_item declared an `output_schema`, validate its agent's post
      against that schema as part of this gate step — a non-conforming or
      malformed post makes that agent's completion **incomplete** (a gate
      failure for that agent, not a spec defect; a malformed schema in the spec
      itself was already caught at preflight, rule 10). All pass → capture the
      wave's declared `outputs`, write/update the checkpoint (§ Resume /
      Checkpoint) with this wave's `work_items` and their gate verdicts, then
      proceed to wave N+1. Any failure → enter the Fix Loop (step 7) for this
      wave before proceeding.

7. **Fix loop (on gate failure):** dispatch fix agent(s) scoped to the specific
   failing items only, re-run the wave's gate after each fix attempt. Cap
   iterations at the wave's `fix_loop_cap` (default 3). Fix agents post to
   `{SESSION_ID}-fix-loop-output`. On cap exhaustion: post
   `{SESSION_ID}-escalation` with `{ halt_reason: "fix-loop-cap-exhausted", wave: N, iterations: <cap> }`
   and **stop** — never silently retry past the cap, never proceed to the next
   wave with a failing gate.

8. **After the final wave's gate passes (or on any halt/escalation path):**
   post the final result to `{SESSION_ID}-rendezvous` (or a spec-declared
   completion topic), then run `cleanup()` explicitly (step 4) as this skill's
   own last action — do not rely solely on the `EXIT` trap firing. A normal
   successful run still tears down its per-session bus exactly as before; only
   the checkpoint file (§ Resume / Checkpoint) is deliberately persistent
   across invocations.

## Bus Rules

Match the idiom of `skills/loop-controller/SKILL.md` — do not re-derive weaker
versions of these:

- **Identity preflight:** sample `/health` 2-3 times before the first dispatch;
  every response must show `status: ok` **and** `app_name`/`data_dir` matching
  this session's own `APP_NAME`/`DATA_DIR`. A single `ok` is not proof the port
  is yours. `/health` can also report `status: degraded` (and, where present, a
  `db_ok` field) — treat anything other than `status: ok` **and** `db_ok: true`
  (when the field is present) as not-ready; do not proceed on a `degraded`
  response.
- **Recovery:** `pm2 restart`, **never** `pm2 reload` — reload overlaps old/new
  workers on the shared bus state file.
- **Explicit `session_id`:** pass it on every send/broadcast call, never rely on
  an implicit default.
- **Port discovery:** read only from `$DATA_DIR/port` — never guess, never reuse
  a port from a prior session.
- **Canonical reference:** bus mechanics (tool schemas, health semantics,
  recovery) are canonically documented in `skills/swarm-communication/SKILL.md`
  — consult it rather than re-deriving.

## Resume / Checkpoint

Machinery only — no new caller-facing field (ADR 0023 Graft 1 / D3). Turns the
manual "split at a wave boundary" discipline into an enforced resume
path instead of always re-running a bundle from wave 1.

- **Checkpoint location:**
  `<parent-directory-of-spec_root>/.wave-execution-state/<spec_root-content-hash>.json`
  — a sibling directory to `spec_root`, not nested inside it.
- **On bootstrap (step 1):** hash `spec_root`'s content and look for a
  checkpoint at that path. A mismatched or absent content hash means "no
  valid checkpoint" — start at wave 1. The hash guards against resuming a
  `spec_root` that changed underneath a prior run.
- **If a matching checkpoint exists:** skip every wave it already records as
  gate-passed and start a **brand-new bus session** (a new `SESSION_ID`,
  derived exactly as in step 3) at the first incomplete wave — resume is
  never keyed on reusing a prior session's bus state.
- **If the checkpoint already shows every wave gate-passed:** report the run
  as already complete and exit — without dispatching anything or
  bootstrapping a new bus session.
- **On each wave's gate pass (step 6.iv):** write/update the checkpoint with
  that wave's `work_items` and their gate verdicts.
- **Teardown is unchanged:** a normal successful run still tears down its
  per-session bus exactly as before (step 8's `cleanup()`); only the
  checkpoint file is deliberately persistent across invocations.

## Constraints

- One `spec_root` bundle drives one run; concurrent runs against the same
  `spec_root` are not coordinated by this skill. Sequential *resumed* runs
  against the same `spec_root` **are** coordinated, via the checkpoint file
  (§ Resume / Checkpoint above) — only true concurrency remains uncoordinated.
- The skill never reads a wave's target files itself — all domain-level file
  access is delegated to the dispatched wave agents. This excludes the
  skill's own `.wave-execution-state/` checkpoint bookkeeping (§ Resume /
  Checkpoint above), which is the skill's own state, not domain data.

## Prohibited Side Channels

The controller MUST NOT determine a sub-agent's or wave's outcome from any of:
stdout/stderr of a `claude -p` process, its exit code (never branch on `$?`),
environment variables a sub-agent exported, task output files, sibling-agent
files in `data_dir`, or named pipes. The bus post to the wave's topic is the sole
valid signal. A dispatch that returns with no new topic message is a gate
failure for that agent, not a side channel to investigate.

**Exception — dispatch stalled/killed with no bus post:** this is still a gate
failure, but the fix agent's scope may be "verify ground truth for the missing
item and post the completion/verdict to the topic" rather than redoing the
work; the controller itself still never reads domain files.

## Topic Naming

| Topic | Written by | Purpose |
|---|---|---|
| `{SESSION_ID}-wave-{N}-output` | wave N's agents | Dedicated output topic when a wave declares one instead of using the shared rendezvous topic. |
| `{SESSION_ID}-rendezvous` | any wave's agents (default) | Default multi-agent completion signal, `WAVE_N_DONE`-style per agent. Gate agents (any `gate_type`) post here too — no dedicated gate topic exists; each gate agent's post is a verdict payload `{agent_id, verdict: pass \| fail, rationale}`. |
| `{SESSION_ID}-fix-loop-output` | fix agents | Fix-loop iteration results, read by the controller between fix attempts. |
| `{SESSION_ID}-escalation` | controller | Halt signal on fix-loop cap exhaustion. The controller writes here and stops; it is not required to poll this topic. |

## Disambiguation vs the loop system

`wave-execution` is **not** `loop-controller`. The `loop-*` family
(`architecture/loop-system.md`) runs an iterative grade-fix loop on **one
artifact** against **one rubric** to convergence or exhaustion — a single
runner→grader→fixer cycle, same criteria every iteration. `wave-execution` runs
**staged, heterogeneous waves**, each with its own goal, work items, and exit
criteria, where one wave's output becomes the next wave's input — there is no
shared rubric across waves and no expectation the same check repeats. Use
`loop-controller` to converge one artifact on a score; use `wave-execution` when
the work itself is staged and different in kind from one stage to the next.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "The wave's agents all returned, so the wave is done." | Only a bus post to the wave's topic counts — a returned dispatch with no new message is a gate failure for that agent (Prohibited Side Channels). |
| "The spec doesn't say what 'exit_criteria' means here, I'll use my own judgment." | Halt at preflight instead (`spec-format.md` rule 8) — vague criteria are a spec defect for the caller to fix, not something this skill infers. |
| "One fix attempt failed, let me just try a few more times past the cap." | The cap is non-negotiable — escalate at `fix_loop_cap` exhaustion, don't retry past it. |
| "I'll skip the `/health` identity check, the bus was clearly just started by me." | Sample 2-3x and check `app_name`/`data_dir` anyway — a stale port file from a prior run looks identical to a fresh one. |
| "This looks like a loop-controller job since it's iterating." | Check whether it's one artifact/one rubric (loop) or staged different-goal stages (wave-execution) before reaching for either skill. |
| "I'll hardcode this caller's wave count/paths into the skill to save a step." | The skill is domain-agnostic by design — wave count, goals, and paths come from `spec_root` only, never baked into `SKILL.md` or its references. |

## Exit criteria

- [ ] `spec_root` passed every preflight rule in `references/spec-format.md`
      before any dispatch (or the run stopped at `VALIDATION_FAILED` naming the
      specific check and wave).
- [ ] `SESSION_ID` was derived before the bus started and passed explicitly to
      every wave agent and bus call.
- [ ] `/health` was sampled 2-3 times with `app_name`/`data_dir` matching this
      session's own values before the first dispatch, and none of those samples
      showed `degraded` or `db_ok: false`.
- [ ] `start_session` ran before the first wave was dispatched, and `end_session`
      ran as part of `cleanup()` before `pm2 delete` — as an explicit final step,
      not solely relying on the `EXIT` trap.
- [ ] Every wave's gate was evaluated only against that wave's own declared
      `exit_criteria` — never an invented or borrowed criterion.
- [ ] Every wave's gate ran using that wave's declared `gate_type` (or the
      `exit_criteria` default when absent) — a `judge_panel` wave was judged by
      `judges` agents with majority rule, an `adversarial_verify` wave by
      `skeptics` agents actively trying to falsify the result, never silently
      downgraded to a single-agent check.
- [ ] Any work_item declaring an `output_schema` had its agent's post validated
      against that schema at the gate; a non-conforming or malformed post was
      treated as an incomplete gate result for that agent, not ignored.
- [ ] A resumed run against a `spec_root` with a matching checkpoint skipped
      every wave already recorded gate-passed and started at the first
      incomplete wave under a brand-new `SESSION_ID`; a hash mismatch or
      absent checkpoint started fresh at wave 1 instead.
- [ ] When `dispatch_budget` was declared, preflight rule 11 computed the
      worst-case dispatch count (after rules 9-10) and halted with
      `VALIDATION_FAILED` before any dispatch if the projected count exceeded
      the budget.
- [ ] No wave's outcome was read from stdout, exit code, env vars, or a file —
      only from its bus-topic post.
- [ ] Any fix loop that ran stayed within its wave's `fix_loop_cap` and posted
      `{SESSION_ID}-escalation` on exhaustion instead of retrying past it.
- [ ] `cleanup()` ran as this skill's own explicit final step (or, if `SIGKILL`
      bypassed it, the bus process was recovered manually) — no dangling PM2
      process or open session left behind.

## References

- [references/spec-format.md](references/spec-format.md) — the full `spec_root`
  contract: layout, required/optional fields, preflight validation rules.
- [references/example-spec/](references/example-spec/) — a working 3-wave
  example bundle (audit → fix → verify) proving the format.
- `architecture/wave-execution.md` — components, spec contract, bus interfaces,
  constraints, and the settled decisions behind this design.
- `architecture/loop-system.md` — the loop-controller family this skill is
  disambiguated against above.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (2026-07-04 entry, "Skills have no
standardized export path")
Lineage: X-context-docs skills/wave-execution@0e9281e (heavily refit —
generalized from an employer-specific 7-wave release pipeline to a
caller-defined N-wave orchestrator per user ruling 2026-07-05; spec_root is
caller-supplied, this skill ships only the format contract and one illustrative
example)
