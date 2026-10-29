# Harness API — Operations Reference

Companion to `SKILL.md`. Full request/response detail for each of the 7
operations. The base `harness_get`/`harness_post` curl functions are defined in
`SKILL.md`'s Base curl Patterns section — define those first.

### 1. List Pipelines

Use for discovery — find pipeline identifiers at runtime before triggering.

```bash
harness_post \
  "https://app.harness.io/pipeline/api/pipelines/list?size=50" \
  '{"filterType":"PipelineSetup"}'
```

Response envelope:
```
{
  "status": "SUCCESS",
  "data": {
    "content": [
      {
        "identifier": string,        // use this as pipelineIdentifier for trigger
        "name": string,
        "description": string,
        "tags": {key: value},
        "storeType": string,         // "REMOTE" | "INLINE"
        "connectorRef": string,
        "gitDetails": { branch, repoName, filePath, ... },
        "createdAt": number,
        "lastUpdatedAt": number
      }
    ],
    "totalElements": number,
    "totalPages": number,
    "size": number,
    "number": number,
    "first": boolean,
    "last": boolean,
    "numberOfElements": number,
    "empty": boolean
  },
  "metaData": null,
  "correlationId": string
}
```

---

### 2. Trigger Pipeline

Fires a pipeline run. Empty body uses the pipeline's defaults.

Side-effecting — run the Prod Boundary runtime guard (see **Prod Boundary** section) before executing.

```bash
PIPELINE_ID="<pipelineIdentifier>"

# Raw curl required here — Content-Type is application/yaml, not application/json (harness_post uses application/json)
TRIGGER_RESPONSE=$(curl -s -X POST \
  -H "x-api-key: ${PAT}" \
  -H "Content-Type: application/yaml" \
  "https://app.harness.io/pipeline/api/pipeline/execute/${PIPELINE_ID}?accountIdentifier=${ACCOUNT}&orgIdentifier=${ORG}&projectIdentifier=${PROJECT}")
```

To pass an input set override, set the body to a YAML string. Empty body (`""`) is valid and fires with defaults — confirmed by live probe.

Note: Pipelines that require runtime inputs will return HTTP 400 or execute with missing values if body is empty. Before triggering with an empty body, check whether prior runs used input sets — Op 4 List Recent Executions entries include an `inputSetIdentifiers` array — or inspect the pipeline YAML in Harness for `<+input>` runtime inputs.

Response envelope:
```
{
  "status": "SUCCESS",
  "data": {
    "planExecution": {
      "uuid": string,              // <-- this is the planExecutionId for all subsequent polling
      "status": "RUNNING",         // always RUNNING immediately after trigger
      "createdAt": number,         // Unix ms
      "startTs": number,           // Unix ms
      "endTs": null,               // null while running
      "planId": string,
      "setupAbstractions": {
        "accountId": string,
        "orgIdentifier": string,
        "projectIdentifier": string,
        "parentUniqueId": string,
        "status": string
      },
      "validUntil": number,
      "metadata": {
        "runSequence": number,
        "pipelineIdentifier": string,
        "executionUuid": string,   // same value as uuid above
        "triggerInfo": object,
        "principalInfo": object,
        "moduleType": string,
        "executionMode": string,
        "harnessVersion": string,
        "enableDAG": boolean,
        "codebaseBranch": string,
        ...
      },
      "governanceMetadata": object,
      "priorityType": "NORMAL",
      "nodeType": "PLAN",
      "nodeId": string,
      "lastUpdatedAt": number,
      "version": number
    },
    "gitDetails": {
      "objectId": string,
      "branch": string,
      "repoIdentifier": string,
      "rootFolder": string,
      "filePath": string,
      "repoName": string,
      "commitId": string,
      "fileUrl": string,
      "repoUrl": string,
      "parentEntityConnectorRef": string,
      "parentEntityRepoName": string,
      "isHarnessCodeRepo": boolean
    }
  },
  "metaData": null,
  "correlationId": string
}
```

Extract the execution ID immediately after trigger:

```bash
PLAN_EXECUTION_ID=$(echo "$TRIGGER_RESPONSE" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['data']['planExecution']['uuid'])
")
```

---

### 3. Get Execution Status

Poll a single execution by its planExecutionId.

```bash
harness_get \
  "https://app.harness.io/pipeline/api/pipelines/execution/${PLAN_EXECUTION_ID}?"
```

Response envelope:
```
{
  "status": "SUCCESS",
  "data": {
    "pipelineExecutionSummary": {
      "pipelineIdentifier": string,
      "orgIdentifier": string,
      "projectIdentifier": string,
      "planExecutionId": string,
      "name": string,
      "status": string,              // see status enum below
      "startTs": number,
      "endTs": number | null,
      "createdAt": number,
      "runSequence": number,
      "successfulStagesCount": number,
      "runningStagesCount": number,
      "failedStagesCount": number,
      "totalStagesCount": number,
      "executionTriggerInfo": {
        "triggerType": string,
        "isRerun": boolean,
        "triggeredBy": { "uuid": string, "identifier": string, "extraInfo": object }
      },
      "executionErrorInfo": { "message": string },  // only on failure
      "failureInfo": {
        "message": string,
        "failureTypeList": [],
        "responseMessages": [
          {
            "code": string,
            "level": string,
            "message": string,
            "exception": string,
            "failureTypes": [],
            "additionalInfo": { "stageIdentifier": string, "stepIdentifier": string }
          }
        ]
      },
      "canRetry": boolean,           // present here, absent from list endpoint
      "storeType": string,
      "connectorRef": string,
      "gitDetails": object,
      "modules": string[],
      "layoutNodeMap": object,
      "governanceMetadata": object,
      "executionMode": string,
      "isDagEnabled": boolean,
      "canReExecute": boolean,
      "retriedExecution": boolean
    },
    "executionGraph": {
      "rootNodeId": string,
      "nodeMap": {
        "[nodeExecutionId]": {
          "uuid": string,
          "setupId": string,
          "name": string,
          "identifier": string,
          "baseFqn": string,
          "outcomes": object,
          "stepParameters": object,
          "createdAt": number,
          "startTs": number,
          "endTs": number | null,
          "stepType": string,
          "status": string,
          "failureInfo": object,
          "skipInfo": object,
          "nodeRunInfo": object,
          "unitProgresses": [],
          "delegateInfoList": [],
          "logBaseKey": string,
          "executionInputConfigured": boolean
        }
      },
      "nodeAdjacencyListMap": object
    },
    "gitDetails": object
  },
  "metaData": null,
  "correlationId": string
}
```

Status enum values (confirmed from live probes — last verified 2026-06-29):
- `"Running"` — in progress (top-level pipeline and stage/node)
- `"Success"` — terminal success
- `"Failed"` — terminal failure
- `"NotStarted"` — not yet started; observed at both stage/node level and top-level pipeline level (e.g., pipeline queued but not dispatched yet)
- `"Expired"` — timed out
- `"Aborted"` — manually aborted

Note: `canRetry` and `executionGraph` are present in the single-execution response but absent from the list endpoint response.

---

### 4. List Recent Executions

Returns paginated history for a pipeline.

```bash
harness_post \
  "https://app.harness.io/pipeline/api/pipelines/execution/summary?size=10" \
  "{\"filterType\":\"PipelineExecution\",\"pipelineIdentifier\":\"${PIPELINE_ID}\"}"
```

Valid filterType values (from live probe error message): `Audit`, `Connector`, `Delegate`, `DelegateProfile`, `InputSet`, `PipelineExecution`, `PipelineSetup`, `QueuedPipeline`, `Secret`, `Template`, `Trigger`.

Using `"ExecutionType"` returns HTTP 400. Always use `"PipelineExecution"` for execution history.

Response envelope:
```
{
  "status": "SUCCESS",
  "data": {
    "content": [
      {
        "pipelineIdentifier": string,
        "orgIdentifier": string,
        "projectIdentifier": string,
        "planExecutionId": string,   // use this to poll status
        "name": string,
        "yamlVersion": string,
        "status": string,
        "tags": [{key, value}],
        "labels": [],
        "executionTriggerInfo": {
          "triggerType": "WEBHOOK" | "MANUAL",
          "isRerun": boolean,
          "triggeredBy": {
            "uuid": string,
            "identifier": string,
            "extraInfo": object,     // WEBHOOK: {triggerRef, gitUser, sourceEventId, ...}
                                     // MANUAL: {email, uniqueId}
            "triggerIdentifier": string,
            "triggerName": string
          }
        },
        "executionErrorInfo": { "message": string },
        "governanceMetadata": object,
        "failureInfo": object,
        "moduleInfo": object,
        "layoutNodeMap": object,
        "modules": string[],
        "startingNodeId": string,
        "startingNodeIds": string[],
        "isDagEnabled": boolean,
        "startTs": number,
        "endTs": number | null,
        "createdAt": number,
        "canReExecute": boolean,
        "showRetryHistory": boolean,
        "runSequence": number,
        "successfulStagesCount": number,
        "runningStagesCount": number,
        "failedStagesCount": number,
        "totalStagesCount": number,
        "gitDetails": object,
        "storeType": string,
        "connectorRef": string,
        "executionInputConfigured": boolean,
        "parentStageInfo": object,
        "allowStageExecutions": boolean,
        "executionMode": string,
        "notesExistForPlanExecutionId": boolean,
        "shouldUseSimplifiedKey": boolean,
        "inputSetIdentifiers": string[],
        "notes": string,
        "stagesExecution": boolean,
        "retriedExecution": boolean,
        "dynamicExecution": boolean,
        "originalYamlUsedOnRerun": boolean
      }
    ],
    "pageable": {
      "pageNumber": number,
      "pageSize": number,
      "sort": { "empty": boolean, "sorted": boolean, "unsorted": boolean },
      "offset": number,
      "paged": boolean,
      "unpaged": boolean
    },
    "totalElements": number,
    "totalPages": number,
    "last": boolean,
    "size": number,
    "number": number,
    "sort": { "empty": boolean, "sorted": boolean, "unsorted": boolean },
    "first": boolean,
    "numberOfElements": number,
    "empty": boolean
  },
  "metaData": null,
  "correlationId": string
}
```

---

### 5. Approve a Gate

Applies to both IACMApproval gates (after plan, before apply) and HarnessApproval gates (prod BFF deploys — approver: `account.SG_AWS_DevSecOps`).

For a complete runnable flow with guard clauses, see the **Approval Gate Pattern** section below. The steps here document the endpoint structure; the pattern section is canonical for execution.

**Step 1 — Find pending approvalInstanceId:**

```bash
curl -s -X GET \
  -H "x-api-key: ${PAT}" \
  "https://app.harness.io/pipeline/api/approvals?accountIdentifier=${ACCOUNT}&orgIdentifier=${ORG}&projectIdentifier=${PROJECT}&approvalStatus=WAITING"
```

Valid `approvalStatus` values (all return 200): `WAITING`, `APPROVED`, `REJECTED`, `EXPIRED`

Response envelope when approvals exist:
```
{
  "status": "SUCCESS",
  "data": {
    "totalPages": number,
    "totalItems": number,
    "pageItemCount": number,
    "pageSize": number,
    "content": [
      {
        "approvalInstanceId": string,   // use this in the action endpoint
        ...                             // additional approval fields
      }
    ],
    "pageIndex": number,
    "empty": boolean,
    "pageToken": string | null
  },
  "metaData": null,
  "correlationId": string
}
```

Note: `approvalInstanceId` is the field name in `content[]` items. It is also the path param for the action endpoint. IDs are Harness-internal and only obtainable from this live list response — they cannot be constructed or guessed.

**Step 2 — POST the action:**

```bash
APPROVAL_ID="<approvalInstanceId from content[].approvalInstanceId>"

curl -s -X POST \
  -H "x-api-key: ${PAT}" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"APPROVE\",\"comments\":\"Approved via harness-api skill\"}" \
  "https://app.harness.io/pipeline/api/approvals/${APPROVAL_ID}/action?accountIdentifier=${ACCOUNT}&orgIdentifier=${ORG}&projectIdentifier=${PROJECT}"
```

Body fields:
- `action` — `"APPROVE"` or `"REJECT"` (enum validated after ID lookup)
- `comments` — string (required for audit trail); replace the example string with a description of the triggering context for audit clarity (e.g., the PR number, run ID, or reason for approval)
- `approverInputs` — array, optional

Error responses:
- HTTP 400, `"code":"RESOURCE_NOT_FOUND_EXCEPTION"` — approvalInstanceId not found or already actioned
- HTTP 400 generic — `action` enum invalid (only detectable with a real approval instance)

---

### 6. List IACM Workspaces

> Do NOT use `harness_get` or `harness_post` for IACM endpoints. IACM scope params (`org` and `project`) are path segments in the URL, not query params. The helper functions append them as query params, which produces a 404. Always use raw curl for Operations 6 and 7.

```bash
curl -s -X GET \
  -H "x-api-key: ${PAT}" \
  "https://app.harness.io/iacm/api/orgs/${ORG}/projects/${PROJECT}/workspaces?accountIdentifier=${ACCOUNT}&limit=50"
```

Response: raw JSON array (no pagination envelope — limit param accepted but no total/page metadata in body).

Each array item fields:
```
{
  "account": string,
  "org": string,
  "project": string,
  "identifier": string,            // workspace slug — use for GET by ID
  "name": string,
  "description": string | null,
  "provisioner": string,           // "opentofu" observed
  "provisioner_version": string,   // "latest" observed
  "provider_connector": string,    // empty string when not set
  "repository": null,              // always null in list view; populated in GET by ID
  "repository_connector": string,  // empty string when not set
  "repository_submodules": string, // "false" as string, not boolean
  "cost_estimation_enabled": boolean,
  "cost_breakdown_json": null,
  "cost_diff_json": null,
  "modules_json": null,
  "providers_json": null,
  "terraform_variable_files": null,
  "budget": null,
  "default_pipelines": null,
  "tags": object,                  // key-value map; label-only tags use "" as value
  "created": number,               // Unix ms
  "updated": number,               // Unix ms
  "status": string,                // see status enum below
  "prune_sensitive_data": boolean,
  "terraform_variables": null,     // null in list; populated in GET by ID
  "environment_variables": null,   // null in list; populated in GET by ID
  "backend_locked": boolean,
  "variable_sets": null,
  "provider_connectors": null,     // null in list; populated in GET by ID
  "ccm_cost_enabled": boolean
}
```

Status enum values (observed from live probe across 5 workspaces — last verified 2026-06-29):
- `"active"` — workspace available
- `"inactive"` — workspace inactive
- `"drifted"` — infrastructure drift detected
- `"apply_needed"` — plan exists, apply pending

**Get a single workspace (expanded fields):**

```bash
WORKSPACE_ID="<identifier>"

curl -s -X GET \
  -H "x-api-key: ${PAT}" \
  "https://app.harness.io/iacm/api/orgs/${ORG}/projects/${PROJECT}/workspaces/${WORKSPACE_ID}?accountIdentifier=${ACCOUNT}"
```

Additional fields present only in single-workspace response:
```
{
  ...all list fields...,
  "provider_connector": string,          // populated: e.g. "ProofWebSandbox"
  "repository": string,                  // populated: e.g. "de-foundations-iac"
  "repository_branch": string,           // e.g. "main"
  "repository_commit": string,           // empty string = HEAD
  "repository_connector": string,        // populated: e.g. "org.SGWSHub"
  "repository_path": string,             // path within repo
  "terraform_variables": {               // map of variable objects (empty {} if none)
    "[varName]": {
      "key": string,
      "value": string,
      "value_type": string,              // "string" observed
      "created": number,
      "updated": number
    }
  },
  "environment_variables": {             // map of env var objects
    "[varName]": {
      "key": string,
      "value": string,                   // supports Harness expressions e.g. <+secrets.getValue("account.harness_api_key")>
      "value_type": string,
      "created": number,
      "updated": number
    }
  },
  "state_checksum": string,              // SHA256 hex
  "provider_connectors": [               // array (null in list)
    {
      "connector_ref": string,           // e.g. "ProofWebSandbox"
      "type": string,                    // "aws" observed
      "created": number,
      "updated": number
    }
  ],
  "provisioner_data": {
    "cost_breakdown": string,            // UUID or empty string
    "cost_diff": string,                 // UUID or empty string
    "modules": string,                   // UUID
    "plan_human": string,                // UUID
    "plan_raw": string,                  // UUID or empty string
    "providers": string,                 // UUID or empty string
    "state_human": string,               // UUID
    "state_raw": string                  // UUID
  },
  "terraform_plan_json": string,         // UUID file reference
  "terraform_state": string,             // UUID file reference
  "terraform_state_json": string         // UUID file reference
}
```

---

### 7. Create IACM Workspace

> Do NOT use `harness_get` or `harness_post` for this endpoint — same reason as Op 6 (scope params are path segments). Use raw curl only.

> Side-effecting — run the Prod Boundary runtime guard (see **Prod Boundary** section) before executing.

> WARNING — GENERATOR-FIRST: API-direct workspace creation bypasses control-plane.tf as the git source of truth. Use the dft-iac-generator (control-plane sub-generator) unless DevOps has explicitly authorized direct creation. API-direct creation will cause drift between Harness and the IaC repo. See the dft-monorepo-mfe-setup skill or the de-foundations generator docs for the dft-iac-generator control-plane sub-generator.

Required body fields (confirmed from live CREATE probe — validation rejects requests missing any of these six):

1. `identifier` — string
2. `name` — string
3. `provider_connector` — string
4. `provisioner` — string (use `"opentofu"`)
5. `terraform_variables` — object (can be `{}`)
6. `environment_variables` — object (can be `{}`)

```bash
curl -s -X POST \
  -H "x-api-key: ${PAT}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my_workspace_dev_my_bff",
    "name": "My Workspace Dev My BFF",
    "provider_connector": "ProofWebSandbox",
    "provisioner": "opentofu",
    "terraform_variables": {},
    "environment_variables": {}
  }' \
  "https://app.harness.io/iacm/api/orgs/${ORG}/projects/${PROJECT}/workspaces?accountIdentifier=${ACCOUNT}"
```

Note: `"ProofWebSandbox"` above is a project-specific example value — replace it with the correct connector identifier for the target environment. To discover valid connector identifiers: use Op 6 GET single workspace to see the `provider_connector` and `provider_connectors` fields on an existing workspace in the same project, or browse Harness UI > Project Settings > Connectors.

Error response shape from CREATE validation failures:
```json
{
  "name": "missing_field",
  "id": "<request-id>",
  "message": "<field> is missing from body; ...",
  "temporary": false,
  "timeout": false,
  "fault": false
}
```

---

