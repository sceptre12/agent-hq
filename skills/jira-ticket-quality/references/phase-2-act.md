# Phase 2 — Act: Per-Ticket Requirements Generation

Read when Phase 2 starts (routed from `SKILL.md`'s Phase 2 section).

## Input: Act-Candidates List

**If arriving from Phase 1:** use the red/yellow tickets with `Needs-Requirements`
label already identified during scoring.

**If `--act-only` flag:** query fresh from DB:
```bash
sqlite3 ~/.jira-scraper/data.db \
"SELECT key, summary, description, type, status, labels
 FROM tickets
 WHERE team = 'Web App Foundations'
 AND labels LIKE '%Needs-Requirements%'
 AND status NOT IN (
   'Done','Closed','Cancelled','Rejected',
   'Won''t Do','Wont Do',
   'In Progress','In Review','Review','QA')
 AND description IS NOT NULL;"
```

If the candidates list is empty: print `No Needs-Requirements tickets found. Nothing to do.` and stop.

## Wave Processing

Divide candidates into waves of 5. Process one wave at a time.

### Dispatch 5 agents in parallel (Agent tool)

For each ticket in the wave, spawn one agent with the prompt template below.
All 5 agents run concurrently. Wait for all 5 to complete before printing the
wave checkpoint.

### Per-ticket agent prompt template

```
You are writing requirements for Jira ticket {KEY}: "{SUMMARY}"

Current description:
{DESCRIPTION}

Auth + REST patterns are in:
~/.claude/skills/jira-ticket-quality/references/jira-write.md

Rubric and canonical template are in:
~/.claude/skills/jira-ticket-quality/references/rubric.md

## Your tasks

### Task 1 — Generate Requirements section

Using the ticket summary and existing description as context, write a
`## Requirements` section following the canonical template structure:

**### Functional Requirements**
Numbered list of concrete, testable requirements derived from the ticket
scope. Each requirement must be specific enough to verify in code or QA.
Include edge cases and error handling expectations where relevant.

**### Non-Functional Requirements**
Cover: Performance, Reliability, Security, Observability, Backwards
Compatibility. Write N/A for any that genuinely do not apply — do not omit
them silently.

### Task 2 — Migration Assessment

Invoke the `migration-assessment` skill with:
- `context_type`: `ticket_description`
- `changes_description`: the ticket summary + description
- `package_scope`: `unknown`

Capture its verdict and brief. Append the result as:

```
## Migration Script Assessment
{verdict and brief from migration-assessment}
```

If the skill is unavailable, write:
`## Migration Script Assessment\n_Assessment unavailable — run migration-assessment manually._`

### Task 3 — Append to ticket via Jira REST

Read ~/.claude/skills/jira-ticket-quality/references/jira-write.md for the
exact auth and PUT call pattern.

Steps:
1. GET current description from Jira REST to get the live ADF doc.
2. Append the Requirements section as new ADF nodes.
3. Append the Migration Script Assessment section as new ADF nodes.
4. PUT the merged ADF back. Do NOT remove or rewrite existing content.
5. Confirm HTTP 204 response.

### Task 4 — Label update (only if PUT succeeded)

Remove label `Needs-Requirements`, add label `Requirements-Review`.
Include all other existing labels unchanged.
Read jira-write.md for the label PUT pattern.

### Report back

Return a JSON object:
{
  "key": "{KEY}",
  "status": "success" | "failed",
  "sections_added": ["Requirements", "Migration Script Assessment"],
  "label_updated": true | false,
  "error": "<message or null>"
}
```

## Wave Checkpoint

After all 5 agents complete, print:
```
--- Wave {N} complete ---
  FOUND-NNN — Requirements + Migration Assessment appended
  FOUND-NNN — Requirements + Migration Assessment appended
  FOUND-NNN — FAILED: {error message}

{remaining} tickets remaining.
Type 'continue' for next wave, 'stop' to exit.
```

Wait for user input before starting the next wave.
If `stop`: exit Phase 2 cleanly (Phase 3 will still run if in default mode).

## ADF Append Pattern

When building the merged description ADF, append new sections as top-level
content nodes after the last existing node. Example structure for one section:

```json
{
  "type": "heading",
  "attrs": { "level": 2 },
  "content": [{ "type": "text", "text": "Requirements" }]
},
{
  "type": "heading",
  "attrs": { "level": 3 },
  "content": [{ "type": "text", "text": "Functional Requirements" }]
},
{
  "type": "orderedList",
  "content": [
    {
      "type": "listItem",
      "content": [{
        "type": "paragraph",
        "content": [{ "type": "text", "text": "Requirement text here." }]
      }]
    }
  ]
}
```

See `references/jira-write.md` § ADF Quick Reference for all node types.

## Error Handling

| Error | Action |
|---|---|
| GET returns 404 | Log as failed, skip PUT, continue to next ticket |
| PUT returns non-204 | Log response body as error, mark failed, do not update labels |
| migration-assessment unavailable | Use placeholder text, still attempt PUT |
| Session stale mid-wave | Halt entire wave, print stale session warning, exit Phase 2 |
