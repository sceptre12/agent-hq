---
name: doc-reviewer
description: >
  Single-agent, 10-step / 3-phase checklist review (Discovery, Decision, Resolution) for
  architecture docs, addendums, task specs, and standards — catches contradictions
  introduced across edit rounds, claims that drift from source code, and cross-cutting
  contract conflicts that only surface when every reference is actually checked. Use when
  a document needs a quality gate before it's finalized or dispatched — whether freshly
  authored in one pass by another agent or accreted over 2+ editing rounds — or when asked
  to "review this doc," "run the checks," "cold read this," "check for conflicts," or "is
  this ready to ship." This is Rung 1 on the
  review ladder (tools/review-ladder.md) — single-artifact, routine review with
  auditability. For contested decisions or multi-perspective review of medium-stakes
  artifacts, escalate to panel-consultation instead (Rung 2). For typo-level or purely
  mechanical checks, review directly (Rung 0) rather than invoking this skill.
---

## Trigger

Use when a document needs a quality gate before being finalized or dispatched — whether
freshly authored in one pass by another agent or accreted over 2+ editing rounds — a new
addendum, standard, or task spec; before marking anything READY FOR DISPATCH; or whenever
asked to "review," "panel review," "check," "cold read," or "run the framework" on a
document. This is Rung 1 on the review ladder (`tools/review-ladder.md`): a single-agent
checklist review for routine, single-artifact review. A multi-file plan directory (e.g. an
overview.md plus a tasks/ directory) reviewed together as one logical artifact is in scope
too, up to what a single context window can hold — escalate to a heavier review only when
coherent single-context review is no longer possible. It is not a substitute for
panel-consultation (Rung 2) when the review is genuinely contested or the artifact spans
multiple systems.

Before starting, gather:
1. The document to review (file, pasted text, or a link/page ID if it lives in a wiki/doc
   tool).
2. The project's contracts/interfaces directory, if one exists (path is project-specific —
   skip Step 4's matrix if none exists).
3. Source code access, for Step 3 (Source Verification), if the doc modifies existing code.
4. Context about what the doc changes — is it a new addendum? An edit to existing? A new
   standard?

Core principle: every finding is presented for a decision before any edit is applied.
Never auto-apply fixes.

## Steps

Read `references/checks.md` for the full spec of every check before executing — the table
below is the authoritative inventory (`references/checks.md` must contain one full spec per
row; if they diverge, `references/checks.md` is stale).

| Check | Name | Applies to |
|---|---|---|
| 1 | File-Line Test | All specs |
| 2 | Runtime Fork Scan | All specs |
| 3 | Source-of-Value Audit | All specs |
| 4 | Cross-Reference Walk | All specs |
| 5 | Ambiguity Inversion Test | All specs |
| 6 | Risky Value Scan | Infrastructure specs |
| 7 | Cold Read Gate | All specs |
| 8 | Source Verification Gate | Addendum specs (existing files) |
| 9 | Export Surface Check | TypeScript/ESM specs |
| 10 | Task List vs Code Blocks | Multi-task specs |
| 11 | Task List vs AC Table | Specs with AC tables |
| 12 | Within-Document Value Consistency | Multi-section specs |
| 13 | AC Runability Check | Specs with command ACs |
| 14 | Flow-Scope Check | Specs/skills with bus topics or message flows |

**Phase A — Discovery (find every issue)**

1. **Cold read.** Read the document end-to-end with zero prior context. Ask: "if I handed
   this to an agent who wasn't in the room, would they produce the correct output?" Check
   for 6 symptoms: incomplete specs, redundant definitions, contradictory statements,
   rendering artifacts (placeholder YAML, TODOs), scope confusion, ambiguous procedures.
   Record every finding with a severity tag (Blocking / Medium / Advisory — full
   classification in `references/checks.md`).
2. **Run the pre-flight checks.** Checks 1–7 always. Check 8 for addendums to an existing
   codebase (skip for net-new specs). Checks 9–13 for TypeScript implementation specs,
   multi-wave delivery specs, or any spec with an explicit task list + AC table. Check 14
   for any skill/doc that defines, produces, or consumes bus topics or inter-agent message
   flows. Full definitions, verdict scales, and examples: `references/checks.md`.
3. **Source Verification (Check 8).** For any section changing EXISTING files: first check
   whether a completed task spec already has an "Implementation Patterns" section (cheap);
   otherwise read the actual source (expensive but necessary). If source is inaccessible,
   record 'unverifiable — source inaccessible' rather than skipping silently. Record which
   path was taken.
4. **Cross-cutting matrix and Architectural Impact Check.**
   - **Cross-cutting matrix:** conditional on a contracts/interfaces directory existing —
     if the project has one, list every file in it and check the document against each
     one, non-negotiable, even ones that look unrelated, and classify each as CONFLICT /
     TENSION / CLEAN. If no such directory exists, this sub-step is N/A.
   - **Architectural Impact Check:** always runs, regardless of whether a
     contracts/interfaces directory exists — confirm the doc is a pure extension (no
     modified interfaces, no broken backward compatibility).

   Output formats: `references/checks.md`.

**Phase B — Decision (present findings, get a decision)**

5. **Compile findings** into one table (`# | Issue | Severity | Check | Recommended Fix`),
   plus severity totals, the cross-cutting matrix, and the architectural impact verdict.
6. **Present the full findings** — severity summary, findings table, matrix, impact
   verdict, and an overall verdict of READY / NOT READY / READY WITH CONDITIONS.
7. **Wait for a decision** on every finding: apply now, defer, reject, or modify. Do not
   proceed to Phase C until findings are reviewed and approved.
8. **Confirm scope** explicitly before touching anything: state exactly which findings will
   be applied and which deferred, and get confirmation.

**Phase C — Resolution (apply only what was approved)**

9. **Apply only approved fixes.** For each: make the edit (wherever the doc lives, plus any
   contract file), verify it didn't introduce a new issue, and check surrounding content
   still makes sense.
10. **Post-fix verification.** Re-read affected sections for coherence, verify
    cross-cutting fixes (scope clauses, coexistence notes) landed in the right place, and
    report a summary of what changed.

Severity classification, panel-role mapping, the multi-wave review protocol, and the full
Key Learnings list are in `references/checks.md`.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "This doc is contested and cuts across systems, but I'll just run doc-reviewer solo." | Escalate to panel-consultation (Rung 2) per `tools/review-ladder.md` — a single-agent checklist review isn't built for genuine multi-perspective disagreement. |
| "I already know this document, I don't need a zero-context cold read." | Context blindness is the specific failure iterative editing creates — reviewers fill gaps from shared understanding an agent won't have. Run the cold read anyway (Step 1). |
| "It's just a global find-replace, low risk." | Check the blast radius first — a replace_all can hit strings it shouldn't (e.g. a shared substring that also appears somewhere that must stay untouched). |
| "This TypeScript spec already passed prose review." | Prose review misses missing `export` keywords entirely — run Check 9 regardless; a function can be described and imported correctly and still fail at build time. |
| "The task list is just a summary, the code blocks are the real spec." | Task lists, code blocks, and AC tables are authored at different times and drift independently — run Checks 10–11 to reconcile them, don't assume they agree. |
| "This new check looks reasonable, ship it." | Validate any new check against a real failing case before finalizing it (per `superpowers:writing-skills`) — an unvalidated check may not catch what it claims to. |
| "I'll review the full document first, then check individual waves." | For multi-wave specs, run wave-scoped checks BEFORE the full-document review — full-first misses within-wave completeness gaps that wave-scoped passes catch (one recorded spec needed 5+ passes because of this ordering mistake). |
| "Third-party services should follow our contracts too." | They can't — contracts need explicit scope clauses for third-party components that can't be made to conform. |

## Exit criteria

- [ ] Every finding is tagged Blocking / Medium / Advisory and appears in the findings
      table.
- [ ] The cross-cutting matrix (if a contracts directory exists) has one row per contract
      with a CONFLICT/TENSION/CLEAN verdict.
- [ ] The overall verdict (READY / NOT READY / READY WITH CONDITIONS) is stated.
- [ ] No fix was applied without an explicit decision recorded first.
- [ ] Applied fixes were re-verified for coherence (Step 10) before reporting completion.

## Provenance
Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md; the recorded port friction)
Lineage: X-context-docs skills/doc-reviewer@0e9281e
