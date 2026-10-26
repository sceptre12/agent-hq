# Fixture 4: one-way door, plus a bad enum
Run A: KIND=doc STAKES=one-way CONTENTION=contested NOVELTY=novel SECURITY_AUDIT=guidance
ORCHESTRATOR_TIER=design SLUG=run-doc-3. Stand-in artifact: `decision.md`, about 200 lines.
Expected line 1: `RUNG: 4 seats: 11`; eleven rows from the roster in `seat-catalog.md` §D.
Run B (save the stdout as `case4-bad.out`): the same inputs (ORCHESTRATOR_TIER=design
included) with STAKES=maybe.
Expected output: exactly one line, `INPUT-ERROR STAKES enum`, and no record file written.
