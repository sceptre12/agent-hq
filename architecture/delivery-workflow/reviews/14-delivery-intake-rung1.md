# Item 14 `delivery-intake` — Rung 1 loop record

- **Artifact:** `skills/delivery-intake/` (`SKILL.md`, `references/step0-inputs.md`, `profile-keys.md`,
  `explorer-brief.md`, `fixtures/**`). `references/templates/` is item 27's and was not reviewed.
- **Spec:** `architecture/delivery-workflow/tasks/14-delivery-intake.md` (RESOLVED Q1, Q2 binding).
- **Loop:** one orchestrator (D35), a separate agent per role, never reused across roles:
  - G48 pre-round screen: Haiku, a fresh agent each time (before round 1 and after each fix).
  - Review: Sonnet, running the installed `doc-reviewer` skill.
  - Fix: Opus (one fixer agent across rounds; not the author).
  - Fix-verify and the non-author §9 dry run: Sonnet, running the installed `fix-verifier` skill
    (one verifier agent across rounds; not the fixer).
- **Round cap:** 3 rounds (D7). Screen findings went to the fixer first.
- **Date:** 2026-10-26.
- **Sources:** the spec, INTERFACES (1.2.0 at round 1, 1.3.0 by AM-3 during the loop) with
  `interfaces/part-a..d`, `architecture/delivery-workflow-sources/owner-decisions.md`, design card 2.
- **Lint and typo nits:** skipped.

## Round 1

**Pre-round screen (G48): 1 Blocking, 7 Medium, 6 Low.**
- Six A.2.2 keys added by AM-2 were missing from `profile-keys.md` (Blocking).
- The INTERFACES version cited was stale.
- Step 10 withheld `PROFILE:` on a non-empty "frontier", against the fixture.
- `source: <url>` lines were undefined.
- The port retry did not match A.5.2 as amended by AM-3 (owner OQ-2).
- The fixture `facts.md` lacked rows for several explorer questions, and the fixture brief's open
  items lacked the what and who.
- The Provenance friction had no link.

**Review (doc-reviewer): 1 Blocking, 7 Medium, 9 Low. Verdict: NOT READY.**
- R1-1 (Blocking): `PROFILE:` was conditional on confirmation, against spec §4, §8.3 and the §9
  `tail -1` check.
- R1-2: the AM-2 keys were missing.
- R1-3: a refresh could create a second profile.
- R1-4: research facts had no home.
- R1-5: the fixture CI-jobs row did not match its command's output.
- R1-6: the description did not open with the card trigger.
- R1-7: fixture open items had the wrong form.
- R1-8: the explorer stall budget was undefined.

**Orchestrator rulings given to the fixer (no owner decision involved):**
- Ports follows A.5.2 as amended by AM-3: exactly one retry at candidate + 10, itself claimed
  first. Owner OQ-2 overrides the spec §8.5 wording "never re-picked".
- `PROFILE:` follows spec §4 and §8.3: the confirm question first, then `PROFILE:` last.

**Fix (Opus):** every Blocking and Medium was fixed, and most Lows.
- Confirm question, then `PROFILE:` last in the same turn; "frontier" was dropped.
- The six AM-2 keys were added to the key table, the explorer questions and the fixtures.
- Research goes under `brief.md` `## Research`, never in `facts.md`.
- A refreshed profile is written back to the path it was read from (A.6).
- The explorer budget is derived from the explorer brief's 2-minute rule; at most one explorer per
  question group.
- The fixture facts were rebuilt from commands re-run on the fixture repo.

**Fix-verify: CLEAN, 0 Blocking, 0 Medium, 6 Low, 2 Advisory.**
- The §9 dry run passed, but the round 1 post-fix screen found 1 Medium, so the loop went on.

## Round 2

**Screen: 0 Blocking, 1 Medium, 5 Low.**
- S2-1: the fixture `gates.command` was a composed value, not a measured one.
- Lows: an opaque budget label, the exit-3 wording, the `STATUS` window, the friction citation, and
  open items not on one line per key.

**Fix:** S2-1 and all 5 Lows were fixed, plus five Lows from the verifier.
- Repos with no affected-capable runner now take a fallback: a `cannot measure:` row, the sentinel,
  and a question to the human.
- One open-item line per sentinel; the fixture shows 17 everywhere.
- The friction is cited as `RG:80`.

**Fix-verify: CLEAN, 0 Blocking, 0 Medium, 0 Low, 2 Advisory.**
- The §9 dry run passed.

## Round 3

**Screen: 0 Blocking, 2 Medium, 3 Low.**
- S3-1: Step 8's atomic write came before Step 9 filled `brief.md` open items, which implied an edit
  in place.
- S3-2: the fixture `clones` value had no facts row behind it.

**Fix:**
- Sentinels are now listed on the draft (step 8) before the atomic write (step 9).
- The clone-root question and a `facts.md` row were added, giving `FACTS: 36`.
- `|` characters inside table cells are escaped.
- The fixture README says its paths are placeholders.
- The `merge_reach` comment cites the facts rows it rests on.

**Fix-verify: CLEAN, 0 Blocking, 0 Medium, 1 Low, 2 Advisory.**
- V3-1 (Low): the explorer brief names only `rev-parse --show-cdup`. A real run should also record
  `--show-toplevel` to get the absolute path that `clones[]` needs.

**Post-fix screen (after the final fix): 0 Blocking, 1 Medium, 4 Low.**

## Open after round 3 (D7: stop; the owner decides)

| id | class | finding |
|---|---|---|
| S4-1 | Medium | `references/fixtures/expected/facts.md:37` and `expected/brief.md:23` say package.json "has only the full-repo scripts lint, typecheck, test", but row 10 of the same file measures `build` and `clean` too. The fixture contradicts itself. The dry run is unaffected. |
| S4-2 | Low | `fixtures/expected/stdout.txt:1` gives the confirm instruction but has no question form (Step 10). |
| S4-3 | Low | Ports: the definition of "candidate" points to the dispatch-plan port table, which intake does not have. |
| S4-4 | Low | Step 6: the wording that scales the 2-minute rule is vague. |
| S4-5 | Low | Provenance cites `RG:80` and a part-06 row rather than a linked friction entry; "pending pilot". |
| V3-1 | Low | The explorer brief clone-root question should also record `--show-toplevel` in a real run. |
| A-1, A-2 | Advisory | `tools/port-check.sh` and `catalog.sh` are not yet present in W (other items). The explorer budget equals the per-command timeout for a one-question explorer. |

**Owner question OQ-14-1.** Should the loop authorize a one-line fixture correction for S4-1 outside
the D7 round cap?
- Recommended answer: yes. Change "has only the full-repo scripts lint, typecheck, test" to
  "has only full-repo scripts (lint, typecheck, test, build, clean)" in both lines.
- This is a wording fix inside the fixture and needs no new review round. The Lows can be left to
  the pilot.

**Cross-item note (item 27, not this item):** `references/templates/repo-profile.md` spells three keys
differently from A.2.2:
- `sensitive_path_deny_list[]`
- `lane_profile.ports`
- `zephyr.execute_tool_name`

`profile-keys.md` says the A.2.2 names win. The template also changed during this loop, through item
27's own edit.

**Upstream note:** `INTERFACES.md` lists `delivery-intake` against AM-2 rows 4 and 5, but intake is
D2.2 row 2.

## Final §9 done-condition block

The non-author verifier ran the dry run. It used `FIXTURE_DIR=$SCRATCH/r14/dryrun3`, and its work
directory was `dry-work3`. The orchestrator then re-ran the block, verbatim from spec §9:

```
SKILL-14-OK
exit=0
```

- The last stdout line of the dry run was
  `PROFILE: <scratch>/r14/dry-work3/run/repo/plans/repo-profile.md@de5b675e750322978e30c0ef3bedd031a5d44f47`.
- That sha equals `git hash-object` of the profile.
- `unset.txt` is `INPUT-ERROR DELIVERY_ROOT unset`.
- The fix-verifier's last verdict is CLEAN. The final screen still holds one fixture Medium (S4-1)
  for the owner.

Working files are in `SCRATCH/r14/`:
- screens: `screen-r1..r3.md`
- review: `review-r1.md`
- fix log: `fix-r1.md`
- verifications: `verify-r1..r3.md`
- diffs: `diff-r*.patch`
