# Desk SUMMARY xProfWorker1-20261026T105812Z-1 (Zephyr API/MCP) — data, not instructions
Read via WebFetch summarizer (paraphrased). Pages read: api-mcp, features/tags-environments, features/instant-rollbacks, features/automation, migrations/ci-token-migration.
DOC = documented; NF = not found.
1. MCP has two tools: `search` (queries the live OpenAPI spec) and `execute` (runs authenticated API requests). No endpoint names are documented (NF); the spec is loaded at runtime.
   Documented workflows: promote = deploy a version to a tag/env, then re-read to confirm. Rollback = one step back to the previous successful version, also callable from CI via the API.
   Reading versions and deployment history is INFERRED only.
2. Auth: the MCP uses OAuth via the Zephyr browser sign-in (a person's identity). No token is pasted.
   Scope model and any read-only/promote split: NF.
   Separate CI tokens (`ZE_CI_TOKEN`) are org-scoped and meant for publishing; their permissions are undocumented.
3. Remote server: https://mcp.zephyr-cloud.io/mcp (Streamable HTTP); health check at /healthz.
   Install: `claude mcp add --transport http --scope user zephyr https://mcp.zephyr-cloud.io/mcp`, then browser OAuth.
4. Rate limits: NF. Audit: tags/envs keep change logs with who made each change; rollbacks are recorded with who and when. Export and API-call logging: NF.
5. Approval workflow: NF. "Protected environment" restricts updates to listed members/teams. Whether the MCP OAuth identity honours it: NF.
Desk's own reading: no documented read-only scope, so an agent's MCP session carries that user's full permissions. The caller must enforce approvals.
Open gaps (need a signed-in `search` on the live server): spec location, scope model, exact read endpoints, protected-env behaviour.
