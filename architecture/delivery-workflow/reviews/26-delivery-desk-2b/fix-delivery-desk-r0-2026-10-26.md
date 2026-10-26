# Fix record r0: 26 delivery-desk (fixer, Opus, 2026-10-26)
Input: `preround-delivery-desk-r1-2026-10-26.md` (6 FAILs). Mechanical fixes only; no behaviour change, no numbers changed.

| id | file:line before -> after | change |
|---|---|---|
| PR1-C2 | skills/delivery-desk/SKILL.md:13-14 -> :13-14 | added `part-b-desk.md:7-172` (B1-B8) and `decisions/0055-desk-verb-permission-tiers-02.md:42-233` (Decision §1-§5) range pointers |
| PR1-C5c | skills/delivery-desk/SKILL.md:18 -> :18-19 | "2 minutes" tagged "default stall bound"; source `architecture/permission-tiers-02.md:95-101`, quoted marking "Rules (ratified R-3)" |
| PR1-C1 | skills/delivery-desk/SKILL.md:228 -> :229-230 | `:309-313` now names the file: `$HOME/claude-profiles/hermes/h1-home/skills/learnings/dispatch-stop-conditions-02/SKILL.md:309-313` (SUB applied; outside W, opens on the owner's machine), plus digest `SCRATCH/hermes-learnings-digest.md:192` |
| PR1-C5a | skills/delivery-desk/references/checks.md:94-95 -> :94-96 | "5 minutes" tagged "default"; source `part-b-desk.md:83`, marked `DEFAULT (integrator)` |
| PR1-C5b | skills/delivery-desk/references/verbs.md:23 -> :23-24 | "5 min" tagged "default"; source `part-b-desk.md:83`, marked `DEFAULT (integrator)`, row R4-J20 |
| PR1-C6 | skills/delivery-desk/references/schemas.json:1-2380 -> :1-894 | re-serialized: 2-space indent; containers that fit in 120 columns, and leaf containers at depth >= 2, on one line. Parsed content identical |

## Checks
- `python3 -I -c` json.load(new schemas.json) == json.load(`SCRATCH/desk26/schemas-f68f6f2.json`): EQUAL.
- `bash SCRATCH/s9-26.sh`: ends DESK-SCHEMAS-OK; 0 lines with MISSING/VIOLATION/NO-USE-WHEN/RULE-MISSING; check-doc-length 0 blocking.
- `wc -l`: SKILL.md 232, checks.md 135, verbs.md 181, human-gates.md 67, schemas.json 894.

## Notes
- PR1-C5c: the source marks the 2-minute bound as a ratified rule (R-3), not a default; the word "default" was added per the fix brief, with the source's own marking quoted next to it. The reviewer may prefer to treat it as a ratified-rule quote instead.
- PR1-C1: the learnings file is outside W and SCRATCH; the digest line is given as the in-SCRATCH fallback.
