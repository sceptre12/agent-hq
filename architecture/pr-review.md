# pr-review — design record (ADR 0011)

One-line summary: 7 independent Sonnet agents each read a PR diff cold, run
domain-specific checks, and deliberate live over the swarm bus; an 8th Sonnet synthesizer
compiles a RACI-attributed findings table — **Rung 3** on the review-escalation ladder
(`tools/review-ladder.md`).

## What This Is

A real (not simulated) multi-agent code-review panel: 7 agents each read the PR diff
independently in Phase 1 (no bus reads — anchoring-avoidance is the point), post
FINDING/PASS to owned check topics, then in Phase 2 deliberate live over the swarm
communication bus (VALIDATE/CHALLENGE/ESCALATE/ADD against peer findings). An 8th
synthesizer agent reads the full bus transcript and produces a Phase B report with
severity, RACI attribution, and deliberation trails. Reserved for substantial code
diffs/PRs — it is Rung 3, one rung **down** from `panel-review` (Rung 4, 11-agent quorum,
one-way-door/high-blast-radius decisions, not yet ported — pending) and one rung **up**
from `panel-consultation` (Rung 2, single-context simulated panel, no infra, used when
there's no code diff — a design/doc/idea instead).

## Components

- `skills/pr-review/SKILL.md` (319 lines) — entrypoint: frontmatter (ladder-rung
  description), Trigger, bus session rules, pre-flight inputs (`REPO`, `PR_NUMBER`),
  model-routing table (Steps 1–9), Steps 1–9 runbook, Network Unavailable section, Red
  flags, Exit criteria, Provenance/Lineage footer.
- `references/agent-roles.md` (69 lines) — per-role RACI (Responsible/Consulted/
  Accountable) across `pr-check-cold-read` + `pr-check-1`…`pr-check-9`.
- `references/agent-briefs.md` (207 lines) — Phase 1/Phase 2 brief templates, posting
  protocol, shell-injection guard.
- `references/bus-schema.md` (97 lines) — canonical topic list, pipe-delimited message
  shapes, quorum rule, timeouts, session-isolation rule.
- `references/phase-b-c-severity.md` (46 lines) — Phase B (reviewer decides) / Phase C
  (apply approved fixes) gate, Blocking/Medium/Advisory severity reference.
- `references/synthesizer-brief.md` (85 lines) — synthesizer instructions for the Phase B
  report; `timed_out_checks` shape `{ gate1: [...], gate2: [...] }`.
- Symlink-installed at `~/.claude/skills/pr-review` → `~/projects/agent-hq/skills/pr-review`
  (ADR 0009 convention).

## Interfaces

- **Trigger surface:** `disable-model-invocation: true` — manual-only, never
  auto-invoked. Fires on "review this PR," "run the panel," "check this PR," "review
  these changes," "look at this diff," or any "review before we merge" variant.
- **Ladder position (Rung 3):** description states the rung explicitly and points both
  directions — down to `panel-consultation` (Rung 2, no infra, no code diff) and up to
  `panel-review` (Rung 4, not yet ported — pending). `## Red flags` carries one ladder row
  ("big architecture doc, but pr-review is already live" → wrong rung, use
  panel-consultation/panel-review instead), satisfying `review-ladder.md` §5's prompt-hint
  mechanism.
- **Required caller inputs:** `REPO` (`owner/repo`), `PR_NUMBER` (integer) — substituted
  into the dispatch prompt before invocation; the skill does not prompt for missing
  inputs.
- **Bus contracts it relies on** (`architecture/swarm-communication-layer.md`):
  `start_session`/`end_session` (explicit `session_id`, caller-supplied, never
  server-generated — discrepancy #1), `send_message`/`broadcast`/`read_messages` (all
  take `session_id` as an **optional** per-call param that this skill treats as
  mandatory on every call — discrepancy #6: nothing is ambient after `start_session`),
  `GET /health` (used only for the Step 1 boot check, not for log discovery — discrepancy
  #7: log_file is PM2-managed, not the health-advertised path). Port is read from
  `$DATA_DIR/port`, never hardcoded.
- **Per-review bus isolation:** each invocation starts its **own** pm2 app
  (`swarm-mcp-<SESSION_ID>`) with its own `DATA_DIR`/port — it does not attach to the
  standing `swarm-mcp` app (port 7777) that other live-bus consumers use. Same rationale
  as the architecture record's own isolation design: one libSQL writer per DB file.
- **Outputs:** no file written by default. The synthesizer's Phase B report (severity
  summary, RACI findings table, deliberation trails for Blocking findings, timed-out-
  threads section, overall verdict) is presented to the reviewer, who gates Phase C (fix
  application) explicitly — no fix lands without confirmation.
- **What it points at:** `tools/review-ladder.md` (own rung + pointers),
  `architecture/swarm-communication-layer.md` (bus contracts, both discrepancies #6/#7),
  `tools/model-routing.md` (dispatch checklist convention), `tools/skill-porting.md`
  (Gate 2 refit that wrote the `pr-check-*` prefix and the ladder hints),
  `~/projects/network-check/check-network.sh` (soft dependency — not yet ported, see
  Constraints).

## Constraints

- **Up to 20 dispatches per run**, each pinned to a model per Rule 3/4: Haiku for the 5
  mechanical dispatches (bus startup, diff fetch, Gate 1 checker, Gate 2 checker, cleanup),
  Sonnet for the 15 judgment dispatches (7 Phase 1 + 7 Phase 2 + 1 synthesizer). No
  dispatch omits an explicit model pin.
- **Phase 1 independence is structural, not advisory:** the 7 agents make zero bus reads
  during Phase 1 — anchoring-avoidance is the documented reason this skill exists over a
  solo review. A Red-flags row exists specifically against letting a fast Phase 1 agent
  peek at peer findings.
- **`session_id` must be passed explicitly on every single bus call** — `start_session`
  does not carry over. This is called out four separate times in `SKILL.md` (bus session
  rules header, Steps 4/6/8/9) plus once in `bus-schema.md` and once in `agent-roles.md`'s
  header note — an omission produces an untagged row that `end_session` never cleans up
  and that `session_id`-filtered `read_messages` calls will silently miss.
- **Gate timeouts are fixed, not tunable per-run:** Gate 1 (`rendezvous`, 7 distinct
  `PHASE1_DONE` agent-ids) times out at 8 minutes; Gate 2 (`phase2-rendezvous`, 7 distinct
  `PHASE2_DONE`) at 10 minutes; per-check threads at 10 minutes. A gate timing out with
  zero signals halts the run (Gate 1) or proceeds with a warning (Gate 2) — never silently
  treated as success.
- **Topic namespace is `pr-check-*`, not the source corpus's bare `check-*`** — Gate 2
  refit decision, made because `doc-reviewer` (already installed) owns its own unrelated
  Check 1–14 taxonomy including its own "Check 7: Cold Read Gate"; the two taxonomies
  share no domain overlap but "check 7"/"the cold read check" would be genuinely ambiguous
  once both skills are installed. The same prefix convention is specified in advance for
  `panel-review` (same source corpus) if/when it ports.
- **Soft dependency, not blocking:** the Network Unavailable pre-check would point at
  `~/projects/network-check/check-network.sh`, which does not exist yet (`network-check`
  not yet ported — pending, RULING-NEEDED in `plans/dev-workspace-base-skills.md`). The
  mainline `gh`-based steps (Step 2's `gh pr diff`, Phase C's `gh pr comment`) work without
  it; only the optional connectivity pre-check is unavailable. Contract once it ships:
  exit 0 = reachable, exit 1 = unreachable.
- **PM2 resolution is a single source of truth duplicated at two call sites** (Step 1 boot
  and Step 9 cleanup) — same snippet verbatim (`PM2_BIN` env var or `which pm2` fallback),
  documented as "edit both together if the discovery pattern ever changes." Not yet
  factored into one shared script.
- **Bind-address guard:** Step 1 verifies the started server is listening on loopback
  (`127.0.0.1`/`::1`) via `lsof` before proceeding — matches the architecture record's own
  hardcoded-loopback constraint; a non-loopback bind aborts the run.

## Settled decisions (port-time rulings)

- **Topic-prefix disambiguation (`pr-check-*`)** — see Constraints; the naming note lives
  in `bus-schema.md` itself so any agent reading the schema sees the collision rationale
  without needing this record.
- **Ladder framing added at port time.** Source predates `tools/review-ladder.md`; the
  installed artifact adds the Rung-3 frontmatter description, Trigger-section restatement,
  and the ladder Red-flags row — none of this existed upstream (mirrors the same addition
  made to sibling port `panel-consultation`).
- **Model-routing table added at port time**, mirroring how `review-validator` and
  `fix-verifier` already state per-dispatch model pins — not present in the source corpus,
  added to satisfy hq Rule 3/4 at every one of the up-to-20 dispatch points.
- **`session_id`-explicit framing is a port-time emphasis, not a port-time behavior
  change.** The bus tool contracts always took `session_id` as an optional per-call param
  (architecture record, discrepancy #6/#1); what changed at port time is that `SKILL.md`
  and both reference files now state, repeatedly and explicitly, that this skill treats it
  as mandatory on every call — the source corpus's own text on this point was thinner.
- **PM2/log discrepancy #7 called out explicitly** in `SKILL.md`'s bus session rules and
  in `bus-schema.md`'s troubleshooting section — a port-time addition reflecting the
  architecture record's live finding, not present in the source corpus (which predates
  that finding).
- **Network Unavailable section's dependency left unresolved, not stubbed out.** Rather
  than inventing a local check-network shim, the Gate 2 refit recorded the gap explicitly
  (RULING-NEEDED) and specified the future contract so the soft-dependency wiring is a
  one-line swap once `network-check` ports, not a redesign.

## Cross-references

- `architecture/swarm-communication-layer.md` — bus component/tool contracts, port
  discovery, and discrepancies #6 (explicit `session_id`) and #7 (PM2 logs, not
  `health`'s advertised path), both load-bearing for every bus-touching step in this
  skill.
- `architecture/panel-consultation.md` — Rung 2 sibling; same ladder-hint mechanism
  pattern (frontmatter description + Red-flags row), same Gate 2 refit wave.
- `tools/review-ladder.md` — the ladder itself; §5 is the prompt-hint mechanism both this
  record and `panel-consultation.md`'s satisfy.

## Source lineage

Lineage: X-context-docs `skills/pr-review@0e9281e`, ported via the seven-gate pipeline
(`tools/skill-porting.md`). Provenance footer as shipped in the installed artifact:
Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md).
