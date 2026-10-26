# Fixture 3: epic architecture, reversible
Inputs: KIND=doc STAKES=reversible CONTENTION=contested NOVELTY=novel SECURITY_AUDIT=guidance
SLUG=run-doc-2. Stand-in artifacts: `architecture.md` (about 800 lines) and a `contracts/`
directory with 3 files. The architecture mentions a database schema change and no UI.
Expected line 1: `RUNG: 2b seats: n`, n between 1 and 7. Every default seat not
selected has `id=reason` in the `tiers:` line after `omitted:`. `data-migration` is
expected in the rows (schema change); `ux-accessibility` is not (no UI).
