# Composing and scoring a ticket body

## Source

`drafts/<slug>.md` was written from the ticket template (`skills/delivery-architecture/references/templates/ticket.md`, part-04 §5.1). Its YAML front matter carries exactly `slug`, `issuetype`, `parent`. The clerk does not invent content; it maps the draft onto the request fields.

## Sections of the description

Header (issue type, team, epic link, priority, requested by), Summary, Problem (background, current, expected, evidence), Impact, Business value, Requirements (functional; non-functional), Acceptance criteria as Gherkin (happy, failure or edge, observability), Dependencies, Risks, Subtasks. An epic adds phases, dependency map, typed children, spikes first and timeboxed, open questions. A missing section is repaired from the draft or reported as a draft defect; the clerk never fills it with guesses.

## Field mapping (closed allowlist)

| Field | Value |
|---|---|
| `summary` | the draft's Summary line (one line) |
| `description` | the sections above, as one string |
| `issuetype` | the front matter `issuetype` |
| `parent` | not in `fields` for a create: the request carries `parent` (a key, from `tickets.tsv`), present exactly when `issuetype` is not `Epic` |
| `labels` | array, each element `^[A-Za-z0-9._:-]+$` |
| `priority` | the header priority |
| `components` | array, when the draft names components |

Nothing else is sent. Ids are Jira-assigned; plans and drafts use the slug until `tickets.tsv` holds a key. The agent-only sections of a draft (scope globs, persona and tier, blocked-by, lanes, done token, verifier) stay in the draft unless the template places them in the description.

## Scoring

Invoke `jira-ticket-quality` on the composed description. Pass: send. Fail: repair from the draft, re-score; after 3 rounds stop and report the draft slug (D7). The skill is not installed on every machine; if it is absent, send nothing, write `jira-ticket-quality missing: move defect` and stop.

## Redaction

The desk refuses a body, payload or attachment with a redaction hit (`REJECTED policy`, terminal). Compose without tokens, credentials or private paths so the hit does not occur.

## Parent re-fetch

The desk re-fetches the parent before it writes a create. A parent that cannot be resolved by the desk is a rejection to report, not to work around.
