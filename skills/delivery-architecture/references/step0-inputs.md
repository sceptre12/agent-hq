# Step 0: input validation (delivery-architecture)

Contract: INTERFACES 1.5.0 (`architecture/delivery-workflow/INTERFACES.md:3`): part D1 (`interfaces/part-d-enums-topics.md:6-11`; line regex `^INPUT-ERROR [A-Za-z_][][A-Za-z0-9_.]* (missing|enum|path|unset|format|sha)$`; reason `sha` added by AM-4 20), part D2.2 row 3 (named inputs, `part-d-enums-topics.md:77`), part A.1 (`DELIVERY_ROOT`, `RUN_HOME`, `<epic>`; `interfaces/part-a-state.md:7-53`), part A.2 (`state.md` keys `orchestrator_tier` `:60` and `security_audit` `:72`), part A.2.2 (profile keys, `part-a-state.md:109-161`; a missing key is `INPUT-ERROR <key> missing`, except `release_tags.*`, `:142`).

Rule: check every field in the order below, print one line per failing field, then stop. An `INPUT-ERROR` reply carries no verdict: it is neither a D7 review round nor a `fix-verifier` iteration; the caller fixes the input and re-invokes (part D1, AM-4 11-Q11-R1). No retry, no prompt, no file written, no agent dispatched. Inputs arrive as `NAME=value` in the skill arguments; `DELIVERY_ROOT` is the environment variable only (part D2.2 transport).

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
| 4 | `REPO_PROFILE` | `git hash-object <path>` equals the sha; on a mismatch, `git -C <repo root> cat-file blob <sha>` reads the pinned content and that content is used (part A.2 `repo_profile` reader rule, `interfaces/part-a-state.md:65`) | `INPUT-ERROR REPO_PROFILE path` (the path does not exist and the blob is unreadable) / `INPUT-ERROR REPO_PROFILE sha` (the file exists, its blob id differs from the sha, and the pinned blob is unreadable; part D1, AM-4 20) |
| 5 | `e2e.harness` | present in the profile, value `nlta` or `none` (D2.1; an A.2.2 key since AM-5 17); a `FILL_IN_BEFORE_DISPATCH` sentinel is not a value | `INPUT-ERROR e2e.harness missing` / `INPUT-ERROR e2e.harness enum` |
| 6 | `durations.unit_median_min` | present (A.2.2); an int, or the sentinel `FILL_IN_BEFORE_DISPATCH`, which is carried into each draft's budget unchanged for the dispatch plan to resolve | `INPUT-ERROR durations.unit_median_min missing` / `INPUT-ERROR durations.unit_median_min format` |
| 7 | `release_tags.used`, `.pattern`, `.approval` | optional (A.2.2 `:132-136`: absent is allowed, and then no tag step is planned, because the desk refuses it); read for step 7 and K12 | none |
| 8 | `review_profile.*` | read if present and passed on through `review-tailor`'s own profile read; absent means none, never an error (spec 16 RESOLVED Q3, AM-2 row 5) | none |

`RUN_HOME/state.md` (one YAML document, part A.2), read only when `RUN_HOME` passed its checks, so a missing `RUN_HOME` prints its one line and nothing about `state.md`. These are reads under `RUN_HOME`, not new inputs (D2.2 row 3 is unchanged); they feed `review-tailor`'s `ORCHESTRATOR_TIER` and `SECURITY_AUDIT` (D2.2 row 4, `part-d-enums-topics.md:78`):

| # | Key | Check | Line on failure |
|---|---|---|---|
| 9 | `orchestrator_tier` | present, one of `design`, `execute`, `verify`, `mechanical` (D2.1 `tier`); an absent `state.md` counts as absent | `INPUT-ERROR orchestrator_tier missing` / `INPUT-ERROR orchestrator_tier enum` |
| 10 | `security_audit` | `guidance` or `full`; absent means `guidance` (the A.2 default). Passed on unchanged, never derived from this skill's own `security_sensitive` line | `INPUT-ERROR security_audit enum` |

The repo root is the parent of the `plans/` directory that holds `PLANS_DIR`; `contracts/` is written there (part A.6). The sha check is the git blob id rule of AM-2 row 4 (the same rule `delivery-intake` uses when it prints `PROFILE:`).

## Fields validated later (same line form, then stop)

| Field | When | Line |
|---|---|---|
| `issuetype` | step 3, every draft's front matter, against `Epic\|Spike\|Story\|Task\|Subtask` (D2.1, capitalised) | `INPUT-ERROR issuetype enum` |
| `rung` | step 10, line 1 of `RUN_HOME/review-tailor-<SLUG>.md` against `^RUNG: (0\|1\|2\|2b\|3\|4) seats: [0-9]+$` (D1.1, D2.1) | `INPUT-ERROR rung enum` |

## Re-entry after `H1.changes`

If `RUN_HOME/gates/H1.<run-id>.changes` exists (the live H1 file, part A.2.1, `part-a-state.md:101`), before step 1:
1. Rename `PLANS_DIR/review-architecture.md` and `PLANS_DIR/h1-packet.md` to `<name>.<yyyymmddThhmmssZ>` (the A.2.1 history convention, applied here as a default of this skill), so no stale `ARCH: ready` stays live while the new pass runs.
2. Read `RUN_HOME/gates/H1.notes.md`; number the notes `1..k` in file order. Each note is a binding change.
3. Update the existing artifacts (do not start over); keep every existing slug and `step_id`, mint only for new nodes and steps. Delete the draft of every node the notes remove (a default of this skill; the notes are binding, step 2) before `drafts/index.md` is rewritten (nothing is published before `H1.ok`).
4. Mint the next `run-doc-<n>` slug; the round counter restarts at 1 for that loop.
5. The packet lists `note <k>: <how it was handled>` for every note (`h1-packet.md`).

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
