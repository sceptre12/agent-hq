# Fix record: INTERFACES 2b, round 0 (pre-round fix), 2026-10-26

Fixer: separate agent (Rule 4). Source of owner answers: `architecture/delivery-workflow-sources/owner-decisions.md:57-60` ("INTERFACES owner questions (2026-10-26)"). Line numbers are post-edit.

- OWNER-Q1 INTERFACES.md:27 "Owner questions" table removed; one-line note: none open, Q1-Q3 settled, see decisions log
- OWNER-Q1 INTERFACES.md:33 Kind legend gains `O` = owner ruling
- OWNER-Q1 INTERFACES.md:56 B1 row: Q1 quoted as owner 2026-10-26 with source; Kind "DEF pending Q1 / DEF" -> "O (relay) / DEF (id read)"
- OWNER-Q1 interfaces/part-b-desk.md:15 "Owner question Q1" / "pending Q1" hedge replaced by the owner ruling quote and source
- OWNER-Q1 interfaces/part-c-waves-control.md:112 "(part B1, Q1)" -> "(part B1; owner Q1)"
- OWNER-Q2 INTERFACES.md:66 C1.1 row: Q2 quoted as owner 2026-10-26 with source, ratifies with ADR 0054; Kind "DEF pending Q2" -> "O"
- OWNER-Q2 interfaces/part-c-waves-control.md:3 "decided here as Owner question Q2" -> settled by owner Q2 YES, ratifies with ADR 0054
- OWNER-Q2 interfaces/part-c-waves-control.md:20 `bus_endpoint` row: "Owner question Q2 ... Recommended answer: adopt" -> owner ruling quote, "Ratifies with ADR 0054"
- OWNER-Q2 interfaces/part-d-enums-topics.md:67 "`bus_endpoint` (Q2)" -> "(owner Q2, 2026-10-26)"
- OWNER-Q2 interfaces/part-d-enums-topics.md:84 "owned by the lead (Q2)" -> "(owner Q2, 2026-10-26; part C1.1)"
- OWNER-Q3 INTERFACES.md:60 B4 row: "`pr-attach` (Q3)" -> owner Q3 YES, Kind adds "O (`pr-attach`)"
- OWNER-Q3 INTERFACES.md:61 B5 row: Q3 quoted as owner 2026-10-26 with source, covers `record_path` and `pr-attach`, ratifies with ADR 0055; Kind "DEF" -> "O"
- OWNER-Q3 INTERFACES.md:94 E11 "(Q3)" -> "(owner Q3, decisions log B5)"
- OWNER-Q3 interfaces/part-b-desk.md:62 `pr-create` "(`DEFAULT` field, M10)" -> "(M10; owner Q3, see `pr-attach`)"
- OWNER-Q3 interfaces/part-b-desk.md:66 `pr-attach` "New verb, Owner question Q3" -> owner ruling quote, ratifies with ADR 0055
- PR-C1 INTERFACES.md:62 B6 row: `schemas.json` -> full path marked "(W1 target, written from this table; not on disk yet)"
- PR-C1 interfaces/part-b-desk.md:118 `delivery-desk/references/schemas.json` -> `skills/delivery-desk/references/schemas.json` marked "(W1 target, written from this table at W1 item 26; not on disk yet)"
- PR-C2a INTERFACES.md:5 design source -> six part files with line ranges; owner-decisions.md:1-61 (owner answers :57-60)
- PR-C2b interfaces/part-a-state.md:4 design source -> per-section path:line ranges (§0, §1, §2.2, §4, §5.0, §5.6, §5.11, §6.3-§6.4)
- PR-C2c interfaces/part-b-desk.md:4 each design section and owner ruling (D3, T1, R2-4, R2-5, R2-7, Q1, Q3) given path:line
- PR-C2d interfaces/part-c-waves-control.md:3 ADR 0054 -> `:37-164` (Decision A0-A9), open item 1 at A9 `:158-164`; owner Q2 at owner-decisions.md:59
- PR-C5a interfaces/part-a-state.md:192 worktree-remove rule: marker `DEFAULT (integrator)` added (no owner ruling covers it; D8/D9 cover branches and catalog scope only)
- PR-C5b interfaces/part-a-state.md:194 process kill rule: marker `DEFAULT (integrator)` added
- PR-C5c interfaces/part-a-state.md:198 tmpdir/file/clone rm rule: marker `DEFAULT (integrator)` added
- PR-C5d interfaces/part-c-waves-control.md:150 STALLED "never one more budget": marker `DEFAULT (integrator)` added (D10 says the lead decides TaskStop; it does not state "never one more budget")

Checks: `bash tools/check-doc-length.sh .` -> 0 blocking files; these five files 100/245/140/159/130 lines, all under 40000 bytes (only changelog.md is over, informational). `grep -n "pending Q\|OPEN:"` -> no `pending Q`; one `OPEN:` hit at INTERFACES.md:99, the pre-existing "Checks run" line that describes the grep itself (not a marker; untouched, no finding id).
