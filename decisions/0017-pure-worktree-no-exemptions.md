# 0017. Pure worktree, no exemptions — and a moving main is normal

- **Status:** accepted (2026-07-12) — ratified per user decision
- **Date:** 2026-07-12
- **Context of:** workspace-wide (git workflow for all repos; amends ADR 0013)

## Context

ADR 0013 put multi-commit hq work in worktrees but carved out an exemption: sub-threshold
single-commit ops (status flips, index rows, one-line fixes) could commit directly on a
clean `main` as an atomic commit+push. 0013 itself named the cost — "the exemption
boundary … has to be judged per work unit rather than mechanically enforced" — and listed
"the exemption boundary is routinely argued around" as its revisit trigger. That judgment
call is exactly the kind of per-work-unit ambiguity this workspace tries to eliminate.

Separately, arrival tooling (global Rule 6 arrival duty; the session-startup skill's
Step 2) treated ANY divergence on main — including being behind a remote that another
session had legitimately pushed to — as an anomaly. Multiple concurrent chat sessions now
work these repos simultaneously as a matter of course, so "main moved since I last
looked" is the everyday state, not an incident. Treating it as an anomaly generates
false first-work-items and trains sessions to ignore the anomaly channel.

The user was shown the friction of removing the exemption and ratified both changes.

## Decision

1. **Pure worktree, no exceptions.** Every work unit in a git repo — including one-line,
   single-commit changes — runs in a dedicated worktree branch
   (`git worktree add ~/projects/agent-hq-worktrees/<slug> -b wt/<slug>` for hq) and
   integrates by merge to the default branch + immediate push (or PR, in PR-flow repos),
   then worktree removal and `wt/` branch deletion. ADR 0013's sub-threshold
   single-commit exemption is **removed**; 0013's worktree mechanics otherwise stand.
2. **Before merging: all invariants pass** inside the worktree; re-run on `main` after
   merge, push immediately (ADR 0006). ("All" deliberately replaces 0013's hardcoded
   count, which went stale when the invariant set grew.)
3. **Concurrent commits are expected.** The default branch moving ahead of a session's
   last-known state because another session pushed is the NORMAL state. Response: a
   light provenance glance — is it a real commit, does it conflict with my work? — then
   proceed. It is never, by itself, an anomaly or a first work item.
4. **The exhaustive anomaly list.** Only these are stop-the-line arrival anomalies:
   - a **dirty working tree** on the shared checkout;
   - **unpushed local commits** — any session's unintegrated work (ADR 0006 backup gap);
   - **failing checks/invariants** on the default branch;
   - a **dangling worktree** (an open work unit, not a parking spot).
   Nothing else. In particular, being behind a fetched remote is not on this list.

## Reasoning

- The exemption was the last remaining judgment boundary in the write discipline; 0013's
  own revisit clause anticipated removing it. One rule with zero carve-outs is
  mechanically checkable and un-arguable — the ceremony cost is paid knowingly.
- With no direct-to-main authoring at all, every commit on main is a merge/integration
  commit from a validated worktree — which is precisely what makes a moving main safe to
  treat as normal: provenance is uniform, so a glance suffices.
- The anomaly list is now exhaustive rather than illustrative, so arrival tooling can be
  literal about it: everything on the list is a genuine unsafe state (interleaved partial
  writes, backup gap, broken invariants, abandoned work); everything off the list is
  expected concurrency.

## Consequences

- Easier: no per-work-unit "is this sub-threshold?" judgment; uniform provenance on
  main; arrival duty stops crying wolf on normal concurrent pushes, so a reported
  anomaly regains its stop-the-line meaning.
- **Harder / accepted trade-off (named honestly):** operations that were designed to be
  zero-friction now each cost a full worktree cycle (add → commit → invariants → merge →
  push → remove): `inbox/` captures, ADR 0014 eval-log lines ("append as they happen"),
  project-record status flips, and index-row/typo fixes. The user reviewed exactly this
  friction and chose it. If the ceremony proves too costly in practice, targeted
  carve-outs can be reintroduced **by amendment to this ADR** — not by quietly reviving
  the 0013 exemption.
- Revisit if: worktree slugs collide across sessions, or the per-capture ceremony
  measurably suppresses inbox/eval-log capture (the point of those channels is that they
  get used).

## Alternatives considered

- **Keep the 0013 exemption as-is** — rejected: the boundary is judged per work unit,
  0013 flagged that as its own weakness, and it is the sole remaining path for
  unvalidated direct-to-main writes.
- **Narrow the exemption (e.g. inbox/ only)** — rejected for now: still a judgment
  boundary; the user chose the clean rule. Recorded above as the amendment path if
  friction bites.
- **Keep treating any main divergence as an anomaly** — rejected: with multiple
  concurrent sessions it misfires daily, flooding the channel that must stay meaningful
  for the four real anomalies.

**Links:** ADR 0013 (amended by this ADR), ADR 0006 (push-is-backup), ADR 0014
(eval-log friction accepted above), global Rule 6, hq CLAUDE.md "Concurrent writes",
skills/session-startup/SKILL.md Step 2.
