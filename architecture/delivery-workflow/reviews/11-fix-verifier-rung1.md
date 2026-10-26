# 11-fix-verifier (EXTEND) — Rung 1 loop record

- **Artifact:** `skills/fix-verifier/SKILL.md` and `skills/fix-verifier/references/file-set-check.md`.
  - These live in W' = `~/projects/agent-hq-worktrees/delivery-extends`, branch `ext/delivery-extends`.
  - Author commit `3988d52` (`version: 1.1.0`, the `FILE_SET` input, M24).
- **Spec:** `architecture/delivery-workflow/tasks/11-fix-verifier.md`. Every RESOLVED line was treated as binding.
- **Loop:** one orchestrator (D35), and a separate agent for every role, never reused across roles:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed `doc-reviewer` (M29).
  - Fix: Opus, one new agent per round.
  - Fix-verify: Sonnet, running the installed `fix-verifier` (M29).
  - §9 fixture: a separate non-author Sonnet verifier with one sub-agent per case.
- **Round cap:** 3 (D7). Lint and typo nits were skipped. The fixer edited only `skills/fix-verifier/`.
- **Date:** 2026-10-26.
- **Sources:** the task spec; INTERFACES 1.2.0 (part-d D1, D1.1 and D2.3; part-a A.6); `delivery-workflow-sources/owner-decisions.md`; `tools/skill-authoring.md`.

## Round 1

- **Pre-round screen (G48): 0 Blocking, 3 Medium, 7 Advisory.**
  - Confirmed the known defect: nothing forbade prose before the `INPUT-ERROR` line.
  - The Security section sent traversal to `files_not_checked`, while a `FILE_SET` traversal is `INPUT-ERROR` with no verdict.
  - An absolute `FILE_SET` entry was `path` in the reference but unspecified in SKILL.md.
- **Review (doc-reviewer): 0 Blocking, 5 Medium, 4 Low. Verdict: NOT READY.**
  - The known prose-before-`INPUT-ERROR` defect.
  - Two response shapes (Output Contract JSON vs a bare `INPUT-ERROR` line), with nothing telling the caller how to distinguish them.
  - Canonicalization of `FILE_SET` entries was underspecified: nonexistent files, whitespace, directories, duplicates.
  - The check compared `changed_files` only, while spec §6 says `changed_files` **and** `diff` headers.
  - The How to Invoke template and the Input Contract JSON never showed `FILE_SET`.
- **Fix (Opus):** closed all six Medium findings and the cheap Low ones.
  - On a Step 0 failure the whole response is exactly the `INPUT-ERROR` line(s), matching the D1 regex. This is stated in Step 0, the Red flags, the Exit criteria and the reference.
  - The two response shapes are defined.
  - A Security exemption sentence was added.
  - Lexical normalization rules were added: `path` covers absolute or escaping entries; `format` covers an empty set or an empty entry; `missing`, `enum` and `unset` are never emitted.
  - `diff` headers are compared too.
  - An optional `FILE_SET=` line was added to the template, with a transport note (D2.3, R4-J22).
  - "the lead" was glossed and M24 was glossed in Provenance.
- **Fix-verify: ISSUES_FOUND, 1 Medium, 4 Low.**
  - The Medium: diff-header parsing had no hunk-body guard, so a false "outside" could fire.

## Round 2

- **Review (doc-reviewer, fresh agent): 0 Blocking, 1 Medium, 4 Low. Verdict: PASS WITH CONDITIONS.**
  - The Medium: `files_not_checked` entries and diff paths outside the root had no defined finding rule.
- **Pre-round screen (G48): 0 Blocking, 4 Medium, 6 Advisory.**
  - Diff headers sit beyond the base "changed_files only" scope text.
  - Mixed forms: lexical `FILE_SET` vs realpath `changed_files`.
  - `file` and "repo-relative" were undefined for diff-only paths.
  - Body size: SKILL.md went from 21,173 to 24,498 bytes against the 5k-token target.
- **Fix (Opus, new agent):**
  - Header recognition is limited to the file-header block, plus the `diff --git` and `rename from/to` lines. The `a/`/`b/` prefixes are stripped only in git-style diffs.
  - The sub-check is documented as the sole exception to the `changed_files`-only scope. The base lines are untouched; a sentence was added instead.
  - "Repo-relative" is defined as relative to the computed project root, with `file` the canonical absolute path. "Never compare mixed forms" is restored. Entries `.`, `a/..` and symlinks out of the root give `INPUT-ERROR FILE_SET path`.
  - One rule now covers out-of-root and `files_not_checked` paths: a Check 3 Medium finding, de-duplicated, in `changed_files` order and then diff order.
  - The Step 0 detail, the "Two response shapes" text and one Red-flags row moved to the reference. SKILL.md is now 22,613 bytes and 411 lines.
  - Lows fixed:
    - Step 1/2 JSON errors take precedence over Step 0.
    - The template's `INPUT-ERROR` line is conditional on `FILE_SET`.
    - The Security cross-reference was fixed.
    - A Provenance alias was added.
- **Fix-verify: CLEAN.** 0 Blocking, 0 Medium, 3 Advisory: shape wording, a path with spaces in a mode-only diff, and body size.

## Round 3

- **Pre-round screen (G48), after the round-2 fix: 0 Blocking, 3 Medium, 4 Advisory.** Orchestrator triage:
  - "Spec §8 'empty list' vs the Step 1 JSON error": **dismissed.** §8 and §7 refer to `FILE_SET` (`FILE_SET=` is `INPUT-ERROR FILE_SET format`), not to `changed_files`. It is already met.
  - "Check 3 base line says changed_files only, with no pointer": **dismissed.** The base line may not be edited (§9). The exception sentence added in round 2 sits in the new paragraph. Rated Low.
  - "The reference cites 'spec §5', which does not ship with the skill": **Medium, fixed (F1).**
  - "An outside-root `file` may be a relative path, but the Output Contract requires absolute": **promoted from Advisory to Medium, fixed (F2).**
  - "The Provenance parenthetical cites the changelog": **Low, fixed (F3).**
  - "Design ids (D1, D2.3, R4-J22) in the reference": left as is. These are contract citations.
- **Fix (Opus, new agent):** F1-F3 as above. The wording changes do not alter fixture cases A-D.
- **Fix-verify:** content CLEAN. 0 Blocking, 0 Medium, 2 Advisory:
  - Contract-id pointers (D1, D2.3, R4-J22) remain in the reference. This is intentional.
  - An absolute header path outside the root: join it or use it as is? Not specified.
  - At iteration 3 the installed skill appends its procedural max-iterations check-0 Blocking, and so returned `ISSUES_FOUND`. That finding is about the loop, not the content. The loop stops here (D7).

## Final

- **Rounds:** 3.
- **Final count:** 0 Blocking, 0 Medium, 4 Low/Advisory (open, listed below). The only Blocking is the procedural iteration-3 one.
- **Size:** SKILL.md is 411 lines and 22,617 bytes (the base was 21,173). The reference is 135 lines.
- **Open Lows (not blocking):**
  - The body is still about 5.6k tokens. The base was already about 5.3k before this item, and the spec only requires under 500 lines or overflow moved to `references/`.
  - A path with spaces in a mode-only or binary diff has no `---`/`+++` lines, so the path is ambiguous.
  - An absolute outside-root diff-header path: the join rule is unspecified.
  - Contract-id pointers are kept as citations.

### §9 done-condition

- The non-author verifier built the fixture under `$TMPDIR/ext11-fixture/` (a git repo with `a.md` and `b.md` both edited) and dispatched the skill once per case. Outputs are in `$TMPDIR/ext11-fixture/out/`:

  | Case | Input | Output |
  |---|---|---|
  | A | `FILE_SET=a.md` | `ISSUES_FOUND`, one finding: check `"3"`, Medium, `b.md`, "change outside FILE_SET: b.md" |
  | B | `FILE_SET=a.md,b.md` | `CLEAN`, no findings |
  | C | `FILE_SET` unset | `CLEAN`, 0 findings |
  | C.base | `FILE_SET` unset, unmodified installed skill | `CLEAN`, 0 findings |
  | D | `FILE_SET=../x` | exactly `INPUT-ERROR FILE_SET path`, with no prose or fence |

- All five replies were raw, with no prose and no code fences.
- The §9 block (`$TMPDIR/ext11-fixture/s9.sh`, copied verbatim from the spec) was re-run by the orchestrator after the round-3 fix:

```
$ FIXTURE_DIR=$TMPDIR/ext11-fixture/out bash $TMPDIR/ext11-fixture/s9.sh; echo "exit=$?"
EXT-11-OK
exit=0
```

- The fixture outputs were produced from the round-2 text. Round 3 changed only wording on paths A-D do not exercise: the spec pointer, the absolute `file` of an outside-root path, and the Provenance alias.

## Owner / integrator questions

- **Q11-R1 (integrator, caller side):** does a fix-verifier response that is an `INPUT-ERROR FILE_SET` line (no verdict) consume a D7 round and an `iteration`, and what does the caller write to `verify-<seat-id>-<n>.md` (A.6)?
  - **Recommended:** it does not count as a round. The caller fixes the input and re-dispatches with the same `iteration`, and writes no `verify-*` record for it.
  - The skill now says only that the line carries no verdict and that iteration accounting is the orchestrator's. The fixers did not decide this.
