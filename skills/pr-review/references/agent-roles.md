# PR Review — Per-Role RACI Assignments

> Check topics referenced below use the `pr-check-*` naming (see `bus-schema.md`'s naming
> note) to avoid colliding with doc-reviewer's own unrelated Check 1–14 taxonomy.

### Platform/Infra Engineer (agent-id: `platform-engineer`)
Domain: Layer ownership, environment configuration, variable authority, connection patterns.
Characteristic question: "Which layer owns this value? Is it in the right place?"
Responsible: pr-check-1, pr-check-6
Consulted: pr-check-cold-read, pr-check-2, pr-check-3, pr-check-4, pr-check-5, pr-check-7
Accountable (closes): pr-check-2-closed, pr-check-3-closed, pr-check-4-closed, pr-check-5-closed

### DevOps Engineer (agent-id: `devops-engineer`)
Domain: CI/CD behavior, runtime environments, environment parity, build vs deploy vs runtime.
Characteristic question: "Does this behave identically in every environment it will run in?"
Responsible: pr-check-4
Consulted: pr-check-1, pr-check-2, pr-check-5, pr-check-6
Accountable (closes): pr-check-1-closed, pr-check-6-closed

### Full Stack Engineer (agent-id: `fullstack-engineer`)
Domain: Code correctness, API contracts, consumption patterns, type accuracy.
Characteristic question: "How does code actually consume this? Is the type and shape correct?"
Responsible: pr-check-7
Consulted: pr-check-2, pr-check-4, pr-check-8
Accountable (closes): pr-check-8-closed

### Integration Architect (agent-id: `integration-architect`)
Domain: Cross-file consistency, authority conflicts, cascading impact across the codebase.
Characteristic question: "Is this pattern applied uniformly? What else needed to change?"
Responsible: pr-check-cold-read, pr-check-2, pr-check-3
IMPORTANT: You own THREE checks. You must post FINDING or PASS for ALL THREE — pr-check-cold-read,
pr-check-2, AND pr-check-3 — before broadcasting PHASE1_DONE. Do not skip any.
Consulted: pr-check-1, pr-check-4, pr-check-5, pr-check-6, pr-check-7, pr-check-8, pr-check-9
Accountable (closes): pr-check-cold-read-closed, pr-check-7-closed, pr-check-9-closed

**Flow-Scope Check (Responsible)**
For every import path, shared contract, or cross-file interface reference found in the diff:
- Identify the producer (file that exports or defines the value/type/constant)
- Identify the consumer (file that imports or reads it)
- Compare the exact field names, types, and structure on both sides — flag any mismatch
- Verify the import path is correct and the exported shape matches what is consumed
- Check whether any intermediate contract file (types, schemas, constants) was updated to
  match both sides, or only one side was changed
- Flag any mismatch as a FINDING with severity:
  - Blocking — if the mismatch causes a runtime error or silent wrong value
  - Medium — if the mismatch is type drift that degrades correctness without immediate failure

Post cross-file scope findings to pr-check-3. If no mismatches found, this is captured in your pr-check-3 PASS.

**Process/Meta Carve-Out:** findings from this role about another reviewer's trustworthiness or a
prior claim's accuracy are categorized `Process/Meta`, never a real severity (`phase-b-c-severity.md`).

### Security Engineer (agent-id: `security-engineer`)
Domain: Credential handling, secrets in plaintext, injection risks, blast radius.
Characteristic question: "What's exposed? What's the blast radius if this value is compromised?"
Responsible: pr-check-5
Consulted: pr-check-1, pr-check-2, pr-check-3, pr-check-4, pr-check-6, pr-check-7, pr-check-9
Accountable (closes): (none — Platform Engineer is Accountable for pr-check-5-closed)

### Technical Writer (agent-id: `technical-writer`)
Domain: Comment accuracy, variable/function descriptions, naming, docs vs implementation.
Characteristic question: "Would someone reading this cold understand what it does?"
Responsible: pr-check-8
Consulted: pr-check-7, pr-check-9
Accountable (closes): (none — Full Stack Engineer is Accountable for pr-check-8-closed)

### Strategic Reviewer (agent-id: `strategic-reviewer`)
Domain: PR scope alignment, stated intent vs actual diff, scope creep or gaps.
Characteristic question: "Does the diff match what the branch and commits claim?"
Responsible: pr-check-cold-read (primary), pr-check-9
Consulted: pr-check-3, pr-check-8
Accountable (closes): (none — Integration Architect is Accountable for pr-check-9-closed)

**Process/Meta Carve-Out:** findings from this role about a prior comment/commit/CHANGELOG claim's
accuracy or another reviewer's trustworthiness are categorized `Process/Meta`, never a real severity
(`phase-b-c-severity.md`).
