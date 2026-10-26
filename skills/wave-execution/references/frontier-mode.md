# DAG-frontier mode, admission and the dispatch record

Depth for `SKILL.md` steps 6-8 (ADR 0054 A1-A5, A7; `INTERFACES.md` part C, C1.1-C1.2).
Field shapes and preflight rules are in `spec-format.md`; this file is controller behaviour.

## Which mode a wave runs in

- **Barrier wave:** no work_item declares a `depends_on` edge (`depends_on: []` declares
  none). It runs as in 1.0.0: all its work_items, one wave gate over the wave's output, and
  the next wave starts only after that gate passes.
- **Frontier wave:** at least one edge: a work_item's `depends_on: [<work_item>, ...]` names
  another work_item. The wave enumerates its work_items (rule 15) and every edge names a
  work_item of the same wave. Frontiers are computed inside the wave; declared waves stay barriers to each other,
  so wave N+1 starts only after every work_item of a frontier wave N has passed its gate.
- There is no global barrier-free flag and no cross-wave edge.

## Admission (both modes)

An agent is dispatched only when all of these hold:

1. **Slots:** fewer than `max_concurrent` agents are live, counting work_item, gate and fix
   agents together. A gate or fix agent with no free slot waits for one; it is never
   dispatched over the cap. `max_concurrent` absent = unbounded.
2. **Lane (work_item agents only):** no other work_item with the same `lane` is live in the
   run (one invocation of the skill). In a barrier and a frontier wave alike a work_item holds its lane from its
   dispatch until its gate passes or it escalates, including its gate and fix agents (INTERFACES 1.5.0 C1.1).
   A work_item generated at runtime, and a fix agent, may carry `persona` and `lane` (C1.1). Leasing the lane's real
   resources is the caller's.
3. **Blockers (frontier only):** every work_item in its `depends_on` has a passed gate.

Work_items without edges are releasable at once.

## Agent ids and the dispatch record

- Each agent gets its own `from_agent` id matching `^[a-z0-9-]+$` that carries the
  per-invocation `NONCE` (step 3), e.g. `<work_item>-<nonce>`, `<work_item>-gate<k>-<nonce>`,
  `<work_item>-fix<k>-<nonce>` (`<k>` as defined in `spec-format.md`, "Agent ids and accepted posts"). These shapes are examples: the id matches the pattern
  whatever the work_item name, and no id is reissued under one `session_id`, even on resume,
  so several gate agents for one work_item, or a gate re-run after a fix, each get a distinct
  id. The controller records the id's role (`worker`, `gate`, `fix`), wave and work_item.
- **Dispatch record (only when `bus_endpoint` is declared):** before dispatching an agent,
  append one JSON line to `dirname(<resolved bus_endpoint>)/dispatch/<invocation>.jsonl`:
  `{"agent_id","role","unit","persona","tier","backend","utc"}` — `role` `worker|gate|fix`;
  `unit` the served work_item id, or `wave-<N>` for a wave-level gate agent (a barrier wave's
  `exit_criteria`, `adversarial_verify` or `judge_panel` gate); `persona` the work_item's `persona`
  for a worker (`none` when it declares none), `gate-checker` for a gate agent, `fixer` for a fix
  agent (INTERFACES 1.5.0 C1.1); `tier` the model the wave's
  `agents` field names (a required field, spec-format) (a worker under `tier_override` takes the overriding tier); `backend` `agent-tool` or
  `claude-p` (the Operating Mode Gate result); `utc` ISO 8601. The caller reads this file;
  the skill only appends to it.
- **Acceptance:** a bus post counts only if its `from_agent` was assigned in this invocation
  (with `bus_endpoint`, registered in this invocation's dispatch record). By role it is a
  completion for that work_item (validated against its `output_schema`) or a gate verdict
  `{agent_id, verdict, rationale}`. Anything else on the topic — other waves, other
  work_items, earlier invocations, the caller's own records — is ignored.

## Frontier release loop

Repeat until no work_item is live or releasable:

1. Dispatch every releasable work_item that passes admission.
2. On a counted completion post, dispatch that work_item's gate agent(s) (admission 1).
3. **Gate per work_item:** the wave's `gate_type`, with the wave's `exit_criteria` read
   against that work_item's output only (under `step_complete`, plus its `done_condition`).
   `g` gate agents per work_item: 1 for `exit_criteria` and `step_complete`, `skeptics` for
   `adversarial_verify`, `judges` for `judge_panel` (majority among that work_item's judges).
   A criterion over the wave's collective output is not checked inside a frontier wave; a
   caller that needs one puts it in a following barrier wave.
4. **Pass:** write the work_item's gate pass to the checkpoint, free its lane, then
   re-evaluate releasability of its dependents.
5. **Fail:** that work_item's fix loop (step 7): the wave's `fix_loop_cap` (default 3),
   counted for this work_item alone, fix agents scoped to it alone. On exhaustion post `{SESSION_ID}-escalation` with
   `{ halt_reason: "fix-loop-cap-exhausted", wave: N, work_item: <id>, iterations: <cap> }`,
   free its lane, and never release its transitive dependents. Other work_items run on to
   their own gate pass or escalation.

**Cancellation is non-release.** A dependent is released only after every blocker's gate
passed, and no passed gate is reopened within an invocation, so a failed or escalated
work_item never has a live dependent. The controller never `TaskStop`s a dependent;
invalidation from outside the run is the caller's.

**Halt.** When no work_item is live or releasable: if every work_item passed, the wave gate
has passed — proceed to wave N+1. Otherwise write the checkpoint, run step 8 and stop; a
later invocation resumes at the unpassed work_items (the checkpoint is the only authority;
an unrecorded completion post is re-gated).

## `step_complete` gate agent

- Rubric: the work_item's `done_condition` (`{"token", "command"}`) and the wave's
  `exit_criteria`, both verbatim, neither reworded or merged.
- Pass only if the agent runs `command`, it exits 0, and its last stdout line equals `token`
  exactly, and the `exit_criteria` hold. The gate agent runs the command; the controller
  never does.
- Which output and where the command runs are stated in the caller's work_item brief (the
  skill is domain-agnostic).
- Barrier wave: one gate agent per work_item; the wave passes only when every one passes.
  Frontier wave: the per-work_item gate above.

## Budget (rule 11)

A frontier wave's worst-case term is `work_items_count x (1 + (fix_loop_cap + 1) x g)`;
barrier waves keep the 1.0.0 term with rule 9's `gate_agents` mapping (`step_complete` =
`work_items_count`). The sum is checked at preflight against `dispatch_budget`.
