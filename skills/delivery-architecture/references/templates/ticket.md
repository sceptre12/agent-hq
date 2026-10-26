# Template: epic and child ticket draft (design 5.1)

Purpose: the local draft of one Jira ticket, written before H1 and published after H1 ACCEPT. One file per ticket at `plans/<epic>/drafts/<slug>.md`; `drafts/index.md` line 1 is `DRAFTS: <n> drafts` (INTERFACES D1.1; `index` is a reserved slug).

**Writer / Reader:** writer `delivery-architecture` (stage 2, card 3); readers `ticket-clerk` (publishes through the desk in dependency order, only after `H1.ok`), `delivery-dispatch-plan` (reads Agent additions to build `.tasks/`), the human at H1.

## Rules
- The file opens with YAML front matter and nothing before it.
- `slug`: `^[a-z0-9][a-z0-9-]*$`, never `index`, equal to the file stem (INTERFACES A.1).
- `issuetype`: one of `Epic`, `Spike`, `Story`, `Task`, `Subtask` (INTERFACES D2.1, "ticket issue type"). Spikes come first in the dependency order and are timeboxed.
- `parent`: the parent ticket slug, or `-` for the epic (the `-` absence token, INTERFACES A.6 `tickets.tsv`).
- Jira `fields` that reach the desk are the closed set `summary, description, issuetype, parent, labels, priority, components` (INTERFACES B4). Everything below the front matter is the `description`.
- Statuses are the canonical set in INTERFACES D3 (`Backlog`, `In Progress`, `In Review`, `Blocked`, `Verified`, `Done`); a draft never sets one.
- Acceptance criteria are Gherkin and also seed the `.feature` files (design 3.6). Keep one scenario per behaviour.
- Dates are `YYYY-MM-DD`. A value not yet known is written `FILL_IN_BEFORE_DISPATCH`, never guessed.

## Skeleton

````markdown
---
slug: <slug>
issuetype: <Epic|Spike|Story|Task|Subtask>
parent: <parent-slug or ->
---
# <Clear, outcome-focused ticket name>

**Team:** <team>
**Epic link:** <epic slug or key; omit on the epic itself>
**Priority:** <the Jira project's priority name; Critical|High|Medium|Low is a template-local example, not an INTERFACES enum (B4 only allows the `priority` field)>
**Requested by:** <channel, team or stakeholder>

## Summary
<1 to 3 sentences: WHAT and WHY, not HOW.>

## Problem
- Background: <system, feature or workflow context; links to docs, threads, dashboards>
- Current behavior: <exactly what happens today>
- Expected behavior: <what should happen instead>
- Evidence: <logs, CI runs, PRs, screenshots>

## Impact
- Who is affected: <teams, users, systems>
- What is blocked or degraded: <...>
- Frequency or severity: <if known>
- Workaround in use: <if any>

## Business value
<Why this matters in product terms: reliability, effort saved, capability enabled, risk removed.>

## Requirements
### Functional
1. <Requirement>
   - <Edge cases>
   - <Error handling>
### Non-functional
- Performance: <limit or "no change">
- Reliability: <retry, failover>
- Observability: <log fields, where visible>
- Security: <auth, secrets, roles; say if the epic is security-sensitive (architecture.md header)>
- Backward compatibility: <flows that must not break>

## Acceptance criteria
### Scenario 1: <happy path>
**Given** <state>
**When** <action>
**Then** <result>
**And** <extra check>

### Scenario 2: <failure or edge case>
**Given** <bad or edge condition>
**When** <action>
**Then** <correct response>
**And** <clear error and log>

### Scenario 3: <observability>
**Given** <event occurs>
**When** <system processes it>
**Then** <logs and metrics are emitted>

## Dependencies
- <upstream services, pipelines, infra, other teams or approvals>
- Blocked by: <slugs, or none>

## Risks
- <regression risk, migration concern, flag needed, rollback>

## Subtasks
1. <slug>: <what is built; files or systems; validation>

## Definition of done
- [ ] Code implemented
- [ ] Unit and integration tests added
- [ ] Verified in non-prod
- [ ] Observability confirmed
- [ ] Docs updated
- [ ] No regressions; flag validated if any

## Notes and open questions
- <unclear items, follow-ups>

## Links
- <architecture doc, PRs, threads, dashboards>
````

## Epic additions (only when `issuetype: Epic`)
Append after Subtasks:
````markdown
## Phases
<phase 1 .. n, each with exit condition>

## Dependency map
<text diagram: slug -> slug>

## Typed children
| slug | issuetype | blocked-by | one-line scope |
|---|---|---|---|

## Spikes (first, timeboxed)
| slug | question | timebox | decision it feeds |
|---|---|---|---|

## Open questions
<owner decisions still needed; none are guessed>
````

## Agent additions (children that become units; read by `delivery-dispatch-plan`)
Append to every child that will be built:
````markdown
## Agent fields
- Scope globs: <one per line, `- <glob>`; they are copied into `.tasks/<unit>-<slug>.md` section 3>
- Persona and tier: <persona token and tier from INTERFACES D2.1, e.g. `implementer` / `execute`>
- Blocked-by: <slugs or none>
- Lanes: <lane names or none>
- Tests: unit <yes|no + reason>; integration <yes|no + reason>; e2e <new|updated|none + reason>
- Done token: <one verifiable line>
- Verifier: <command or agent that checks the done token>
- Budget: FILL_IN_BEFORE_DISPATCH (measured median from the dispatch plan; no cost figures)
````

## Lifecycle
1. Local drafts only until the human writes `H1.ok` (INTERFACES A.2.1).
2. After `H1.ok`, `ticket-clerk` publishes in dependency order through `jira-create` and records each row in `RUN_HOME/tickets.tsv` (`slug key parent status utc`).
3. `H1.changes` returns the drafts to `delivery-architecture`; `H1.reject` stops the run.
