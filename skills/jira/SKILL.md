---
name: jira
description: Use whenever the conversation involves Jira tickets, epics, issues, or backlog/sprint work at sgwsagility.atlassian.net — not just explicit create/update/look-up requests. Triggers on a ticket-key pattern (e.g. FOUND-1234, PROJ-123), a pasted Jira URL, phrases like "under this epic", "spawn a story for", "file a bug for", "what's the status of [ticket]", or general discussion of backlog/sprint items that implies acting on a real Jira ticket. Does not trigger on casual, non-Jira uses of the words "ticket" or "issue" (e.g. raffle tickets, movie tickets, a passing complaint) — check context before invoking.
model: haiku
context: fork
agent: general-purpose
background: false
---

## Task

Jira operation requested: $ARGUMENTS

This skill runs in a forked subagent with no access to the calling conversation's
history — the line above (ticket key, epic, the exact fields/text to write, etc.) is
the only information it receives about what to do. If it is empty or underspecified for
a write operation, stop and report what's missing rather than guessing field values.

---

# Jira CRUD via REST API

## Trigger

Use whenever the conversation involves Jira tickets, epics, issues, or backlog/sprint
work at `sgwsagility.atlassian.net` — a ticket-key pattern (e.g. `FOUND-1234`), a pasted
Jira URL, "under this epic", "spawn a story for", "file a bug for", "what's the status
of [ticket]". Does not trigger on casual non-Jira uses of "ticket"/"issue" (raffle
tickets, movie tickets, a passing complaint) — check context before invoking. If it's
ambiguous whether the user wants a real Jira action performed, ask before invoking
rather than assuming.

## Overview

Always read from the local SQLite cache first. Use the Jira REST API for writes (create/update) and for tickets not in the DB. Auth for REST writes uses the **shared atlassian-auth session** — not an API token.

**DB:** `~/.jira-scraper/data.db`
**Scraper:** `~/projects/jira-scraper`
**Jira scraper's own session (DOM scraping only):** `~/.jira-scraper/session.json`
**Shared session (used for REST auth):** `~/.atlassian-auth/session.json` — see `~/projects/atlassian-auth`
**Schema contract:** `~/projects/context-docs/projects/jira-scraper/contracts/schema.md`

## Steps

1. **Check session freshness** before any REST call or scrape — shell out to the shared
   atlassian-auth CLI rather than decoding the session JWT inline:

   ```bash
   cd ~/projects/atlassian-auth && npm run --silent cli -- status
   ```

   Prints `FRESH` or `STALE` plus the expiry date; exits 0 if fresh, 1 if stale or
   missing. **If STALE — stop and tell the user:**
   > The Atlassian session has expired. Please run:
   > `cd ~/projects/atlassian-auth && npm run bootstrap`
   > Complete the SSO login in the browser, then press Enter. After that, re-run the operation.

   Do NOT proceed with REST calls on a stale session — they will silently return 401 or
   redirect to auth.

2. **Reads: query the DB first.**

   ```bash
   sqlite3 ~/.jira-scraper/data.db \
     "SELECT key, summary, status, priority, description, last_scraped_at FROM tickets WHERE key = 'FOUND-1234';"
   ```
   ```bash
   sqlite3 ~/.jira-scraper/data.db \
     "SELECT key, summary, status FROM tickets WHERE epic_id = 'FOUND-100' ORDER BY key;"
   ```
   ```bash
   sqlite3 ~/.jira-scraper/data.db \
     "SELECT key, summary FROM tickets WHERE summary LIKE '%migration%' LIMIT 10;"
   ```

   If the ticket is absent from the DB, scrape it first (requires a fresh session), then
   re-query:
   ```bash
   cd ~/projects/jira-scraper && npm run scrape -- --ticket FOUND-1234
   ```

3. **Writes: get cookies, then call the REST API.**

   ```bash
   cd ~/projects/atlassian-auth && npm run --silent cli -- cookies
   ```

   Prints a ready-to-use `Cookie: name=value; name2=value2...` header string — use its
   output as `COOKIE_STRING_HERE` in the curl commands below.

   **Create a ticket.** If setting the Team field (FOUND project), always pair it with
   Team Validation — see Known Field Gotchas below. Omitting `customfield_11144` causes
   transitions like "In Progress" to fail later.

   ```bash
   curl -s -X POST \
     "https://sgwsagility.atlassian.net/rest/api/3/issue" \
     -H "Cookie: COOKIE_STRING_HERE" \
     -H "X-Atlassian-Token: no-check" \
     -H "Content-Type: application/json" \
     -d '{
       "fields": {
         "project": { "key": "FOUND" },
         "summary": "Your summary",
         "issuetype": { "name": "Story" },
         "priority": { "name": "Medium" },
         "customfield_10001": "4fc14eca-59f9-4f5f-9128-24b7c28bd218",
         "customfield_11144": { "id": "12551" },
         "description": { "version": 1, "type": "doc", "content": [
           { "type": "paragraph", "content": [{ "type": "text", "text": "Description here." }] }
         ]}
       }
     }'
   ```

   **Update a ticket description** (GET current description first, merge, then PUT — see
   Red flags):

   ```bash
   curl -s -X PUT \
     "https://sgwsagility.atlassian.net/rest/api/3/issue/FOUND-1234" \
     -H "Cookie: COOKIE_STRING_HERE" \
     -H "X-Atlassian-Token: no-check" \
     -H "Content-Type: application/json" \
     -d '{
       "fields": {
         "description": { "version": 1, "type": "doc", "content": [
           { "type": "paragraph", "content": [{ "type": "text", "text": "Updated description." }] }
         ]}
       }
     }'
   ```

   **Update a ticket's Team field** (always update Team Validation in the same request —
   see Known Field Gotchas):

   ```bash
   curl -s -X PUT \
     "https://sgwsagility.atlassian.net/rest/api/3/issue/FOUND-1234" \
     -H "Cookie: COOKIE_STRING_HERE" \
     -H "X-Atlassian-Token: no-check" \
     -H "Content-Type: application/json" \
     -d '{
       "fields": {
         "customfield_10001": "4fc14eca-59f9-4f5f-9128-24b7c28bd218",
         "customfield_11144": { "id": "12551" }
       }
     }'
   ```

   Success = HTTP 201 (create) or 204 (update). **Delete** requires "Delete Issues"
   project permission, which Xavier's account does not have — do not attempt; inform the
   user instead.

## ADF Quick Reference

| Element | ADF type |
|---|---|
| Paragraph | `{"type":"paragraph","content":[...text nodes...]}` |
| Heading (h2) | `{"type":"heading","attrs":{"level":2},"content":[...]}` |
| Bullet list | `{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph",...}]}]}` |
| Bold text | text node with `"marks":[{"type":"strong"}]` |
| Inline code | text node with `"marks":[{"type":"code"}]` |
| Rule (divider) | `{"type":"rule"}` |

## Known Field Gotchas

**Confirmed for the FOUND (Foundations) project.** This skill is currently scoped to the FOUND project only — all field IDs below were confirmed against FOUND's `createmeta`. If this skill is ever reused against a different Jira project, re-verify the custom field IDs via `/rest/api/2/issue/createmeta?projectKeys=<KEY>&expand=projectkeys.fields` before assuming these same IDs apply — custom field IDs are per-instance but their meaning can still be project-scoped screen config, so do not copy them blind.

**Team field (`customfield_10001`, schema type `atlassian-team`) requires a bare STRING team-id on write, not a wrapped object — despite GET always rendering it back as a rich object.**

This was empirically verified via direct PUT tests against FOUND-1796 (string form) and FOUND-1798 (object form) on 2026-07-22, after two agents reported conflicting results for this field:

- Right: `"customfield_10001": "4fc14eca-59f9-4f5f-9128-24b7c28bd218"` (this UUID is the "Web App Foundations" team) — PUT to FOUND-1796 returned **HTTP 204** (accepted).
- Wrong: `"customfield_10001": { "id": "4fc14eca-59f9-4f5f-9128-24b7c28bd218" }` — PUT to FOUND-1798 returned **HTTP 400** with body `{"errorMessages":[],"errors":{"customfield_10001":"Team id 'JsonData{data={id=4fc14eca-59f9-4f5f-9128-24b7c28bd218}}' is not valid."}}`.

Do not be misled by GET responses: Jira always renders an `atlassian-team` field back as a rich object (`{"id":..., "name":..., "avatarUrl":..., ...}`) regardless of which shape was originally written. GET output is not evidence of the accepted write-shape — only a PUT/POST test (checking the HTTP status, not just re-GETting) proves it. On this instance, only the bare string is accepted for writes; the object form is rejected outright, it does not "also work."

Also note: this field cannot be set directly on a Sub-task — Jira returns `HTTP 400` with `"Issue 'X' is a subtask, and inherits the team assignment from its parent."` Sub-tasks inherit Team from their parent issue; do not attempt to PUT `customfield_10001` on a subtask.

**Team Validation (`customfield_11144`) MUST be explicitly set to `{"id": "12551"}` (the "Valid" option) any time the Team field is set — on both create and update.** Do not rely on Jira auto-populating it; in past incidents it silently did not populate, and tickets failed to transition (e.g. to "In Progress") with this exact error:

```
Please select a team.; Field Team Validation with actual value '' does not match regular expression \bValid\b
```

If you see this error on a ticket, the fix is to PUT `"customfield_11144": { "id": "12551" }` on that ticket (paired with a valid `customfield_10001`), then retry the transition.

## Ticket Template

See [ticket-template.md](./ticket-template.md) for the full template.

## Network Unavailable

This skill makes outbound network calls: Jira REST API via `curl` to `sgwsagility.atlassian.net` (reads and writes Jira tickets).

If network connectivity is unavailable when this skill is invoked:
- Do not attempt any `curl` calls to Atlassian
- Log or echo: `[SKIPPED] network unavailable — jira skipped`
- Exit 0 in script/automated contexts (do not error — launchd tracks LastExitStatus)
- If running interactively: inform the user the Jira operation could not be completed and suggest retrying when connectivity is restored
- Note: session staleness and network unavailability are distinct failure modes — this note covers network-level failures (connection refused, DNS failure, timeout before response), not auth/session errors

To verify connectivity before running: use the `network-check` skill.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll use an API token for auth." | Use the shared atlassian-auth session cookies instead — no API token is stored. |
| "I'll skip the session check, it was fresh recently." | Always check session freshness before any REST call or scrape. |
| "I'll query the REST API directly instead of the DB." | The DB is instant and offline — always check it first for reads. |
| "I'll just PUT the new description." | GET the current description first, merge, then PUT — a blind PUT overwrites it. |
| "I'll set Team without Team Validation." | Always pair `customfield_10001` with `customfield_11144: {"id":"12551"}` or later transitions fail. |
| "I'll wrap the Team field as `{"id": ...}` since GET renders it that way." | Writes require the bare string team-id — the object form is rejected with HTTP 400. |
| "The user asked for a delete, I'll try it." | Xavier's account lacks Delete Issues permission — tell the user to delete manually instead of attempting it. |

## Exit criteria

- [ ] Session freshness was checked before any REST call or scrape; a STALE session
  halted with the bootstrap instruction.
- [ ] Reads queried the DB before any network call.
- [ ] A write that sets the Team field also sets Team Validation in the same request.
- [ ] The REST response's HTTP status was checked (201/204 for success) — not just
  assumed.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/jira@9d7143e (trimmed: connectivity-check cross-reference
now points at the `network-check` skill instead of a work-machine-only absolute script
path; dropped the source's "Decision Flow" dot-graph diagram — its read-vs-write/
session-fresh-vs-stale branching is fully restated as numbered Steps 1-3, so the
diagram was redundant rather than additive, unlike query-confluence where the diagram
covers branches the Steps prose doesn't fully spell out)
