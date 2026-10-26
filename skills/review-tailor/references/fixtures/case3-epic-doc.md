# Fixture 3: epic architecture, reversible
Inputs: KIND=doc STAKES=reversible CONTENTION=contested NOVELTY=novel SECURITY_AUDIT=guidance
ORCHESTRATOR_TIER=design SLUG=run-doc-2. Stand-in artifacts: `architecture.md` (about 800 lines) and a `contracts/`
directory with 3 files. The architecture mentions a database schema change and no UI, and
has no trust boundary, secret or injection path.
Expected line 1: `RUNG: 2b seats: n`, n between 1 and 7 (both `contested` and `novel`;
modifier none). Seats follow the `seat-catalog.md` §A selection rule: `data-migration` (schema
change) and `contract-interface` (contracts directory) are in the rows; `ux-accessibility` is not
(no UI). Every default seat not selected has `id=reason` in the `tiers:` line after `omitted:`,
either an absent surface or `displaced by <seat>`.
Deterministic reading of this stand-in: the schema change matches both `api-contract`
("public interface or schema") and `data-migration` ("schema"); the `contracts/` directory
matches `contract-interface`. Defaults present: all but `security` (no trust boundary).
Six defaults plus `api-contract` reach 7; `data-migration` displaces `operability` and
`contract-interface` displaces `docs-accuracy`. Rows (n = 7): `correctness-design`,
`test-adequacy`, `cold-implementer`, `fact-remeasurer`, `api-contract`, `data-migration`,
`contract-interface`. Tail: `omitted: security=surface absent; operability=displaced by
data-migration; docs-accuracy=displaced by contract-interface`.
