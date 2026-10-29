# Jira Ticket Template

Use this template when creating new Jira tickets. Fill in all sections — omit sections only if genuinely not applicable.

```markdown
# Ticket Name: <Clear, concise, outcome-focused title>

**Issue Type:** <Epic | Story | Subtask | Bug>  
**Team:** <Team Name>  
**Epic Link:** <Epic Name or Link (if applicable)>  
**Priority:** <Critical | High | Medium | Low>  
**Reporter:** Xavier Thomas  
**Requested By:** <Channel / Team / Stakeholders>

---

## Summary

<1–3 sentence high-level summary of the issue or feature. Focus on WHAT and WHY, not HOW.>

---

## Problem Description

<Detailed explanation of the current problem or gap. Include all relevant context.>

- Background:
  - <Relevant system, feature, or workflow context>
  - <Links to docs, Slack threads, incident reports, dashboards>

- Current Behavior:
  - <Describe exactly what is happening today>

- Expected Behavior:
  - <Describe what should happen instead>

- Evidence / References:
  - <Links to logs, Dynatrace, GitHub Actions, PRs, screenshots, etc.>

---

## Impact

- <Who is impacted (teams, users, systems)>
- <What is blocked or degraded>
- <Frequency / severity if known>
- <Any workarounds currently in use>

---

## Business Value

<Explain why this matters in business/product terms.>

- Improves <developer productivity / reliability / performance>
- Reduces <failures / incidents / manual effort>
- Enables <new capability or scalability>
- Protects <revenue / SLAs / customer experience>

---

## Requirements

### Functional Requirements

1. <Top-level requirement>
   - <Sub requirement>
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

---

## Acceptance Criteria (Gherkin Format)

### Scenario 1: <Happy path>

**Given** <initial state>  
**When** <action taken>  
**Then** <expected result>  
**And** <additional validation>

---

### Scenario 2: <Failure case / edge case>

**Given** <bad or edge condition>  
**When** <action>  
**Then** <system responds correctly>  
**And** <clear error/logging is provided>

---

### Scenario 3: <Observability / validation>

**Given** <event occurs>  
**When** <system processes event>  
**Then** <logs/metrics are emitted correctly>  

---

## Dependencies

- <Upstream services / APIs>
- <Pipelines (GitHub Actions / Harness)>
- <Infra (AWS, Terraform, OpenTofu)>
- <Other teams / approvals>

---

## Risks / Considerations

- <Potential regression risks>
- <Migration concerns>
- <Feature flags required?>
- <Rollback strategy>

---

## Subtasks

1. <Subtask Name>
   - <Specific work to be completed>
   - <Files / systems to modify>
   - <Validation steps>

2. <Subtask Name>
   - <Details>

---

## Definition of Done

- [ ] Code implemented
- [ ] Unit / integration tests added
- [ ] Verified in non-prod (RGR / staging)
- [ ] Observability confirmed (logs + metrics)
- [ ] Documentation updated
- [ ] No regressions introduced
- [ ] Feature flag (if applicable) validated

---

## Notes / Open Questions

- <Anything still unclear or needing decisions>
- <Follow-ups or future improvements>

---

## Links

- <Architecture Docs>
- <GitHub PRs>
- <Slack Threads>
- <Dashboards / Monitoring>
```
