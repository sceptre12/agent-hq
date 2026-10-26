# G48 pre-round check: finding classes

Rule (part-03 quality rules; D6 adopted): before round 1 and after every fix, a mechanical-tier agent checks the artifacts against the classes below and the fixes land before any seat reads. Evidence G47 to G51 cut a loop from 5 rounds to 1.

Artifacts for `pre-pr-gate`: the diff, `pr-body.md`, the plan's unit list, the checklist, and any docs or changelog touched.

| Class | Check |
|---|---|
| Unmeasured claim | A number, duration or "fact" in docs or the PR body with no command or source behind it. |
| Arithmetic | Counts, totals, percentages stated in text re-added. |
| Cross-document contradiction | The same value stated in two files (PR body vs changelog vs docs vs code). |
| Missing done condition | A unit, test row or AC without an observable done check. |
| Protected value | A value the fixer brief lists as protected (versions, ids, flags, paths) changed. |

Output: a list `class | file:line | text`, empty if clean. The checker fixes nothing; the fixer does. Do not edit the review record from this check.
