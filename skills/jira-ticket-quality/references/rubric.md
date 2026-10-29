# Scoring Rubric — Jira Ticket Quality

Reference for Phase 1 scoring and per-ticket agents in Phase 2.

---

## Stories / Bugs Rubric (100 pts total)

Section detection: case-insensitive regex match against `## <heading>` in description.

| Section | Max pts | Detection patterns | Scoring rule |
|---|---|---|---|
| Problem Description | 25 | `## Problem Description`, `## Problem`, `## Background` | 0=absent; 10=present but body text <150 chars; 25=present and ≥150 chars of body |
| Acceptance Criteria | 25 | `## Acceptance Criteria`, `## AC`, `## Acceptance` | 15=section present; +10 if description contains `Given` AND `When` AND `Then` (Gherkin check) |
| Functional Requirements | 20 | `## Requirements`, `### Functional Requirements`, `## Functional Requirements` | 0=absent; 20=present (either heading counts) |
| Business Value | 15 | `## Business Value`, `## Value`, `## Business Case` | 0=absent; 15=present |
| Impact | 10 | `## Impact`, `## User Impact`, `## Customer Impact` | 0=absent; 10=present |
| Dependencies | 5 | `## Dependencies`, `## Depends On`, `## Blockers` | 0=absent; 5=present |

**Total: 100 pts**

---

## Epics Rubric (100 pts total)

| Section | Max pts | Detection patterns | Scoring rule |
|---|---|---|---|
| Problem Description / Goal | 25 | `## Problem Description`, `## Goal`, `## Overview`, `## Description` | 0=absent; 10=thin (<150 chars body); 25=substantive (≥150 chars) |
| Acceptance Criteria | 20 | `## Acceptance Criteria`, `## AC`, `## Acceptance` | 12=present; +8 if Gherkin keywords (`Given`, `When`, `Then`) detected |
| Business Value | 20 | `## Business Value`, `## Value`, `## Business Case` | 0=absent; 20=present |
| Scope & Boundaries | 20 | `## Scope`, `## Scope & Boundaries`, `## Scope and Boundaries` | 0=absent; 20=present |
| Success Metrics / KPIs | 10 | `## Success Metrics`, `## KPIs`, `## Metrics`, `## KPI` | 0=absent; 10=present |
| Dependencies | 5 | `## Dependencies`, `## Depends On`, `## Blockers` | 0=absent; 5=present |

**Total: 100 pts**

---

## Health Color Thresholds

| Score | Color |
|---|---|
| ≥ 70 | green |
| 40 – 69 | yellow |
| < 40 | red |

---

## Gap Identification

A gap is any section that scores 0 (absent). List the section name exactly as
it appears in the rubric (e.g. "Problem Description", "Scope & Boundaries").

Body length check: count non-whitespace characters in the text that follows the
section heading up to the next `##` heading (or end of description).

---

## Canonical Ticket Template

Use this when generating Requirements sections in Phase 2. The agent must
produce content that matches this structure for the `## Requirements` section.

```markdown
## Requirements

### Functional Requirements

1. <Top-level requirement>
   - <Sub-requirement>
   - <Edge cases>
   - <Error handling expectations>

2. <Next requirement>
   - <Details>

---

### Non-Functional Requirements

- Performance: <e.g., must not increase latency beyond X ms>
- Reliability: <e.g., must support retry / failover>
- Observability:
  - Logs must include <fields>
  - Must be visible in <Dynatrace / logging platform>
- Security: <auth, secrets, roles if applicable>
- Scalability: <expected scale, concurrency, load>
- Backward Compatibility: <must not break existing flows>
- SLA / SLO: <define or leave placeholder>
```

Full ticket template reference (for context on all sections):

```
## Summary          — 1–3 sentence WHAT + WHY
## Problem Description — detailed gap/problem with background, current/expected behavior
## Impact           — who, what blocked, frequency, workarounds
## Business Value   — business/product terms, improvements enabled
## Requirements     — Functional + Non-Functional (generated in Phase 2)
## Acceptance Criteria — Gherkin scenarios (Given/When/Then)
## Dependencies     — upstream services, pipelines, infra, other teams
## Risks / Considerations
## Subtasks
## Definition of Done
## Notes / Open Questions
## Links
```
