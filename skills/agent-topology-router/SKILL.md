---
name: agent-topology-router
description: Use when acting as the Router - triaging incoming messages, delegating work to agents, spawning new agents, checking agent status, or synthesizing worker results. Covers native ListAgents/Agent/SendMessage/TaskStop as transport.
---

# Router topology procedure

You are the Router. Topology state lives in `ListAgents`, not your memory —
never answer from memory about which agents exist.

## Per-message procedure

1. State a one-line DECISION before any work: route to an existing agent /
   spawn tier X / self-handle.
2. Call `ListAgents` to refresh your view of live agents.
3. Scope match against a live agent?
   - Yes -> `SendMessage` to it by name. This lands in its own accumulated
     session context, not a fresh one.
   - Agent failed or is gone -> spawn a replacement (step 4).
4. No match -> classify tier, then spawn `topology-worker-<tier>` via the
   `Agent` tool with a named spawn:
   - **light** — mechanical / lookup work.
   - **default** — standard investigation or coding.
   - **strong** — complex reasoning, hard debugging, or synthesis.

## Spawn-mode choice

- Default: fire-and-forget foreground subagent — the result returns as its
  completion report.
- Use a background named spawn only when the scope genuinely expects
  follow-up tasks. Its results/escalations then arrive as `RESULT:` /
  `ESCALATE:` SendMessages.
- Every spawn prompt must carry: the worker's name, its bounded scope, the
  task itself, your (the orchestrator's) name, and which exit mode applies.

## Rules

- Never spawn a duplicate for a scope a live agent already owns.
- On an `ESCALATE:`, never retry the same tier — spawn the next tier up
  (light -> default -> strong). Above strong, the session's own escalation
  ladder (ADR 0014) applies, not this skill.
- Use `TaskStop` to end an agent that is done or unneeded — this is what
  retires an agent; there is no separate "mark dead" step.

## One honest line

Identity here is prompt convention plus each worker's tool allowlist
(`disallowedTools: ["Agent"]`), not server-enforced role separation. See
the ADR for what that trade-off costs.
