# Panel Review — Phase B, Phase C, Severity Reference, and Reference Files

## Phase B — Requester Decides

After the synthesizer presents the findings table:

1. Present the FULL report — severity summary, findings table, deliberation trails,
   timed-out threads, overall verdict
2. Wait for the requester's decisions: which fixes to apply, defer, or reject
3. Confirm scope before touching anything:
   "I'll apply B1, M2, M3. Deferring A1. Rejecting A2. Correct?"
4. Get explicit confirmation.

---

## Phase C — Apply Approved Fixes

For each approved fix: apply the edit, verify no new issues introduced, report what
changed, what was deferred, and any residual risks.

Do NOT apply any fix before the requester approves. The panel presents; the requester decides.

---

## Severity Reference

**Blocking (B)** — Cannot be dispatched in this state. Prevents execution, creates invalid
output, violates architectural constraints, or is a direct security vulnerability.

**Medium (M)** — Could lead to wrong output or agent confusion. Missing clarity, unverified
claims, unexplained deviations from established patterns.

**Advisory (A)** — Does not prevent execution. Confusing but workable language, unhandled
edge cases, suggestions for future improvement.

---

## Reference Files

- `references/bus-schema.md` — topic list, message shape, quorum rule, timeout behavior
- `references/agent-briefs.md` — Wave 1 and Wave 2 brief templates (posting protocol, verification steps)
- `references/agent-roles.md` — per-role RACI assignments for all 11 agents
- `references/synthesizer-brief.md` — synthesizer instructions for Phase B report; `timed_out_checks` is `{ gate1: [...], gate2: [...] }`
