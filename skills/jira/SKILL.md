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

Default to the live Jira REST API for both reads and writes. Auth uses the **shared
atlassian-auth session** — not an API token. The local SQLite cache below exists but has
not been refreshed in months — it is not queried by default; only fall back to it if the
REST API is unreachable (see Network Unavailable), and treat anything read from it as
potentially stale.

**DB (stale, explicit-fallback only):** `~/.jira-scraper/data.db`
**Scraper:** `~/projects/jira-scraper`
**Jira scraper's own session (DOM scraping only):** `~/.jira-scraper/session.json`
**Shared session (used for all REST auth):** `~/.atlassian-auth/session.json` — see `~/projects/atlassian-auth`
**Schema contract (for the fallback DB):** `~/projects/context-docs/projects/jira-scraper/contracts/schema.md`

## Steps

1. **Check session freshness** before any REST call — shell out to the shared
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

2. **Get cookies, then filter them — do not use the raw CLI output directly.**

   ```bash
   cd ~/projects/atlassian-auth && npm run --silent cli -- cookies
   ```

   This prints the full raw session cookie jar (~12KB — dozens of SSO/analytics cookies
   picked up during the Playwright login). **Jira's REST API gateway rejects a Cookie
   header that large with a bare HTTP 400 (an Apache/Tomcat error page, not a Jira JSON
   error) — verified 2026-10-29 against both `GET /rest/api/3/issue/*` and
   `POST /rest/api/3/search/jql`, and against a write (`PUT /rest/api/3/issue/*`).**
   Jira only actually needs two of those cookies. Filter before using the output in any
   curl call below:

   ```bash
   FULL_COOKIES=$(cd ~/projects/atlassian-auth && npm run --silent cli -- cookies)
   COOKIE=$(echo "$FULL_COOKIES" | tr ';' '\n' | sed 's/^ //' \
     | grep -E '^(cloud\.session\.token|tenant\.session\.token)=' | paste -sd';' -)
   ```

   Use `$COOKIE` (the filtered ~2KB pair), never the raw `$FULL_COOKIES`, as the `Cookie`
   header value in every Jira REST call — reads and writes alike. (Confluence's REST API
   does not have this problem — the `query-confluence`/`update-confluence` skills use the
   unfiltered cookie string fine. This filtering requirement is specific to Jira's API
   gateway.)

3. **Reads: query the REST API directly.**

   Single ticket:
   ```bash
   curl -s "https://sgwsagility.atlassian.net/rest/api/3/issue/FOUND-1234?fields=summary,status,priority,description" \
     -H "Cookie: $COOKIE" -H "Accept: application/json"
   ```

   Epic children, keyword search, or any other list query — Jira Cloud retired the
   classic `GET /rest/api/3/search` (returns `410 Gone`); use the current JQL endpoint:
   ```bash
   curl -s -X POST "https://sgwsagility.atlassian.net/rest/api/3/search/jql" \
     -H "Cookie: $COOKIE" -H "Accept: application/json" -H "Content-Type: application/json" \
     -d '{"jql": "parent = FOUND-100 ORDER BY key", "fields": ["summary","status"], "maxResults": 50}'
   ```
   Swap the `jql` value for the lookup needed (`summary ~ "migration"` for a keyword
   search, `project = FOUND ORDER BY created DESC` for a recency scan, etc.).

   If a response is empty or looks wrong, re-check step 2 — an unfiltered cookie silently
   returns a non-JSON error page, not a clean failure.

4. **Writes: call the REST API** (same `$COOKIE` from step 2).

   **Create a ticket.** If setting the Team field (FOUND project), always pair it with
   Team Validation — see Known Field Gotchas below. Omitting `customfield_11144` causes
   transitions like "In Progress" to fail later.

   ```bash
   curl -s -X POST \
     "https://sgwsagility.atlassian.net/rest/api/3/issue" \
     -H "Cookie: $COOKIE" \
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
     -H "Cookie: $COOKIE" \
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
     -H "Cookie: $COOKIE" \
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
| "I'll query the local DB instead of the REST API." | The DB hasn't been refreshed in months — default to the live REST API; only use the DB as an explicit, flagged-stale fallback. |
| "I'll use the raw `cookies` CLI output as-is." | That's the full ~12KB cookie jar — Jira's gateway rejects it with a bare HTTP 400. Filter to `cloud.session.token` + `tenant.session.token` first (Step 2). |
| "I'll just PUT the new description." | GET the current description first, merge, then PUT — a blind PUT overwrites it. |
| "I'll set Team without Team Validation." | Always pair `customfield_10001` with `customfield_11144: {"id":"12551"}` or later transitions fail. |
| "I'll wrap the Team field as `{"id": ...}` since GET renders it that way." | Writes require the bare string team-id — the object form is rejected with HTTP 400. |
| "The user asked for a delete, I'll try it." | Xavier's account lacks Delete Issues permission — tell the user to delete manually instead of attempting it. |

## Exit criteria

- [ ] Session freshness was checked before any REST call; a STALE session halted with
  the bootstrap instruction.
- [ ] The cookie string was filtered to `cloud.session.token` + `tenant.session.token`
  before use in any curl call — not the raw `cookies` CLI output.
- [ ] Reads hit the live REST API by default; the local DB was only used if explicitly
  asked for, with its staleness flagged.
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
covers branches the Steps prose doesn't fully spell out).
2026-10-29: flipped reads from DB-first to REST-API-first (the DB cache hadn't been
refreshed in months, per Xavier's request). While rebuilding the read path, found and
fixed a live production bug uncovered in the process: the raw `cookies` CLI output
(~12KB) gets silently rejected by Jira's REST API gateway with a bare HTTP 400 on both
reads and writes (confirmed via a non-destructive invalid-field PUT test) — Confluence's
API doesn't have this problem, only Jira's does. Fixed by filtering to the two cookies
Jira actually needs; this also fixes the pre-existing write examples, which were silently
exposed to the same failure mode.
