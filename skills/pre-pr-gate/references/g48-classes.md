# G48 pre-round check: finding classes

Rule (part-03 §4 "Quality rules adopted from the review-loop history", G48 `RLM:101`, D69 `:102`, G51 `:105`; owner-approved, D6): before round 1 and after every fix, a mechanical-tier agent checks the artifacts against the classes below and the fixes land before any seat reads. Evidence (same source): G47 to G51 cut a loop from 5 rounds to 1.

Artifacts for `pre-pr-gate` (card 10 step 5b, SKILL step 8, names the diff, record and PR body; the rest follow from the classes): the diff, the review record once it exists, `pr-body.md` once drafted (SKILL step 19 re-runs the check on it), the plan's unit list, the checklist, and any docs or changelog touched.

| Class | Check |
|---|---|
| Unmeasured claim | A number, duration or "fact" in docs or the PR body with no command or source behind it. |
| Arithmetic | Counts, totals, percentages stated in text re-added. |
| Cross-document contradiction | The same value stated in two files (PR body vs changelog vs docs vs code). |
| Missing done condition | A unit, test row or AC without an observable done check. |
| Protected value | A value the fixer brief lists as protected (versions, ids, flags, paths) changed. |

Output: a list `class | file:line | text`, empty if clean. The checker fixes nothing and writes the list to its own `RUN_HOME/<subtask>/status/<agent-id>.md` (A.6); the fixer (SKILL step 12 role) does, before any seat reads. It reads the review record but never edits it.
