---
name: update-confluence
description: Use when any request involves writing, updating, or editing a Confluence page at sgwsagility.atlassian.net. Triggers on phrases like "update the confluence page", "write to confluence", "edit the page", "add a section to the doc", or any request to PUT content to a Confluence page ID or URL.
model: haiku
---

## Model Delegation

This skill prefers Haiku for cost efficiency. If your context contains `is_subagent: true` and you are not already running on `claude-haiku-4-5-20251001`, attempt:

```bash
claude --model claude-haiku-4-5-20251001 -p "TASK_PROMPT_HERE"
```

Check the output before returning it. If it contains an error (non-zero exit, "API Error", "not authorized", "403", or any message indicating the model call failed rather than completed the task), DO NOT return that error as your result. Instead, perform TASK_PROMPT_HERE yourself directly, in your own context, and return that result.

---

# Update Confluence Pages via REST API

## Trigger

Use when a request involves writing, updating, or editing a Confluence page at
`sgwsagility.atlassian.net` — "update the confluence page", "write to confluence", "edit
the page", "add a section to the doc", or a PUT to a Confluence page ID/URL.

## Overview

Read Confluence pages via the local SQLite cache. Write (update) via the REST API using session cookies — same session as the jira skill. Never use WebFetch for Confluence URLs.

**DB:** `~/.confluence-scraper/data.db` (reads and page ID lookups)
**Session:** `~/.atlassian-auth/session.json` (shared REST auth for writes — see `~/projects/atlassian-auth`)
**Scraper:** `~/projects/confluence-scraper`

## Steps

1. **Check session freshness** before any REST write call — shell out to the shared
   atlassian-auth CLI rather than decoding the session JWT inline:

   ```bash
   cd ~/projects/atlassian-auth && npm run --silent cli -- status
   ```

   Prints `FRESH` or `STALE` plus the expiry date; exits 0 if fresh, 1 if stale or missing.
   **If STALE — stop and tell the user:**
   > The Atlassian session has expired. Please run:
   > `cd ~/projects/atlassian-auth && npm run bootstrap`
   > Complete the SSO login in the browser, then press Enter. Re-run after.

2. **Extract cookies:**

   ```bash
   cd ~/projects/atlassian-auth && npm run --silent cli -- cookies
   ```

   Prints a ready-to-use `Cookie: name=value; name2=value2...` header string — use its
   output as `COOKIE_STRING` in the curl commands below.

3. **GET the page first** (always, before PUT) to capture the current `version.number`:

   ```bash
   curl -s "https://sgwsagility.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=version,body.storage" \
     -H "Cookie: COOKIE_STRING" \
     -H "X-Atlassian-Token: no-check" \
     | python3 -c "import sys,json; d=json.load(sys.stdin); print('Title:', d['title']); print('Version:', d['version']['number'])"
   ```

   **PUT requires `version.number` + 1.**

4. **PUT the updated page:**

   ```bash
   curl -s -X PUT \
     "https://sgwsagility.atlassian.net/wiki/rest/api/content/{PAGE_ID}" \
     -H "Cookie: COOKIE_STRING" \
     -H "X-Atlassian-Token: no-check" \
     -H "Content-Type: application/json" \
     -d '{
       "version": { "number": N_PLUS_1 },
       "title": "Exact current page title",
       "type": "page",
       "body": {
         "storage": {
           "value": "<p>Your HTML content here.</p>",
           "representation": "storage"
         }
       }
     }'
   ```

   Success = HTTP 200.

## Find a Page ID from DB

```bash
sqlite3 ~/.confluence-scraper/data.db \
  "SELECT page_id, title FROM pages WHERE title LIKE '%keyword%';"
```

## Storage Format Quick Reference

Confluence uses XHTML-like Storage Format (NOT ADF):

| Content | Storage HTML |
|---|---|
| Paragraph | `<p>text</p>` |
| Heading 2 | `<h2>text</h2>` |
| Bullet list | `<ul><li>item</li></ul>` |
| Bold | `<strong>text</strong>` |
| Inline code | `<code>text</code>` |
| Code block | `<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">bash</ac:parameter><ac:plain-text-body><![CDATA[code here]]></ac:plain-text-body></ac:structured-macro>` |

## Network Unavailable

This skill makes outbound network calls: Confluence REST API via `curl` to `sgwsagility.atlassian.net` (reads current page version and writes updated content).

If network connectivity is unavailable when this skill is invoked:
- Do not attempt any `curl` calls to Atlassian
- Log or echo: `[SKIPPED] network unavailable — update-confluence skipped`
- Exit 0 in script/automated contexts (do not error — launchd tracks LastExitStatus)
- If running interactively: inform the user the Confluence update could not be completed and suggest retrying when connectivity is restored
- Note: session staleness (stale session warning) and network unavailability are distinct — this note covers network-level failures (connection refused, DNS failure, timeout before response), not auth errors

To verify connectivity before running: use the `network-check` skill.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll build the body in ADF format." | Confluence uses Storage Format (XHTML), not ADF — see the quick reference table. |
| "I'll skip the GET and guess the version number." | PUT returns 400 without the correct `version.number`; always GET first and send current + 1. |
| "The title doesn't need to match exactly." | PUT requires the title to match the current page title exactly. |
| "I'll skip the session check, it was fresh last time." | Always check session freshness before writes — tokens expire. |
| "I'll just WebFetch the page to update it." | Use REST with session cookies only — WebFetch cannot authenticate or write. |

## Exit criteria

- [ ] Session freshness was checked before any write; a STALE session halted with the
  bootstrap instruction rather than attempting the write.
- [ ] The PUT used the GET-captured `version.number + 1` and the exact current title.
- [ ] The PUT returned HTTP 200, or a network-unavailable/stale-session halt was reported
  clearly — never a silent failure.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/update-confluence@9d7143e (trimmed: pointed the
connectivity-check cross-reference at the `network-check` skill instead of a
work-machine-only absolute script path)
