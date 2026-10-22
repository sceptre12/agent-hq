# panel-review — design record (ADR 0011)

One-line summary: 11 independent Sonnet agents each read an artifact cold, run
domain-specific checks, and deliberate live over the swarm bus; a 12th Sonnet
synthesizer compiles a RACI-attributed findings table — **Rung 4, the top rung**, on the
review-escalation ladder (`tools/review-ladder.md`).

## What This Is

A real (not simulated) multi-agent architecture-review panel: 11 agents each read the
artifact independently in Wave 1 (no bus reads — anchoring-avoidance is the point), post
FINDING/PASS to owned check topics, then in Wave 2 deliberate live over the swarm
communication bus (VALIDATE/CHALLENGE/ESCALATE/ADD against peer findings). A 12th
synthesizer agent reads the full bus transcript and produces a Phase B report with
severity, RACI attribution, and deliberation trails. Reserved for large architecture
docs, one-way-door decisions, and high-blast-radius artifacts where perspective
independence — not simulation — actually matters. This is the **top rung**: it points
one rung **down** to `pr-review` (Rung 3, 7-agent quorum, for a substantial code
diff/PR instead of a doc); there is no rung above it.

## Components

- `skills/panel-review/SKILL.md` (283 lines) — entrypoint: frontmatter (ladder-rung
  description, `disable-model-invocation: true`), Trigger, bus session rules, pre-flight
  inputs (artifact path, session suffix), model-routing table (Steps 1–8, up to 28
  dispatches), Steps 1–8 runbook, Red flags, Exit criteria, Provenance/Lineage footer.
- `references/agent-roles.md` (121 lines) — per-role RACI (Responsible/Consulted/
  Accountable) across `panel-check-cold-read` + `panel-check-1`…`panel-check-11`,
  including the dual-Responsible note on `panel-check-11` (both `foundations-planner`
  and `project-planner`, merged by `integration-architect`) and the Integration
  Architect's flow-scope check spec.
- `references/agent-briefs.md` (258 lines) — Wave 1/Wave 2 brief templates, posting
  protocol.
- `references/bus-schema.md` (116 lines) — canonical topic list, pipe-delimited message
  shapes, quorum rule, timeouts, session-isolation rule, bus troubleshooting.
- `references/phase-b-c-severity.md` (43 lines) — Phase B (requester decides) / Phase C
  (apply approved fixes) gate, Blocking/Medium/Advisory severity reference.
- `references/synthesizer-brief.md` (87 lines) — synthesizer instructions for the Phase
  B report; `timed_out_checks` shape `{ gate1: [...], gate2: [...] }`.
- **Symlink-installed** at `~/.claude/skills/panel-review` (created 2026-07-04 23:48, per
  ADR 0009 convention). The skill's own Step 3/5 dispatch prompts hardcode `references/*`
  paths under `~/.claude/skills/panel-review/` — these resolve for a live dispatch now
  that the symlink exists.

## Interfaces

- **Trigger surface:** `disable-model-invocation: true` — manual-only, never
  auto-invoked. Fires on "panel review," "run the panel on this," "full review,"
  "cross-role review," "bring in the panel," or any "multiple expert perspectives"
  variant on a document, spec, architecture decision, or codebase.
- **Ladder position (Rung 4, top rung):** frontmatter description states the rung
  explicitly and points **down** to `pr-review` (Rung 3, code diffs/PRs); there is no
  up-pointer — this is the ceiling of the ladder. `## Red flags` carries one ladder row
  ("big high-stakes doc, but I'll run panel-consultation myself to save bus overhead" →
  under-escalating a one-way-door/high-blast-radius artifact), satisfying
  `tools/review-ladder.md` §5's prompt-hint mechanism.
- **Required caller inputs:** artifact path (or content written to a temp file) and a
  unique session suffix (e.g. `doc-name-YYYYMMDD`) — the skill does not dispatch Wave 1
  until the artifact is confirmed readable.
- **Bus contracts it relies on** (`architecture/swarm-communication-layer.md`):
  `start_session`/`end_session` (explicit `session_id`, caller-supplied, never
  server-generated — discrepancy #1); `send_message`/`broadcast`/`read_messages` all
  take `session_id` as an optional per-call param that this skill treats as mandatory on
  every single call (discrepancy #6: nothing is ambient after `start_session` — called
  out in the SKILL.md bus-session-rules header, every step 2–8 that touches the bus,
  `bus-schema.md`'s equivalence note, and `synthesizer-brief.md` Step 0); `GET /health`
  (Step 1 boot check only, not log discovery); PM2 logs read for troubleshooting instead
  of the health-advertised `log_file` path (discrepancy #7). Port is read from
  `$DATA_DIR/port`, never hardcoded.
- **Per-review bus isolation:** each invocation starts its **own** pm2 app
  (`swarm-mcp-<SESSION_ID>`, own `DATA_DIR`, own port) rather than attaching to the
  standing `swarm-mcp` app (port 7777, per `data/port`) that other live-bus consumers
  use — same one-writer-per-DB-file rationale as the architecture record's own
  isolation design.
- **Outputs:** no file written by default. The synthesizer's Phase B report (severity
  summary, RACI findings table, deliberation trails for Blocking findings, timed-out-
  threads section split by Wave, overall verdict) is presented to the requester, who
  gates Phase C (fix application) explicitly.
- **What it points at:** `tools/review-ladder.md` (own rung + down-pointer),
  `architecture/swarm-communication-layer.md` (bus contracts, discrepancies #6/#7),
  `tools/model-routing.md` (dispatch-checklist convention), `architecture/pr-review.md`
  (Rung 3 sibling — see Cross-references).

## Constraints

- **Up to 28 dispatches per run**, each pinned to a model per Rule 3/4: Haiku for the 5
  mechanical dispatches (bus startup, start_session, Gate 1 checker, Gate 2 checker,
  cleanup), Sonnet for the 23 judgment dispatches (11 Wave 1 + 11 Wave 2 + 1
  synthesizer). No dispatch omits an explicit model pin.
- **Wave 1 independence is structural, not advisory:** the 11 agents make zero bus reads
  during Wave 1 — a Red-flags row exists specifically against letting a fast Wave 1
  agent peek at peer findings.
- **`session_id` must be passed explicitly on every single bus call** — `start_session`
  does not carry over; an omission produces an untagged row `end_session` never cleans
  up, and other agents filtering by `session_id` silently miss it.
- **Gate timeouts are fixed:** Gate 1 (`rendezvous`, 11 distinct `PHASE1_DONE`
  agent-ids) at 8 minutes; Gate 2 (`phase2-rendezvous`, 11 distinct `PHASE2_DONE`) at 10
  minutes; per-check threads at 10 minutes. Gate 1 timing out at zero signals halts the
  run; Gate 2 timing out at zero signals proceeds to the synthesizer with a warning.
- **Topic namespace is `panel-check-*`**, distinct from both `doc-reviewer`'s unrelated
  Check 1–14 taxonomy and from `pr-review`'s `pr-check-*` (same source corpus, already
  claimed) — `bus-schema.md`'s naming note gives a concrete collision example
  (`panel-check-9` = Security Engineer's domain vs. doc-reviewer Check 9 = Export
  Surface Check). Never cross-reference by bare number.
- **Bind-address guard:** Step 1 verifies the started server is listening on loopback
  (`127.0.0.1`/`::1`) via `lsof` before proceeding, matching the architecture record's
  hardcoded-loopback constraint.
- **PM2 resolution is a single source of truth duplicated at two call sites** (Step 1
  boot and Step 8 cleanup), same `PM2_BIN`-env-var-or-`which pm2` snippet — "edit both
  together if the discovery pattern ever changes," not yet factored into one script.
- **Check-ownership hotspot:** `context-designer` owns 3 checks (cold-read, 1, 7);
  `integration-architect` owns 2 (3, 4), where check 4 is the full flow-scope trace
  (producer/consumer topic-string and payload-schema comparison across
  `~/.claude/skills/`) — operators debugging a stalled review inspect these two agents
  first (SKILL.md's check-ownership note).

## Settled decisions (port-time rulings)

- **Topic-prefix disambiguation (`panel-check-*`)**, pre-committed by `pr-review`'s own
  port record specifically for this skill's eventual arrival — see Constraints;
  collision rationale lives in `bus-schema.md` itself.
- **Ladder framing added at port time.** Source predates `tools/review-ladder.md`; the
  installed artifact adds the Rung-4 frontmatter description, Trigger-section
  restatement, and the ladder Red-flags row — mirrors the same addition made to sibling
  ports `panel-consultation` and `pr-review`.
- **Model-routing table added at port time** (28-dispatch breakdown), mirroring
  `pr-review`'s 20-dispatch table — not present in the source corpus.
- **Discrepancies #6/#7 called out explicitly and repeatedly** in `SKILL.md`'s bus
  session rules, every step, `bus-schema.md`'s equivalence note, and
  `synthesizer-brief.md` Step 0 — reflecting the architecture record's live findings
  (both attributed to D5; #6 dated 2026-07-04, #7 marked "(D5, live)" without a separate
  date), not present in a source corpus that predates them.
- **Check-ownership note added at port time** (SKILL.md, after the 11-role list) — a
  port-time operator aid for debugging stalled Wave 1 runs, calling out
  `context-designer` and `integration-architect` as the heaviest-loaded agents; not
  present upstream.

## Cross-references

- `architecture/swarm-communication-layer.md` — bus component/tool contracts, port
  discovery, and discrepancies #6 (explicit `session_id`) and #7 (PM2 logs, not
  `health`'s advertised path), both load-bearing for every bus-touching step in this
  skill.
- `architecture/pr-review.md` — Rung 3 sibling one rung down; same ladder-hint
  mechanism pattern, same `*-check-*` topic-prefix disambiguation, same source corpus.
- `tools/review-ladder.md` — the ladder itself; §5 is the prompt-hint mechanism this
  record satisfies at the top rung.

## Source lineage

Lineage: X-context-docs `skills/panel-review@0e9281e`, ported via the seven-gate
pipeline (`tools/skill-porting.md`). Provenance footer as shipped in the installed
artifact: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md).
