# 0016. Source file length limit — default ~300 lines, split don't butcher

- **Status:** accepted (2026-07-12) — ratified per user decision
- **Date:** 2026-07-12
- **Context of:** workspace-wide (code style convention for all repos under `~/projects/`)
- **Amendment (2026-07-12):** test files are now a blanket exemption alongside skills,
  and scope is clarified to hq + projects we author — not cloned/forked/third-party/
  vendored repos. See "Amendment 2026-07-12" under Decision and Consequences below.

## Context

hq already has a size-discipline convention for documentation: STANDARDS.md §4 splits any
doc trending past ~500 lines into numbered parts with an index file, credited as an
adaptation inspired by Addy Osmani's material. That material specifies no code
line-limit — the doc-split rule was hq's own extension. Source code has no analogous rule
today: files can and do grow without bound, which hurts both human navigability and
agent-driven editing (large files are harder to hold in context, harder to diff cleanly,
and harder for an LLM to patch correctly).

There is no controlled study that validates any specific number as a defect-reducing
threshold for file size. El Emam et al., "The Optimal Class Size for Object-Oriented
Software" (IEEE TSE, 2002), tested the "optimal file/class size" conjecture directly and
found no defect-based threshold — the older "small modules are less buggy" claim is a
statistical artifact of the correlation between defect density and size, not a causal
size effect. Robert C. Martin (*Clean Code*) advocates small functions without citing a
research basis for the specific numbers. McConnell (*Code Complete*) tolerates routines
around ~200 lines. None of this converges on "300" as a measured optimum.

"300" is convention, most plausibly anchored by ESLint's `max-lines` rule, whose default
is 300 — echoed by AWS Labs' "Vibe Coding Tips" guidance ("if a file is longer than 300
lines... break it down into multiple files"). It sits inside the roughly 100–500 line band
that essentially every source on the topic treats as reasonable; nothing in the literature
argues for treating exactly 300 as special.

There is real, if indirect, support for "avoid sprawling files" as a *range* concern
rather than a magic number. Chong et al. (arXiv, 2026), studying LLM patch success across
212 real commits, found an inverted-U relationship between file size and edit success —
in one model's data, failed edits averaged ~4340 mean LOC in the touched file versus ~690
LOC for successful edits. "Lost in the Middle" (Liu et al., 2023) shows models
systematically under-use information buried in the middle of a large context, which is
exactly the failure shape a sprawling file invites. Two cautions push toward a soft
default rather than a hard cap: numeric caps invite Goodhart's-law gaming (files padded or
trimmed to just clear the number rather than actually improved), and Anthropic's own
large-codebase guidance deliberately avoids specifying a line number, warning that static
rules can under-serve capable models on legitimately large files.

## Decision

We will adopt a default file-length convention for source code we author, modeled on the
existing doc-split rule in STANDARDS.md §4 but tighter, since code is denser than prose:

1. **Default: source files we author should be ≤~300 lines.** This is a **default with a
   justified escape hatch — not a hard cap.** Files may legitimately exceed it.
2. **Skills are a blanket exemption.** No skill file needs a reason or an allowlist entry
   to exceed the limit.
3. **Split, don't butcher — this is the most important clause in this decision.** When a
   file must exceed the limit, the correct response is to **split it into multiple
   files.** It is **never** correct to compress, delete, reformat, or reword content
   purely to force a file back under the number. If a file's content genuinely belongs
   together and can't be split without harming clarity, it goes on the allowlist with a
   reason instead of being mutilated to fit. **Hitting the number by degrading the code is
   a worse outcome than leaving the file long.**
4. **Scope:** applies to source code we author. It does not apply to vendored or
   third-party code, generated files, lockfiles, or data fixtures — none of which are
   authored-and-maintained prose in the sense this rule cares about.
5. **Escape hatch:** a repo may carry a `.file-length-allowlist` file at its root listing
   exempted paths, one per line, each with a **mandatory one-line reason**
   (`<relative-path> — <reason>`). An allowlist entry with a path but no reason is invalid
   and must fail the check closed (nonzero exit), not silently pass.
6. **Enforcement:** `tools/check-file-length.sh [target-dir]` walks a target directory,
   applies the exclusions in this ADR, and flags any non-exempt file over `LIMIT` (300,
   a variable in the script) lines that isn't on the allowlist. INVARIANTS.md gains a
   corresponding check that hq itself passes this script clean (or documents its
   exceptions on the allowlist with reasons).

### Amendment 2026-07-12

7. **Test files are a blanket exemption**, same treatment as skills (clause 2): no reason
   or allowlist entry needed. A file is exempt as a test file if its basename matches
   `*.test.*` or `*.spec.*`, or its path contains a `__tests__/`, `test/`, or `tests/`
   segment. **Rationale:** test files are low-risk for agent editing — they don't
   accumulate the cross-cutting logic sprawl this rule targets, and a large test file is
   rarely the kind of file an agent needs to hold entirely in context to patch correctly.
8. **Scope clarification:** this rule applies to hq and to projects **we author** from it.
   It does not apply to cloned, forked, third-party, or vendored repos we merely work
   inside. **Rationale:** the rule targets code we own and edit repeatedly — sprawl in a
   repo we don't control and can't restructure isn't ours to fix, and running the scanner
   there produces noise, not signal. This is documentation guidance about *where* to run
   the scanner (per-repo, on repos we author); the scanner itself has no way to detect
   authorship and is unchanged by this clarification.

## Reasoning

- **300 is a convention anchor, not a measured threshold — and we say so plainly.** No
  study cited above (or found) validates 300 specifically; El Emam et al. found no
  defect-based optimum at all. Claiming otherwise would misrepresent the evidence. The
  defensible core of this decision is narrower than "300 is correct": it is "avoid
  sprawling files" (supported by the Chong et al. inverted-U and Lost-in-the-Middle
  findings) plus "don't let the metric get gamed" (supported by the Goodhart's-law and
  Anthropic large-codebase cautions) — the specific number is a reasonable, widely-used
  default (ESLint, AWS Labs) chosen for consistency, not derived from a threshold effect.
- **Default-not-cap is the mechanism that keeps the number honest.** A hard cap pressures
  authors to hit the number by any means, including degrading the code — exactly the
  failure mode the split-don't-butcher clause exists to foreclose. A soft default with a
  documented, reasoned escape hatch lets genuinely justified long files stay long and
  correct, while still catching unintentional sprawl.
- **This is the code analogue of an existing, working house pattern.** STANDARDS.md §4
  already splits docs past ~500 lines; that pattern has been running without complaint.
  This decision extends the same shape — default threshold, split (not compress) as the
  remedy — to code, with a tighter number because code is denser per line than prose.
- **Skills are exempted, not merely allowlisted,** because skill files are a distinct
  authored format (per ADR 0009/0010) whose length is driven by the instructions they
  must convey, not by accreting unrelated logic — the sprawl concern this rule targets
  doesn't apply to them the same way.

## Consequences

- **Amendment 2026-07-12:** exempting test files removes a category of large-but-low-risk
  files from the trip-wire (fewer allowlist entries needed for `*.test.ts`-style sprawl);
  clarifying scope to hq + authored projects means the checker is never expected to run
  clean against a vendored or cloned repo's own file-length habits — that was never the
  intent, but was ambiguous before this note.
- Easier: sprawling files get a mechanical trip-wire; the fix path (split into multiple
  files) is spelled out up front, so the response to a violation isn't ambiguous. Agent-
  driven editing has a better chance of landing clean patches on files kept near the
  default.
- Harder / accepted trade-off: running the checker against an existing repo may surface a
  backlog of already-long files; per the split-don't-butcher clause, those are *not* fixed
  by hasty edits just to pass — they get split properly (real refactor work) or reasoned
  onto the allowlist, either of which takes real time. The allowlist itself requires
  discipline: a lazy or vague one-line reason defeats the point of the escape hatch, and
  nothing but review catches that (the script only checks that a reason string exists,
  not that it's a *good* reason).
- Revisit if: the allowlist balloons past a handful of entries per repo (signal that 300 is
  miscalibrated for that codebase, or that the exemption is being used as a bypass rather
  than a genuine escape hatch), or if agent-editing success data on hq's own repos
  contradicts the Chong et al. finding this decision leans on.

## Alternatives considered

- **Hard cap enforced in CI (block the commit)** — rejected: no evidence 300 is a true
  defect or edit-failure threshold rather than a convention anchor; a hard block invites
  exactly the Goodhart's-law gaming (pad-to-file-count, or strip content to fit) that the
  split-don't-butcher clause is written to prevent.
- **No rule at all** — rejected: the doc-split precedent (STANDARDS.md §4) already treats
  sprawling files as a real problem for a lightweight, agent-ingestible workspace, and the
  Chong et al. inverted-U result gives an independent, non-anecdotal reason to expect large
  files to reduce LLM patch-edit reliability specifically — a concern doc-splitting alone
  doesn't cover.
- **A different number** (200 per McConnell's routine tolerance, or 500 to match the
  existing doc-split threshold) — rejected in favor of 300: it's the most widely-adopted
  convention default (ESLint `max-lines`, echoed by AWS Labs), sits centrally in the
  100–500 band every source treats as reasonable, and staying below the doc-split number
  reflects that code reads denser per line than prose.

**Links:** STANDARDS.md §4 (doc-split precedent), STANDARDS.md new source-file-length
section (this ADR), `tools/check-file-length.sh` (enforcement), ADR 0009/0010 (skills
authoring — basis for the blanket skills exemption).
