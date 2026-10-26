# 0013. hq writes via worktrees — merge to main when finished

- **Status:** accepted (2026-07-04) — ratified per user decision, verbal
- **Amended by:** 0017 (2026-07-12) — single-commit exemption removed (pure worktree, no exceptions); concurrent-main-is-normal posture and exhaustive anomaly list recorded there.
- **Date:** 2026-07-04
- **Context of:** workspace-wide (git workflow for all hq work)

## Context

Concurrent sessions have been writing directly to hq `main`. This has already caused, in
one day: an invariant-15 parity break landing on main (ADR 0012 committed without its
matching `decisions/README.md` index row); multi-hour backlogs of unpushed local commits,
violating ADR 0006's push-is-backup guarantee; and wave publishers forced into defensive
explicit-path `git add` staging to avoid clobbering other sessions' untracked
in-progress files under `skills/` and `architecture/`.

hq has no branch discipline today — every session commits straight to `main` in the same
shared working directory. That collides badly the moment more than one work unit is live
at once: partial commits interleave, invariants can pass locally but be broken by a
concurrent partial write, and there is no way to tell a finished work unit from one still
mid-flight.

## Decision

Any hq work unit expected to produce **more than one commit** runs in a git worktree,
outside the shared working directory:

```
git worktree add ~/projects/agent-hq-worktrees/<slug> -b wt/<slug>
```

- Worktrees live under `~/projects/agent-hq-worktrees/` — outside the `hq` checkout itself.
- Branch namespace: `wt/<slug>`.
- **Before merging:** invariants must be 23/23 inside the worktree.
- **When the work unit finishes:** merge to `main` from the main checkout
  (`git merge wt/<slug>`, ff or `--no-ff`), re-run invariants on `main`, push `main`
  immediately (ADR 0006), then `git worktree remove` the worktree and delete the `wt/`
  branch.
- Main must never be left un-merged or un-pushed at the end of a finished work unit — a
  dangling worktree is an open work unit, not a parking spot.

**Exemption:** sub-threshold single-commit ops (status flips, index rows, one-line
fixes) may commit directly on `main`, but ONLY as an atomic commit-then-push in the same
action, on a clean `main`.

**Arrival duty:** any session starting hq work on a `main` with failing invariants or
unpushed foreign commits fixes-or-surfaces that FIRST (stop-the-line) — this happened
twice in one day before this ADR.

## Reasoning

- Worktrees give each concurrent work unit its own working directory and branch, so
  partial writes from one session can never interleave with another's — the shared
  working directory was the root cause of all three incidents.
- Requiring invariants 23/23 in the worktree before merge, then re-checked on main after
  merge, catches a class of parity break (like the ADR 0012 incident) that only
  manifests when two writers land near-simultaneously.
- Merge-and-push-immediately (rather than leaving a merged-but-unpushed main) keeps ADR
  0006's push-is-backup guarantee intact without adding a second, separate discipline to
  remember.
- The single-commit exemption keeps genuinely trivial ops (a status flip, an index row)
  cheap — forcing a worktree for a one-line fix would be ceremony without payoff.

## Consequences

- Easier: concurrent sessions no longer need defensive explicit-path staging to avoid
  clobbering each other's untracked files; a broken/unpushed main is caught at the door
  by arrival duty instead of discovered mid-session; multi-commit work units have a clear
  finished-vs-in-progress signal (worktree exists vs. removed).
- Harder / accepted trade-off: one more mechanical step (worktree add/remove) around any
  work unit expected to span multiple commits; the exemption boundary (what counts as
  "sub-threshold single-commit") has to be judged per work unit rather than mechanically
  enforced.
- Revisit if: worktrees themselves start colliding (e.g. two sessions picking the same
  `<slug>`) or if the exemption boundary is routinely argued around to avoid worktree
  overhead.

## Alternatives considered

- **Per-session branches without worktrees** — rejected: still shares one working
  directory, so checkout-switching between sessions collides worse than the current
  problem (uncommitted changes get carried across branch switches).
- **File-level locking** — rejected: no enforcement mechanism available in this
  lightweight-markdown-and-git setup (ADR 0001); would need tooling hq doesn't have.
- **Status quo defensive explicit-path staging** — rejected: relies on every session
  remembering to stage narrowly; already failed twice in one day.
