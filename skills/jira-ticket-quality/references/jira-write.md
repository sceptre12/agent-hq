# Jira REST Write Patterns — Jira Ticket Quality

Auth uses cookie-based sessions from `~/.confluence-scraper/session.json`.
All writes target `https://sgwsagility.atlassian.net`.

---

## Step 0 — Extract auth cookie

Run this before any REST call to get the cookie string and XSRF token:

```bash
COOKIE=$(python3 -c "
import json
with open('/Users/Xavier.Thomas/.confluence-scraper/session.json') as f:
    s = json.load(f)
cookies = s.get('cookies', [])
print('; '.join(f\"{c['name']}={c['value']}\" for c in cookies))
")

XSRF=$(python3 -c "
import json
with open('/Users/Xavier.Thomas/.confluence-scraper/session.json') as f:
    s = json.load(f)
cookies = s.get('cookies', [])
token = next((c['value'] for c in cookies if 'xsrf' in c['name'].lower()), '')
print(token)
")
```

Always verify freshness (SKILL.md Pre-flight §1) before using these values.

---

## Read current ticket (GET)

Fetch live ADF description before any PUT — never skip this step.

```bash
curl -s -X GET \
  "https://sgwsagility.atlassian.net/rest/api/3/issue/FOUND-XXXX" \
  -H "Cookie: $COOKIE" \
  -H "Content-Type: application/json"
```

Extract description ADF from response:
```bash
# Pipe to jq to isolate description
curl -s ... | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(json.dumps(data['fields']['description'], indent=2))
"
```

Success: HTTP 200. If 404: ticket not found — do not proceed.

---

## Append to description (PUT)

**IMPORTANT:** Jira REST API v3 uses Atlassian Document Format (ADF), not
Markdown. Never PUT a raw Markdown string.

### Pattern

1. GET current description ADF (see above).
2. Parse the `content` array from the ADF doc node.
3. Append new ADF nodes to the content array.
4. PUT the full merged ADF doc.

```bash
# Build merged ADF inline with Python then PUT
python3 << 'EOF'
import json, subprocess, sys

KEY = "FOUND-XXXX"
BASE = "https://sgwsagility.atlassian.net"
SESSION_FILE = "/Users/Xavier.Thomas/.confluence-scraper/session.json"

with open(SESSION_FILE) as f:
    s = json.load(f)
cookies = '; '.join(f"{c['name']}={c['value']}" for c in s.get('cookies', []))

# GET current description
result = subprocess.run(
    ["curl", "-s", "-X", "GET",
     f"{BASE}/rest/api/3/issue/{KEY}",
     "-H", f"Cookie: {cookies}",
     "-H", "Content-Type: application/json"],
    capture_output=True, text=True
)
issue = json.loads(result.stdout)
current_desc = issue["fields"].get("description") or {
    "version": 1, "type": "doc", "content": []
}

# Append new nodes (replace NEW_NODES with actual ADF nodes list)
NEW_NODES = [
    {"type": "heading", "attrs": {"level": 2},
     "content": [{"type": "text", "text": "Requirements"}]},
    # ... additional nodes ...
]
current_desc["content"].extend(NEW_NODES)

payload = json.dumps({"fields": {"description": current_desc}})
put_result = subprocess.run(
    ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
     "-X", "PUT", f"{BASE}/rest/api/3/issue/{KEY}",
     "-H", f"Cookie: {cookies}",
     "-H", "X-Atlassian-Token: no-check",
     "-H", "Content-Type: application/json",
     "-d", payload],
    capture_output=True, text=True
)
print(f"HTTP {put_result.stdout.strip()}")
EOF
```

Success = HTTP **204**. Any other code = failure, log the response body.

---

## Update labels (PUT)

Labels field is a **full replacement** — always include every label to keep.

```bash
# 1. GET current labels first
LABELS=$(curl -s -X GET \
  "https://sgwsagility.atlassian.net/rest/api/3/issue/FOUND-XXXX" \
  -H "Cookie: $COOKIE" | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['fields']['labels']))")

# 2. Build new labels array in Python (remove old, add new)
NEW_LABELS=$(python3 -c "
import json, sys
labels = $LABELS
labels = [l for l in labels if l != 'Needs-Requirements']
labels.append('Requirements-Review')
print(json.dumps(labels))
")

# 3. PUT new labels
curl -s -o /dev/null -w "%{http_code}" \
  -X PUT "https://sgwsagility.atlassian.net/rest/api/3/issue/FOUND-XXXX" \
  -H "Cookie: $COOKIE" \
  -H "X-Atlassian-Token: no-check" \
  -H "Content-Type: application/json" \
  -d "{\"fields\": {\"labels\": $NEW_LABELS}}"
```

Success = HTTP **204**.

---

## ADF Node Quick Reference

| Element | ADF snippet |
|---|---|
| Heading h2 | `{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"..."}]}` |
| Heading h3 | `{"type":"heading","attrs":{"level":3},"content":[{"type":"text","text":"..."}]}` |
| Paragraph | `{"type":"paragraph","content":[{"type":"text","text":"..."}]}` |
| Ordered list | `{"type":"orderedList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"..."}]}]}]}` |
| Bullet list | `{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"..."}]}]}]}` |
| Rule (divider) | `{"type":"rule"}` |
| Bold text | text node: `{"type":"text","text":"...","marks":[{"type":"strong"}]}` |
| Code inline | text node: `{"type":"text","text":"...","marks":[{"type":"code"}]}` |

---

## Error Reference

| HTTP code | Meaning | Action |
|---|---|---|
| 200 | GET success | Parse response |
| 204 | PUT/label update success | Done |
| 400 | Bad ADF payload | Log response body, fix ADF |
| 401 | Session expired | Re-run bootstrap, retry |
| 403 | Permission denied | Report to user |
| 404 | Ticket not found | Skip, log as failed |
