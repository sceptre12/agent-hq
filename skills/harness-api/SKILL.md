---
name: harness-api
description: Use when reading Harness pipeline status, triggering a pipeline run, checking IACM workspace state, approving an IACMApproval or HarnessApproval gate, or performing any Harness operation that would normally require the Harness UI.
---

# Harness API

## Trigger

Use when reading Harness pipeline status, triggering a pipeline run, checking IACM
workspace state, approving an IACMApproval or HarnessApproval gate, or performing any
Harness operation that would normally require the Harness UI.

## Setup

Credential file: `~/.harness-scraper/credentials.json` (chmod 600)

Keys present in the file:
- `pat` — Personal Access Token
- `account_id`
- `org_id`
- `project_id`

Load all four at runtime with python3 (jq may not be available everywhere):

```bash
PAT=$(python3 -c "import json; d=json.load(open(\"$HOME/.harness-scraper/credentials.json\")); print(d['pat'])")
ACCOUNT=$(python3 -c "import json; d=json.load(open(\"$HOME/.harness-scraper/credentials.json\")); print(d['account_id'])")
ORG=$(python3 -c "import json; d=json.load(open(\"$HOME/.harness-scraper/credentials.json\")); print(d['org_id'])")
PROJECT=$(python3 -c "import json; d=json.load(open(\"$HOME/.harness-scraper/credentials.json\")); print(d['project_id'])")
```

Do NOT hardcode the PAT. Always load from credentials.json at runtime.

Token rotation: app.harness.io > My Profile > API Keys > rotate PAT > update `~/.harness-scraper/credentials.json`

---

## Network Check (Always Run First)

Before any Harness API call, verify network connectivity (see the `network-check` skill):

```bash
~/.claude/skills/network-check/scripts/check-network.sh
```

- Exit 0 = network up, proceed with API calls
- Exit 1 = skip all Harness API calls, report "network unavailable — Harness API skipped"
- Any other exit code (e.g., 127 = script missing) = network status unknown. Fall back to a single direct probe — `curl -sf -m 5 -o /dev/null https://app.harness.io` — and proceed only if it succeeds; otherwise treat as network unavailable.

---

## Base curl Patterns

Two reusable shell functions. Define these before running any operation below.

```bash
# GET with x-api-key header and scope params appended to the URL
harness_get() {
  local url="$1"
  curl -s -X GET \
    -H "x-api-key: ${PAT}" \
    -H "Content-Type: application/json" \
    "${url}&accountIdentifier=${ACCOUNT}&orgIdentifier=${ORG}&projectIdentifier=${PROJECT}"
}

# POST with x-api-key header and scope params; $2 is the JSON body string
harness_post() {
  local url="$1"
  local body="$2"
  curl -s -X POST \
    -H "x-api-key: ${PAT}" \
    -H "Content-Type: application/json" \
    -d "${body}" \
    "${url}&accountIdentifier=${ACCOUNT}&orgIdentifier=${ORG}&projectIdentifier=${PROJECT}"
}
```

For IACM endpoints the scope params differ — see Operations 6 and 7.

Convention: angle-bracket values (`<...>`) in code blocks are placeholders — always substitute a real value before executing. For example, `"<pipelineIdentifier>"` must be replaced with an actual pipeline identifier string.

## Steps

1. **Run the Network Check** (above) before any Harness API call.
2. **Pick the operation** that matches the task, from `references/operations.md`:

   | # | Operation | Side-effecting? |
   |---|---|---|
   | 1 | List Pipelines | No |
   | 2 | Trigger Pipeline | Yes — run the Prod Boundary guard first |
   | 3 | Get Execution Status | No |
   | 4 | List Recent Executions | No |
   | 5 | Approve a Gate | Yes — run the Prod Boundary guard first |
   | 6 | List IACM Workspaces | No (raw curl, not `harness_get`/`harness_post` — see note in `references/operations.md`) |
   | 7 | Create IACM Workspace | Yes — run the Prod Boundary guard first; GENERATOR-FIRST warning applies |

3. **For a side-effecting operation** (2, 5, 7), run the Prod Boundary runtime guard
   (below) immediately before the call.
4. **After triggering a pipeline** (Op 2), follow the Validation Flow below to poll to
   a terminal status.
5. **For an approval gate** (Op 5), follow the Approval Gate Pattern below for the full
   list → extract → action flow.
6. **On any error**, check the Error Reference below before treating it as unexpected.

## Nonprod Pipeline Reference

Confirmed via Op 1 (List Pipelines) as of 2026-06-29. Re-run Op 1 to verify before use — if identifiers differ from this table (e.g., a newer version suffix), confirm with the user before triggering.

| Identifier | Purpose |
|---|---|
| `foundations_iac_workspace_provision_v1` | Provision IAC workspace |
| `foundations_iac_workspace_destroy_v1` | Destroy IAC workspace |
| `foundations_iac_build_and_quality_check_v1` | IAC PR quality check |
| `bff_setup_phase_1` | Initial BFF setup |
| `foundations_bff_scaffold_v1` | Scaffold new BFF |
| `foundations_bff_pr_merge_deployment_v1` | Nonprod deploy on merge |
| `Proof_MFE_CI_PR_Build_Quality_v2` | MFE PR quality check |
| `Proof_MFE_CI_PR_Standardization_Checks_v2` | MFE PR standardization |
| `Proof_MFE_CI_PR_Nx_Sonar_Scan_v2` | MFE PR Sonar scan |

---

## Workspace Identifier Formula

Pattern: `{workspace_prefix}_{env}_{bff_name_snake_case}`

- `workspace_prefix` — the product/domain slug for the consuming app (e.g., `cust_on_web` for Customer On-Web). Assigned by DevOps at workspace onboarding. Check existing workspaces via Op 6 List IACM Workspaces to find the prefix for an existing product, or confirm with the workspace owner.
- `env` — deployment environment, e.g. `dev`, `staging`, `prod`
- `bff_name_snake_case` — the BFF service name in snake_case, e.g. `auth_bff`

Example: `cust_on_web_dev_auth_bff`

---

## Validation Flow — Poll After Trigger

After triggering a pipeline:

1. Extract `planExecutionId` from the trigger response (`data.planExecution.uuid`)
2. Poll the status endpoint every 10 seconds
3. Continue while `status == "Running"`
4. Terminal outcomes: `"Success"` = good, `"Failed"` / `"Expired"` / `"Aborted"` = investigate

Shell polling loop:

```bash
MAX_POLLS=60   # 10 minutes at 10s intervals
POLL_COUNT=0

while [ $POLL_COUNT -lt $MAX_POLLS ]; do
  STATUS_RESPONSE=$(harness_get \
    "https://app.harness.io/pipeline/api/pipelines/execution/${PLAN_EXECUTION_ID}?")

  EXEC_STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d['data']['pipelineExecutionSummary']['status'])
except Exception:
    print('PARSE_ERROR')
")

  echo "[$POLL_COUNT] Status: $EXEC_STATUS"

  case "$EXEC_STATUS" in
    "Running"|"NotStarted")
      POLL_COUNT=$((POLL_COUNT + 1))
      sleep 10
      ;;
    "Success")
      echo "Pipeline completed successfully."
      break
      ;;
    "Failed"|"Expired"|"Aborted")
      echo "Pipeline ended with status: $EXEC_STATUS"
      FAIL_MSG=$(echo "$STATUS_RESPONSE" | python3 -c "
import json, sys
d = json.load(sys.stdin)
info = d['data']['pipelineExecutionSummary'].get('failureInfo', {})
print(info.get('message', 'no failure message'))
")
      echo "Failure message: $FAIL_MSG"
      break
      ;;
    "PARSE_ERROR")
      echo "Could not parse status response (API error or malformed JSON) — stopping poll. Raw response:"
      echo "$STATUS_RESPONSE"
      break
      ;;
    *)
      echo "Unknown status: $EXEC_STATUS — stopping poll"
      break
      ;;
  esac
done

if [ $POLL_COUNT -ge $MAX_POLLS ]; then
  echo "Polling timed out after $MAX_POLLS attempts (10 minutes)."
fi
```

---

## Approval Gate Pattern

Full flow for IACMApproval or HarnessApproval gates:

Step 1 (list) is read-only. Steps 2–3 lead to a side-effecting POST — run the Prod Boundary runtime guard (see below) before Step 3.

```bash
# Step 1 — List all pending approvals in the project
APPROVALS=$(curl -s -X GET \
  -H "x-api-key: ${PAT}" \
  "https://app.harness.io/pipeline/api/approvals?accountIdentifier=${ACCOUNT}&orgIdentifier=${ORG}&projectIdentifier=${PROJECT}&approvalStatus=WAITING")

# Step 2 — Extract the approvalInstanceId (first pending item)
APPROVAL_ID=$(echo "$APPROVALS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
items = d['data']['content']
if not items:
    print('NO_PENDING')
else:
    print(items[0]['approvalInstanceId'])
")

if [ "$APPROVAL_ID" = "NO_PENDING" ]; then
  echo "No pending approvals found."
  exit 0
fi

# Step 3 — Approve (or REJECT — change action value)
curl -s -X POST \
  -H "x-api-key: ${PAT}" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"APPROVE\",\"comments\":\"Approved via harness-api skill\"}" \
  "https://app.harness.io/pipeline/api/approvals/${APPROVAL_ID}/action?accountIdentifier=${ACCOUNT}&orgIdentifier=${ORG}&projectIdentifier=${PROJECT}"
```

If the project has multiple approval gates in flight, filter `content[]` by `pipelineIdentifier` before extracting the approval ID. Use this pattern instead of the single-item extract above:

```bash
TARGET_PIPELINE="<pipelineIdentifier>"

APPROVAL_ID=$(echo "$APPROVALS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
items = d['data']['content']
matched = [i for i in items if i.get('pipelineIdentifier') == '$TARGET_PIPELINE']
if not matched:
    print('NO_PENDING')
else:
    print(matched[0]['approvalInstanceId'])
")
```

Replace `<pipelineIdentifier>` with the identifier from the Nonprod Pipeline Reference table or from Op 1 List Pipelines.

---

## Prod Boundary

Prod pipeline identifiers are NOT included in this skill. To discover them:

1. Use List Pipelines (Operation 1) against the prod project
2. Confirm the exact identifier with the user before triggering
3. Never perform a side-effecting operation (trigger a pipeline, approve/reject a gate, create a workspace) with "prod" scope without explicit user confirmation

**Prod scope definition:** A project is considered prod-scoped if `project_id` loaded from credentials.json contains the substring `prod` (case-insensitive), or is one of the known prod project identifiers: `Proof_Web_Prod`, `ProofWebProd`.

**Runtime guard — run this after loading credentials, before any side-effecting operation (Op 2 trigger, Op 5 approve/reject, Op 7 create workspace):**

```bash
if echo "${PROJECT}" | grep -qi "prod"; then
  echo "HALT: credentials.json points at a prod project (${PROJECT}). Explicit user confirmation required before any side-effecting operation."
  exit 1
fi
```

Read-only operations (Op 1, 3, 4, 6, and the approval *list* in Op 5 Step 1) do not require the guard.

If credentials.json does not match the pattern but you suspect a prod context, confirm with the user before proceeding.

**Unattended runs (no human reachable):** Every "confirm with the user" requirement in this skill is a hard gate, and its fail mode is BLOCK, not proceed. If this skill is running unattended (automated pipeline, scheduled job, agent with no human in the loop) and a confirmation point is reached, abort that operation cleanly: report which operation was blocked and why, and exit non-zero. Never proceed on the assumption that confirmation would have been granted, and never wait or poll for input that cannot arrive — the runtime guard above already behaves this way (immediate `exit 1`, no interactive prompt, cannot hang). Apply the same abort-and-report behavior to every other confirmation point in this skill (pipeline-identifier drift in the Nonprod Pipeline Reference, suspected-prod contexts that don't match the grep pattern, and API-direct workspace creation without DevOps authorization in Op 7).

---

## Error Reference

**Invalid Token:**
```json
{ "code": "INVALID_TOKEN", "status": "FAILURE", ... }
```
Fix: app.harness.io > My Profile > API Keys > rotate PAT > update `~/.harness-scraper/credentials.json`

**Resource Not Found (approval action):**
```json
{ "status": "FAILURE", "code": "RESOURCE_NOT_FOUND_EXCEPTION", "message": "HTTP 404 Not Found" }
```
Cause: `approvalInstanceId` does not exist or the approval was already actioned.

**Invalid filterType (execution summary):**
HTTP 400 — `"Unable to process JSON / Could not resolve type id 'ExecutionType'"`
Fix: Use `"PipelineExecution"` as the filterType, not `"ExecutionType"`.

**CREATE workspace validation error:**
```json
{ "name": "missing_field", "message": "<field> is missing from body; ..." }
```
Fix: Ensure all six required fields are present (identifier, name, provider_connector, provisioner, terraform_variables, environment_variables).

**Network unavailable:**
`~/.claude/skills/network-check/scripts/check-network.sh` exits 1.
Action: Skip all Harness API calls. Report "network unavailable — Harness API skipped". Do not retry until the script exits 0.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll hardcode the PAT I see in a prior response." | Always load from `credentials.json` at runtime — never hardcode a token. |
| "IACM endpoints work the same as the other ops, I'll use `harness_get`/`harness_post`." | IACM scope params are path segments, not query params — those helpers append them as query params and produce a 404. Use raw curl for Operations 6 and 7. |
| "I'll trigger/approve/create against this project without checking for prod." | Run the Prod Boundary runtime guard before any side-effecting operation — it's a hard gate, not a suggestion. |
| "No human is reachable, I'll proceed since confirmation would probably be granted." | Abort and report which operation was blocked and why — never proceed on an assumed confirmation, and never hang waiting for input that can't arrive. |
| "I'll create the IACM workspace directly via the API, it's faster." | GENERATOR-FIRST: use the `dft-iac-generator` control-plane sub-generator unless DevOps has explicitly authorized direct API creation — direct creation causes drift from the IaC repo. |
| "Empty trigger body is always safe." | Pipelines with runtime inputs (`<+input>`) return HTTP 400 or run with missing values on an empty body — check prior runs' `inputSetIdentifiers` or the pipeline YAML first. |

## Exit criteria

- [ ] Network connectivity was checked before any Harness API call.
- [ ] Every side-effecting operation (trigger, approve/reject, create workspace) passed
  the Prod Boundary runtime guard first.
- [ ] A triggered pipeline was polled via the Validation Flow to a terminal status
  (`Success`/`Failed`/`Expired`/`Aborted`), not left unobserved.
- [ ] An unattended run that hit a confirmation point aborted and reported the block,
  rather than proceeding or hanging.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/harness-api@9d7143e (restructured: moved the 7 full
Operations request/response schemas to `references/operations.md` to bring SKILL.md
under the L2 token budget — a 585-line, on-demand-loaded reference rather than
always-loaded body text; kept Network Check, Base curl Patterns, Validation Flow,
Approval Gate Pattern, and Prod Boundary inline since they're safety-critical and
always-applicable; pointed the network-check invocation at the real installed skill
script path, `~/.claude/skills/network-check/scripts/check-network.sh`, instead of a
pre-skill-packaging path that no longer exists)
