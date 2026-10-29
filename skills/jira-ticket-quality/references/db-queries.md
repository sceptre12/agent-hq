# DB Queries — Jira Ticket Quality

All queries use the sqlite3 CLI against `~/.jira-scraper/data.db`.
Never use Python or Node for DB reads.

---

## Phase 1 — Score all open tickets

### Stories and Bugs
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

Filters explained:
- `team = 'Web App Foundations'` — scope to this team only
- `status NOT IN (...)` — exclude terminal states and actively-worked tickets
  (in-flight tickets are unlikely to accept description appends without conflict)
- `description IS NOT NULL` — skip blank-description tickets (nothing to score)

### Epics
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

Same filters as tickets — epics use a separate table.

---

## Phase 2 — Act candidates (--act-only mode)

Query tickets that already carry the `Needs-Requirements` label and are still
open. The LIKE pattern matches the label whether it appears alone, at the
start, middle, or end of a comma-separated list.

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

---

## Utility queries

### Check a single ticket
```bash
sqlite3 ~/.jira-scraper/data.db \
"SELECT key, summary, status, labels, description
 FROM tickets WHERE key = 'FOUND-XXXX';"
```

### Count by team + status
```bash
sqlite3 ~/.jira-scraper/data.db \
"SELECT status, count(*) FROM tickets
 WHERE team = 'Web App Foundations'
 GROUP BY status ORDER BY count(*) DESC;"
```

### List all labels in use
```bash
sqlite3 ~/.jira-scraper/data.db \
"SELECT DISTINCT labels FROM tickets
 WHERE team = 'Web App Foundations'
 AND labels IS NOT NULL;"
```

### Check DB schema (verify column names)
```bash
sqlite3 ~/.jira-scraper/data.db ".schema tickets"
sqlite3 ~/.jira-scraper/data.db ".schema epics"
```

---

## Notes

- The `labels` column stores a comma-separated string (or JSON array string
  depending on scraper version). Use `LIKE '%LabelName%'` for broad matching.
  Verify schema with `.schema` if exact format is unknown.
- `last_scraped_at` column exists on tickets — check it if data seems stale.
  Tickets scraped more than 24 hours ago may have drifted from Jira truth.
- Epics do not have a `type` column — they are always epics by table membership.
