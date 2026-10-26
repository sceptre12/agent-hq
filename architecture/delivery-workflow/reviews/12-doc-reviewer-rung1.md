# 12-doc-reviewer EXTEND — Rung 1 loop record

- **Artifact:** `skills/doc-reviewer/SKILL.md` and the new `skills/doc-reviewer/references/delivery-doc-checks.md`.
  - Worktree `~/projects/agent-hq-worktrees/delivery-extends`, branch `ext/delivery-extends`.
  - Author commit `156013b`. The fixes are uncommitted in the working tree; the integrator (Worker1) commits.
  - `references/checks.md` is byte-identical to the merge-base with `wt/delivery-w0`.
- **Spec:** `architecture/delivery-workflow/tasks/12-doc-reviewer.md` in W (`~/projects/agent-hq-worktrees/delivery-w0`).
- **Loop:** one orchestrator (D35), and a separate agent for every role (M29):
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the INSTALLED, unmodified `~/projects/agent-hq/skills/doc-reviewer`. The EXTENDED copy was the artifact under review.
  - Fix: Opus, a fresh agent each round, editing only `skills/doc-reviewer/`.
  - Fix-verify: Sonnet, running the INSTALLED `fix-verifier`.
  - §9: a non-author verifier that built the fixtures and spawned fresh reviewers on the EXTENDED skill.
- **Round cap:** 3 rounds (D7). The pre-round screen ran before round 1 and after each fix.
- **Owner-side rulings applied before the loop:**
  - `DOC-` labels appear only in finding rows.
  - DOC-4 scope is template format only.
- **Date:** 2026-10-26.

## Result

**Closed in round 3 at B=0 M=0 L=3** (doc-reviewer's Advisory). Both fix-verifies were CLEAN. Five owner questions are open (below).

| Round | Pre-check (G48) | Review | Fix | Fix-verify |
|---|---|---|---|---|
| 1 | 7 rows (3 contradictions, 3 undefined refs, 1 anatomy) | B=0 M=3 L=7, READY WITH CONDITIONS | All Mediums, Lows and pre-check rows fixed; OQ-1 and OQ-2 raised | CLEAN, 1 Low |
| 2 | 5 rows (draft front matter vs §5.1 header, unpathed citations, `security_sensitive`, 2 borderline) | B=0 M=3 L=6, READY WITH CONDITIONS | All fixed; OQ-3 and OQ-4 raised | CLEAN, 1 Low (OQ-3 default not marked in text) |
| 3 | 2 rows (1 Medium-class: "task spec" applicability narrowing vs Q12-4; 1 Advisory: status-line tokens) | B=0 M=0 L=3, READY | none (cap reached; open items below) | n/a |

## Key changes by round

**Round 1**
- The `SKILL.md` inventory sentence now says `references/checks.md` holds one spec per *numbered* row. The DOC row's spec is in `references/delivery-doc-checks.md`; `checks.md` is untouched.
- A per-document applicability table says which of DOC-1..DOC-4 apply to `architecture.md`, `dispatch-plan.md`, a task spec and a ticket draft. "Not applicable" emits nothing.
- The DOC-3/DOC-4 boundary is fixed: an absent or empty AC is DOC-3 (child without AC); AC that is present but malformed (including non-Gherkin, or missing a case kind) is DOC-4.
- Severities are brought inside the spec §8 scheme, each marked plan-check default:
  - Blocking: a missing `architecture.md` section; a child without AC.
  - Medium: an uncommanded `(fact)`; a template-format miss; a missing task-spec or `dispatch-plan.md` section; a sub-task without a draft; an orphan draft.
  - Advisory: wording.
- `test-plan.md` and `release-plan.md` were dropped from DOC-1, which now matches the Q12-4 trigger.
- The bare "(Q12-3)" id became prose, the drafts location is named (`plans/<epic>/drafts/`, INTERFACES A.6), and the "older 11/13-section lists" history is gone.
- The status line is defined: "delivery checks: run" or "delivery checks: clean", never with a label.

**Round 2**
- Sections 12 (Review record) and 13 (Human acceptance block) pass at stage 2 when they hold their template placeholder.
- Epic additions are checked only on the epic draft (`parent: -`). There is a "missing epic addition" finding form.
- A stage 2 artifact is now identified by its path or by what it calls itself. Other documents get no DOC rows. No input and no mode flag were added.
- The `dispatch-plan.md` list is now the full 18 items of part-04 §5.3.
- Summary over 15 lines became Medium, and DOC-2 gained a finding form for a missing date or where.
- New status line "delivery checks: clean, partial" for when a part could not be checked.
- `drafts/index.md` is excluded, a miss is reported once under its DOC row, and citations carry repo-relative paths.
- DOC-4 checks the A.6 front matter (exactly `slug`, `issuetype`, `parent`) and the §5.1 header fields. `issuetype` counts as issue type and `parent` as epic link (see OQ-3).

## Open Low findings (round 3, not fixed; cap reached)

| # | Finding | Source |
|---|---|---|
| L1 | DOC-2 calls a missing date/where Advisory "(wording)", which doesn't fit the checks.md scale. | review-r3 #1 |
| L2 | The `SKILL.md` Exit criteria line restates the reference's status-line wording, so the two copies can drift. | review-r3 #2 |
| L3 | "The caller may override it" (severity defaults) reads like an implicit input. | review-r3 #3 |
| L4 | The status tokens "run", "clean", "clean, partial" are not verdict words. They come from the author's original exit criterion, not from spec §4. | precheck-r3 #2 (Advisory) |
| L5 | The DOC-4 header rule applies the OQ-3 meanwhile default without marking it as pending. | fixverify-r2 |

## Owner questions

**OQ-1.** Should a sub-task with no child draft be Blocking rather than Medium?
- Recommended: yes for "sub-task has no draft", since stage 3 would dispatch nothing for it. Keep an orphan draft at Medium. This would add one case to the spec §8 Blocking list.
- Meanwhile: both are Medium (plan-check default).

**OQ-2.** The extension's Provenance cites the design card, not a recorded friction entry (skill-authoring §5). Should a friction entry be recorded?
- Recommended: no action now. Spec §8 requires the card citation, and the base friction link remains. Add an entry the first time a delivery run hits a DOC-check miss.
- Meanwhile: the card citation is kept.

**OQ-3.** A.6 fixes a draft's front matter to exactly `slug`, `issuetype`, `parent`. Part-04 §5.1 also lists team, priority and requested by. Where do those live in a local draft, and are they required at stage 2?
- Recommended: front matter stays the A.6 three keys. Team, priority and requested by go in a short body header under it. Record this in part-04 §5.1 or A.6 so `delivery-architecture` (item 15) writes it.
- Meanwhile: DOC-4 checks both, Medium on a miss.

**OQ-4.** INTERFACES 1.3.0 AM-3 requires a `security_sensitive: yes|no` line in `architecture.md`. Should DOC-1 check it?
- Recommended: yes, as a DOC-1 Medium, once part-04 §5.2 lists the line, so the template stays the single source.
- Meanwhile: not checked (outside spec 12 scope).

**OQ-5** (precheck-r3 #1). Q12-4 says the checks apply to "a task spec". To keep non-delivery specs clean (review-r2 M3), the reference narrows this to a task spec under the epic's `plans/` or `.tasks/` tree, or one that names itself a delivery unit task spec. Is that narrowing accepted?
- Recommended: yes. Q12-4's own lead-in is "a delivery stage 2 artifact", and the narrowing only makes it operational. Amend the Q12-4 line to read "a delivery task spec".
- Meanwhile: the narrowing stands.

## §9 done-condition

**Result: exit 0, last stdout line `EXT-12-OK`.** The orchestrator re-ran the spec's §9 block verbatim (extracted from the task spec) on 2026-10-26, against the final working tree:

```
$ FIXTURE_DIR=<SCRATCH>/ext12/fixture-results bash s9-verbatim.sh; echo "EXIT=$?"
EXT-12-OK
EXIT=0
```

- **Fixtures:** built by a non-author verifier (Sonnet) under the session scratchpad (`<SCRATCH>/ext12/fixtures/{fixture,control}/plans/demo-epic/`), not `$TMPDIR`. The tree holds `architecture.md`, `drafts/index.md`, an epic draft and three child drafts.
  - Fixture: 13 sections (no Provenance), one `(fact)` without a command, one child with no AC, and one child whose AC has no observability case.
  - Control: clean.
- **Reviewers:** fresh Sonnet agents, given only "follow `skills/doc-reviewer/SKILL.md` (EXTENDED) on this document set", with no hints about the DOC labels or the expected findings. The reports were saved raw and never edited.
- **Review-time check (Q12-3):** `fixture.out` has DOC-1 Blocking, DOC-3 Blocking, DOC-2 Medium, and DOC-4 Medium twice (the observability case, plus the epic typed children). `control.out` has 0 `DOC-` tokens and the status line "delivery checks: clean".
- **First run failed (`FAIL: control flagged`).** The verifier's control epic draft had no typed children, a genuine §5.1 deviation that the extended skill correctly flagged as DOC-4 Medium. That report is kept as `control.run1.out`. The verifier fixed the control tree, and one new fresh control reviewer produced the passing `control.out`. The fixture report was not re-run.
- **Evidence:** `<SCRATCH>/ext12/` holds `s9-verifier.md`, `s9-result.txt`, `fixture-results/` and the round reports (`precheck-r1..r3.md`, `review-r1..r3.md`, `fix-r1..r2.md`, `fixverify-r1..r2.md`). `<SCRATCH>` is the build session scratchpad named in `build-common.md`.
