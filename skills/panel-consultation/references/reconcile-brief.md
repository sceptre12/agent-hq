# Reconcile-mode brief (`MODE=reconcile`)

One-line summary: briefs each of the 9 seats, in `MODE=reconcile`, to classify every delta
between two independently-diverged versions of one artifact — a classification task, never a
defect-hunt — then feeds a synthesizer's reconciliation verdict and a Fixer that writes only
`MERGE_TARGET_PATH`. Format follows `references/briefs.md`; swap in the sections below wherever
that file's "Phase 1 seat brief", "A-close brief", "Synthesizer brief" and "Fixer brief" apply
when `MODE=reconcile`. Inputs named here are `SKILL.md`'s Inputs table: `VERSION_A_PATH`,
`VERSION_B_PATH` (read-only, always — nothing in this process ever writes to either),
`COMMON_ANCESTOR_PATH` (optional), `MERGE_TARGET_PATH` (the Fixer's one write target). All four
are already-materialised plain files by the time a seat reads them; when the two versions live on
git refs rather than disk, the caller materialises them first (`SKILL.md`, `## Inputs`) — no seat,
A-close or the synthesizer ever runs a checkout.

## 1. Reading the two versions

- **No `COMMON_ANCESTOR_PATH`:** each seat reads `VERSION_A_PATH` and `VERSION_B_PATH` in full —
  never a 2-way diff alone: with no known common point, a diff conflates "A added this" with "B
  removed this" and cannot say which happened. `diff -u [VERSION_A_PATH] [VERSION_B_PATH]` is read
  as orientation only, never as the basis for a classification.
- **`COMMON_ANCESTOR_PATH` given:** a real 3-way diff, `diff3 -m [VERSION_A_PATH]
  [COMMON_ANCESTOR_PATH] [VERSION_B_PATH]` — this is what lets a seat say "A added X; B left X as
  the ancestor had it" instead of guessing which side changed. Prefer this reading whenever
  `COMMON_ANCESTOR_PATH` is given. (`git merge-file --diff3 -p` is NOT a drop-in alternative here:
  by default it takes three file-path operands, not blobs, and needs the explicit `--object-id`
  flag to take blobs at all — `diff3 -m` above is the one command this brief specifies.)
- Both forms: a seat classifies from the full text of its domain in each version; the diff only
  orients where to look.

## 2. Classification taxonomy (replaces severity in this mode) (default)

A seat's job is sorting, not judging defect severity. Every delta in a seat's own topic
(`references/seats-raci.md` section 4, the same nine checks, applied to both versions) gets
exactly one class (default; the five-class split below carries no owner ruling yet):

| Class | Test |
|---|---|
| `IMPROVEMENT` | one side's treatment is strictly better (clearer, more correct, closes a gap) and the other side did not also change that same spot incompatibly |
| `REGRESSION` | one side's treatment is strictly worse than the other's (or than the ancestor's, when known), with no compensating gain |
| `NEUTRAL` | both sides changed the spot, but the difference carries no improvement or regression either way (wording-only, order-only) |
| `CONFLICT` | genuine two-way divergence: both sides changed the SAME spot in incompatible ways and neither reading is mechanically better — no owner quote or cited fact picks a winner |
| `MISSING-FROM-BOTH` | a gap neither version addresses; not a delta between A and B, a bonus finding surfaced alongside them |

`CONFLICT` is reserved for a real tie with no mechanical winner — a seat that can cite a reason
one side is better writes `IMPROVEMENT`/`REGRESSION`, not `CONFLICT`. A seat never invents
authorial intent nobody stated to break a tie (design background); an unresolved tie is named,
not guessed at.

## 3. `DELTA` line shape (this mode's `FINDING` equivalent)

```
DELTA | <id> | <topic> | IMPROVEMENT/REGRESSION/NEUTRAL/CONFLICT/MISSING-FROM-BOTH | <A-loc> / <B-loc> / <ancestor-loc or "n/a"> | <what changed> | Disposition: <A wins / B wins / merge: <instruction> / needs owner call>
```

A topic with no delta in scope writes one `PASS` line instead: `PASS | <topic> | no delta found
between A and B in this domain`. Ids: seats `<seat-id>-D<n>` (n from 1 per record); A-close
additions `<topic>-DA<n>` — same numbering rule as `references/severity-and-records.md` section 4.
A `MISSING-FROM-BOTH` delta still gets an id and a `DELTA` line; its Disposition field reads
`bonus — not required for the bar` (section 8 below).

## 4. Seat brief (Phase 1; Sonnet; nine in ONE message)

Carries `references/briefs.md` section 1's common block, model pin, secrets/removals/stop clauses
and budget unchanged. Replace that brief's ARTIFACT, RULES and OUTPUT blocks with:

```
You are [SEAT NAME] (agent-id [SEAT_ID]) on a 9-seat reconcile panel, Phase 1.
[COMMON BLOCK — references/briefs.md section 1]
VERSION A (read-only): [VERSION_A_PATH]
VERSION B (read-only): [VERSION_B_PATH]
COMMON ANCESTOR (read-only, if given): [COMMON_ANCESTOR_PATH or "none - read A and B directly"]
YOUR LENS: "[CHARACTERISTIC QUESTION, references/seats-raci.md section 1]"
YOUR R TOPIC: [TOPIC] - classify every delta in this domain (check definition: references/seats-raci.md section 4)
YOUR C TOPICS: [TOPIC-1], [TOPIC-2] - one C-NOTE each, blind, `risk-seen` only if you see an
  unclassified delta in that topic's area reading A and B alone, else `none-seen`
TASK: this is classification, not a defect hunt. For every delta your topic's check surfaces,
  write one DELTA line (section 3) with exactly one class (section 2) and a disposition. Never
  skip classifying a delta because neither side is clearly "wrong" - NEUTRAL and
  MISSING-FROM-BOTH exist for exactly that.
OUTPUT: write the record [RECORD_PATH]; hand back at most 12 lines (counts per class and the
  record path).
```

## 5. A-close brief (Phase 2; Sonnet; one fresh instance per topic with a delta)

Same close rule as `references/seats-raci.md` section 2 (one `CLOSED` line per in-scope topic; a
topic with a `DELTA` line or a `risk-seen` C-NOTE gets an A-close). Replace that rule's severity
re-measurement with classification adjudication:

```
You are the Accountable closer ([SEAT NAME]) for topic [TOPIC], reconcile round.
[COMMON BLOCK]
INPUTS: the topic file [TOPIC_FILE] (R's DELTA/PASS lines, the C-NOTEs), VERSION A, VERSION B,
  COMMON ANCESTOR (if given), your own references/seats-raci.md row.
DO: re-read each DELTA from source. APPEND one VERDICT line per existing id (validated /
  reclassified <new class> / escalated-to-CONFLICT), any delta you add (id [TOPIC]-DA<n>), and
  one CLOSED line naming the final class and disposition per id. A reclassification needs a cited
  reason (a line, an owner quote, or a fact); absent one, a tie stays CONFLICT - do not break it
  by guessing intent.
OUTPUT: the appended topic file; hand back at most 6 lines.
```

`CLOSED` line (reconcile mode): `CLOSED | <topic> | <seat-id> | <n classified>: <classes and
counts> | disposition set: <ids>=<disposition>,... ; CONFLICT open: <ids or "none">`.

## 6. Synthesizer: the reconciliation verdict

One fresh Sonnet synthesizer, same independence rule as `review` mode (reads every topic file,
the ledger, no peer seat record). Its record IS the reconciliation verdict, not a findings table:

1. Line 1: `RECONCILE <n deltas> - <n CONFLICT open>` (the bar, section 8).
2. **Disposition table**, one row per de-duplicated delta: `id | topic | class | A-loc/B-loc |
   disposition (A wins / B wins / merge: <instruction>) | seat ids`. De-duplication key (default):
   two DELTA ids collapse into one row when they name the same `(A-loc, B-loc)` pair (allowing one
   side to be "n/a"); the surviving id is the A-close's own id for that topic if one exists
   (`<topic>-DA<n>`), else the earliest-numbered seat id citing it; the row's `seat ids` column
   lists every id that collapsed into it, so none is silently dropped. Every `IMPROVEMENT`,
   `REGRESSION`, `NEUTRAL` and `MISSING-FROM-BOTH` delta gets a row with a disposition (a
   `MISSING-FROM-BOTH` row's disposition is always `bonus - not required for the bar`).
3. **Residual CONFLICT list**, named, separate from the table above: every `CONFLICT` that stayed
   open through A-close, with both sides' text quoted and why neither is a mechanical winner. The
   synthesizer resolves none of these itself (never invent authorial intent nobody stated) - it
   names them for the human owner.
4. Then it stops. It writes no file outside its own record; it decides no owner-only item.

## 7. Fixer (reconcile variant of the existing Fixer role, `SKILL.md` Roles table)

```
You are the Fixer, reconcile round, fix [c][k] (main fix: a1). [COMMON BLOCK]
INPUTS: the synthesizer's reconciliation verdict [SYNTH_RECORD]; VERSION_A_PATH, VERSION_B_PATH
  (read-only - never write to either); MERGE_TARGET_PATH (your one write target; need not
  pre-exist, create it if absent).
DO: write MERGE_TARGET_PATH implementing every disposition in the verdict's table (IMPROVEMENT,
  REGRESSION and NEUTRAL rows: apply the winning side or the stated merge instruction;
  MISSING-FROM-BOTH rows: leave as a gap, do not author new content to fill it). For each item in
  the residual CONFLICT list: do not resolve it - mark the spot with the target format's own
  comment syntax if it has one (e.g. `<!-- CONFLICT: <id>, see verdict -->` in Markdown/HTML,
  `# CONFLICT: <id>, see verdict` in a line-comment format); with no comment syntax available
  (e.g. a data-only format), mark it with the bracketed literal `[CONFLICT: <id>, see verdict]`
  inline instead — one of the two always applies, so the spot is never left silently unmarked.
  Never silently pick a side.
OUTPUT: write MERGE_TARGET_PATH only; write the fix record [RECORD_PATH] with changed_files
  (MERGE_TARGET_PATH alone) and one line per disposition id: applied / marked-open (CONFLICT ids).
```

After the write, the orchestrator runs the post-write check (`SKILL.md`, `## Reconcile mode`):
re-hash `VERSION_A_PATH` and `VERSION_B_PATH` against the Prepare-time snapshot; a mismatch is
stop-the-line before `fix-verifier` is ever dispatched. Only once that check passes does the
orchestrator invoke the existing `fix-verifier` skill (unchanged; `skills/fix-verifier/SKILL.md`),
same dispatch shape as `references/briefs.md` section 5, with `changed_files` = measured from a
fresh listing of what actually changed under `MERGE_TARGET_PATH` (never hand-fed as a bare
assertion) and `fix_description` = the verdict's disposition table, to confirm the merge was
actually applied as described. CLEAN hands back; ISSUES_FOUND runs the existing narrow-fix cycle
(`SKILL.md`, Loop) once as fix `b1`, re-running the post-write check first, capped the same way,
scoped to `MERGE_TARGET_PATH` only; a cap-escalated new cycle restarts at `a2`/`b2` per the next
`<k>` (section 9).

## 8. The bar (reconcile mode; replaces 0 Blocking/0 Medium) (default)

Met when both hold: (a) every delta surfaced by any seat or A-close has exactly one disposition
row in the synthesizer's table (no delta silently dropped); (b) every `CONFLICT` that stayed open
is named in the residual list, none left unresolved-and-unlisted. This mode never loops seeking to
resolve a `CONFLICT` itself (design background) - reaching the bar is reaching full
classification plus a named escalation list, not agreement between the two sides.

## 9. Record names (reconcile mode; mirrors `references/severity-and-records.md` section 3)

| Step | Record |
|---|---|
| seat; topic file; synthesizer | `pc-reconcile-<slug>-s-<seat-id>-<date>.md`; `pc-reconcile-<slug>-topic-<topic>-<date>.md`; `pc-reconcile-<slug>-synth-<date>.md` |
| fix; fix-verifier | `pc-reconcile-fix-<slug>-<c><k>-<date>.md`; `pc-reconcile-verify-<slug>-<c><k>-<date>.md` |

`<slug>` and `<date>` as `references/severity-and-records.md` section 2; `<c><k>` as that file's
section 2 (`a1` the main fix, `b1` the one narrow fix, `a2`/`b2` a cap-escalated new cycle). No
round number: this mode is one seat round, with one or more fix points under the shared fix-cycle
and cap (`SKILL.md`, Reconcile mode).

## Lineage

New in this pass (2026-10-29): no prior panel-consultation or review-7-panel capability
reconciles two independently-diverged artifact versions. Built by extending this skill's existing
nine-seat RACI structure (`references/seats-raci.md`), brief format (`references/briefs.md`), and
line-shape/record-name conventions (`references/severity-and-records.md`) with a classification
taxonomy in place of a severity scale, and the existing `fix-verifier` skill reused unchanged to
confirm the merge.
