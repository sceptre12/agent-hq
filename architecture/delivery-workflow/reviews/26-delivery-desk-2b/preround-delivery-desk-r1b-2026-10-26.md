# Pre-round check r1b: 26 delivery-desk (G48, read-only, 2026-10-26)
Artefact: skills/delivery-desk/{SKILL.md, references/checks.md, verbs.md, human-gates.md, schemas.json}; pin f68f6f2 (last change to these paths); worktree HEAD now dc626c0; fix r0 uncommitted.
C1 PASS all cites open and match: SKILL.md:13-14, :19, :229-230 (Hermes SKILL.md:309-313, digest :192); checks.md:95 and verbs.md:23 (part-b-desk.md:83 "DEFAULT (integrator)"); SKILL.md:19 quote "Rules (ratified R-3)" at permission-tiers-02.md:95.
C2 FAIL skills/delivery-desk/SKILL.md:226 "design panel finding B1 (`agent-workflow-design-panel.md` §2" gives a section pointer only, no path:line-range or quote; file exists only in SCRATCH.
C2 FAIL skills/delivery-desk/SKILL.md:224 "Hermes skill `learnings/gh-auth`" names an external source with no path:line-range or quote.
C2 FAIL skills/delivery-desk/SKILL.md:148 "stated once, in `architecture/delivery-workflow/interfaces/part-a-state.md` A.7" gives a section pointer only, no line range.
C3 PASS hunks map: SKILL.md:13-14 PR1-C2; :18-19 PR1-C5c; :229-230 PR1-C1; checks.md:94-96 PR1-C5a; verbs.md:23-24 PR1-C5b; schemas.json whole-file PR1-C6 (json.load equal to SCRATCH/desk26/schemas-f68f6f2.json: EQUAL).
C4 PASS ids, step order and sha pins unchanged by fix r0 (cite-only hunks).
C5 FAIL skills/delivery-desk/references/checks.md:131 "polls `.out` ... up to 5 minutes, re-sends the same `<id>` once, then renames" states a cap and retry rule with no marker and no pointer.
C5 FAIL skills/delivery-desk/SKILL.md:185 "the requester may resend once the cause clears, with a **fresh id**" states a retry rule with no marker.
C5 PASS r1 items closed: SKILL.md:18-19, checks.md:94-96, verbs.md:23-24 carry "default".
C6 PASS schemas.json 894 lines (was 2380); SKILL.md 232, checks.md 135, verbs.md 181, human-gates.md 67.
C7 PASS paths pinned at f68f6f2. New sha256 prefixes: SKILL.md d457debfe5c8 -> 8df20af97ea8; checks.md 392ddb671427 -> bbd21614a454; human-gates.md 6cd62ed270ae (unchanged); schemas.json 364969e802c5 -> d3dd9c04beba; verbs.md 70b958bf7339 -> 91237648b1a3.
preround: 5 fails
