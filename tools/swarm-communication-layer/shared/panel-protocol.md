# Panel Protocol — swarm-communication-layer

Project-specific consultation triggers. Grows only from real execution failures.
Cross-project defaults live in `_shared/consultation-protocol.md` — apply those first.

---

## Phase 1: Contract Authoring

| Trigger | Consult | Source |
|---------|---------|--------|
| A dependency package is named in a build prompt | Verify actual exports: `import('pkg').then(m => console.log(Object.keys(m)))` — then probe the factory return value. Do this before writing any worker prompts. | smoke-001, 2026-05-02 |

---

## Phase 2: Spec Writing

| Trigger | Consult | Source |
|---------|---------|--------|
| Build orchestrator prompt includes `node --check` as final verification | Add a smoke test step after syntax checks: start server, `curl /health`, confirm `status: ok`, then kill server. Only mark complete after smoke test passes. | smoke-001, 2026-05-02 |

---

## Phase 3: L2 Review

| Trigger | Consult | Source |
|---------|---------|--------|
| | | |

---

## Phase 4: Retrospective

| Trigger | Consult | Source |
|---------|---------|--------|
| | | |

---

## Project-Specific Risky Values

| Value | Correct | Wrong (seen before) | Authority |
|-------|---------|---------------------|-----------|
| `@tursodatabase/database` import | `import { connect } from '@tursodatabase/database'` | `import { createClient } from '@tursodatabase/database'` — doesn't exist | smoke-001, 2026-05-02 |
| DB connection path | Bare absolute path: `~/projects/agent-hq/tools/swarm-communication-layer/data/swarm.db` | `file:./data/swarm.db` — rejected by connect() | smoke-001, 2026-05-02 |
| Write query API | `db.prepare(sql).run(...args)` | `client.execute({ sql, args })` — @libsql/client cloud pattern, doesn't exist here | smoke-001, 2026-05-02 |
| Read query API | `db.prepare(sql).all(...args)` | `client.execute({ sql, args })` | smoke-001, 2026-05-02 |
| Transaction API | `db.transaction(fn)` — returns wrapped fn, call it to execute | `client.batch([...statements])` — doesn't exist | smoke-001, 2026-05-02 |
| Schema init | `db.exec(multiStatementSql)` | `client.execute(singleStatement)` in a loop | smoke-001, 2026-05-02 |
| schema.sql path from db.js | `new URL('../schema.sql', import.meta.url)` — one level up from src/ | `new URL('../../schema.sql', import.meta.url)` — goes too far up | smoke-001, 2026-05-02 |
| Signal file content | `ready` | `DONE` | arch-002, 2026-05-02 |
| pm2 instances | `1` — mandatory | Any value > 1 causes duplicate fallback sync | architecture.md |
