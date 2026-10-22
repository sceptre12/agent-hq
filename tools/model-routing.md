# Model routing — who executes what

Universal principles live in the global rules (Rule 3: always pin the model; Rule 4:
match model to task, escalate don't retry, design expensive / execute cheap / verify
independently). This file holds the hq-pipeline-specific assignments. Update rows as
phases complete — this is tail content, never loaded into the prompt prefix.

## Standing assignments

| Task type | Model | Rationale |
|---|---|---|
| Architecture / system design passes | Fable or Opus | Settle designs once at the top tier |
| Design revision against new constraints | Fable | Revises its own prior proposal coherently |
| Executing a settled spec (doc authoring, installs, config) | Sonnet | Judgment within a decided frame, no open design |
| Coordinating fan-out recon/research | Sonnet | Orchestration + synthesis of worker digests |
| Inventory / lookup / measurement workers | Haiku | Mechanical: list, fetch, run, record |
| File copies, index fixes, packaging | Haiku | Pure mechanics |
| Hard debugging with ambiguous signals (e.g. cache misbehavior) | Opus | The one place cheap tiers flail |
| Verification of an author's work | Separate instance, tier per difficulty | Never the author; mechanical checks main-thread |

## Pipeline-specific (current)

| Step | Model | Status |
|---|---|---|
| Phase 0+1 authoring (ADRs, STANDARDS, runbooks) | Sonnet | done |
| Publish hq to GitHub | Haiku | this batch |
| Git identity auto-switch build (3 accounts) | Sonnet (spec was Opus-validated in sandbox) | queued |
| Phase 2 installs: Serena → agentmemory → Headroom LAST | Sonnet each | queued |
| Phase 2/3 measurements (ccusage, token counts) | Haiku | queued |
| Phase 3 diagnosis if cache misbehaves | Opus | contingent |
| Skills derivation after Phase 3 | Fable/Opus design → Sonnet author → Haiku package | later |

## Dispatch checklist (P2.3, ratified 2026-07-02)

> Every dispatch states an explicit, verifiable done condition and a stop-on-anomaly
> clause; subagent reports are checked against the done condition before acceptance.
> A blocked gate or safety stop in any report is stop-the-line for the orchestrator —
> never bypassed, never assumed benign.
> — (Rule 4 amendment, Q3 ruling)

**Before dispatch**

- Model pinned explicitly, with a one-line cost-vs-difficulty rationale.
- An explicit, VERIFIABLE done condition stated in the prompt (what artifact/evidence
  proves completion).
- A stop-on-anomaly clause: the specific conditions that must halt the agent (gate
  blocks, spec contradictions, unexpected repo state, auth failures).
- Scope boundaries: what the agent must NOT touch, commit, or push.

**On report**

- Check the report against the done condition before acceptance — evidence, not
  claims (quoted command output beats "done successfully").
- Any blocked gate or safety stop = stop-the-line for the orchestrator: read the gate
  output verbatim; never bypass, never `--no-verify`, never assume benign.
- Substantive builds get verified by a SEPARATE agent instance, never the author.
- On stall, failure, or genuine ambiguity: escalate one model tier and re-dispatch —
  never re-run the same tier hoping for a better result.
