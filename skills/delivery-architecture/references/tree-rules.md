# Tree rules: typed tree, spikes first, slugs, checks

Sources: design v2 card 3; part-04 §5.1 (tickets), §5.2 (`architecture.md`); INTERFACES 1.5.0 (`architecture/delivery-workflow/INTERFACES.md:3`) part A.1 `<slug>` (`interfaces/part-a-state.md:7-53`), A.6 (`drafts/<slug>.md`, `drafts/index.md`; `part-a-state.md:293-334`), D1.1 `DRAFTS:` (`interfaces/part-d-enums-topics.md:12-31`), D2.1 ticket issue type and e2e per unit (`:34-68`); AM-2 row 10 (draft front matter, plan-check default PC-11).

## Typed tree

- Exactly one `Epic` node, the root; its draft has `parent: -`.
- Children use only `Spike`, `Story`, `Task`, `Subtask` (D2.1, capitalised as written).
- `Story`: a user-visible or consumer-visible behaviour; carries Gherkin AC. `Task`: technical work with no user-visible behaviour (still has a done condition and a verifier). `Subtask`: a slice of one Story or Task; its parent is that Story or Task, never the Epic. `Spike`: a timeboxed question.
- Spikes first: every unknown that blocks a design choice becomes a `Spike` placed before the nodes it unblocks (in `drafts/index.md` order and in `architecture.md` item 5). Each Spike states its question, its timebox (from the profile `durations.*`, or `FILL_IN_BEFORE_DISPATCH`), and its exit (the decision it feeds and who takes it).
- Epic additions (part-04 §5.1): phases, dependency map, typed children, open questions.
- Merge order (owner ruling D5): one PR per sub-task; `architecture.md` item 5 gives the tree with merge order (§Item 5); the dispatch plan cuts sub-tasks from it later (this skill writes no dispatch plan).

## Item 5

`architecture.md` item 5 uses the template columns `sub-task | scope | depends-on | merge order | ticket slug` (`templates/architecture.md:50-53`). Rows (defaults of this skill where the template is silent):
- `st0`, the plan PR (D5): scope `plans/<epic>/*`, `contracts/`, `.tasks/`, plus the repo path of every existing doc step 1 updated (so the dispatch plan's `st0` commits it); ticket slug `-` (no draft); merge order 1.
- One row `st<N>` (`N` = 1, 2, ... in merge order) per node built in its own PR: a `Story` or `Task` with no `Subtask` child, or a `Subtask`; ticket slug its draft slug; merge order `N + 1`; depends-on a sub-task id or `independent`.
- One row per other draft (the `Epic`, a `Spike`, a `Story` or `Task` split into `Subtask`s) with sub-task `-`, merge order `-`, depends-on `-`, so every draft slug appears exactly once in the ticket-slug column. A `Spike` whose exit commits files gets an `st<N>` row instead.
- Story-scale versus epic-scale (for the card 3 rung floor, a default of this skill): the tree is story-scale when the Epic has exactly one non-Spike child and no Spike; otherwise epic-scale. A one-way door (an irreversible choice in `architecture.md` item 4) raises the floor to 4.

## Slug minting

1. Start from the node's summary; lowercase it.
2. Replace every run of characters outside `[a-z0-9]` with one `-`; trim leading and trailing `-`.
3. Cut to at most 48 characters at a `-` boundary (a default; keeps file names short).
4. If the result is empty or does not start with `[a-z0-9]`, prefix the type initial (`e`, `sp`, `s`, `t`, `st`).
5. If the result is `index` (reserved, part A.1) or already taken in this tree, append `-2`, `-3`, ... until unique.
6. The result must match `^[a-z0-9][a-z0-9-]*$`; check it before writing.

Slugs are never renamed after `H1.ok` (`ticket-clerk` keys `tickets.tsv` on them, part A.6). On an `H1.changes` re-entry, keep every existing slug; mint only for new nodes.

## Draft file shape

```
---
slug: export-order-status-csv
issuetype: Story
parent: order-status-export
---
```
Then the body of `templates/ticket.md` (item 27): the short body header under the front matter (`**Team:**`, `**Epic link:**`, `**Priority:**`, `**Requested by:**`; team, priority and requested-by are carried here, part D3 "Ticket parents", `interfaces/part-d-enums-topics.md:110`, AM-4; the top-level Jira `parent` is `ticket-clerk`'s job, part B4 `jira-create`, `interfaces/part-b-desk.md:100`), Summary, Problem, Impact, Business value, Requirements, Acceptance criteria as Gherkin, Dependencies, Risks, Subtasks, and the agent fields (scope globs, persona and tier, blocked-by, lanes, tests: unit `yes|no` + reason, integration `yes|no` + reason, e2e `new|updated|none` + reason (D2.1 e2e per unit, `templates/ticket.md:134`), done token, verifier, budget). Until step 8, each contract a draft cites is written `PIN-TBD:<contract name>`. The front matter has exactly these three keys, in this order.

Gherkin AC for a Story: at least one happy-path `Scenario`, at least one failure or edge `Scenario`, and an observability `Scenario` (what is logged or measured), each with `Given`, `When`, `Then`.

## `drafts/index.md`

Line 1: `DRAFTS: <n> drafts` (`^DRAFTS: [0-9]+ drafts$`), `<n>` = number of `drafts/*.md` files other than `index.md`. Then a table, one row per draft in publish order (parents before children, spikes before what they unblock): `slug | issuetype | parent | summary`. Written after every draft, and rewritten after any draft change (atomic, part A.1).

## Large epics

When `architecture.md` would pass about 500 lines (the agent-hq doc-length default), write a landing page `architecture.md` (header block with `security_sensitive`, item 1 summary, a parts index, item 13 human block, item 14 provenance) plus parts `architecture-part-<NN>-<topic>.md` in `PLANS_DIR` (`NN` two digits; the part file name is a default of this skill). Every part goes into `ARTIFACTS` for review.

## Checks

Run every check in the G48 pre-round slot (before round 1 and after every fix, `review-handoff.md` §4): a failing check is fixed by the loop's non-author fixer, then `fix-verifier`, then re-run before any seat reads, so every fix it causes is reviewed by the next round. Step 12 re-runs them on the final artifacts and pastes each command and result into `review-architecture.md`; a failure there is an open finding, not an unreviewed fix. `D=$PLANS_DIR/drafts`.

| Id | Check | How |
|---|---|---|
| K1 | index token | `head -1 $D/index.md` matches `^DRAFTS: [0-9]+ drafts$` and the number equals `ls $D/*.md | command grep -v '/index\.md$' | wc -l` |
| K2 | slug shape | every stem matches `^[a-z0-9][a-z0-9-]*$`, none is `index`, none repeats |
| K3 | front matter | lines 1-5 of each draft are `---`, `slug: <stem>`, `issuetype: <D2.1 value>`, `parent: <slug or ->`, `---` |
| K4 | one epic | exactly one draft has `issuetype: Epic`, and it alone has `parent: -` |
| K5 | parents resolve | every `parent` other than `-` names an existing draft; a `Subtask` parent is a `Story` or `Task` |
| K6 | child coverage | the set of item 5 ticket-slug cells other than `-` equals the set of draft stems, each once; an `st0` row with ticket slug `-` exists; every `st<N>` row has a merge order; every Epic child listed in the epic draft's Subtasks or Typed children exists |
| K7 | Gherkin | every `Story` has at least one happy and one failure or edge `Scenario`, each with `Given`, `When`, `Then` |
| K8 | spikes first | in `drafts/index.md`, every `Spike` precedes the nodes that name it in blocked-by |
| K9 | template format, drafts | the `## ` headings of each draft, in order, are exactly the list in §Draft headings for its `issuetype` |
| K10 | template format, architecture | `architecture.md` (with its parts) carries items 1-14 of part-04 §5.2 in order and exactly one line matching `^security_sensitive: (yes\|no)$` in the header block; item 13 is blank |
| K11 | template format, plans | `test-plan.md` and `release-plan.md` carry the section headings of their templates in order |
| K12 | release step ids and tags | the `step_id` column matches `^[a-z0-9-]+$`, has no duplicate, and every owner is `agent` or `human`; every `tag` cell other than `-` matches the profile `release_tags.pattern` (`grep -E`), and there is no tag step when the profile has no `release_tags` entry, `used: "no"`, or a malformed entry (`pattern` absent or not an anchored `^...$` ERE, `approval` absent or outside `none\|human`); every tag step's owner is `human` when `approval: human` |
| K13 | e2e coverage | `e2e.harness: nlta`: each user-visible Story has an e2e row in `test-plan.md`; `none`: each has a gap line in `architecture.md` item 8 and a human hand-test row post-merge in `test-plan.md`; every A3 `sub-task` cell and every batched-list `st<N>:` label is an item 5 `st<N>` id (not `-`, not `st0`) |
| K14 | contract owners and pins | each file in `contracts/` appears exactly once in the owner-path column of the `architecture.md` item 3 contract sub-table (`contract \| owner path \| consumers`); no draft or doc restates a contract body; no `PIN-TBD:` is left in any artifact (`references/contracts.md` §Check) |
| K15 | item 7 ports | every fixed port in `architecture.md` item 7 is a cite to its item 3 contract sub-table row (no port, bind or reason written twice), and every item 3 port row is cited in item 7 |

## Draft headings (K9)

Only `## ` lines count; `#` and `###` lines (title, `### Functional`, `### Scenario <n>: ...`) are ignored. From `templates/ticket.md`:
- Base (every draft): `Summary`, `Problem`, `Impact`, `Business value`, `Requirements`, `Acceptance criteria`, `Dependencies`, `Risks`, `Subtasks`, `Definition of done`, `Notes and open questions`, `Links`.
- `Epic`: the base list with `Phases`, `Dependency map`, `Typed children`, `Spikes (first, timeboxed)`, `Open questions` inserted right after `Subtasks` (template: "Append after Subtasks"); no `Agent fields`.
- `Spike`, `Story`, `Task`, `Subtask`: the base list, then `Agent fields` last (template: "Append to every child that will be built"; every non-Epic draft counts as built, a default of this skill).

Heading comparison (K9-K11): compare heading text with any trailing parenthetical note of the template removed (for example `(v0)`, `(omit when ...)`); a section the template marks optional may be absent.

If a template file of item 27 is absent at run time, use the part-04 section as the outline, run the check against that outline, and say so in the review record.
