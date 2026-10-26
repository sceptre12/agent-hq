# Step 0: input validation (delivery-architecture)

Contract: INTERFACES 1.1.0 part D1 (line regex `^INPUT-ERROR [A-Za-z_][][A-Za-z0-9_.]* (missing|enum|path|unset|format)$`), part D2.2 row 3 (named inputs), part A.1 (`DELIVERY_ROOT`, `RUN_HOME`, `<epic>`), part A.2.2 (profile keys; a missing key is `INPUT-ERROR <key> missing`).

Rule: check every field in the order below, print one line per failing field, then stop. No retry, no prompt, no file written, no agent dispatched. Inputs arrive as `NAME=value` in the skill arguments; `DELIVERY_ROOT` is the environment variable only (part D2.2 transport).

## Order and cases

| # | Field | Check | Line on failure |
|---|---|---|---|
| 1 | `DELIVERY_ROOT` (env) | set and matches `^/[^[:space:]]+$` (part A.1: every skill fails loudly when it is unset) | `INPUT-ERROR DELIVERY_ROOT unset` / `INPUT-ERROR DELIVERY_ROOT format` |
| 2 | `RUN_HOME` | present | `INPUT-ERROR RUN_HOME missing` |
| 2 | `RUN_HOME` | an existing absolute directory directly under `$DELIVERY_ROOT`, last segment `^[a-z0-9-]+$` (part A.1 run-id) | `INPUT-ERROR RUN_HOME path` |
| 3 | `PLANS_DIR` | present | `INPUT-ERROR PLANS_DIR missing` |
| 3 | `PLANS_DIR` | an existing absolute directory whose parent directory is named `plans` (part A.6: `plans/<epic>/`), holding `brief.md` and `facts.md` | `INPUT-ERROR PLANS_DIR path` |
| 3 | `facts.md` | line 1 matches `^FACTS: [0-9]+ facts$` (part D1.1) | `INPUT-ERROR facts.md format` |
| 4 | `REPO_PROFILE` | present | `INPUT-ERROR REPO_PROFILE missing` |
| 4 | `REPO_PROFILE` | matches `^(/[^[:space:]]+)@([0-9a-f]{40})$` | `INPUT-ERROR REPO_PROFILE format` |
| 4 | `REPO_PROFILE` | the path exists, and `git hash-object <path>` equals the sha; on a mismatch, `git -C <repo root> cat-file blob <sha>` reads the pinned content and that content is used | `INPUT-ERROR REPO_PROFILE path` (neither the file at the sha nor the blob is readable) |
| 5 | `e2e.harness` | present in the profile, value `nlta` or `none` (D2.1); a `FILL_IN_BEFORE_DISPATCH` sentinel is not a value | `INPUT-ERROR e2e.harness missing` / `INPUT-ERROR e2e.harness enum` |
| 6 | `durations.unit_median_min` | present (A.2.2); an int, or the sentinel `FILL_IN_BEFORE_DISPATCH`, which is carried into each draft's budget unchanged for the dispatch plan to resolve | `INPUT-ERROR durations.unit_median_min missing` / `INPUT-ERROR durations.unit_median_min format` |
| 7 | `review_profile.*` | read if present and passed on through `review-tailor`'s own profile read; absent means none, never an error (spec 16 RESOLVED Q3, AM-2 row 5) | none |

The repo root is the parent of the `plans/` directory that holds `PLANS_DIR`; `contracts/` is written there (part A.6). The sha check is the git blob id rule of AM-2 row 4 (the same rule `delivery-intake` uses when it prints `PROFILE:`).

## Fields validated later (same line form, then stop)

| Field | When | Line |
|---|---|---|
| `issuetype` | step 3, every draft's front matter, against `Epic\|Spike\|Story\|Task\|Subtask` (D2.1, capitalised) | `INPUT-ERROR issuetype enum` |
| `rung` | step 10, line 1 of `RUN_HOME/review-tailor-<SLUG>.md` against `^RUNG: (0\|1\|2\|2b\|3\|4) seats: [0-9]+$` (D1.1, D2.1) | `INPUT-ERROR rung enum` |

## Re-entry after `H1.changes`

If `RUN_HOME/gates/H1.changes` exists (the live H1 file, part A.2.1), read `RUN_HOME/gates/H1.notes.md` before step 1. Each note is a binding change; the new stage-2 pass updates the existing artifacts (it does not start over), mints the next `run-doc-<n>` slug, and the packet lists how each note was handled.

## Examples

`RUN_HOME` absent, everything else valid (the dry-run case saved as `unset.txt`):
```
INPUT-ERROR RUN_HOME missing
```
`RUN_HOME` absent and `e2e.harness: maybe`:
```
INPUT-ERROR RUN_HOME missing
INPUT-ERROR e2e.harness enum
```
