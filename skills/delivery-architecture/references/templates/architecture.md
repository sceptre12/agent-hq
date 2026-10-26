# Template: architecture.md (design 5.2)

Purpose: the single design document of one epic, reviewed at stage 2 and accepted at H1. Path `plans/<epic>/architecture.md`. About 500 lines or fewer; a large epic uses a landing page plus parts (design 5.2), each linked from the landing page; the part file names (`architecture-01.md`, ...) are template-local.

**Writer / Reader:** writer `delivery-architecture` (INTERFACES A.6); readers the human at H1, `delivery-dispatch-plan` (sections 5 to 9), the conductor (reads the header line `security_sensitive`), `review-tailor`, `test-plan.md` and `release-plan.md` authors.

## Header lines (before section 1)
````markdown
# Architecture: <epic title>
epic: <epic>
repo_profile: <path>@<40-hex sha>
security_sensitive: yes|no
````
- The `epic:` and `repo_profile:` header lines are template-local (no INTERFACES key); only `security_sensitive` is read by a consumer (INTERFACES A.2).
- `epic` is the original-case epic token (INTERFACES A.1).
- `repo_profile` links the profile with its full 40-hex sha and never copies it (D22).
- `security_sensitive: yes|no` is required: exactly one such line, `no` allowed (INTERFACES 1.3.0 A.2, AM-3, owner OQ-1). Write `yes` when the epic touches any of:
  - auth;
  - secrets;
  - money;
  - personal data;
  - the e2e mock or auth-bypass gate;
  - network-facing input parsing;
  - a new third-party dependency;
  - and `yes` when unsure.
  Otherwise write `no`. `yes` makes the conductor set `state.md` `security_audit: full`; `no` leaves the default `guidance` (INTERFACES A.2, D2.1 `guidance|full`).

## Skeleton (14 sections, in this order)
````markdown
## 1. Summary
<at most 15 lines>

## 2. Goals and non-goals
- Goals: <...>
- Non-goals: <...>

## 3. Components, interfaces, contracts
Primary repo: <abs clone root; restates `state.md` `primary_repo`>
Other repos: <abs clone roots of the other repos of a multi-repo epic, or `none`>
(INTERFACES A.1 multi-repo rule: the primary repo governs; the other repos' profiles are its `linked_profiles[]`, A.2.2.)

| component | responsibility | interface or contract | owning document |
|---|---|---|---|
One owning document per cross-unit contract (D63, design `part-06-build-plan-and-sources.md` stage 2 row); contracts live under `contracts/` at the repo root.

## 4. Decisions
- Locked: <decision> (ADR <ref>)
- Open: <decision> (who decides, by when)

## 5. Epic and sub-task tree, merge order
| sub-task | scope | depends-on (sub-task id or `independent`) | merge order | ticket slug |
|---|---|---|---|---|
Sub-task 0 is the plan PR (D5).

## 6. Scope
- In: <...>
- Out: <...>
- External open items: <...>

## 7. Dispatch-plan requirement
<what `delivery-dispatch-plan` must honour: serial lanes, shared-file owners, ports to claim, units that must not run in parallel>

## 8. Testing plan pointer
Link `test-plan.md`. E2E harness statement: harness present (`e2e.harness` per the repo profile) or gap named (D17).

## 9. Release sketch pointer
Link `release-plan.md`. Agent-run versus human split in one line each (D15).

## 10. Risks and stop-the-line
| risk | signal | stop-the-line action |
|---|---|---|

## 11. Diagrams (text)
<ASCII or mermaid source; no images>

## 12. Review record
Rung: <0|1|2|2b|3|4>; seats: <ids>; rounds: <n of at most 3>; open findings at round 3: <list or none>
Record file: `review-architecture.md`.

## 13. Human acceptance (H1)
Verdict: ACCEPT | CHANGES | REJECT
Name: <name>
Date: <YYYY-MM-DD>
The verdict is written by the human through the desk as `H1.ok`, `H1.changes` or `H1.reject` (INTERFACES A.2.1); this block only mirrors it. An agent never fills it.

## 14. Provenance
Sources: <brief.md, facts.md, ADRs, tickets>; authored <YYYY-MM-DD> by `delivery-architecture`.
````

## Checks before the H1 packet
- Section 5 ids and ticket slugs match `drafts/index.md`.
- Section 8 and 9 exist even when the answer is "none, because ...".
- Every enum cited (persona, tier, issue type) is the INTERFACES D2.1 value.
- Unmeasured values are `FILL_IN_BEFORE_DISPATCH`.
