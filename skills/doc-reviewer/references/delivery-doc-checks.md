# Delivery doc checks (stage 2): DOC-1 to DOC-4

Applies when the document under review is a delivery stage 2 artifact: `architecture.md`,
`dispatch-plan.md`, a task spec, or an epic/child ticket draft. There is no input and no
mode flag; the document itself decides. These checks run in Phase A step 2 next to Checks
1-14 and report in the same findings table (`# | Issue | Severity | Check | Recommended Fix`)
with the label `DOC-<n>` in the Check column. They add no severity and no verdict word.

Severity is the existing scale (Blocking / Medium / Advisory, `references/checks.md`
"Severity Classification"). Each severity below is a plan-check default (Q12-3), a proposal
and not an owner rule; the caller may override it.

Sources: the delivery design templates, section 5.1 (epic and child tickets) and section 5.2
(`architecture.md`), plus 5.3, 5.3b, 5.4, 5.5 for the other documents; the "Measured facts
(command, date, where)" convention of the execution-constraints part; the ticket-decomposer
stop rule "child without AC".

## DOC-1 Required sections present

**Reads:** the heading list of the document, compared with the section list for its type.

**Section lists (count them; do not trust the doc's own numbering):**
- `architecture.md`, 14 sections: 1 Summary (15 lines or fewer); 2 Goals and non-goals;
  3 Components, interfaces, contracts; 4 Locked decisions with ADR references (and open
  decisions); 5 Epic and sub-task tree with merge order; 6 Scope (in, out, external open
  items); 7 Dispatch-plan requirement; 8 Testing plan pointer incl. the e2e harness statement
  (present, or gap named); 9 Release sketch pointer with the agent-run / human split;
  10 Risks and stop-the-line; 11 Diagrams as text; 12 Review record (rung, seats, rounds,
  open findings if round 3); 13 Human acceptance block (ACCEPT / CHANGES / REJECT, name,
  date); 14 Provenance. A large epic may split into a landing page plus parts; then the
  union of the parts must carry all 14.
- Unit task spec, 11 sections: Objective; Context package; Scope (in, out, do-not-create);
  Contracts table; Inherited module API; What you inherit; Known risky values; Acceptance
  criteria; Verification commands; Branch and worktree; Decision Gate reminder.
- `dispatch-plan.md`, `test-plan.md`, `release-plan.md`: the field lists of design templates
  5.3, 5.4, 5.5 respectively (header, tables, rules named there).
- Ticket drafts: see DOC-4.

**Pass rule:** every required section exists as a heading (or a named part for a split
epic) and is non-empty. A heading that holds only "TBD" or a placeholder is missing.
Section 1 over 15 lines is a finding.

**Finding text:** `DOC-1: <doc> has <n> of <14|11> required sections; missing: <names>.`

**Severity (plan-check default):** Blocking for a missing `architecture.md` section or a
missing task-spec section; Medium for a missing section in the other delivery docs;
Advisory for wording, order or a Summary slightly over 15 lines.

**Worked example.** A 13-heading `architecture.md` ends at "13 Human acceptance block" and has
no "Provenance". Finding: `| 1 | DOC-1: architecture.md has 13 of 14 sections; missing: 14
Provenance | Blocking | DOC-1 | Add the Provenance section (source docs, dates, author) |`.
Counting trap: the older 11- and 13-section lists are wrong; the count is 14.

## DOC-2 Every "(fact)" names its command

**Reads:** every occurrence of the tag `(fact)` in the document, and the text beside it.

**Pass rule:** a claim tagged `(fact)` carries the command that measured it, the date
(YYYY-MM-DD) and where it ran (path, host, repo or worktree), inline or in a footnote the
claim links to. DOC-2 checks that a command is NAMED; whether the command's output really
supports the claim is Check 8 (Source Verification) and is not repeated here. A tagged claim
whose command is only "checked" or "verified" with no command string fails.

**Finding text:** `DOC-2: "(fact)" at <line/section> has no command: "<claim excerpt>".`

**Severity (plan-check default):** Medium for an uncommanded `(fact)`; Advisory when the
command is present but the date or where is missing, or the format is inconsistent.

**Worked example.** Line: `The CI pipeline runs in 9 minutes (fact).` Finding: `| 2 | DOC-2:
"(fact)" at section 8 has no command: "CI pipeline runs in 9 minutes" | Medium | DOC-2 |
Add the measuring command, date and where, or drop the tag |`. Passing form: `The CI
pipeline runs in 9 minutes (fact: gh run view 123 --json durationMs, 2026-10-20, repo X).`

## DOC-3 Child coverage

Builds on the Cross-Reference Walk (Check 4); use its method, do not restate it.

**Reads:** the epic and sub-task tree in `architecture.md` section 5, the dispatch plan unit
table if present, and every child ticket draft in the drafts directory.

**Pass rule (three parts, all required):**
1. Every child draft is reachable from the architecture doc: it appears as a node of the
   section 5 tree (by id or title).
2. Every sub-task in the tree has at least one child draft.
3. Every child draft has acceptance criteria (a non-empty AC block with at least one
   scenario). A child without AC is the ticket-decomposer stop rule.

If the drafts directory is not available to the reviewer, report `DOC-3: unverifiable - drafts
not provided` for parts 1-2 and still check part 3 on any draft supplied.

**Finding text:** `DOC-3: <orphan draft <id> | sub-task <id> has no draft | child <id> has no
AC>.`

**Severity (plan-check default):** Blocking for a child without AC; Blocking for a sub-task
with no draft or a draft not in the tree; Advisory for a title mismatch between tree and
draft when the id matches.

**Worked example.** The tree lists sub-tasks S1, S2, S3; drafts exist for S1 and S2, and the
S2 draft has an empty "Acceptance criteria" heading. Findings: `| 3 | DOC-3: sub-task S3
has no child draft | Blocking | DOC-3 | Draft S3 or remove it from the tree |` and `| 4 |
DOC-3: child S2 has no AC | Blocking | DOC-3 | Add Gherkin AC (happy, failure or edge,
observability) |`.

## DOC-4 Template format

**Reads:** each epic and child ticket draft, against design template 5.1. **Scope: template
format only** (header fields, section presence and order, AC shape, agent additions). A content
judgment about a draft (wrong scope, weak reasoning, a missing epic draft) is a finding under
this skill's normal checks (Checks 1-14), never a `DOC-` label.

**Pass rule, every draft:**
- Header fields: issue type, team, epic link, priority, requested by.
- Body sections in order: Summary; Problem (background, current, expected, evidence);
  Impact; Business value; Requirements (functional; non-functional); Acceptance criteria;
  Dependencies; Risks; Subtasks.
- Acceptance criteria are Gherkin (Given/When/Then) with three kinds of case: a happy case,
  a failure or edge case, and an observability case. Happy-only AC fails.
- Epic additions: phases, dependency map, typed children, spikes first and timeboxed, open
  questions.
- Agent additions (child drafts that agents execute): scope globs, persona and tier,
  blocked-by, lanes, test expectations (unit, integration, e2e yes or no with reason), done
  token, verifier, budget.

An AC block that is entirely absent is a DOC-3 finding (child without AC), not a DOC-4
finding; do not report it twice. DOC-4 covers a present but malformed template.

**Finding text:** `DOC-4: draft <id> deviates from the ticket template: <missing header
field | missing section | AC lacks <failure|edge|observability> case | missing agent
addition>.`

**Severity (plan-check default):** Medium for a template-format miss (missing header field,
section, AC case kind or agent addition); Advisory for wording, ordering or capitalisation.

**Worked example.** Child draft C4 has Gherkin AC with one happy scenario and one failure
scenario and nothing about logging or metrics. Finding: `| 5 | DOC-4: draft C4 AC lacks an
observability case | Medium | DOC-4 | Add a scenario stating what is logged or measured |`.

## Reporting

- One row per finding; the Check column holds `DOC-1`..`DOC-4`. The `DOC-` label appears ONLY in
  those finding rows (and in the finding text of a row): never in the report header, a "ran" or
  "clean" line, a summary or any other prose. A clean document produces no `DOC-` token at all;
  state "delivery checks: clean" in prose without the label.
- Tokens such as `ARCH: ready` and `DRAFTS: n drafts` belong to the delivery-architecture
  caller; this skill only reports findings and its verdict.
- Phase B (wait for a decision) is unchanged; an unattended caller supplies the decision.
