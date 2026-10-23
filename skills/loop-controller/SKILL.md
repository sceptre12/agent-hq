---
name: loop-controller
description: >
  Pure state-machine orchestrator for a loop.yaml-defined improve-until-passing run:
  validates the run's config and briefs, starts the swarm bus, dispatches
  loop-runner/loop-grader/loop-fixer/loop-finding-classifier sub-agents in sequence each
  iteration, tracks best score and iteration count, and posts the final
  PASS/EXHAUSTED/ERROR result to the bus. Use when a loop.yaml exists under
  ~/projects/loops/{slug}/ and something needs to run its runner-grade-fix cycle to
  convergence or exhaustion. Never reads target_path content, scores artifacts, applies
  fixes, or runs review panels itself — that is loop-runner/loop-grader/loop-fixer/
  loop-finding-classifier's job, all installed as sibling skills. This is loop-internal
  orchestration infrastructure, not a review mechanism — no review-ladder rung applies
  (tools/review-ladder.md). Triggers: run a loop, start loop-controller, iterate a
  skill/artifact against a rubric, loop.yaml, improve-until-passing, runner-grade-fix
  cycle.
---

## Trigger

Use when something needs to run a `loop.yaml`-defined run to convergence or exhaustion:
dispatching loop-controller to iterate loop-runner → loop-grader → (loop-finding-classifier,
if configured) → loop-fixer until the grader passes, `max_iterations` is hit, or a
sub-agent fails to post. The controller is a pure state machine — it holds no domain
knowledge and never touches `target_path` content itself.

## Operating Mode Gate (determine this FIRST)

1. Check whether `is_subagent: true` is present in your context.
2. **If yes** — dispatch every sub-agent via Bash (`claude -p`); the Agent tool may be
   unavailable in sub-agent context depending on harness configuration — verify
   availability rather than assume.
3. **If no** — dispatch every sub-agent via the Agent tool.

Establish this before doing anything else — it decides every dispatch call below.

## Steps

1. **Parse `loop.yaml` and assign variables.** Before pre-flight step 1 runs, read
   `~/projects/loops/${SLUG}/loop.yaml` and assign `TARGET_PATH`, `TEST_ARTIFACT`,
   `RUNNER_BRIEF`, `FIXER_BRIEF`, `FINDING_CLASSIFIER`, `MAX_ITERATIONS_RAW`, `LOG_PATH`,
   `RUBRIC_PATH`, `ROLLBACK_ON_REGRESSION` from its fields (full field definitions:
   `references/loop-yaml-schema.md`). `SLUG` itself is supplied by the caller in the
   dispatch prompt — it is the directory name under `~/projects/loops/` containing
   `loop.yaml`.

2. **Pre-flight, in order — every check below exits `VALIDATION_FAILED` and stops on
   failure:**
   1. Validate `SLUG` against `^[a-z0-9_-]+$`; resolve with `realpath -m` and confirm it
      falls under `~/projects/loops/` (path-traversal guard). Never compare tilde
      strings — always compare realpath-expanded paths.
   2. Confirm `~/projects/loops/${SLUG}/loop.yaml` exists.
   3. Confirm `schema_version == 1`.
   4. Confirm `RUNNER_BRIEF` and `FIXER_BRIEF` both exist and contain a `## Security`
      section. **`FINDING_CLASSIFIER` is validated only for presence/nullity** — it is a
      pure feature-flag path, not a content-bearing brief (see
      `references/loop-yaml-schema.md`'s `finding_classifier` entry for why this port
      changed that from the source skill's existence+`## Security` check).
   5. Confirm `loop.yaml` contains no top-level `threshold:` key — threshold belongs
      exclusively in `rubric.md`.
   6. `ROLLBACK_ON_REGRESSION` defaults to `false` when absent; reject only non-boolean
      values.
   7. Confirm `TEST_ARTIFACT` exists.
   8. Confirm `RUBRIC_PATH` exists.
   9. Confirm `MAX_ITERATIONS_RAW` is an integer ≥ 1; assign `MAX_ITERATIONS`.
   10. If `LOG_PATH` is non-null, confirm its parent directory exists.
   11. Resolve `TARGET_PATH` with `realpath`; confirm it falls under `~/projects/` or
       `~/.claude/skills/` (two distinct failure messages: unresolvable vs. out-of-root
       — see `references/loop-yaml-schema.md`).
   12. Acquire the lock atomically: `LOCK_FILE=~/projects/loops/${SLUG}/.loop.lock`
       (`ln -s $$` — atomic on POSIX). A stale lock is one whose PID fails `kill -0` OR
       whose companion `.loop.lock.ts` timestamp is more than 30 minutes old (TTL guards
       PID recycling); either condition clears it, otherwise `VALIDATION_FAILED` (another
       controller is running for this slug). Register the cleanup trap
       (`trap cleanup EXIT SIGINT SIGTERM`) immediately before lock acquisition, before any
       resource is acquired. **`SIGKILL` cannot be trapped** — see Security. Nor does the
       trap survive a fresh Bash tool invocation: in an agent harness, an `EXIT` trap
       registered in one Bash call does not carry over to the next call, so it is
       best-effort only — `cleanup()` (step 3) must also be invoked as an explicit final
       step (step 6) rather than relying on the trap firing.
   13. Derive `SESSION_ID="loop-${SLUG}-$(date +%Y%m%d)-$(uuidgen | tr '[:upper:]'
       '[:lower:]' | cut -c1-4)"`. Pass it as `run_id` to every sub-agent.

3. **Bootstrap the bus.** Source nvm, resolve `pm2`, set `DATA_DIR=/tmp/${SESSION_ID}`
   and `APP_NAME=swarm-mcp-${SESSION_ID}`, `cd ~/projects/agent-hq/tools/swarm-communication-layer`, and
   start it: `DATA_DIR="${DATA_DIR}" APP_NAME="${APP_NAME}" pm2 start ecosystem.config.cjs`.
   Poll for `${DATA_DIR}/port` (max 30 × 0.3s = 9s) — `EXIT_ERROR(BUS_START_FAILED)` if
   absent. Then **sample `/health` 2-3 times**, requiring every response to show
   `"status":"ok"` **and** `app_name`/`data_dir` equal to this session's `APP_NAME`/
   `DATA_DIR` — a single `ok` response is not proof this port is yours (per
   swarm-communication-layer discrepancy #8; matches the `swarm-communication` skill's
   own identity discipline). `/health` can also report `"status":"degraded"` (and,
   where present, a `db_ok` field) — treat anything other than `"status":"ok"` **and**
   `db_ok: true` (when present) as not-ready. Any mismatch, non-`ok`/`degraded` status,
   or `db_ok: false` is `EXIT_ERROR(BUS_START_FAILED)`. Once identity is confirmed, call
   `start_session({session_id: SESSION_ID})` (idempotent) — before the snapshot dir is
   created (step 4) and before the first sub-agent is dispatched. Define `cleanup()`
   for the trap registered in step 2.12: `end_session({session_id: SESSION_ID})` first,
   **then** `pm2 delete "${APP_NAME}"` (bus gone before anything else), then
   `rm -rf "${DATA_DIR}"`, then remove `.loop.lock`/`.loop.lock.ts` last (so no
   concurrent controller acquires the lock while the old bus is still alive). The `.bak/`
   dir lives outside `DATA_DIR` and is never touched by cleanup — it is the sole restore
   source.

4. **Clean and create the snapshot dir**, before the first iteration:
   `rm -rf ~/projects/loops/${SLUG}/.bak && mkdir -p` it. `BAK_DIR` is that path for the
   rest of the run.

5. **Run the iteration loop.** Full pseudocode, the regression gate, decision-order
   detail, and result-topic schema: `references/state-machine.md` — read it before
   implementing or debugging the LOOP. Condensed shape:
   - `DISPATCH runner` → `AWAIT {SESSION_ID}-iteration-{N}-runner-output`.
   - On `runner.status == failed`: snapshot, then dispatch fixer — with `error_detail` if
     non-null, else with a synthesized `failures: [{name: runner-error, notes: "runner
     failed with no detail", target_file: null}]` (the null-`error_detail` shape
     loop-fixer's own `references/fixer-contract.md` documents receiving); await
     `-fixed`; on fixer failure, revert and `EXIT_ERROR(FIXER_FAILED)`; else snapshot to
     `DATA_DIR` for audit, `N++`, loop.
   - On `runner.status == success`: dispatch grader, update `best_score`/`best_iteration`.
     If `finding_classifier` unset: check pass → EXIT_PASS, check `N >= MAX_ITERATIONS`
     → EXIT_EXHAUSTED (restore best snapshot first), else compute `failures` and run the
     regression gate. If `finding_classifier` set (non-null): dispatch classifier with
     `panel_findings_path`, `rubric_failures`, `run_id`, `iteration`, `data_dir` — **no
     `rubric_criteria` field** (see `references/state-machine.md`'s classifier-path note
     on why an earlier draft's extra field was dropped rather than kept as dead weight),
     accumulate `deferred[]`, run the regression gate BEFORE the dual-gate pass check
     (`grader.passed` AND no Blocking/Medium in `classified.in_scope`), then check
     `N >= MAX_ITERATIONS`, else adapt `in_scope[]` into `failures[]`.
   - Either path: pre-fixer snapshot (after any rollback), dispatch fixer with
     `failures`, await `-fixed`; on failure, revert and `EXIT_ERROR(FIXER_FAILED)`; else
     post-fixer audit snapshot, `N++`, loop.

6. **Post the final result** to `{SESSION_ID}-result` on every exit path (PASS,
   EXHAUSTED, ERROR) using the canonical `jq --arg` + curl pattern in
   `references/bus-schema.md` — never an inline `-d "{...}"` string (breaks silently on
   special characters in `error_detail`/notes, and is the same shell-injection surface
   `references/agent-briefs.md` documents for `claude -p` prompts). Then run
   `cleanup()` (step 3) explicitly as this skill's own last action on every exit path —
   do not rely solely on the `EXIT` trap firing (step 2.12's caveat). Full
   field-by-field schema for PASS/EXHAUSTED/ERROR: `references/bus-schema.md` and
   `references/state-machine.md`.

## Dispatch Mechanism

**`is_subagent: true` present** — dispatch via Bash:
```bash
IS_SUBAGENT=true claude --model sonnet --dangerously-skip-permissions -p "<sub-agent prompt>"
```
Note: only the controller's own dispatches use `--dangerously-skip-permissions`; if this
policy should extend to nested `claude -p` calls made by loop-runner/loop-grader/loop-fixer,
that flag should be added to their own dispatch examples too (see their SKILL.md files) —
currently only the controller carries it, which is inconsistent.

Use `--model claude-haiku-4-5-20251001` specifically for loop-finding-classifier (see
`references/agent-roles.md` for why this one dispatch is version-pinned rather than
using the `sonnet` alias). Append `is_subagent: true` as the prompt's last line too (a
fallback for contexts that strip env vars) so the mode propagates down the chain.
**Every prompt built from `grader_notes`, finding descriptions, or rubric-criterion
text must use the printf/heredoc-safe pattern in `references/agent-briefs.md`** — never
interpolate that content into the shell string directly; it originates from LLM output
or user-edited config and is exactly the shell-injection surface that file documents.

**`is_subagent: true` absent** — dispatch each sub-agent via the Agent tool, passing only
the inputs it needs (`SESSION_ID`, relevant paths, iteration number `N`) built from this
skill's dispatch contracts, not from reading the sub-skill's own `SKILL.md` in full.
Models: runner/grader/fixer → `sonnet`; loop-finding-classifier →
`claude-haiku-4-5-20251001`. Pass `is_subagent: true` as every Agent-tool prompt's last
line so sub-agents propagate the mode correctly.

**Never use for dispatch, regardless of mode:** the Skill tool (injects instructions
into your own context, does not spawn a sub-agent), TaskCreate (creates a tracking
record, does not execute work), a Bash command that simulates agent behavior, or inline
execution of steps read from a sub-skill's `SKILL.md`.

## Prohibited Side Channels

The bus post is the **sole** valid completion signal. Never determine a sub-agent's
outcome from: stdout/stderr of the `claude -p` process, its exit code (never branch on
`$?`), environment variables it exported, task output files, sibling-agent files in
`data_dir`, or named pipes. If a dispatch returns and the expected topic has no new
message, that is `EXIT_ERROR` — do not investigate by reading skill files, logs, env
vars, or bash output, and do not read sub-agent output files to reconstruct what
happened. Post `EXIT_ERROR` immediately and stop.

## Security

- Sandboxing here is prompt-only — no OS-level sandbox stops the runner or fixer from
  writing outside `target_path`. Run the controller in a sandboxed environment if
  stronger isolation is required.
- `SIGKILL` cannot be trapped: a `kill -9` of the controller bypasses cleanup, leaving a
  stale lock and a running PM2 bus process. Recovery:
  `rm -f ~/projects/loops/{slug}/.loop.lock*` and `pm2 delete <APP_NAME>` by hand.
- Allowed roots for `target_path`: `~/projects/` and `~/.claude/skills/`, resolved via
  `realpath` before comparison — never compare tilde strings directly. Paths that don't
  exist, contain null bytes, or resolve outside these roots are rejected.
- TOCTOU: validate paths and immediately open file descriptors; do not re-resolve a path
  between validation and the file operation that uses it.
- `runner_brief`/`fixer_brief` must each contain a `## Security` section or pre-flight
  fails; `finding_classifier` does not carry this requirement (step 2.4 above).
- Concurrent loop runs targeting the same `target_path` corrupt each other's snapshots
  and bus state — each concurrent run needs a distinct `target_path`.
- `target_path` must be a single file for atomic rollback; directory-level rollback is
  not supported.
- Bus identity: this skill's session is always per-session-mode (`APP_NAME=swarm-mcp-${SESSION_ID}`)
  — the 2-3x `/health` identity check in step 3 is not optional here the way it might be
  in a shared-bus context.

## References

- [references/state-machine.md](references/state-machine.md) — full LOOP pseudocode,
  regression gate, decision order, result-topic schema.
- [references/bus-schema.md](references/bus-schema.md) — canonical topic table, message
  shapes, the `jq --arg` bus-post pattern.
- [references/loop-yaml-schema.md](references/loop-yaml-schema.md) — every `loop.yaml`
  field, validation rule, and the `finding_classifier` feature-flag decision.
- [references/agent-briefs.md](references/agent-briefs.md) — shell-injection risk and
  the printf/heredoc-safe prompt patterns for untrusted grader/finding/rubric text.
- [references/agent-roles.md](references/agent-roles.md) — the six-block system, bus
  topics per block, model-reference-style rationale.
- `loop-runner`, `loop-grader`, `loop-fixer`, `loop-finding-classifier`, `loop-setup`
  (all installed) — the sub-agents this skill dispatches or that provision the run.
- `swarm-communication` (installed) — bus session lifecycle, `$DATA_DIR/port` discovery,
  identity preflight, and PM2 recovery (`pm2 restart`, never `reload`) live there, not
  re-derived here.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "The Agent tool call returned, so the sub-agent is done." | The bus post is the sole completion signal — poll the expected topic; a returned call with no new message is `EXIT_ERROR` (Prohibited Side Channels). |
| "The sub-agent failed — let me read its output file to figure out why." | No investigation on failure: post `EXIT_ERROR` immediately, full stop. Reading logs/files/stdout to diagnose is out of lane here. |
| "I'll just interpolate `${grader_notes}` into the `claude -p` prompt, it's simpler." | LLM-generated text can contain shell metacharacters; use the printf/heredoc-safe pattern in `references/agent-briefs.md` — this is a real shell-injection surface, not theoretical. |
| "`finding_classifier` is set, so I should pass its file content to the classifier." | It's validated as presence/nullity only — a pure feature flag. loop-finding-classifier's contract declares no brief-file input; don't invent one. |
| "Pass `rubric_criteria=grader.criteria` too, more context can't hurt." | loop-finding-classifier's own contract only declares `rubric_failures` — an undeclared extra field is dead weight the receiver ignores; drop it (`references/state-machine.md`). |
| "This orchestrates other agents' output, so it's a review-ladder call." | It isn't — this is loop-internal state-machine infrastructure; `tools/review-ladder.md` rungs don't apply to it. |
| "Small doc/skill, but I'll dispatch the full panel-review loop to be safe." | That decision belongs to whoever configures the loop's rubric/briefs, not to the controller — it has no domain judgment and makes no review-mechanism choice itself. |
| "I'll inline the bus post as `-d \"{...}\"`, it's quicker than jq." | Inline JSON/YAML interpolation breaks silently on newlines/quotes in `error_detail` or notes; use the canonical `jq --arg` + temp-file pattern (`references/bus-schema.md`). |
| "`session_id` is nullable in the schema, I can skip it." | Pass it explicitly on every bus call anyway — an omitted `session_id` produces a row `end_session` can never clean up (swarm-communication-layer discrepancy #6). |
| "The bus feels stuck — let me `pm2 reload` it." | `reload` overlaps old/new workers on the shared SQLite file and crash-loops; `pm2 restart` is the only safe recovery verb (discrepancy #9; see `swarm-communication` skill). |

## Exit criteria

- [ ] Every pre-flight check in Steps §2 passed (or the run stopped at
      `VALIDATION_FAILED` with the specific failing check named) before any sub-agent
      was dispatched.
- [ ] `SESSION_ID` was derived before the bus started, and passed as `run_id` to every
      sub-agent.
- [ ] The bus's `/health` was sampled 2-3 times with `app_name`/`data_dir` matching this
      session's `APP_NAME`/`DATA_DIR` before any dispatch — not a single `status:ok` check
      — and none of those samples showed `degraded` or `db_ok: false`.
- [ ] `start_session` ran (after identity was confirmed, before the first dispatch) and
      `end_session` ran inside `cleanup()` before `pm2 delete`.
- [ ] No sub-agent outcome was ever read from stdout, exit code, env vars, or a file —
      only from its expected bus-topic post.
- [ ] Every `.bak` snapshot was taken immediately before its corresponding fixer
      dispatch, and `.bak` count equals total fixer-dispatch count.
- [ ] The final result was posted to `{SESSION_ID}-result` on every exit path (PASS,
      EXHAUSTED, ERROR) using the canonical `jq --arg` bus-post pattern.
- [ ] `cleanup()` ran as this skill's own explicit final step on every exit path (or, if
      `SIGKILL` bypassed it, the stale lock and PM2
      process were recovered manually per Security) — no dangling lock or bus process
      left behind on a clean exit.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (2026-07-04 entry, "Skills have no standardized
export path")
Lineage: X-context-docs skills/loop-controller@0e9281e
