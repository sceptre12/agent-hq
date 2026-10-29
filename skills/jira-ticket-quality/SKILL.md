---
name: jira-ticket-quality
description: >
  Score and improve Jira ticket quality for the Web App Foundations team.
  Detects missing sections, scores against a rubric, and optionally writes
  Requirements + Migration Assessment sections back to Jira via REST.
  Triggers: "score jira tickets", "jira quality check", "run quality scan",
  "fix ticket requirements", "jira-ticket-quality".
---

# Jira Ticket Quality

## Trigger

Use when asked to score Jira ticket quality, run a quality scan, fix ticket
requirements, or any variant of "jira-ticket-quality" for the Web App Foundations team.

**Companion files (read when needed):**
- `references/phase-2-act.md` — Phase 2 per-ticket agent logic
- `references/rubric.md` — Scoring tables + canonical template
- `references/db-queries.md` — Exact sqlite3 queries
- `references/jira-write.md` — Jira REST auth + write patterns

## Steps

1. **Pre-flight checks** — run both before any phase; halt on failure.
   - **Session token check:** shell out to the shared atlassian-auth CLI rather than
     decoding the session JWT inline:
     ```bash
     cd ~/projects/atlassian-auth && npm run --silent cli -- status
     ```
     Prints `FRESH` or `STALE` plus the expiry date; exits 0 if fresh, 1 if stale or
     missing. If `STALE` (or the session file is missing): print `Session token expired
     — run: cd ~/projects/atlassian-auth && npm run bootstrap` and **halt**.
   - **DB check:**
     ```bash
     test -f ~/.jira-scraper/data.db && echo "DB_OK" || echo "DB_MISSING"
     ```
     If `DB_MISSING`: print `~/.jira-scraper/data.db not found — run the jira scraper
     first.` and **halt**.

2. **Route by mode.** Inspect the invocation flags:

   | Flag | Action |
   |---|---|
   | `--score-only` | Phase 1 only → print report → stop |
   | `--act-only` | Phase 2 only (query Needs-Requirements tickets from DB, skip scoring) |
   | `--report` | Phase 3 only (re-score + diff vs baseline) |
   | _(no flag)_ | Phase 1 → checkpoint → Phase 2 → Phase 3 |

3. **Phase 1 — Score.** Query tickets and epics for the team, score each against the
   rubric, and print the report.

   Query tickets:
   ```bash
   sqlite3 ~/.jira-scraper/data.db \
   "SELECT key, summary, description, type, status, labels
    FROM tickets
    WHERE team = 'Web App Foundations'
    AND status NOT IN (
      'Done','Closed','Cancelled','Rejected',
      'Won''t Do','Wont Do',
      'In Progress','In Review','Review','QA')
    AND description IS NOT NULL;"
   ```
   Query epics:
   ```bash
   sqlite3 ~/.jira-scraper/data.db \
   "SELECT key, summary, description, status, labels
    FROM epics
    WHERE team = 'Web App Foundations'
    AND status NOT IN (
      'Done','Closed','Cancelled','Rejected',
      'Won''t Do','Wont Do',
      'In Progress','In Review','Review','QA')
    AND description IS NOT NULL;"
   ```

   Score each ticket — full tables in `references/rubric.md`:

   **Stories / Bugs (100 pts):** detect sections via case-insensitive `## Section`
   heading regex.

   | Section | Max pts | Rule |
   |---|---|---|
   | Problem Description | 25 | 0=absent, 10=present <150 chars body, 25=present ≥150 chars |
   | Acceptance Criteria | 25 | 15=section present, +10 if description contains `Given` AND `When` AND `Then` |
   | Functional Requirements | 20 | 0=absent, 20=present (`## Requirements` OR `### Functional Requirements`) |
   | Business Value | 15 | 0=absent, 15=present |
   | Impact | 10 | 0=absent, 10=present |
   | Dependencies | 5 | 0=absent, 5=present |

   **Epics (100 pts):**

   | Section | Max pts | Rule |
   |---|---|---|
   | Problem Description / Goal | 25 | 0=absent, 10=thin <150 chars, 25=substantive (headings: `## Problem Description`, `## Goal`, `## Overview`, `## Description`) |
   | Acceptance Criteria | 20 | 12=present, +8 if Gherkin detected |
   | Business Value | 20 | 0=absent, 20=present |
   | Scope & Boundaries | 20 | 0=absent, 20=present (`## Scope`, `## Scope & Boundaries`, `## Scope and Boundaries`) |
   | Success Metrics / KPIs | 10 | 0=absent, 10=present (`## Success Metrics`, `## KPIs`, `## Metrics`) |
   | Dependencies | 5 | 0=absent, 5=present |

   **Health color:** green ≥70 \| yellow 40–69 \| red <40. **Gaps list:** name of every
   zero-scoring section for that ticket.

   Output format:
   ```
   === Jira Ticket Quality Report ===
   Team: Web App Foundations
   Scanned: {N} tickets + {M} epics

   RED ({count}):
     FOUND-NNN [Story] "Summary text" — score: 23/100 — gaps: Problem Description, Acceptance Criteria, Business Value

   YELLOW ({count}):
     FOUND-NNN [Epic] "Summary text" — score: 55/100 — gaps: Scope & Boundaries, Success Metrics

   GREEN ({count}):
     FOUND-NNN [Story] "Summary text" — score: 85/100

   Needs-Requirements (act candidates): {count} red/yellow tickets with Needs-Requirements label
   ```

   Save baseline to `/tmp/jira-quality-baseline.json` — array of `{key, score, color, gaps}`.

4. **Checkpoint.** After printing the report, print:
   ```
   --- CHECKPOINT ---
   {N} tickets ready for Phase 2 (Red/Yellow with Needs-Requirements label).
   Type 'continue' to start Phase 2, or 'stop' to exit.
   ```
   Wait for user input. If `stop` (or any non-`continue` input): exit.

5. **Phase 2 — Act.** Print `Reading references/phase-2-act.md for Phase 2
   instructions.`, then read `references/phase-2-act.md` and follow it exactly
   (per-ticket wave dispatch, Requirements + Migration Assessment generation, REST
   write-back, label update).

6. **Phase 3 — Improvement Report.** Re-run Phase 1 scoring (same queries, same
   rubric). Load `/tmp/jira-quality-baseline.json`. For each ticket present in both
   sets, compute delta. Print:
   ```
   === Quality Improvement Report ===
   RED → YELLOW:   {count}
   RED → GREEN:    {count}
   YELLOW → GREEN: {count}
   Unchanged:      {count}

   Changed tickets:
     FOUND-NNN: 23 → 71 (red → green)
     FOUND-NNN: 45 → 68 (yellow → yellow, +23 pts)
   ```
   New tickets (not in baseline) are listed as `NEW` with their current score.

## Network Unavailable

This skill (including Phase 2) makes outbound network calls: Jira REST API via `curl`
to `sgwsagility.atlassian.net` (reads ticket data and writes updated
descriptions/labels).

If network connectivity is unavailable when this skill is invoked:
- Do not dispatch agents that make `curl` calls to Atlassian
- Log or echo: `[SKIPPED] network unavailable — jira-ticket-quality skipped`
- Exit 0 in script/automated contexts
- If running interactively: inform the user the quality check could not be completed and suggest retrying when connectivity is restored
- Note: session staleness (STALE signal) and network unavailability are distinct — this note covers network-level failures, not auth errors

To verify connectivity before running: use the `network-check` skill.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll skip the pre-flight checks, the session was fine earlier." | Always run both pre-flight checks before any phase; halt on failure. |
| "I'll proceed to Phase 2 without the checkpoint." | Print the checkpoint and wait for explicit `continue`/`stop` input — never auto-advance. |
| "GET returned 404, I'll retry the PUT anyway." | Log as failed and skip the PUT for that ticket; continue to the next one. |
| "migration-assessment is unavailable, I'll skip Task 2 entirely." | Use the placeholder text and still attempt the PUT — don't drop the section silently. |
| "The session went stale mid-wave, I'll finish this wave first." | Halt the entire wave immediately, print the stale-session warning, and exit Phase 2. |

## Exit criteria

- [ ] Both pre-flight checks passed (or the skill halted with the documented message).
- [ ] Phase 1's report was printed and the baseline was saved before any checkpoint.
- [ ] Phase 2, if run, processed candidates in waves of 5 with a checkpoint between
  waves, and only updated labels on tickets where the PUT returned HTTP 204.
- [ ] Phase 3, if run, computed deltas against the saved baseline, not a re-guess.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/jira-ticket-quality@9d7143e (restructured: merged
SKILL.md + SKILL-02.md into one SKILL.md entrypoint + `references/phase-2-act.md`,
per `tools/skill-porting.md` Gate 2's multi-file-source rule — the 5th such instance
after loop-controller/pr-check-migration-needed/swarm-communication/wave-execution;
trimmed the duplicated "Network Unavailable" section that appeared verbatim in both
source files down to one copy, and pointed the connectivity-check cross-reference at
the `network-check` skill instead of a work-machine-only absolute script path)

### Gate 4 fix (deviation from pinned source)

`references/jira-write.md` carried over a bug that also exists in the pinned source:
its auth section read cookies from `~/.confluence-scraper/session.json` (the
Confluence DOM-scraper's own session, unrelated to Jira REST auth), while this
SKILL.md's own Pre-flight §1 checks freshness of the **shared** `atlassian-auth`
session, and the sibling `jira` skill's write path uses
`~/.atlassian-auth/session.json` via the same shared CLI. A REST write following
`jira-write.md` as written would pull cookies from the wrong file — stale,
Confluence-scoped, and never freshness-checked by Pre-flight §1 — producing silent
401s or writes with the wrong identity. Fixed in this port by pointing
`references/jira-write.md`'s three session-file reads at
`~/.atlassian-auth/session.json`, matching the `jira` skill and this file's own
Pre-flight check. Not yet fixed upstream in `X-context-docs` — flagged for a
follow-up PR there; context-docs@9d7143e still has the stale path.
