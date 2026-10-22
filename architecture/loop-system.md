# loop-system — improve-until-passing loop pipeline (ADR 0011)

One-line summary: six cooperating skills that run a `loop.yaml`-defined
runner→grader→(classifier)→fixer cycle to convergence or exhaustion, coordinating
entirely over the swarm-communication-layer bus.

## What This Is

One connected system, not six independent skills (user ruling) — the six blocks share a
single `loop.yaml` contract, a single bus-topic namespace per run, and one lifecycle
(bootstrap → iterate → PASS/EXHAUSTED/ERROR). `loop-setup` is the only block a user
invokes directly; the other five are dispatched programmatically once `loop.yaml` exists
under `~/projects/loops/{slug}/`.

## Components

| Block | Model | Role |
|---|---|---|
| `loop-setup` | Sonnet | User-facing wizard. Collects config, writes `loop.yaml` + `rubric.md` to `~/projects/loops/{slug}/`. Writes no bus topics. The sole authoring entry point — none of the other five create these files. `disable-model-invocation: true` — manual-only, like the classifier; a user must invoke it explicitly, not rely on natural-language auto-trigger. |
| `loop-controller` | Haiku (dispatched); uses `sonnet` alias for its own sub-dispatches | Pure state machine. Validates `loop.yaml`/briefs, bootstraps the per-session bus, dispatches the loop below in sequence, tracks `best_score`/`N`, posts the final result. No domain knowledge — never reads `target_path` content, never knows the threshold. |
| `loop-runner` | Sonnet | Executes `target_path` against `test_artifact` per the active brief (`briefs/skill.md`, `script.md`, or `test-suite.md`); posts `runner-output`. Always dispatches its own sub-agents via `claude -p`, never the Agent tool. |
| `loop-grader` | Sonnet | Scores the runner's output artifact against `rubric_path`; threshold lives in the rubric, never in `loop.yaml`. Temperature 0, 2-of-3 majority vote on borderline scores. Posts `grade`. Only dispatched when the runner posts `status: success`. |
| `loop-finding-classifier` | `claude-haiku-4-5-20251001` (version-pinned, not the `sonnet`/`haiku` alias) | Optional control-path filter, active only when `loop.yaml` sets `finding_classifier` (non-null). Scopes panel findings to the currently-failing rubric criteria (`in_scope`/`deferred`), posts `classified`. `disable-model-invocation: true` — never invoked from natural language. |
| `loop-fixer` | Sonnet | Patches `target_path` per `failures[]` (from grader or, on the classifier path, the classifier's `in_scope[]` adapted by the controller). Posts `fixed`. Runs on both the normal failed-grade path and the runner-error path. |

`finding_classifier` is a pure feature-flag path: the controller validates only its
presence/nullity, never its content, and no block reads that path's file — the
classifier's own contract declares no brief-file input. Treat it strictly as the
classifier-path on/off switch, not a content-bearing brief like `runner_brief`/`fixer_brief`.

## Interfaces

**Entry point.** `loop-setup` is the block a user actually invokes (intent: "set up a loop
to refine X"); it is the only path that creates `loop.yaml`/`rubric.md`. Like
`loop-finding-classifier`, it carries `disable-model-invocation: true` — manual-only, so
that intent must be issued as an explicit invocation, not relied on to auto-trigger from
the phrasing alone (both flags verified present in the shipped `SKILL.md` frontmatter).
`loop-controller` is dispatched with a `slug` once `loop.yaml` exists.
`loop-runner`/`loop-grader`/`loop-fixer`/`loop-finding-classifier` are never dispatched
except by the controller, mid-iteration — `loop-finding-classifier`'s own `SKILL.md`
additionally states explicitly it must not be invoked standalone.

**Bus.** All inter-block coordination goes over swarm-communication-layer
(`architecture/swarm-communication-layer.md`) — one PM2 instance per run
(`APP_NAME=swarm-mcp-${SESSION_ID}`, `DATA_DIR=/tmp/${SESSION_ID}`), torn down by the
controller's cleanup trap. `SESSION_ID = loop-${SLUG}-$(date)-$(uuid)`; it already carries
a `loop-` prefix, so every topic string below uses `{SESSION_ID}` with no additional
prefix — a doubled prefix is a topic nothing subscribes to and the controller hangs in
its `AWAIT` state forever (documented identically in all six blocks' own files).

**Identity preflight.** Before any sub-agent dispatch, the controller samples `/health`
2-3 times and requires `status: ok` **and** `app_name`/`data_dir` matching this session's
own values (swarm-communication-layer discrepancy #8) — a single `ok` response is not
proof the port belongs to this run. `loop-finding-classifier` repeats this same 2-3x
identity check before its own post. `session_id` is passed explicitly on every
send/broadcast (discrepancy #6); bus recovery is `pm2 restart`, never `reload`
(discrepancy #9) — sourced from the `swarm-communication` skill, not re-derived per
block. All five bus-posting blocks (`loop-controller`, `loop-runner`, `loop-fixer`,
`loop-finding-classifier`, `loop-grader`) restate this inline plus carry a matching
Red-flags row — `loop-grader` was the one exception until gap 5 below was resolved
(verified against the shipped `SKILL.md`, not assumed).

**Canonical bus topics** (single writer per topic per iteration, no quorum):

| Topic | Writer | Reader |
|---|---|---|
| `{SESSION_ID}-iteration-{N}-runner-output` | loop-runner | controller |
| `{SESSION_ID}-iteration-{N}-grade` | loop-grader | controller |
| `{SESSION_ID}-iteration-{N}-classified` | loop-finding-classifier | controller (classifier path only) |
| `{SESSION_ID}-iteration-{N}-fixed` | loop-fixer | controller |
| `{SESSION_ID}-iteration-{N}-regression-rollback` | controller | audit/observability only |
| `{SESSION_ID}-result` | controller | the caller that dispatched loop-controller (not loop-setup) |

**Bus post pattern.** `jq --arg` to a temp JSON file, `curl --data @file`, both
`Content-Type: application/json` and `Accept: application/json, text/event-stream`
headers, port read only from `$DATA_DIR/port` — canonical across all six blocks
(`loop-controller/references/bus-schema.md` is the source of truth; inline `-d "{...}"`
is prohibited everywhere it appears because it silently breaks on newlines/quotes in
LLM-generated `notes`/`error_detail`).

**Dispatch mechanism.** `is_subagent: true` gate: Agent tool when absent from context,
`claude -p` via Bash when present (the Agent tool silently fails inside a sub-agent).
`is_subagent: true` is appended as the last line of every downstream prompt to propagate
the mode. The bus post is the **sole** valid completion signal for every `AWAIT` state —
never stdout, exit code, env vars, or sibling files (loop-controller's Prohibited Side
Channels; a returned dispatch call with no new topic message is `EXIT_ERROR`).

## Constraints

- Sandboxing is prompt-only in all six blocks — no OS-level isolation anywhere in this
  system.
- `target_path` allowed roots: `~/projects/`, `~/.claude/skills/`, always `realpath`-
  resolved before comparison — never a tilde-string compare.
- Rubric threshold lives exclusively in `rubric.md`; a `threshold` key in `loop.yaml` is
  `VALIDATION_FAILED` at controller pre-flight.
- Concurrent loop runs against the same `target_path` corrupt each other's snapshots and
  bus state — one `target_path` per run, enforced by convention, not by the system.
- `.bak/` (outside `DATA_DIR`, survives the cleanup trap) is the sole rollback/restore
  source; `DATA_DIR/snapshots/` is audit-only and never used to restore.
- Dual-gate `EXIT_PASS` (classifier path): `grader.passed == true` AND no `Blocking`/
  `Medium` finding in `classified.in_scope[]`. No-classifier path: `grader.passed` alone.

## Settled port-time decisions and open system-consistency gaps

Verified against the shipped skill files in this worktree (not assumed from the finding
text alone). All six findings below were resolved by follow-up dispatches (see "Open
contract gaps — port-time dispositions" below) — entries here are kept as the original
gap record, now marked RESOLVED.

1. **RESOLVED — `target_path` shape (High).** Briefs in `loop-fixer`/`loop-runner`
   described `target_path` as tolerating a directory, contradicting the controller's
   single-file `cp`-based rollback. This entry's own prior "Direction" (extend rollback
   to directories) is superseded — see gap a below for the settled disposition.
2. **RESOLVED — `runner_timeout_seconds` enforcement (Medium).** Schema docs claimed a
   controller watchdog that doesn't exist in the Steps; runner had a dead self-enforcement
   instruction. See gap b below.
3. **RESOLVED — Rubric-criterion `severity` (Medium).** Collected by `loop-setup`,
   documented as gating `EXIT_PASS`, but never consumed by the dual gate. See gap c below.
4. **RESOLVED — `fixer-contract.md` Input Schema (Low).** Omitted `maps_to`, which the
   controller's dispatch actually sends. See gap d below.
5. **RESOLVED — `loop-grader` omitted the restart-vs-reload/escalate discipline inline
   (Medium).** The other four bus-posting blocks restate it inline plus a matching
   Red-flags row; `loop-grader/SKILL.md` step 6 had only a passing cross-reference. See
   gap 5 below.
6. **RESOLVED — `--dangerously-skip-permissions` propagation to nested `claude -p` calls
   was undocumented (Low).** Only the controller's own dispatch example carried the flag;
   whether nested sub-agent calls should inherit it was unstated. See gap 6 below.

## Open contract gaps — port-time dispositions

- **Gap a — `target_path` single-file contract (High).** Disposition: fixed — closed-by-you.
  Reworded the four directory-tolerant spots (`loop-fixer/briefs/skill.md`, `briefs/code.md`,
  `loop-runner/briefs/script.md`, `loop-runner/briefs/skill.md`) to state `target_path`
  names a single file, matching `loop-controller/SKILL.md`'s Security section and the
  plain-`cp` (no `-r`) rollback mechanism in `state-machine.md`. Added an explicit caveat
  that companion files a brief may still need to edit (references/briefs/rubrics for
  skills; sibling source files for code) live alongside `target_path` but are not
  themselves snapshotted or rolled back — a stated fact, not a silent gap. Also corrected
  `loop-runner/briefs/script.md`'s `target_path`/`test_artifact` framing (previously had
  `test_artifact` picking a script *within* a `target_path` directory, inconsistent with
  `loop-yaml-schema.md`'s own generic `test_artifact` definition and with the `skill`
  brief's pattern) and added a `target_path` note to `loop-yaml-schema.md` cross-referencing
  all four briefs. Principle: security contradictions take the stricter reading.
- **Gap b — `runner_timeout_seconds` enforcement ownership (Medium).** Disposition: fixed —
  closed-by-you. Confirmed via `state-machine.md`'s `AWAIT_RUNNER` row that no
  bus-polling watchdog implementing this field exists in the controller's Steps (only the
  Agent tool's own built-in dispatch timeout applies). Removed `loop-runner/SKILL.md` step
  9's dead self-enforcement instruction (the runner never receives this field per
  `loop-yaml-schema.md`'s own consumption table) and corrected `loop-yaml-schema.md`'s and
  `bus-schema.md`'s overstated "controller watchdog" claims to "declared but not currently
  enforced (port-time note)." Principle: the executing skill's Steps are ground truth.
- **Gap c — rubric criterion `severity` unconsumed (Medium).** Disposition: fixed —
  closed-by-you. Added a port-time note to `rubrics/default.md`'s Severity Labels table
  (the declaration site) stating that criterion-level `severity` is authoring/documentation
  metadata only — `grade-contract.md` never consumes it, and EXIT_PASS is gated solely by
  `grader.passed` plus, on the classifier path, `classified.in_scope[].severity` (a
  separate, classifier-owned field). Principle: unconsumed validated fields get a
  "declared but not currently consumed" note at the declaration site.
- **Gap d — `fixer-contract.md` Input Schema missing `maps_to` (Low).** Disposition:
  fixed — closed-by-you. Added `maps_to: string | null  # classifier-active only` to the
  Input Schema block, matching the same file's Transformation Note and the controller's
  actual classifier-to-fixer adapter (`state-machine.md`). Principle: incomplete schemas
  completed to match the dispatcher.
- **Gap 5 — `loop-grader` omitted the restart-vs-reload/escalate discipline inline.**
  Disposition: fixed — added the same "if the post itself fails... escalate to your
  orchestrator instead" paragraph after `loop-grader/SKILL.md` step 6 and a matching
  Red-flags row (`skills/loop-grader/SKILL.md:104-110,168`), for parity with
  loop-runner/loop-fixer/loop-controller/loop-finding-classifier. Principle (1): ground
  truth is what the executing skill's Steps instruct — the other four blocks' inline
  restatement is the pattern being matched, not the reference-only cross-link.
- **Gap 6 — `--dangerously-skip-permissions` propagation was undocumented.** Disposition:
  fixed — documented explicitly in `skills/loop-controller/references/agent-roles.md:26-37`
  that the flag is controller-only, a top-level human-attended dispatch convenience not
  meant to propagate to nested `claude -p` calls in loop-runner/loop-fixer/loop-grader,
  which already run non-interactively under `is_subagent: true`. No flag was added to
  the nested examples. Principle (5): one line per gap recording the disposition and the
  principle applied — this entry, plus the settled-decisions item 6 above it, are that
  record for this gap.

## Provenance

Lineage: X-context-docs `skills/loop-*@0e9281e` (all six blocks, this wave).
Cross-link: `architecture/swarm-communication-layer.md` — the bus this system runs on;
identity-preflight discrepancies #6/#8/#9 referenced above are defined there.
