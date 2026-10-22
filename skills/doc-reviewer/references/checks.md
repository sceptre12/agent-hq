# Pre-Flight Checks — Full Specification

This reference contains the detailed specification for each pre-flight check
used in the Architecture Document Review framework.

**Checks 1–8:** Original framework — infrastructure addendums, contract compliance, source verification.
**Checks 9–13:** Added from x_wiki multi-pass learnings + superpowers:verification-before-completion.
Apply Checks 9–13 whenever the document is a multi-file TypeScript implementation spec, a multi-wave
delivery spec, or any spec with an explicit task list and AC table.
**Check 14:** Added after flow-scope mismatch survived artifact-scoped review. Apply whenever the
document defines, produces, or consumes bus topics or inter-agent message flows.

## Table of Contents

1. [Check 1: File-Line Test](#check-1-file-line-test)
2. [Check 2: Runtime Fork Scan](#check-2-runtime-fork-scan)
3. [Check 3: Source-of-Value Audit](#check-3-source-of-value-audit)
4. [Check 4: Cross-Reference Walk](#check-4-cross-reference-walk)
5. [Check 5: Ambiguity Inversion Test](#check-5-ambiguity-inversion-test)
6. [Check 6: Risky Value Scan](#check-6-risky-value-scan)
7. [Check 7: Cold Read Gate](#check-7-cold-read-gate)
8. [Check 8: Source Verification Gate](#check-8-source-verification-gate)
9. [Check 9: Export Surface Check](#check-9-export-surface-check)
10. [Check 10: Task List vs Code Blocks Reconciliation](#check-10-task-list-vs-code-blocks-reconciliation)
11. [Check 11: Task List vs AC Table Reconciliation](#check-11-task-list-vs-ac-table-reconciliation)
12. [Check 12: Within-Document Value Consistency](#check-12-within-document-value-consistency)
13. [Check 13: AC Runability Check](#check-13-ac-runability-check)
14. [Check 14: Flow-Scope Check](#check-14-flow-scope-check)
15. [Severity Classification](#severity-classification)
16. [Panel Composition](#panel-composition)
17. [Multi-Wave Spec Protocol](#multi-wave-spec-protocol)
18. [Key Learnings](#key-learnings-from-real-reviews)

---

## Check 1: File-Line Test

**Purpose:** Verify that every file needing modification gets exact, copy-paste-ready content.

**What to check:**
- Is line-for-line content provided for critical files?
- Are insertion points specified (before/after which existing line)?
- Are file paths exact and unambiguous?
- For new files: is the full content specified, or just described?
- For modifications: is it clear what to add, remove, or change?

**Writing-plans standards (apply when the spec was not authored with a planning tool):**
- No placeholders — "TBD", "see above", "as appropriate", "as needed" are failures
- Every file modification has a complete code block, not prose description
- Each task represents a focused unit of work — flag tasks that bundle hours of changes with no sub-steps
- Zero-context executability — the spec alone is sufficient; no "in-the-room" knowledge assumed

**Verdict scale:**
- PASS — All critical files have exact content + insertion points; no placeholders
- MARGINAL — Some files have enough context for agent to infer from patterns
- FAIL — Missing guidance on how to edit files, or placeholder sections present

**Example failure:**
"Add Verdaccio check to doctor.js" — FAIL
Agent doesn't know: what URL to ping, what success looks like, what error message to show,
which helper functions to use, or where in the file to insert the check.

**Example pass:**
Full Commander.js subcommand registration pattern shown with exact code, specifying it goes
in `cli/src/index.js`, noting this is the FIRST subcommand group in the codebase and that
existing commands use flat `program.command()` pattern.

---

## Check 2: Runtime Fork Scan

**Purpose:** Identify if the spec requires changes across multiple runtimes or platforms.

**What to check:**
- Does this change affect only one runtime (e.g., Node)?
- Or does it split across runtimes (Node AND Python AND Rust)?
- Are there conditional behaviors the agent must branch on?
- Does the spec assume a single platform but the system supports multiple?
- Are there Alpine vs Debian differences that matter?

**Verdict scale:**
- PASS — Single runtime, no branching needed
- N/A — Clearly no fork scenarios
- CONCERN — Multiple runtimes require conditional logic not specified in the doc

**Common fork points in this ecosystem:**
- Alpine-based images (Verdaccio) don't have `curl` — use `wget`
- `localhost` vs `127.0.0.1` — Alpine's IPv6 handling breaks `localhost`
- Container-side vs host-side hostnames (container DNS vs OrbStack DNS)
- `stat -c` (Linux) vs `stat -f` (macOS) syntax differences

---

## Check 3: Source-of-Value Audit

**Purpose:** Ensure all hardcoded values trace to authoritative sources.

**What to check:**
- Every port number — where is it defined? (port registry, third-party default, contract)
- Every hostname — is it from OrbStack convention, container name, or invented?
- Every image tag — does it match the official image or base image contract?
- Every file path — does it match the repository structure?
- Every credential — is it from the database-naming contract or invented?
- Are there ORPHANED values (used but no source declared)?

**Valid sources:**
- Architecture documents (design decisions, ADRs)
- Contracts in `contracts/` (formal agreements)
- Existing codebase patterns (precedent from repo)
- Known Risky Values documentation
- Third-party standards (Verdaccio port 4873, Postgres port 5432)

**Verdict scale:**
- PASS — All values sourced, no orphans
- FAIL — Orphaned values with no declared source

**Example failure:**
Spec uses port 3010 for staging environment. Where did 3010 come from? Is it in the port
registry? Does it conflict with anything? If the source is "offset convention (base + 10
per environment)," that should be stated explicitly.

---

## Check 4: Cross-Reference Walk

**Purpose:** Verify that references to contracts and other docs are accurate and consulted.

**What to check:**
- When the spec mentions a contract by name, has it been actually read?
- Are deviations from contracts documented and justified?
- Are there IMPLICIT contract references that should be explicit?
- Does the spec's Context Package list all relevant contracts?
- Are cross-reference links correct (right page IDs, right section titles)?

**Verdict scale:**
- PASS — All references explicit, cross-checked, deviations justified
- MARGINAL — Most references present, minor gaps
- FAIL — References missing or not consulted

**Example failure:**
Spec says "Add Traefik labels" but doesn't list `contracts/traefik-labels.md` in the Context
Package. Agent wouldn't know to cross-check label format, might miss the `/_health` requirement
or the `dev-mesh` network requirement.

**Example pass:**
Spec says "Add 4 Traefik labels (deviation from 6-label standard: healthcheck labels omitted
because Verdaccio uses /-/ping, not /_health — see Traefik Labels Deviation section below)."
Contract listed in Context Package with specific deviation note.

---

## Check 5: Ambiguity Inversion Test

**Purpose:** Identify where a "minimum effort" agent could legitimately skip work.

**What to check:**
- Is every section covered by at least one acceptance criterion?
- Are "Do NOT" instructions explicit or just implied?
- Could an agent satisfy all acceptance criteria while ignoring 50% of the spec?
- Are there sections that describe optional/nice-to-have work without flagging it as such?
- Could an agent interpret the spec to do less than intended?

**The inversion technique:**
For each acceptance criterion, ask: "What is the MINIMUM work an agent could do to pass this?"
If the minimum work is less than what the spec intends, the criterion is underspecified.

**Verdict scale:**
- PASS — Every section has explicit acceptance criteria that prevent skipping
- MARGINAL — Most sections covered, a few have creative discretion
- FAIL — Large sections have no verification and can be skipped

**Example failure:**
Spec has a "CLI Updates" section describing `dev doctor` changes, but acceptance criteria only
say "`dev doctor` validates Verdaccio." A minimum-effort agent could add a check that always
returns true — the criterion doesn't specify what "validates" means.

**Example fix:**
Acceptance criterion: "`dev doctor` runs `docker exec verdaccio wget -q -O-
http://localhost:4873/-/ping` and prints 'Verdaccio reachable' on success or
'Verdaccio not reachable' on failure."

---

## Check 6: Risky Value Scan

**Purpose:** Catch host/container URL confusion, port misuse, and security-adjacent values.

**Applies to:** Infrastructure specs.

**What to check:**
- When `*.orb.local` hostnames appear — are they ONLY on the host side?
- When container-side — does it use container DNS (`redis`, `postgres`) instead?
- Are `localhost` references correct? (Use `127.0.0.1` in containers, not `localhost`)
- Are mount paths using correct relativity? (`./foo` vs `../foo` depends on compose location)
- Are credentials appropriate? (dev:dev for local, no real secrets in specs)
- Are generated files going to the right directory? (e.g., Traefik configs to `traefik/dynamic/`)

**Known risky values in this ecosystem:**
- `*.orb.local` — host-side only, never in container-to-container URLs
- `localhost` vs `127.0.0.1` — Alpine IPv6 breaks `localhost` resolution
- `./` paths in compose files — relative to compose file location, not repo root
- `pino` in `package.json` — should NOT be there (pre-installed in base image)
- Port numbers — must cross-reference against the port registry
- `postgres.orb.local` vs `postgres` — host vs container hostname
- `redis.orb.local` vs `redis` — same pattern
- `traefik/dynamic/` — only Traefik config files belong here (file provider parses everything)

**Verdict scale:**
- PASS — All risky values correctly scoped and documented
- FAIL — Host/container confusion, path mistakes, or security issues

---

## Check 7: Cold Read Gate

**Purpose:** Enforce that Phase 0 Cold Read has been completed.

**What to check:**
- Has the document been read end-to-end with zero prior context?
- Are any of the 6 Cold Read symptoms present?
  1. Incomplete specs
  2. Redundant definitions
  3. Contradictory statements
  4. Rendering artifacts
  5. Scope confusion
  6. Ambiguous procedures
- Would an agent actually understand what to do from this document alone?
- Are there sections that only make sense if you were "in the room"?

**Cold read symptom list:** see `SKILL.md` Step 1 (Phase A, Cold Read).

**Verdict scale:**
- PASS — None of the 6 symptoms present
- MARGINAL — Mostly clear, 1-2 minor ambiguities
- FAIL — Any symptom present — each instance is a separate finding

**Why this exists:**
Iterative editing creates "context blindness" — each review pass evaluates the delta
(what changed), not the whole document. Reviewers fill in gaps from SHARED UNDERSTANDING
that agents won't have. Multiple rounds create a "context ratchet" where incrementally
correct edits collectively degrade the document's standalone clarity.

**Writing-plans pre-check (run before other checks if the spec was not authored with a planning tool):**
Apply these criteria first — failures here make all other checks harder to evaluate:
- Are tasks granular? A task that bundles 5 file changes with no sub-steps is a red flag.
- Are there placeholder sections? Search for "TBD", "see above", "as needed", "etc."
- Could an agent with zero codebase context execute every step using only this document?
If the answer to any of these is no, fix the writing-plans violations before running Checks 1–8.

---

## Check 8: Source Verification Gate

**Purpose:** For any section specifying changes to EXISTING files, verify implementation
patterns against the actual codebase.

**Applies to:** Addendum specs (existing files).

**Key insight:**
Architecture docs describe WHAT and WHY. Source code shows HOW existing patterns work.
Addendums to existing codebases need both — without source verification, the spec may be
architecturally correct but implementation-pattern wrong.

**Two-step lookup process:**
1. FIRST: Check if a completed task spec has an "Implementation Patterns" section (cheap).
   This section is filled post-execution by the L2 reviewer and shows patterns actually used.
2. FALLBACK: Read source code directly (expensive but necessary if no Implementation Patterns).

**What to verify against source:**
- CLI command registration patterns (flat vs subcommand groups)
- Helper function signatures (`check()`, `run()` in doctor.js)
- Config file formats (YAML structure, key names)
- Docker compose patterns (volume mounts, network declarations, label format)
- File paths and directory structure (does `cli/src/utils/` exist or is it `cli/src/lib/`?)
- Import/require patterns (CJS vs ESM)
- Error handling patterns (try/catch, process.exit, error messages)

**Verdict scale:**
- PASS — Implementation patterns verified against source or documented in task spec
- COST — Source reading was required (no Implementation Patterns doc existed)
- FAIL — Patterns in the spec contradict the actual codebase

**Example failure:**
Spec says "doctor.js: add Verdaccio health check using HTTP GET."
Actual `doctor.js` uses `execSync()` with `docker exec` commands and `check()`/`run()` helpers.
There are no HTTP clients in the file. An agent following the spec would write incompatible code.

---

## Cross-Cutting Concerns Matrix

This is not a numbered check but runs alongside Steps 1-4.

**Process:**
1. List ALL contracts in the project's contracts/interfaces directory, e.g.:
   ```
   base-image.md, database-naming.md, health-check.md,
   logging.md, package-registry.md, traefik-labels.md,
   environment-provisioning.md (if it exists)
   ```
   (Skip this matrix entirely if the project has no such directory — see `SKILL.md` Step 4.)
2. For each contract, read the relevant parts of both the contract and the spec
3. Classify the relationship:
   - **CONFLICT** — Incompatible rules. Cannot coexist. Must resolve before promotion.
   - **TENSION** — Different mechanisms, both work, but not documented. Should add coexistence note.
   - **CLEAN** — No conflict, clean integration or no intersection.
4. Present findings in matrix format

**Output format:**
```
| Contract | Status | Finding | Action Needed |
|----------|--------|---------|---------------|
| database-naming.md | CONFLICT | Transformation method differs | Must resolve |
| traefik-labels.md | TENSION | File provider vs labels | Add coexistence note |
| health-check.md | CLEAN | No intersection | None |
```

---

## Architectural Impact Check

**Purpose:** Verify the document is a pure extension, not a breaking change.

**A pure extension:**
- Adds new functionality, services, or layers
- Does NOT modify existing interfaces
- Does NOT change existing contracts (may extend them)
- Does NOT invalidate existing task specs
- Does NOT break backward compatibility

**Four verification points:**
1. **Layer Integrity** — Does the spec respect existing layer boundaries?
2. **Contract Non-Violation** — Does it violate any existing contracts? (Deviations OK if documented)
3. **Backward Compatibility** — Do existing task specs still execute correctly?
4. **Service Composition Impact** — Does this change affect how existing services connect?

**Verdict scale:**
- PASS — Pure extension, no breaking changes
- REQUIRES MATRIX — Has deviations, documented and non-breaking
- FAIL — Breaks existing architecture or contracts

---

## Check 9: Export Surface Check

**Purpose:** For TypeScript/ESM specs, verify that every symbol imported across file boundaries
is marked `export` in the corresponding file's code block.

**Applies to:** Any spec containing multi-file TypeScript code blocks.

**What to check:**
- For every `import { X, Y } from 'some/file.js'` in any code block, find the code block for `some/file.ts`
- Verify X and Y are marked `export` in that code block (`export function`, `export const`, `export type`)
- Flag any import where the source file's code block is absent from the spec entirely
  (symbol referenced but never specified — agent must guess the implementation)

**Common failure pattern:**
A function is defined in File A and imported by File B. The spec shows File B's import statement
correctly. The reviewer approves because the import looks right. But File A's code block is missing
the `export` keyword — the agent creates the function without `export`, File B fails to import it,
build fails with "does not provide an export named X."

**Verdict scale:**
- PASS — Every imported symbol has a matching `export` in its source file's code block
- FAIL — One or more imported symbols are not marked `export`, or have no source code block in the spec

**Real failures caught:**
- x_wiki Pass 4 (B1): `checkAndReindex` imported by `get_project_meta.ts` and `get_project_context.ts`
  but defined without `export` in `src/indexer/index.ts` code block.
- x_wiki Wave 3 (B1): `cosineSimilarity` imported by `search_context.ts` but not assigned to any task;
  `export` keyword present in code block but agent would not know which task to add it in.

---

## Check 10: Task List vs Code Blocks Reconciliation

**Purpose:** For multi-wave or multi-task specs, verify the task list completely covers all code
changes shown in the spec's code blocks.

**Applies to:** Any spec with an explicit task list AND code blocks showing what to create/modify.

**What to check:**
1. Enumerate every function, file, and significant code addition shown in code blocks for each wave/phase
2. Map each to a task list entry by name or description
3. Flag any code block item with no matching task entry
4. Flag any task list entry that references something not shown in a code block (spec gap in the other direction)

**The task list is an abstraction over code changes. The code blocks are the truth. They must agree.**

**Common failure pattern:**
Author writes the task list as a high-level summary: "Add Bedrock embedding support." Then writes
code blocks covering 5 distinct functions. The task list covers 4 of them — the 5th floats in
the code blocks without a task home. A task-list-following agent misses it; a careful agent catches
it at build time (import fails) but only after unnecessary iteration.

**Verdict scale:**
- PASS — Every code block addition maps to a named task list entry
- FAIL — One or more code block items have no task entry; agent will miss them

**Real failures caught:**
- x_wiki Wave 3 (B1): `cosineSimilarity` function specified in code blocks, imported by
  `search_context.ts` Wave 3, but not mentioned in any of Tasks 1–9. Build failure at Task 6.

---

## Check 11: Task List vs AC Table Reconciliation

**Purpose:** Verify the task list and acceptance criteria table are aligned — same count,
consistent numbering, no orphaned rows in either direction.

**Applies to:** Any spec with both a task list and a separate AC table.

**What to check:**
- Count tasks. Count AC rows. They must match.
- Numbering must be consistent — if tasks are numbered 1–N, ACs must be numbered 1–N
  (not 0 to N-1, which creates a phantom Task 0 visible only in the AC table)
- For each task N, verify AC N exists and is scoped to that task's output
- Flag any task with no AC (cannot be verified complete)
- Flag any AC with no task (verifying something the agent was never asked to do)

**Common failure pattern:**
Tasks are authored top-down (1–9). ACs are authored separately, sometimes with an implicit
prerequisite check inserted late as "Task 0." Result: task list is 1–9, AC table is 0–8.
An agent executing the task list never sees the Task 0 prerequisite and skips the credential
check. The failure surfaces much later at first live call.

**Verdict scale:**
- PASS — Tasks and ACs aligned: same count, consistent numbering, each task has an AC
- FAIL — Count mismatch, numbering offset, or orphaned rows in either direction

**Real failures caught:**
- x_wiki Wave 3 (M1): Task list had Tasks 1–9. AC table had Tasks 0–8. Task 0 (AWS credentials
  check, "valid before proceeding") was in the AC table but absent from the task list. Task 9
  (end-to-end test) was in the task list but had no AC row.
- x_wiki Wave 1 (A2): File list said 8 files inline; AC6 said "11 files listed above." Count
  mismatch made AC6 untestable.

---

## Check 12: Within-Document Value Consistency

**Purpose:** Identify values or patterns used in multiple sections that have drifted to
inconsistent forms across sections authored at different times.

**Applies to:** Any spec authored across multiple sessions or with multiple distinct sections
(schema, code blocks, wave sections, AC tables).

**Note:** This check is about INTERNAL consistency — the same value used in multiple places
within the spec itself. Check 3 (Source-of-Value) traces values to external authoritative sources.
These are complementary, not redundant.

**What to check:**
- SQL function syntax — `datetime('now')` vs `datetime("now")`, single vs double-quoted literals
- ENV var names — same variable referenced differently across sections
- Function names — called one way in one section, defined differently in another
- File paths — same file referenced with inconsistent paths
- Comment patterns — same concept described with contradictory language in different sections

**Common failure pattern:**
The schema section is written first using canonical SQLite `datetime('now')` (single quotes).
Wave 3 code blocks are written in a later session by an author who defaults to `datetime("now")`
(double quotes). Both work in SQLite due to fallback behavior, but the inconsistency signals
accumulated context drift and may cause failures in stricter SQL contexts or linters.

**Verdict scale:**
- PASS — Values and patterns are consistent across all sections
- FAIL — Same value appears in inconsistent forms; risk of copy-paste errors at implementation time

**Real failures caught:**
- x_wiki Wave 3 (A1): `embedded_at=datetime("now")` in Wave 3 code blocks vs `datetime('now')`
  in the schema section. Both functional; flagged as advisory inconsistency.

---

## Check 13: AC Runability Check

**Purpose:** Verify that each acceptance criterion specifying a command can actually be run and
will produce a binary pass/fail result.

**Applies to:** Any spec with acceptance criteria that include shell commands, SQL queries,
grep patterns, or file-existence checks.

**Derived from:** `superpowers:verification-before-completion` — the Iron Law that no completion
claim is valid without fresh verification evidence. Applied to specs: if an AC's command cannot
be traced through to a specific pass/fail output, it cannot gate completion.

**What to check for each command-based AC:**
1. **Syntax validity** — Is it real shell syntax, or pseudocode? (`grep "X" <<< "$(cmd 2>&1)"` vs "check the output")
2. **Path existence** — Will the file/binary/directory referenced actually exist after the tasks run?
   Is the path dependent on a prior task completing first?
3. **Binary pass/fail** — Does the command output clearly distinguish pass from fail, or is interpretation required?
4. **Exact string matching** — If the AC says "message containing X," does the code actually emit X verbatim?
   Trace the exact log line from source to AC.
5. **Data dependency** — Does the AC assume state that only exists after a later task completes?
   (e.g., AC for Task 2 assumes data from Task 4)

**The Iron Law (from superpowers:verification-before-completion):**
"NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE."
Applied to specs: if an AC cannot produce fresh evidence, it cannot gate completion.

**Common failure patterns:**
- AC says server exits with `"CONTEXT_DOCS_PATH is required"` but actual output is
  `"[x_wiki] Startup failed: CONTEXT_DOCS_PATH is required"`. Exact-string match fails
  even when the behavior is correct. Fix: "message containing" + grep command shown.
- AC says "returns the correct count" without specifying how to verify the count —
  agent could return any array and claim pass. Fix: specify exact expected value or comparison.
- AC references `node_modules/@aws-sdk/...` before `npm install` has run.
  Fix: note the data dependency explicitly or reorder tasks.

**Verdict scale:**
- PASS — Every command-based AC has valid syntax, reachable paths, and binary pass/fail output
- MARGINAL — Most ACs are verifiable; 1–2 have minor ambiguity that a careful agent would handle
- FAIL — ACs use pseudocode, reference paths that won't exist, or cannot produce binary verdicts

**Real failures caught:**
- x_wiki Wave 1 (A1): AC1 said exits with `"CONTEXT_DOCS_PATH is required"` — actual output
  is `"[x_wiki] Startup failed: CONTEXT_DOCS_PATH is required"`. Fixed to "message containing"
  with explicit grep verification command.

---

## Check 14: Flow-Scope Check

**Purpose:** Trace every bus topic string across the full producer→consumer chain and verify
that topic strings, payload schemas, and registry entries all agree.

**Applies to:** Any skill or architecture doc that defines, produces, or consumes bus topics
or inter-agent message flows.

**Why artifact-scoped review misses this:**
A producer posting to `loop-{SESSION_ID}-topic` and a consumer awaiting `{SESSION_ID}-topic`
both look correct when read in isolation. The mismatch is only visible when you hold both ends
of the channel side by side and compare topic strings character-by-character.

**What to check for each bus topic found in the artifact under review:**

1. **Find the producer** — grep all skill files for the exact topic string being posted to.
   Confirm the producer exists and that the topic string matches exactly (same variable names,
   same format, no prefix differences).

2. **Find the consumer** — grep all skill files for the exact topic string being awaited or
   read. Confirm the consumer exists and uses an identical topic string.

3. **Compare topic strings exactly** — producer and consumer must use identical template
   strings. Flag any mismatch, including prefix differences (e.g., `loop-{SESSION_ID}-topic`
   vs `{SESSION_ID}-topic`), different variable names for the same substitution, or
   different separators.

4. **Compare payload schemas** — list the fields the producer includes in the message. List
   the fields the consumer reads or expects. Flag any field present on one side but absent
   on the other. A consumer that reads `msg.taskId` when the producer sends `msg.task_id`
   will silently receive `undefined`.

5. **Check the schema registry, if one exists.** If the doc defines bus topics, verify each
   against the owning swarm skill's bus-schema reference (e.g. `bus-schema.md` or an
   equivalent registry file) — confirm the topic and its message shape are registered, and
   that the registered shape matches both producer and consumer. Flag if the topic is absent
   from the registry, or if the registered shape differs from the producer or consumer
   definition.

6. **Check role attribution, if a roles registry exists.** If the ecosystem tracks agent
   roles (e.g. `agent-roles.md`), verify the topic's write and read responsibilities are
   correctly attributed to the right agents. Flag if a role listed as writer does not
   actually produce the topic, or a role listed as reader does not actually consume it.

**Verdict scale:**
- PASS — All producers, consumers, topic strings, and schemas align; registry and roles match
- FAIL — Any mismatch found; each mismatch is a separate finding

**Common failure patterns:**
- Topic string prefix added on one side only: producer posts `loop-{SESSION_ID}-findings`,
  consumer awaits `{SESSION_ID}-findings`. Broker receives; no subscriber matches; messages
  silently drop.
- Field name casing drift: producer sends `{ agentId: "..." }`, consumer destructures
  `{ agent_id }`. No runtime error — consumer just sees `undefined`.
- Registry entry added for the topic but schema describes old fields from a refactor; neither
  producer nor consumer match the registered shape.
- Agent-roles.md lists Agent A as writer but Agent B was renamed in the latest skill revision;
  the cross-reference is stale.

---

## Severity Classification

### Blocking (B)

The document CANNOT be promoted/dispatched in this state.

Characteristics:
- Prevents agent execution entirely
- Creates invalid output (wrong file paths, runtime errors)
- Violates architectural constraints
- Contains contradictions that make execution impossible

Examples: wrong SQL syntax, two conflicting transformation rules, mount path errors

### Medium (M)

Gaps or inconsistencies that could lead to wrong output if not addressed.

Characteristics:
- Missing clarity that could cause agent confusion
- Incomplete specs (missing insertion points, exact content)
- Unverified claims against source code
- Contract deviations not explained

Examples: unspecified directory resolution, contradictory project_safe definition

### Advisory (A)

Minor issues that don't prevent execution but improve clarity.

Characteristics:
- Confusing but workable language
- Missing documentation with no impact on execution
- Edge cases not handled
- Suggestions for future improvement

Examples: port range mismatch notes, optional clarifying comments

---

## Panel Composition

The review simulates a panel of domain experts. Each check maps to panel roles:

| Role | Checks Owned |
|------|-------------|
| Context Designer | Check 1 (File-Line), Check 7 (Cold Read Gate) |
| Staff Platform Engineer | Check 1 (File-Line), Check 6 (Risky Values) |
| Staff DevOps Engineer | Check 6 (Risky Values) |
| Integration Architect | Check 3 (Source-of-Value), Check 4 (Cross-Reference) |
| Agent Orchestration Architect | Check 5 (Ambiguity Inversion) |
| Full Panel | Check 2 (Runtime Fork), Check 8 (Source Verification) |
| Integration Architect / Full Stack Engineer | Check 14 (Flow-Scope) |

---

## Multi-Wave Spec Protocol

For specs with multiple delivery waves (Wave 1 → Wave 2 → Wave 3), the review order matters:

**Run wave-scoped reviews BEFORE the full-document review, not after.**

Full-document reviews apply checks at document granularity and miss within-wave completeness gaps.
Wave-scoped reviews apply the same checks at wave granularity — "is THIS wave's task list complete
vs THIS wave's code blocks?" — and catch issues the full review glosses over.

**Protocol:**
1. For each wave in order: run Checks 1, 9, 10, 11, 13 (if wave has command ACs), and Check 12 for multi-section specs where the same value appears in more than one place — scoped to that wave's section only
2. Apply fixes per wave before moving to the next
3. After all waves are clean: run the full-document review (Checks 1–8 + 12) for cross-wave coherence

Check 14 is excluded from per-wave passes — it is cross-skill scoped, not within-wave scoped.

**Why:** The x_wiki spec required 5+ review passes because full-document reviews were run first
repeatedly. Wave-scoped passes at the end kept finding wave-specific completeness issues that
the coarser full review missed. Running wave-first eliminates this loop.

---

## Key Learnings (from real reviews)

These patterns were discovered during actual review cycles and should inform every review:

1. **replace_all operations are dangerous** — Global string replacements can hit places they
   shouldn't (e.g., changing `myapp` also changes Traefik hostnames that should keep hyphens).
   Always check the blast radius.

2. **Third-party services don't follow your contracts** — Verdaccio, Traefik, Redis, Postgres
   are third-party images that can't conform to `/_health`, structured JSON logging, or
   Traefik healthcheck labels. Contracts need scope clauses.

3. **Transformation methods matter** — "hyphens stripped" vs "hyphens to underscores" produces
   different results. When a transformation is defined, verify EVERY example matches.

4. **Cross-contract authority conflicts are subtle** — The database naming contract and
   environment provisioning contract can define different naming patterns for the same resource.
   The matrix check catches these.

5. **CWD-based vs argument-based CLI patterns** — Specs that say "run from project directory"
   need to document how the CLI finds files (CWD resolution, --dir override, getRepoRoot).

6. **Generated comments survive edits** — When a CLI signature changes, search for ALL places
   it appears in generated code/comments/examples. Old signatures in comments are Medium issues.

7. **File provider gotchas** — Traefik's file provider parses ALL files in its watched directory.
   Non-Traefik files (like JSON registries) must live elsewhere.

8. **The "Known Risky Values" section is a living document** — Every review that discovers a
   new risky pattern should add it to the spec's Known Risky Values list.

9. **Export surface failures are invisible to prose review** — A function can be described
   correctly, imported correctly, and still fail at build time if the source file's code block
   is missing `export`. Always run Check 9 for TypeScript/ESM specs — prose review alone misses it.

10. **Task lists and code blocks drift independently** — They are authored at different times
    and the author mentally fills in the gap. An agent does not. Every function shown in a code
    block must be traceable to a task list entry by name. Check 10 catches the delta.

11. **Task lists and AC tables are written separately and drift** — A Task 0 can appear in the
    AC table without ever being in the task list. A Task 9 can be in the task list without an
    AC. Check 11 prevents this by requiring count and numbering alignment.

12. **Within-document consistency degrades across sessions** — SQL quoting, ENV var names,
    function names — these drift when sections are written in different sessions. Check 12
    is the specific check for this; Check 3 (Source-of-Value) does not catch it.

13. **New checks must be validated before shipping** — Per `superpowers:writing-skills`:
    "If you didn't watch an agent fail without the skill, you don't know if the skill teaches
    the right thing." When adding new checks to this framework, test the check against a real
    failing case (e.g., x_wiki's export surface failures) before finalizing the check spec.

14. **Flow-scope mismatches are invisible to artifact-scoped review** — A producer posting to
    `loop-{SESSION_ID}-topic` and a consumer awaiting `{SESSION_ID}-topic` both look correct
    in isolation. Only a flow-scope check that traces the full producer→consumer chain catches
    the mismatch. Always run Check 14 for skills that communicate via a message bus.
