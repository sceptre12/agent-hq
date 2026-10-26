# Tree rules: typed tree, spikes first, slugs, checks

Sources: design v2 card 3; part-04 §5.1 (tickets), §5.2 (`architecture.md`); INTERFACES 1.1.0 part A.1 `<slug>`, A.6 (`drafts/<slug>.md`, `drafts/index.md`), D1.1 `DRAFTS:`, D2.1 ticket issue type; AM-2 row 10 (draft front matter, plan-check default PC-11).

## Typed tree

- Exactly one `Epic` node, the root; its draft has `parent: -`.
- Children use only `Spike`, `Story`, `Task`, `Subtask` (D2.1, capitalised as written).
- `Story`: a user-visible or consumer-visible behaviour; carries Gherkin AC. `Task`: technical work with no user-visible behaviour (still has a done condition and a verifier). `Subtask`: a slice of one Story or Task; its parent is that Story or Task, never the Epic. `Spike`: a timeboxed question.
- Spikes first: every unknown that blocks a design choice becomes a `Spike` placed before the nodes it unblocks (in `drafts/index.md` order and in `architecture.md` item 5). Each Spike states its question, its timebox (from the profile `durations.*`, or `FILL_IN_BEFORE_DISPATCH`), and its exit (the decision it feeds and who takes it).
- Epic additions (part-04 §5.1): phases, dependency map, typed children, open questions.
- Merge order (owner ruling D5): one PR per sub-task; `architecture.md` item 5 gives the tree with merge order; the dispatch plan cuts sub-tasks from it later (this skill writes no dispatch plan).
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
Then the body of `templates/ticket.md` (item 27): header (issue type, team, epic link, priority, requested by), Summary, Problem, Impact, Business value, Requirements, Acceptance criteria as Gherkin, Dependencies, Risks, Subtasks, and the agent additions (scope globs, persona and tier, blocked-by, lanes, test expectations: unit, integration, e2e yes or no with reason, done token, verifier, budget). The front matter has exactly these three keys, in this order.

Gherkin AC for a Story: at least one happy-path `Scenario`, at least one failure or edge `Scenario`, and an observability `Scenario` (what is logged or measured), each with `Given`, `When`, `Then`.

## `drafts/index.md`

Line 1: `DRAFTS: <n> drafts` (`^DRAFTS: [0-9]+ drafts$`), `<n>` = number of `drafts/*.md` files other than `index.md`. Then a table, one row per draft in publish order (parents before children, spikes before what they unblock): `slug | issuetype | parent | summary`. Written after every draft, and rewritten after any draft change (atomic, part A.1).

## Large epics

When `architecture.md` would pass about 500 lines (the agent-hq doc-length default), write a landing page `architecture.md` (header block with `security_sensitive`, item 1 summary, a parts index, item 13 human block, item 14 provenance) plus parts `architecture-part-<NN>-<topic>.md` in `PLANS_DIR` (`NN` two digits; the part file name is a default of this skill). Every part goes into `ARTIFACTS` for review.

## Checks

Run each check after the loop (step 12) and paste the command and result into `review-architecture.md`. `D=$PLANS_DIR/drafts`. A failing check is fixed by the loop's fixer, then `fix-verifier`, then re-run.

| Id | Check | How |
|---|---|---|
| K1 | index token | `head -1 $D/index.md` matches `^DRAFTS: [0-9]+ drafts$` and the number equals `ls $D/*.md | command grep -v '/index\.md$' | wc -l` |
| K2 | slug shape | every stem matches `^[a-z0-9][a-z0-9-]*$`, none is `index`, none repeats |
| K3 | front matter | lines 1-5 of each draft are `---`, `slug: <stem>`, `issuetype: <D2.1 value>`, `parent: <slug or ->`, `---` |
| K4 | one epic | exactly one draft has `issuetype: Epic`, and it alone has `parent: -` |
| K5 | parents resolve | every `parent` other than `-` names an existing draft; a `Subtask` parent is a `Story` or `Task` |
| K6 | child coverage | the set of slugs in `architecture.md` item 5 equals the set of draft stems; every Epic child listed in the epic draft's Subtasks or typed children exists |
| K7 | Gherkin | every `Story` has at least one happy and one failure or edge `Scenario`, each with `Given`, `When`, `Then` |
| K8 | spikes first | in `drafts/index.md`, every `Spike` precedes the nodes that name it in blocked-by |
| K9 | template format, drafts | each draft carries every section heading of `templates/ticket.md`, in order |
| K10 | template format, architecture | `architecture.md` (with its parts) carries items 1-14 of part-04 §5.2 in order and exactly one line matching `^security_sensitive: (yes\|no)$` in the header block; item 13 is blank |
| K11 | template format, plans | `test-plan.md` and `release-plan.md` carry the section headings of their templates in order |
| K12 | release step ids | the `step_id` column matches `^[a-z0-9-]+$`, has no duplicate, and every owner is `agent` or `human` |
| K13 | e2e coverage | `e2e.harness: nlta`: each user-visible Story has an e2e row in `test-plan.md`; `none`: each has a gap line in `architecture.md` item 8 and a human hand-test row post-merge in `test-plan.md` |
| K14 | contract owners | each file in `contracts/` appears exactly once in the `architecture.md` item 3 contract table (name, owner path, consumers); no draft or doc restates a contract body (`references/contracts.md` §Check) |

Heading comparison (K9-K11): compare heading text with any trailing parenthetical note of the template removed (for example `(v0)`, `(omit when ...)`); a section the template marks optional may be absent.

If a template file of item 27 is absent at run time, use the part-04 section as the outline, run the check against that outline, and say so in the review record.
