# PR Review — Phase B, Phase C, Severity Reference, and Reference Files

## Phase B — Reviewer Decides

After the synthesizer presents the findings table:

1. Present the FULL report — severity summary, findings table, deliberation trails,
   timed-out threads, overall verdict
2. Wait for decisions: which fixes to apply, defer, or reject
3. Confirm scope before touching anything:
   "I'll apply B1, M2. Deferring M3. Rejecting A1. Correct?"
4. Get explicit confirmation.

---

## Phase C — Apply Approved Fixes

For each approved fix:
1. Apply the edit in the repo (local-diff mode: in the author's `wt/` worktree, never `REPO_DIR`)
2. Verify the fix didn't introduce new issues in surrounding code
3. Report completion: what changed, what was deferred, any residual risks

Do NOT apply any fix before the reviewer approves. The panel presents; the reviewer decides.

---

## Severity Reference

**Blocking (B)** — Cannot merge. Prevents correct runtime behavior, creates silent
misconfiguration, violates security requirements, or is an incomplete change that will
fail in production.

**Medium (M)** — Should fix before merge. Missing clarity, partial migration, unverified
claims, unexplained deviations from established patterns.

**Advisory (A)** — Does not block merge. Confusing but workable, minor doc gaps,
unhandled edge cases not currently exercised.

---

## Reference Files

- `references/bus-schema.md` — topic list, message shape, quorum rule, timeout behavior
- `references/agent-briefs.md` — Phase 1 and Phase 2 brief templates with posting protocol and shell injection guard
- `references/agent-roles.md` — per-role RACI assignments (Responsible, Consulted, Accountable)
- `references/synthesizer-brief.md` — synthesizer instructions for Phase B report; `timed_out_checks` is `{ gate1: [...], gate2: [...] }`
