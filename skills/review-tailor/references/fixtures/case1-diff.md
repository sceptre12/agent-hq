# Fixture 1: code diff (D12 off)
Inputs: KIND=diff STAKES=reversible CONTENTION=none NOVELTY=known SECURITY_AUDIT=guidance
ORCHESTRATOR_TIER=design SLUG=st1-diff-1. Stand-in artifact: one file `change.diff`, about 30 lines, touching a single
shell script. Any other risk surface (add a security-sensitive line, a schema line) must give
the same result.
Expected line 1: `RUNG: 3 seats: 7`. Seven rows: the pr-review ids in `d12-gate.md`; the
`security-engineer` reason ends `mode=guidance`; `dispatch:` says 21 per round, peak 8 (seats 7 + orchestrator 1); `tiers:` ends `omitted: none`.
