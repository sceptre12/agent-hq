# Delivery doc checks (stage 2): DOC-1 to DOC-4

Applies when the document under review is a delivery stage 2 artifact: `architecture.md`,
`dispatch-plan.md`, a delivery task spec, or an epic/child ticket draft (DOC findings apply to
delivery task specs only, INTERFACES 1.5.0 D2.3, AM-4 12). There is no input and no
mode flag; the document itself decides. These checks run in Phase A step 2 next to Checks
1-14 and report in the same findings table (`# | Issue | Severity | Check | Recommended Fix`)
with the label `DOC-<n>` in the Check column. They add no severity and no verdict word.

Severity is the existing scale (Blocking / Medium / Advisory, `references/checks.md`
"Severity Classification"): Blocking for a missing `architecture.md` section, a child
without AC (DOC-3) or a sub-task with no child draft (DOC-4; INTERFACES 1.5.0 D2.3, AM-4 12;
INTERFACES 1.6.0 AM-6 C-6); Medium for
an uncommanded `(fact)` and for a template-format miss; Advisory for wording. Every severity below is a plan-check default: a default, not an owner rule; the
caller may override it.

Sources (repo-relative): `architecture/delivery-workflow/part-04-templates.md` sections 5.1
(epic and child tickets), 5.2 (`architecture.md`), 5.3 (`dispatch-plan.md`) and 5.3b (unit
task spec); `architecture/delivery-workflow/part-05-execution-constraints.md` section 6.1
"Measured facts (command, date, where)"; the ticket-decomposer stop rule "child without AC"
in `architecture/delivery-workflow/part-03-personas-and-concurrency.md` section 3.2.

Locations (`architecture/delivery-workflow/interfaces/part-a-state.md` A.6 and
`architecture/delivery-workflow/interfaces/part-d-enums-topics.md` D1.1): `architecture.md`,
`dispatch-plan.md` and the ticket drafts `drafts/<slug>.md` live in `plans/<epic>/`; unit task
specs live in `.tasks/<unit>-<slug>.md`. `drafts/index.md` is an index (reserved slug
`index`), not a draft: no delivery check runs on it. Each draft opens with YAML front matter
of exactly `slug`, `issuetype` and `parent` (the parent slug, `-` for the epic). The epic
draft is the one whose `parent` is `-` (or whose `issuetype` is Epic); every other draft is a
child draft.

## Identifying a delivery stage 2 artifact

A document is a delivery stage 2 artifact, and these checks run, only when one of these holds:
- it is `architecture.md` or `dispatch-plan.md` inside a `plans/<epic>/` directory;
- it is a draft in `plans/<epic>/drafts/` (not `index.md`), or it opens with the
  `slug` / `issuetype` / `parent` front matter;
- it is a unit task spec at `.tasks/<unit>-<slug>.md` or under a `plans/<epic>/` tree, or it
  names itself a delivery unit task spec.

Any other document, including a task spec outside these locations, gets no delivery check,
no `DOC-` row and no status line. Path and self-description decide; there is no input.

## Applicability by document type

| Document under review | DOC-1 | DOC-2 | DOC-3 | DOC-4 |
|---|---|---|---|---|
| `architecture.md` | yes (14 sections) | yes | yes, parts 1-2, against the child drafts in `plans/<epic>/drafts/` | yes, on every draft in `plans/<epic>/drafts/` (not `index.md`), plus the sub-task coverage final sweep |
| `dispatch-plan.md` | yes (template 5.3) | yes | not applicable | not applicable |
| Unit task spec | yes (11 sections) | yes | not applicable | not applicable |
| Child ticket draft (alone) | not applicable (DOC-4 covers its sections) | yes | part 2 only | yes |
| Epic ticket draft (alone) | not applicable (DOC-4 covers its sections) | yes | not applicable | yes |

"Not applicable" produces nothing: no finding row, no `DOC-` token, no prose line. When a
check applies but its counterpart document is not available to the reviewer (the drafts for
an `architecture.md`, or the `architecture.md` for drafts), write one prose line without a label,
for example "delivery checks: child coverage unverifiable, drafts not provided", and still run
every part that the available documents allow. An unverifiable part is not a finding.

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
- `dispatch-plan.md`, the 18 items of template 5.3: Header (epic, repos, `repo-profile.md`
  link plus sha); Sub-task table; Version-bump list; Persona roster with tiers; Repo table;
  Unit table; Shared-file owner and serial-lane table; DAG and wave sketch; Lane table;
  Parallelism note; Shepherd cadence; Branching and merge order; Pre-PR gate rule; Cleanup
  rule; Pre-dispatch checklist; Stop-the-line table; Review rung table; Throughput formula.
- Ticket drafts: not a DOC-1 target; see DOC-4.

**`security_sensitive` line (`architecture.md` only; INTERFACES 1.5.0 D2.3, AM-4 12, AM-3; design
§5.2 per erratum E29):** the doc carries exactly one line `security_sensitive: yes` or
`security_sensitive: no`. Absent, repeated or another value is graded as a missing section.

**Pass rule:** every required section exists as a heading (or a named part for a split
epic) and is non-empty. A heading that holds only "TBD" or a placeholder is missing, with
one exception: in `architecture.md`, sections 12 (Review record) and 13 (Human acceptance
block) are filled by the stage 2 review and the human after it, so at review time each
passes with its heading plus the template skeleton (empty rung / seats / rounds fields;
the ACCEPT / CHANGES / REJECT options with a blank name and date). Only a missing heading
12 or 13 fails.

**Finding text:** `DOC-1: <doc> has <n> of <14|11|18> required sections; missing: <names>.`
or `DOC-1: architecture.md Summary has <n> lines (template: 15 or fewer).`

**Severity (plan-check default):** Blocking for a missing `architecture.md` section; Medium
(template-format miss) for a missing section in a unit task spec or `dispatch-plan.md`, and
for an `architecture.md` Summary over 15 lines; Advisory (wording) for section wording or
order.

**Worked example.** A 13-heading `architecture.md` ends at "13 Human acceptance block" and has
no "Provenance". Finding: `| 1 | DOC-1: architecture.md has 13 of 14 sections; missing: 14
Provenance | Blocking | DOC-1 | Add the Provenance section (source docs, dates, author) |`.
Count the headings against the list above; the count is 14.

## DOC-2 Every "(fact)" names its command

**Reads:** every occurrence of the tag `(fact)` in the document, and the text beside it.

**Pass rule:** a claim tagged `(fact)` carries the command that measured it, the date
(YYYY-MM-DD) and where it ran (path, host, repo or worktree), inline or in a footnote the
claim links to. DOC-2 checks that a command is NAMED; whether the command's output really
supports the claim is Check 8 (Source Verification) and is not repeated here. A tagged claim
whose command is only "checked" or "verified" with no command string fails.

**Finding text:** `DOC-2: "(fact)" at <line/section> has no command: "<claim excerpt>".` or
`DOC-2: "(fact)" at <line/section> lacks <date | where>: "<claim excerpt>".`

**Severity (plan-check default):** Medium for an uncommanded `(fact)`; Advisory (wording)
when the command is present but the date or where is missing, or the format is inconsistent.

**Worked example.** Line: `The CI pipeline runs in 9 minutes (fact).` Finding: `| 2 | DOC-2:
"(fact)" at section 8 has no command: "CI pipeline runs in 9 minutes" | Medium | DOC-2 |
Add the measuring command, date and where, or drop the tag |`. Passing form: `The CI
pipeline runs in 9 minutes (fact: gh run view 123 --json durationMs, 2026-10-20, repo X).`

## DOC-3 Child coverage

Builds on the Cross-Reference Walk (Check 4); use its method, do not restate it.

**Reads:** the epic and sub-task tree in `architecture.md` section 5, and every child ticket
draft in `plans/<epic>/drafts/` (or the single child draft under review). The epic draft and
`drafts/index.md` are not child drafts and are outside parts 1-2.

**Pass rule (two parts, both required where applicable):**
1. Every child draft is reachable from the architecture doc: it appears as a node of the
   section 5 tree (by id or title).
2. Every child draft has acceptance criteria: an "Acceptance criteria" section that exists
   and holds any content other than a placeholder. A child whose AC section is absent, empty
   or only "TBD" is a child without AC (the ticket-decomposer stop rule). Whether present AC
   is well formed (Gherkin, case kinds) is DOC-4, not DOC-3.

Part 1 needs both `architecture.md` and the drafts; reviewing a lone draft runs part 2
only (see Applicability). A sub-task with no child draft is DOC-4 (final sweep), not DOC-3
(INTERFACES 1.6.0 AM-6 C-6).

**Finding text:** `DOC-3: <orphan draft <id> | child <id> has no AC>.`

**Severity:** Blocking for a child without AC (INTERFACES 1.5.0 D2.3, AM-4 12);
Medium (plan-check default) for a draft not in the tree; Advisory (wording) for a title mismatch between
tree and draft when the id matches.

**Worked example.** The tree lists sub-tasks S1, S2, S3; drafts exist for S1 and S2, and the
S2 draft has an empty "Acceptance criteria" heading. Finding: `| 3 | DOC-3: child S2 has no AC | Blocking | DOC-3 | Add Gherkin AC
(happy, failure or edge, observability) |`; S3 is reported under DOC-4 (final sweep).

## DOC-4 Template format

**Reads:** each epic and child ticket draft (never `drafts/index.md`), against design
template 5.1 and the A.6 draft front matter, and the
`dispatch-plan.md` unit table when it is available; for the final sweep, the section 5 tree
of `architecture.md`. **Scope: template format only** (header fields, section presence and
order, AC shape, agent additions), plus the final sweep below. A content judgment about a
draft (wrong scope, weak reasoning, a missing epic draft) is a finding under this skill's
normal checks (Checks 1-14), never a `DOC-` label.

**Pass rule, every draft:**
- Front matter (A.6): YAML keys exactly `slug`, `issuetype`, `parent`, no more, no fewer.
- Header fields (5.1): issue type, team, epic link, priority, requested by. The front matter
  `issuetype` satisfies issue type and `parent` satisfies epic link; team, priority and
  requested by sit in the body header under the front matter.
- Body sections in order: Summary; Problem (background, current, expected, evidence);
  Impact; Business value; Requirements (functional; non-functional); Acceptance criteria;
  Dependencies; Risks; Subtasks.
- Acceptance criteria are Gherkin (Given/When/Then) with three kinds of case: a happy case,
  a failure-or-edge case (either kind satisfies it), and an observability case. Happy-only
  AC fails; AC written as bullets or prose without Given/When/Then fails.
- Epic additions, only for the epic draft (`parent: -`): phases, dependency map, typed
  children, spikes first and timeboxed, open questions. A child draft is never checked for
  them.
- Agent additions, only for an agent-executed child: scope globs, persona and tier,
  blocked-by, lanes, test expectations (unit, integration, e2e yes or no with reason), done
  token, verifier, budget. A child is agent-executed when it carries any agent-addition field
  or the `dispatch-plan.md` unit table lists its ticket; otherwise skip this bullet.

**Final sweep (needs `architecture.md` and the drafts):** every sub-task in the section 5
tree has at least one child draft. A sub-task with none is Blocking (stage 3 would dispatch
nothing for it; INTERFACES 1.5.0 D2.3, AM-4 12; INTERFACES 1.6.0 AM-6 C-6). Reviewing a lone
draft skips the sweep (see Applicability).

**Boundary with DOC-3.** For a child draft, AC absent, empty or placeholder only: DOC-3
(child without AC), never also DOC-4; for the epic draft it is a DOC-4 missing section.
AC present but malformed (not Gherkin, or a case kind missing): DOC-4.
Report each draft's AC under exactly one of the two.

**Finding text:** `DOC-4: draft <id> deviates from the ticket template: <front matter keys
not exactly slug, issuetype, parent | missing header field | missing section | AC not
Gherkin | AC lacks <failure-or-edge|observability> case | missing epic addition | missing
agent addition>.` Final sweep: `DOC-4: sub-task <id> has no child draft.`

**Severity (plan-check default):** Blocking for a sub-task with no child draft (final sweep);
Medium for a template-format miss (front matter keys,
missing header field, section, Gherkin form, AC case kind, epic addition or agent addition);
Advisory (wording) for wording, ordering or capitalisation.

**Worked example.** Child draft C4 has Gherkin AC with one happy scenario and one failure
scenario and nothing about logging or metrics. Finding: `| 5 | DOC-4: draft C4 AC lacks an
observability case | Medium | DOC-4 | Add a scenario stating what is logged or measured |`.
In the DOC-3 example, S3 gives `| 4 | DOC-4: sub-task S3 has no child draft | Blocking | DOC-4 |
Draft S3 or remove it from the tree |`.

## Reporting

- One row per finding; the Check column holds `DOC-1`..`DOC-4`. The `DOC-` label appears ONLY in
  those finding rows (and in the finding text of a row): never in the report header, a "run" or
  "clean" line, an unverifiable line, a summary or any other prose. A clean document produces
  no `DOC-` token at all.
- Report a delivery-check miss once, under its `DOC-` row; do not repeat it as a cold-read
  (Step 1) or Checks 1-14 row.
- Status line, in prose and without a label, once per report on a delivery stage 2 artifact:
  "delivery checks: clean" when the parts that ran produced no finding row and no part was
  unverifiable; "delivery checks: clean, partial" when the parts that ran produced no finding
  row but a part was unverifiable; "delivery checks: run" when they produced at least one
  finding row. Each unverifiable line (see Applicability) follows the status line, so a
  "clean" never stands next to an unverifiable part without saying "partial".
- Tokens such as `ARCH: ready` and `DRAFTS: n drafts` belong to the delivery-architecture
  caller; this skill only reports findings and its verdict.
- Phase B (wait for a decision) is unchanged; an unattended caller supplies the decision.
