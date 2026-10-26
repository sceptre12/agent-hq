# Fix record r0: 15 delivery-architecture (fixer, Opus, 2026-10-26)
Input: `preround-delivery-architecture-r1-2026-10-26.md` (9 FAIL lines). Mechanical fixes only; no behaviour change, no step reordered, no number changed. The fixer is not the author.

| finding id | file:line changed | change (one clause) | status |
|---|---|---|---|
| PR1-C1a | skills/delivery-architecture/SKILL.md:68 | Provenance now defines `H` = `$HOME/claude-profiles/hermes/h1-home/skills` and `RLM` = `H/brain/review-loop-mechanics/SKILL.md` once (outside W; `RLM` also at part-06:68); `:89` written as `RLM:89` | fixed |
| PR1-C1b | skills/delivery-architecture/references/contracts.md:3 | `RLM` expanded to its full path, pointing to the key in `../SKILL.md` §Provenance | fixed |
| PR1-C1c | skills/delivery-architecture/references/review-handoff.md:47 | `RLM:99` points to the key in `../SKILL.md` §Provenance | fixed |
| PR1-C1d | skills/delivery-architecture/references/architect-brief.md:13; decomposer-brief.md:12 | source-key line before the COMMON block gives `$HOME/claude-profiles/hermes/h1-home/skills/learnings/dispatch-stop-conditions-02/SKILL.md:307-320` (outside W; checked it exists, lines 307-320 are the "constraints do not propagate" entry); the block stays byte-identical to part-03:6 (cmp checked) | fixed |
| PR1-C2 | skills/delivery-architecture/SKILL.md:68 | every INTERFACES part, card 3 and part-04 section now has a W-relative path with its line range; version string 1.1.0 -> 1.3.0 (INTERFACES.md:3) | fixed |
| PR1-C4 | skills/delivery-architecture/SKILL.md:33 | one "Spec map" sentence: 5a and 8 are sub-steps of spec §8 item 3 steps; the record is written at 13 and moved at 14 so `ARCH: ready` is "written last" (spec §4) | fixed (explained, not reordered) |
| PR1-C5a | skills/delivery-architecture/SKILL.md:31 | "publish nothing" anchored to spec 15 §4 H1 row and part A.2.1 (drafts local until `H1.ok`) | fixed |
| PR1-C5b | skills/delivery-architecture/references/review-handoff.md:31-32 | "at most 9" and "at most 7 seats" anchored to card 4 (`part-02-skill-inventory.md:56`, "never exceed 7 at Rung 2b or 9 at Rung 2") | fixed |
| PR1-C5c | skills/delivery-architecture/references/security-sensitive.md:31 | anchored to spec 15 Open points RESOLVED Q2 (`tasks/15-delivery-architecture.md:96`), marked plan-check default | fixed |

## Checks
- Spec 15 §9 static lines (all except the FIXTURE_DIR dry run, which is the verifier's): sections 5/5, version 0.1.0, no disable-model-invocation, "Use when" present, SKILL.md 2259 words / 68 lines, all 11 grep tokens present, `plan-check default` present, forbidden list 0 matches outside templates/, no symlinks: rc 0.
- `bash W/tools/check-doc-length.sh W`: 0 blocking, 0 allowlisted over 500 lines.
- Reference files: largest tree-rules.md 70 lines; total 327.
- Every cited W path exists (test -f on 9 files); the three outside-W Hermes files exist.

## Notes (not fixed; outside the listed findings)
- `references/security-sensitive.md:3,15`, `architect-brief.md:3`, `decomposer-brief.md:3`, `contracts.md:3` still say "INTERFACES 1.1.0"; the brief limited the version fix to Provenance.
- `security-sensitive.md:3` says "pending owner OQ-1", but `architecture/delivery-workflow-sources/owner-decisions.md:89` records the owner's OQ-1 answer (BROAD LIST). No finding marks it stale, so the text is unchanged; flagged for the next round.
