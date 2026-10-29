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

**Process/Meta (P)** — Not a code severity; never counted toward the Blocking/Medium
tally that drives the Overall verdict (READY / NOT READY / READY WITH CONDITIONS). Covers:
- the accuracy of a prior review comment, commit message, or CHANGELOG claim
- whether another reviewer's (human or automated) approval, review, or finding was
  trustworthy, well-founded, or should be reweighted ("trust-signal"/"quorum" findings)
- process, governance, or review-hygiene observations that are NOT about whether the
  current diff's code is correct

Test question when unsure: "If every word of this finding is true, does the code in
this diff still work correctly? If yes, it is Process/Meta, not a code severity."

If a Phase 2 agent ESCALATEs a Process/Meta finding during deliberation, the ESCALATE
may add detail or evidence but must NOT change its category — Process/Meta is not
escalatable to Blocking, Medium, or Advisory.

This is the canonical definition — `agent-roles.md`, `agent-briefs.md`, `synthesizer-brief.md`, and
SKILL.md's exit criteria each cross-reference this section rather than restating it.

---

## Reference Files

- `references/bus-schema.md` — topic list, message shape, quorum rule, timeout behavior
- `references/agent-briefs.md` — Phase 1 and Phase 2 brief templates with posting protocol and shell injection guard
- `references/agent-roles.md` — per-role RACI assignments (Responsible, Consulted, Accountable)
- `references/synthesizer-brief.md` — synthesizer instructions for Phase B report; `timed_out_checks` is `{ gate1: [...], gate2: [...] }`
- `references/roles-subset.md` — `ROLES` refusal and the D12 remap procedure
- `references/local-diff-mode.md` — local-diff mode inputs and read-only rules
- `references/bus-start-standalone.md` — Step 1 and Step 9 scripts with `RUN_HOME` unset
- `references/bus-start-run.md` — Step 1, the Step 2 diff path and Step 9 inside a run (port guard)
- `references/diff-fetch.md` — Step 2 scripts (pr mode, local-diff mode) and network-unavailable handling
- `references/review-record.md` — Step 8 `RECORD_PATH` writer (lines 1-2, A.6)
- `references/step0-inputs.md` — Step 0 input table (rule and `INPUT-ERROR` reason per field)
