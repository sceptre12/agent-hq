# 0021. Document length limit for non-skill docs — enforce a default, and split plans by task not by narrative slice

- **Status:** accepted (2026-07-19) — ratified via Fable dispatch, ADR 0014 T6. Ratified outcome: **Option C (both mechanisms), general limit 500** — see Decision below.
- **Date:** 2026-07-19
- **Context of:** workspace-wide (documentation convention for all `.md` under `~/projects/`, excluding skills)

## Context

**The existing-but-unenforced rule.** STANDARDS.md §4 already says: "Split any doc that
trends past ~500 lines into numbered parts (e.g. `doc-01.md`, `doc-02.md`) with an index
file." This is **prose-only and unenforced.** ADR 0016's enforcement script,
`tools/check-file-length.sh`, scans source code only — its `EXTENSIONS` array has no
`.md`, so no `.md` file is ever checked against any limit today. There is no doc-type
carve-out anywhere in hq; there is simply no teeth.

**The sibling precedent (ADR 0016), and why docs need their own ADR.** ADR 0016 set a
~300-line default for *source code we author*, and its own scope clause explicitly
excludes docs. It established a house shape worth mirroring: **default, not hard cap;
split-don't-butcher as the most important clause; an allowlist escape hatch requiring a
mandatory one-line reason per entry; a `tools/check-*.sh` enforcement script.** It also
modeled intellectual honesty about its number — "300" is a *convention anchor* (ESLint
`max-lines` default), not a measured defect threshold; the defensible core is "avoid
sprawling files" (Chong et al. 2026's inverted-U on LLM edit success vs. file size) plus
"don't let the metric get gamed" (Goodhart). Docs get their own ADR rather than folding
into 0016 because (a) 0016's scope deliberately excludes them, (b) the right *number* and
the right *split remedy* differ for prose vs. code, and (c) one of 0016's own citations —
"Lost in the Middle" (Liu et al. 2023), on models under-using information buried in the
middle of a long context — is arguably **more** applicable to prose: a review/ratification
pass reads a doc as a linear narrative, exactly the shape that citation warns about.

**Survey of actual violations** (`.md` files over 500 lines, live `find`/`wc -l`):

| Path | Lines | Status today |
|---|---|---|
| `plans/file-organizer.md` | 2,368 | — |
| `plans/file-organizer-folder-placement.md` | 977 | — |
| `references/x-context-docs/CATALOG.md` | 906 | informally grep-only (STANDARDS §11) |
| `skills/doc-reviewer/references/checks.md` | 717 | skill reference (release valve, see below) |
| `decisions/0008-container-execution-lane.md` | 631 | **undocumented violation, no exemption** |
| `architecture/file-organizer.md` | 546 | **undocumented violation, no exemption** |

Second — **the load-bearing authoring-vs-dispatch-time distinction.** The `wave-execution`
split mechanism (`plans/<slug>-waves/README.md` + `waves/NN-<name>.md`) already solves the
*dispatch-time* read problem: a work agent executing one task reads only that task's
section, not the whole plan (confirmed verbatim in a waves README: "Every wave reads its
own Task section(s) from this file; a dispatched agent executes that task's steps
verbatim"). **But it does not solve the authoring/review/ratification-time problem.** The
waves bundle is a *separate, later* artifact produced by a dedicated Opus
wave-decomposition dispatch that must itself first read the entire monolithic plan; and the
monolithic source-of-truth file still exists in full for its whole life — doc-review, Fable
ratification, and the decomposition dispatch all read the whole thing. That is exactly the
failure that just happened. Plans are also **code-dense**: the trigger file was ~4,200
lines but cost far more per line than prose (heavy with code blocks, tables, and verbatim
command steps), so it reads more like source code than narrative — which argues the plans
remedy should be a *semantic* split (by task), not a *narrative* slice (by `doc-NN.md`).

## Decision — ratified: Option C (both mechanisms), general limit 500

The draft laid out three options (A: general enforced limit; B: `plans/` authoring-time
directory split; C: both) and reserved the A/B/C choice and the 400-vs-500 number for
Fable. **Ratified: Option C, with the general limit at 500.** Both mechanisms are adopted
as the numbered clauses below; the rejected 400 arm is recorded under Alternatives.

### Clause 1 — general non-skill doc limit (≤~500 lines), enforced

Non-skill `.md` docs we author default to **≤~500 lines** — the existing §4 number, now
enforced; a soft default, not a hard cap. Enforcement is a new `tools/check-doc-length.sh`
that **mirrors `check-file-length.sh` exactly**: scans `.md`, excludes the `skills/` tree
wholesale (blanket, as the code script already excludes `skills`), excludes
third-party/generated docs we don't author, and flags any non-exempt doc over `LIMIT`
(500) lines not recorded in a root `.doc-length-allowlist` with a **mandatory one-line
reason** (`<path> — <reason>`, em-dash separator, **fail closed** on a path with no
reason — identical mechanics to `.file-length-allowlist`). Split-don't-butcher carries
over verbatim: over the limit → split; never compress/reword to dodge the number; if it
genuinely belongs together, allowlist it with a reason.

### Clause 2 — plans split by task at authoring time

Since the authoring/review-time problem is what actually bit us, `plans/` gets its **own
split-at-authoring-time convention** instead of retrofitting §4's narrative "numbered
parts + index" onto content that is task-structured, not narrative:

- A plan that would exceed the doc limit is authored as a **directory** from the start:
  `plans/<slug>/00-overview.md` (goal, global constraints, dependency map, **task index**)
  + `plans/<slug>/tasks/NN-<taskname-or-group>.md` (one file per task or coherent task
  group). STANDARDS §3's `plans/<slug>.md` single-file form is amended accordingly;
  **small plans stay single-file**.
- **Doc-review and Fable ratification then run per-file / per-group** — the reviewer reads
  `00-overview.md` plus the specific task files it needs, and can chunk or parallelize,
  instead of holding one monolith. The downstream **wave-decomposition dispatch** reads the
  overview + task files too — so the authoring-time split propagates to every later reader,
  including the one that today must read the whole monolith first.
- This is a *semantic* split: one file = one task = one unit an agent executes or reviews —
  strictly more meaningful than an arbitrary `doc-01.md`/`doc-02.md` narrative cut, and it
  directly attacks the 8/10 worst offenders. Under it, each task file naturally lands under
  the limit, so `check-doc-length.sh` passes plans without special-casing them.

### Clause 3 — §4's numbered-parts remedy survives for narrative docs only

§4's "numbered parts + index" survives unchanged as the split remedy for the *rare*
genuinely-narrative doc that must legitimately run long (e.g. a long learning) — it is
superseded by Clause 2 **for `plans/` specifically only**.

### Clause 4 — coexistence with `plans/<slug>-waves/` (settled at ratification)

The `wave-execution` bundle stays a **sibling** directory, `plans/<slug>-waves/`, for
single-file and directory-form plans alike — this is coexistence, not a collision:
`<slug>` and `<slug>-waves` are distinct names on disk, and the two are distinct artifacts
with distinct lifecycles (the plan is the authored source of truth; the waves bundle is
generated packaging produced later by the wave-decomposition dispatch). Nesting the bundle
inside the plan directory was considered and rejected: it would churn the `wave-execution`
spec format and the three existing bundles, and blur authored content vs. generated
packaging. For a directory-form plan, the bundle's caller-supplied `plan_file` pointer
becomes the **plan directory** (the decomposition dispatch and each wave's `work_items`
reference `00-overview.md` + the specific `tasks/NN-*.md` files instead of one monolith),
and `00-overview.md` links to the waves bundle once one exists.

### Ratification reasoning (Fable, 2026-07-19)

- **Why C:** the survey shows the problem is plans-concentrated *and* has clean non-plan
  outliers, so neither mechanism suffices alone; plans are demonstrably code-dense and
  task-structured, so a semantic per-task split is the correct remedy and a narrative
  slice is not; Clause 2 fixes the *authoring/review-time* failure the waves mechanism
  provably does not.
- **Why 500, not 400:** tightening buys nothing observable — both existing narrative
  violations (546, 631) already exceed 500, and the trigger-class offenders (multi-thousand-
  line plans) are fixed structurally by Clause 2 regardless of the number. 500 is the
  zero-invention choice already in §4, preserves ADR 0016's stated code(300)-below-prose(500)
  rationale, and avoids raising split-pressure on coherent narrative docs (the over-tight
  trade-off named under Consequences) for no demonstrated gain. The user's "lower limits"
  intent is delivered by *enforcement* (unbounded status quo → 500 with teeth) plus the
  structural plans fix that attacks the actual 4,200-line failure class.

## Scope

- **Excludes skills entirely** — `SKILL.md` and every skill `references/*` file. Basis:
  ADR 0016's blanket skills exemption (its clause 2), and `tools/skill-authoring.md`'s
  own guidance to move SKILL.md overflow *into* reference files precisely to keep SKILL.md
  under its ~500-line tip — so skill reference-file growth is a sanctioned release valve.
  `skills/doc-reviewer/references/checks.md` (717) is exempt on this basis; the
  `check-doc-length.sh` `skills/` exclusion enforces it mechanically, mirroring the code
  script.
- **Excludes what ADR 0016 already covers** — source code (0016's domain); this ADR adds
  no code rule.
- **Excludes third-party / generated docs we don't author** — same shape as 0016's
  vendored/generated exclusion. `references/x-context-docs/CATALOG.md` (906) is a
  **generated index over a third-party mirror**, already grep-only per STANDARDS §11; it is
  covered by this scope-exclusion and needs **no bespoke §4 carve-out and no allowlist
  entry**. (Folding it into the allowlist was considered and rejected: an allowlist entry
  implies "authored doc we chose to exempt," which misdescribes a generated third-party
  index — the scope exclusion is the honest home for it.)

## Migration / grandfather clause

The survey lists 8 oversized plans plus 2 clean doc violations already over any reasonable
new limit. This ADR **does not mandate an immediate mass retrofit** — that would be a large
blocking migration for an adoptable rule:

2. **Scheduled follow-up retrofit (non-blocking).** A separate tracked task converts the
   monolith plans to Clause 2 directory form — opportunistically on next substantive edit,
   or as a batched retrofit project — and splits/allowlists the two narrative outliers
   (`0008` at 631, `architecture/file-organizer.md` at 546). New docs follow the rule
   immediately; old docs migrate lazily. INVARIANTS.md gains a check that hq passes
   `check-doc-length.sh` (clean or fully-reasoned-allowlist), matching 0016's invariant.
3. **Ratification ≠ implementation.** `check-doc-length.sh`, the initial
   `.doc-length-allowlist`, and the INVARIANTS.md check land in a follow-up implementation
   work unit, not this ratification commit. Until it lands, the rule binds authors by
   convention (this ADR + STANDARDS §3/§4/§13) without mechanical teeth.

## Consequences

- **Positive:** the previously-unenforced §4 number gets teeth; agents that read docs
  (review, ratification, decomposition) stop blowing large context on single files; the
  authoring-time failure that just cost 350k+/216k+ tokens is structurally prevented for
  plans; the fix path on a violation is unambiguous (split by task for plans, split or
  allowlist for narrative docs); the escape hatch keeps genuinely-coherent content from
  being mutilated to hit a number.
- **Negative / honest trade-offs (mirroring 0016's candor):**
  - *Goodhart / gaming risk* — as in 0016, a numeric limit invites padding-to-just-under or
    a lazy one-line allowlist reason that defeats the escape hatch; only review catches a
    bad reason, since the script checks only that a reason *string* exists.
  - *Static rule under-serving capable models* — Anthropic's large-codebase guidance
    deliberately avoids a line number; a fixed prose limit may under-serve a review pass
    that could comfortably hold a longer, genuinely-coherent doc. The soft-default +
    allowlist shape is the mitigation, not a cure.
  - *Over-tight limit awkwardly splitting coherent content* — even 500 can force a
    genuinely single-narrative doc into an unnatural cut; split-don't-butcher plus the
    allowlist are the release valve, but the temptation to hit the number by degrading the
    doc is real.
  - *Clause 2 process overhead on small/simple plans* — a directory + `00-overview.md` +
    `tasks/` scaffold is overkill for a short plan that never needed splitting. Mitigation:
    the directory form is required **only** once a plan would exceed the limit; small plans
    stay single-file `plans/<slug>.md`.
- **Revisit if:** the doc allowlist balloons past a handful of entries (signal the number is
  miscalibrated or the hatch is a bypass); Clause 2's directory scaffold measurably slows
  small-plan authoring; or the sibling coexistence settled in Clause 4 fights the
  `wave-execution` `<slug>-waves/` convention in practice despite the settlement.

## Alternatives considered

- **Fold into ADR 0016 (one doc+code rule)** — rejected: 0016's scope explicitly excludes
  docs, and prose wants a different number and a different split remedy (by task /
  numbered-parts, not by code file).
- **General limit only (Option A alone)** — rejected: it fires on
  plans while pointing at the wrong remedy (retrofit numbered-parts onto task-structured,
  code-dense content) and leaves plans' authoring-time monolith intact until someone
  manually slices it.
- **`plans/`-only fix (Option B alone)** — rejected: leaves the two
  clean non-plan outliers (`0008`, `architecture/file-organizer.md`) uncovered and adds no
  general enforcement for future `architecture/`/`decisions/`/`learnings/` sprawl.
- **400 as the general limit (the draft's recommended arm)** — rejected at ratification:
  both existing narrative violations (546, 631) already exceed 500, so tightening catches
  nothing real today; the trigger-class offenders are plans, fixed structurally by Clause 2
  regardless of the number; and a second invented number would diverge from §4's
  long-standing 500 and disturb ADR 0016's stated code-below-prose rationale, while raising
  split-pressure on coherent narrative docs with no demonstrated gain.
- **Nesting the waves bundle inside the plan directory** (`plans/<slug>/waves…/`) —
  rejected in Clause 4: churns the `wave-execution` spec format and the three existing
  sibling bundles, and blurs authored source of truth vs. generated dispatch packaging.
- **A hard cap blocking the commit** — rejected, same as 0016: no evidence any prose number
  is a true threshold; a hard block invites the exact gaming split-don't-butcher exists to
  prevent.
- **Rely on `wave-execution` splitting (do nothing new)** — rejected: waves solve
  dispatch-time reads only; the monolith still exists for authoring, review, ratification,
  and the decomposition dispatch itself — the failure that triggered this ADR.

**Links:** ADR 0016 (source-file-length sibling precedent; mirrored shape), STANDARDS.md §4
(doc-split rule, amended by this ADR), STANDARDS.md §3 (`plans/<slug>.md` naming, amended by
this ADR — Clause 2), STANDARDS.md §13 (the doc-length section this ADR adds), STANDARDS.md
§11 (CATALOG.md grep-only), `tools/check-file-length.sh` (the enforcement script this ADR's
`check-doc-length.sh` mirrors), `tools/skill-authoring.md` (skill reference-file release
valve), ADR 0009/0010 (skills basis for the blanket skills exclusion), ADR 0014 T6 (the
Fable ratification trigger this ADR was accepted under), `skills/wave-execution` +
`plans/<slug>-waves/` (dispatch-time mechanism; coexistence settled in Clause 4).
