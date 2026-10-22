# State Machine Reference

Full iteration loop. `SKILL.md` gives the condensed version; this file is the
authoritative detail — read it before implementing or debugging the LOOP.

## All AWAIT States

AWAIT means: poll the bus topic (see `bus-schema.md` AWAIT polling pattern) until a
message appears, posted by the sub-agent itself — never self-post to an AWAIT topic,
and never treat a returned Agent-tool call as completion by itself (the bus post is the
sole valid completion signal — see `SKILL.md` Prohibited Side Channels). If a sub-agent
returns without posting to its expected topic, that is EXIT_ERROR — do not continue or
retry inline.

| State | Topic awaited | Timeout | EXIT_ERROR reason if unmet |
|---|---|---|---|
| AWAIT_RUNNER | `{SESSION_ID}-iteration-{N}-runner-output` | Agent tool built-in | RUNNER_FAILED |
| AWAIT_GRADE | `{SESSION_ID}-iteration-{N}-grade` | Agent tool built-in | GRADER_FAILED |
| AWAIT_CLASSIFIED | `{SESSION_ID}-iteration-{N}-classified` | Agent tool built-in | CLASSIFIER_FAILED |
| AWAIT_FIXED | `{SESSION_ID}-iteration-{N}-fixed` | Agent tool built-in | FIXER_FAILED |

## State Variables

Initialized at startup, before the first dispatch:

| Variable | Initial value | Updated when |
|---|---|---|
| `N` | 1 | `N++` after each fixer dispatch |
| `best_score` | 0.0 | `grade.score > best_score` |
| `best_iteration` | 0 (sentinel: no iteration scored yet) | alongside `best_score` |
| `ROLLBACK_COUNT` | 0 | each time the regression gate triggers a restore |
| `ROLLBACK_FAILED` | false | when a rollback snapshot is missing |
| `DEFERRED_FINDINGS` | [] | classifier `deferred[]` appended each iteration |

## Full State Machine

```
START
  Validate slug, loop.yaml, schema_version, briefs, target_path, lock, bus (SKILL.md pre-flight)
  rm -rf ~/projects/loops/{slug}/.bak && mkdir -p ~/projects/loops/{slug}/.bak
  BAK_DIR = ~/projects/loops/{slug}/.bak
  N = 1; ROLLBACK_COUNT = 0; ROLLBACK_FAILED = false

LOOP:
  DISPATCH runner (run_id=SESSION_ID) → AWAIT_RUNNER

  if runner.status == failed:
    cp target_path → BAK_DIR/pre-iter-{N}.bak            # pre-fixer snapshot, every fixer dispatch
    if runner.error_detail != null:
      DISPATCH fixer(error_detail=runner.error_detail, run_id=SESSION_ID, iteration=N) → AWAIT_FIXED
    else:
      DISPATCH fixer(failures=[{name: runner-error, notes: "runner failed with no detail",
                                 target_file: null}], run_id=SESSION_ID, iteration=N) → AWAIT_FIXED
    if fixer.status == failed:
      cp BAK_DIR/pre-iter-{N}.bak → target_path            # revert (EXIT_ERROR cleanup)
      POST EXIT_ERROR(FIXER_FAILED, deferred_findings=DEFERRED_FINDINGS,
                       rollback_count=ROLLBACK_COUNT, rollback_failed=ROLLBACK_FAILED) → DONE
    mkdir -p DATA_DIR/snapshots/iter-{N}; cp target_path → DATA_DIR/snapshots/iter-{N}/   # audit only
    N++; GOTO LOOP

  # runner.status == success from here on
  DISPATCH grader(artifact_path=runner.artifact_path, rubric_path=RUBRIC_PATH,
                   run_id=SESSION_ID, iteration=N, data_dir=DATA_DIR) → AWAIT_GRADE
  if grade.score > best_score: best_score = grade.score; best_iteration = N
  failures_from_grade = grader.criteria.filter(passed==false)

  if finding_classifier not set (null):
    if grader.passed == true:
      POST EXIT_PASS(...) → DONE
    if N >= MAX_ITERATIONS:
      SCAN grade topics → best_iteration (highest score; gaps = runner-failure iters)
      cp BAK_DIR/pre-iter-{best_iteration+1}.bak → target_path        # restore before exit
      POST EXIT_EXHAUSTED(...) → DONE
    failures = failures_from_grade
    # regression gate (below) runs here, before the pre-fixer snapshot

  else:  # finding_classifier is set — pure feature flag, see loop-yaml-schema.md
    DISPATCH classifier(panel_findings_path=runner.artifact_path,
                         rubric_failures=failures_from_grade,
                         run_id=SESSION_ID, iteration=N, data_dir=DATA_DIR) → AWAIT_CLASSIFIED
    DEFERRED_FINDINGS += classified.deferred[]

    # REGRESSION GATE runs BEFORE the dual-gate PASS check on the classifier path
    <regression gate — see below>

    if grader.passed == true AND classified.in_scope has no Blocking/Medium:
      POST EXIT_PASS(deferred_findings=DEFERRED_FINDINGS, ...) → DONE
    if N >= MAX_ITERATIONS:
      cp BAK_DIR/pre-iter-{best_iteration+1}.bak → target_path        # restore before exit
      POST EXIT_EXHAUSTED(deferred_findings=DEFERRED_FINDINGS, ...) → DONE

    # classifier-to-fixer adapter: in_scope[] becomes failures[]
    failures = []
    for item in classified.in_scope[]:
      criterion = grader.criteria.find(name == item.maps_to)
      failures.append({name: item.finding_id, score: criterion.score, max: criterion.max,
                        passed: false, target_file: criterion.target_file, maps_to: item.maps_to,
                        notes: item.description + " — fix: " + item.fix})

  # regression gate (no-classifier path only; classifier path already ran it above)
  <regression gate — see below, no-classifier path>

  cp target_path → BAK_DIR/pre-iter-{N}.bak      # pre-fixer snapshot, AFTER any rollback
  DISPATCH fixer(failures=failures, run_id=SESSION_ID, iteration=N, data_dir=DATA_DIR) → AWAIT_FIXED
  if fixer.status == failed:
    cp BAK_DIR/pre-iter-{N}.bak → target_path       # revert
    POST EXIT_ERROR(FIXER_FAILED, deferred_findings=DEFERRED_FINDINGS,
                     rollback_count=ROLLBACK_COUNT, rollback_failed=ROLLBACK_FAILED) → DONE
  mkdir -p DATA_DIR/snapshots/iter-{N}; cp target_path → DATA_DIR/snapshots/iter-{N}/   # audit only
  N++; GOTO LOOP
```

**Regression gate (both paths, identical logic):**
```
if ROLLBACK_ON_REGRESSION == true:
  if best_iteration == 0:
    skip   # sentinel — no valid snapshot yet
  elif grade.score < best_score:
    src = BAK_DIR/pre-iter-{best_iteration+1}.bak
    if src exists:
      cp src → target_path
      ROLLBACK_COUNT++
    else:
      ROLLBACK_FAILED = true
    broadcast {SESSION_ID}-iteration-{N}-regression-rollback:
      {grade_score, best_score, best_iteration, rollback_failed}
    # failures[] computed below reflect the pre-rollback (regressed) artifact — stale
    # hints; the fixer must treat target_file/line-number hints as advisory only.
```

Classifier-path note on inputs: the classifier dispatch above passes
`panel_findings_path`, `rubric_failures`, `run_id`, `iteration`, `data_dir` only — this
is the exact input set loop-finding-classifier's own contract declares. An earlier draft
also passed `rubric_criteria=grader.criteria`, a field loop-finding-classifier's contract
never declared; it has been dropped here rather than sent as dead weight. If accurate
deferred-reason attribution genuinely needs the full criteria list, add the field to
loop-finding-classifier's declared Inputs and its dispatch call together, in the same
change.

---

## Decision Order (Critical)

**Pass condition is always checked before max_iterations.** A run that satisfies the
pass condition on the final iteration exits EXIT_PASS, never EXIT_EXHAUSTED.

**No-classifier path:**
1. Runner status → failure path if `status: failed`
2. Dispatch grader → AWAIT_GRADE
3. Update `best_score`/`best_iteration` if `grade.score > best_score`
4. `grader.passed == true` → EXIT_PASS
5. `N >= max_iterations` → EXIT_EXHAUSTED (restore best-scoring snapshot first)
6. Regression gate (if `rollback_on_regression: true` and `best_iteration > 0`)
7. Pre-fixer snapshot (after any rollback)
8. Dispatch fixer

**Classifier path** (regression gate runs before the pass check — different order from
the no-classifier path):
1. Runner status (failure path)
2. Dispatch grader → AWAIT_GRADE
3. Dispatch classifier → AWAIT_CLASSIFIED
4. Accumulate `deferred[]`
5. **Regression gate** (if `rollback_on_regression: true`) — runs BEFORE the pass check
6. Dual-gate check (`grader.passed` AND no Blocking/Medium in `in_scope`) → EXIT_PASS
7. `N >= max_iterations` → EXIT_EXHAUSTED (restore best-scoring snapshot first)
8. Dispatch fixer

## Dual-Gate Rule

Exit PASS only when **both** hold:
- (a) `grader.passed == true`
- (b) `classified.in_scope` contains no `severity: Blocking` or `severity: Medium` finding

When the classifier is not configured, only condition (a) applies.

## Snapshot Timing

**Pre-fixer snapshot (mandatory, every fixer dispatch):**
- If a rollback occurred, `target_path` already holds the restored best state
- `cp target_path → BAK_DIR/pre-iter-{N}.bak`, taken AFTER any rollback
- Lives outside `DATA_DIR` — survives the cleanup trap; **the sole restore source**
- `.bak` count == total fixer-dispatch count (not grade count) — a contiguous sequence

**Post-fixer snapshot (audit only):**
- `cp target_path → DATA_DIR/snapshots/iter-{N}/`, taken after the fixer posts `fixed`
- Lives inside `DATA_DIR` — deleted on cleanup; audit/scoring-scan use only
- Never used for restoration — `.bak/` is the sole restore source

## EXIT_EXHAUSTED Best-Iteration Scan

1. Scan grade topics `N=1..current`; gaps are runner-failure iterations (skipped)
2. Find the `N` with the highest score → `best_iteration`
3. Restore `target_path` from `BAK_DIR/pre-iter-{best_iteration+1}.bak` — the `+1` is
   because the snapshot is taken *before* that iteration's fixer runs, so it captures
   the artifact state that produced `best_score`
4. Post EXIT_EXHAUSTED with `final_artifact_path: target_path` (after restore)

## Iteration Counting

- Runner-failure iterations count: `N++` happens after the fixer dispatch on that path too
- Every iteration increments `N`, whether or not a grade was produced
- `max_iterations` is the hard ceiling, enforced after every grade/classify check

## Terminology

- **"revert"** = EXIT_ERROR cleanup (`cp` the most recent `.bak` back to `target_path`).
- **"restore"** = regression-gate or EXIT_EXHAUSTED action (`cp` the best-scoring `.bak`
  back to `target_path`).
- **`best_iteration=0`** is a sentinel meaning no iteration has produced a grade yet.

## Result Topic Schema

Topic: `{SESSION_ID}-result` — posted by the controller on all exit paths (see
`bus-schema.md` for the canonical `jq --arg` post pattern).

| Field | Type | Description |
|---|---|---|
| `exit_reason` | string | `PASS \| EXHAUSTED \| ERROR` |
| `best_score` | float | Highest score achieved |
| `best_iteration` | int | Iteration that produced `best_score` |
| `iterations_completed` | int | Total iterations run |
| `final_artifact_path` | string\|null | `target_path` after any finalization restore; null on ERROR |
| `rollback_count` | int | Number of regression-gate restores performed |
| `rollback_failed` | bool | true if any restore could not complete (snapshot missing) |
| `deferred_findings` | list | Accumulated classifier `deferred[]` across all iterations |
