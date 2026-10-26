# Pre-round check r1: 26 delivery-desk (G48, read-only, 2026-10-26)
Artefact: skills/delivery-desk/{SKILL.md, references/checks.md, verbs.md, human-gates.md, schemas.json}; pin f68f6f2 (no change to these paths since f68f6f2; worktree HEAD 16fcad8).
C1 FAIL skills/delivery-desk/SKILL.md:228 cite "(`:309-313`: brief constraints did not reach a grandchild" names no file path; the cited file cannot be opened from the artefact. Fixer: add the source path.
C2 FAIL skills/delivery-desk/SKILL.md:13-14 "Authority for every name, regex, field and check: `architecture/delivery-workflow/interfaces/part-b-desk.md` (B1-B8, INTERFACES 1.2.0) and ADR 0055" gives section pointers only: no path:line-range, no verbatim quote.
C3 PASS n/a (round 1)
C4 PASS 20 verbs, 10 reason codes with classes, 12-step order and no sha pins are identical across SKILL.md, checks.md, verbs.md and tasks/26-delivery-desk.md.
C5 FAIL skills/delivery-desk/references/checks.md:94-95 "`push` waits up to 5 minutes for `ci.min_push_spacing_s`" states a cap with no default/question/proposed/owner-to-decide marker.
C5 FAIL skills/delivery-desk/references/verbs.md:23 "wait up to 5 min, else `marker` `push-spacing`" states the same cap with no marker.
C5 FAIL skills/delivery-desk/SKILL.md:18 "a `STATUS <id>` gets `BUSY <id> | <what> | <ETA>` within 2 minutes" states a cap with no marker.
C6 FAIL skills/delivery-desk/references/schemas.json: 2380 lines (rule: no file at or over 1000; preround-check.md has no JSON exemption).
C6 PASS SKILL.md 230, checks.md 134, verbs.md 180, human-gates.md 67 lines.
C7 PASS artefact head sha f68f6f2 for all five paths; sha256 prefixes match the brief (SKILL d457debfe5c8, checks 392ddb671427, human-gates 6cd62ed270ae, schemas 364969e802c5, verbs 70b958bf7339).
preround: 6 fails
