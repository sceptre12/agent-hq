# Composing and scoring a ticket body

## Source

`drafts/<slug>.md` was written from the ticket template (`skills/delivery-architecture/references/templates/ticket.md`, part-04 §5.1). Its YAML front matter carries exactly `slug`, `issuetype`, `parent` (part A.6; `parent` is the parent's slug, `-` for the epic). The clerk does not invent content; it maps the draft onto the request fields.

## Sections of the description

Header (issue type, team, epic link, priority, requested by), Summary, Problem (background, current, expected, evidence), Impact, Business value, Requirements (functional; non-functional), Acceptance criteria as Gherkin (happy, failure or edge, observability), Dependencies, Risks, Subtasks. An epic adds phases, dependency map, typed children, spikes first and timeboxed, open questions. A missing section is repaired from the draft or reported as a draft defect; the clerk never fills it with guesses.

## Field mapping (closed allowlist)

The nested `fields` map takes keys only from the part B4 allowlist `summary, description, issuetype, parent, labels, priority, components`, with string or string-array values.

| Field | Value |
|---|---|
| `summary` | the draft's Summary line (one line) |
| `description` | the sections above, as one string |
| `issuetype` | the front matter `issuetype` |
| `parent` | not in the nested map for a create; the request's top-level `parent` carries the parent's KEY (see below) |
| `labels` | array, each element `^[A-Za-z0-9._:-]+$` (part B4), when the draft names labels |
| `priority` | the header priority |
| `components` | array, when the draft names components |

Nothing else is sent. Ids are Jira-assigned; plans and drafts use the slug until `tickets.tsv` holds a key. The agent-only sections of a draft (scope globs, persona and tier, blocked-by, lanes, done token, verifier) stay in the draft unless the template places them in the description.

Required and optional fields (part B4 `jira-create` row and D3 "Ticket parents", AM-4 22; formerly OQ-22-2): apart from `summary` and `issuetype` every allowlisted field is optional, and the top-level `parent` is the only parent carrier, never a `fields` entry (a non-Epic create without it is `schema`, part B9). This skill sends `summary`, `description`, `issuetype` always, `priority` when the header has one, `labels` and `components` only when the draft names them, and carries the parent only as the top-level `parent`.

## Request files

The file given to `desk-req.sh` is the B4 verb object (part B3 puts it under the envelope `fields`).

Child (`issuetype` not `Epic`; part B4: `parent` present exactly then, typed `JIRA-KEY`):

```json
{"parent": "PROJ-1", "fields": {"summary": "...", "description": "...", "issuetype": "Story", "priority": "..."}}
```

Epic (no `parent`):

```json
{"fields": {"summary": "...", "description": "...", "issuetype": "Epic", "priority": "..."}}
```

`PROJ-1` stands for the `key` column of the parent's latest row in `tickets.tsv`; never the slug. Update: `{"key": "<KEY>", "fields": {<changed allowlist keys only>}}`. Transition: `{"key": "<KEY>", "to": "<canonical status or archive>"}`. Read: `{"key": "<KEY>", "fields": ["summary", "description", ...]}`.

## Scoring

Invoke `jira-ticket-quality` on the composed description. Pass: send. Fail: repair from the draft, re-score; after 3 rounds stop and report the draft slug (this cap is the skill's own rule, not an owner ruling). The skill is not installed on every machine; if it is absent, send nothing, write `jira-ticket-quality missing: move defect` and stop.

## Redaction

The desk refuses a body, payload or attachment with a redaction hit (`REJECTED policy`, terminal). Compose without tokens, credentials or private paths so the hit does not occur.

## Parent re-fetch

The desk re-fetches the parent before it writes a create (part B4 `jira-create` row). A parent that cannot be resolved by the desk is a rejection to report, not to work around.
