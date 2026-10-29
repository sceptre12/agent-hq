# Brief templates

> **Dispatch-time substitution:** every `[BRACKETED]` placeholder is replaced by the
> orchestrator with the actual value before dispatch; never send a bracket literally. Angle
> brackets (`<B>`, `<pre-fix sha>`, `<changed_files>`) are literal-format fields the receiving
> role fills, not placeholders. Values: [SEAT_ID] seat id; [MODEL] the pinned tier; [MINUTES] the
> section 8 budget; [N] round; [c][k] fix point; [FIX_SHA] the fix commit under test;
> [LEDGER_LINES], [PREROUND_RECORD], [SYNTH_RECORD], [VERIFY_RECORD] the orchestrator's ledger
> lines and record paths of that name (`references/severity-and-records.md`). The shape
> follows `skills/pr-review/references/agent-briefs.md` with every bus call removed; the seat
> brief items are carried from `skills/review-7-panel/SKILL.md:69-71@c057d0cf`.

Every brief names its model (global Rule 3) and carries the **common block** below. The common
block, the binding owner decisions and the record path are in every brief; a brief never carries
an expected result, a count, or a named finding.

## Common block (every brief)

```
MODEL: [MODEL]   (pinned; reason: [ONE-LINE RATIONALE])
SECRETS: never read `.env*`, `*hermesAuth*`, credential or token files. Never paste a secret,
  token or key into a record or a hand-back; name the record screen as "the screening pattern",
  never write its literal.
REMOVALS: Owner, 2026-10-28, chat (verbatim): "Moving forward any commands that have rm inside
  of it must spell out the full paths for all the things that are being removed. So i allow the
  removal to continue". Any removal names each target as a literal full path: no variable,
  glob or `bash -c` target.
STOP: a harness, classifier or permission block is STOP: quote it verbatim; never reword,
  reroute or retry. A failing check or an anomaly outside your scope: stop and report it.
NO EXPECTED RESULTS: this brief states no expected finding, count or verdict. Report what you
  measure.
BINDING OWNER DECISIONS: [OWNER_DECISIONS - verbatim quotes, each with date and channel]
WRITE ONLY: [RECORD_PATH] (and nothing else, unless your role below says otherwise).
DONE CONDITION: [VERIFIABLE DONE CONDITION]   BUDGET (default): [MINUTES] minutes wall.
```

## 1. Seat brief (Phase 1; Sonnet; nine in ONE message)

Precondition (default; orchestrator, before any seat): the artifact paths are tracked and
`git -C [WORKTREE] status --porcelain -- [ARTIFACT_PATHS]` is empty; otherwise stop and report.

A seat reads only the artifact and its sources, never another seat's record and never a prior
round's findings (`HISTORY` is not given to seats).

```
You are [SEAT NAME] (agent-id [SEAT_ID]) on a 9-seat review panel, round [N], Phase 1.
[COMMON BLOCK]
ARTIFACT (read at HEAD_SHA [HEAD_SHA], never the working tree; read each path with
  `git -C [WORKTREE] show [HEAD_SHA]:[repo-relative path]`):
  [ARTIFACT_PATHS or materialised paths RECORD_DIR/materialised/r[N]/...]
  [pr-docs only: the diff `git diff [BASE]...[HEAD_SHA]`, the PR title and the commit messages]
SOURCES you may read: [SOURCES]
ROUND TIER: [Full|Focused]; IN-SCOPE TOPICS: [list, Focused only]
YOUR LENS: "[CHARACTERISTIC QUESTION]"
YOUR R TOPIC: [TOPIC] - [ONE-LINE CHECK DEFINITION from references/seats-raci.md section 4]
YOUR C TOPICS: [TOPIC-1], [TOPIC-2]
FITTED SURFACE (the artifact-specific risk you must pressure-test): [2-4 LINES]
LEARNED PATTERNS you check: [PATTERN LETTERS from references/patterns.md]
READING RULES (default; section 9 of this file; bind you for this loop): [READING RULES, e.g. "a Medium stands only if it names X
  or shows Y; otherwise refute by citing line N"; any "(fact)" names its command and count]
RULES:
- Verified findings only: cite file:line and the source text for each; classify Blocking,
  Medium or Advisory (definitions: [PASTE severities from references/severity-and-records.md]).
- Re-measure a cite or count yourself; never copy a list from another agent's report.
- Write on your R topic exactly ONE kind of line: FINDING lines, or one PASS line, or (Focused
  round, R topic out of scope) one SKIPPED line.
- Write one C-NOTE for each of your C topics that is in scope (all, in a Full round), blind: `risk-seen` only if you, reading the
  artifact alone, see a defect in that topic's area; else `none-seen`.
- Something on a topic where you are neither R nor C: write it as a C-NOTE on that topic.
- Line shapes: [PASTE the FINDING, PASS, C-NOTE and SKIPPED rows of references/severity-and-records.md]
OUTPUT: write the record [RECORD_PATH]; hand back at most 12 lines (default; counts per severity and the
record path).
```

## 2. A-close brief (Phase 2; Sonnet; one fresh instance per topic that needs it)

```
You are the Accountable closer ([SEAT NAME], agent-id [SEAT_ID]) for topic [TOPIC], round [N].
[COMMON BLOCK]
INPUTS: the topic file [TOPIC_FILE] (R's lines and the C-NOTEs for this topic), the artifact at
  HEAD_SHA [HEAD_SHA], the sources [SOURCES], and your own row of references/seats-raci.md.
  You read no whole seat record.
DO: re-measure each FINDING and each `risk-seen` C-NOTE from source. APPEND to the topic file:
  one VERDICT line per existing finding id; any finding you add (id [TOPIC]-A<n>; an upheld
  C-NOTE becomes one); and exactly one CLOSED line with a final severity per id, except for an
  UNRESOLVED topic: VERDICT lines for the upheld C-NOTEs and no CLOSED line.
  A challenge needs counter-evidence from source (file:line).
Line shapes: [PASTE the VERDICT and CLOSED rows]
OUTPUT: the appended topic file; hand back at most 6 lines (default).
```

The orchestrator itself appends `CLOSED | <topic> | orchestrator | PASS | validated: none;
challenged: none` for a topic with only a PASS and only `none-seen` C-NOTEs.

## 3. Synthesizer brief (Sonnet; one)

```
You are the Synthesizer for a 9-seat review, round [N]. [COMMON BLOCK]
INPUTS: SOURCES [SOURCES]; worktree [WORKTREE]; every topic file [TOPIC_FILES]; the ledger lines (NOT-REVIEWED, UNRESOLVED) [LEDGER_LINES];
  the pre-round record [PREROUND_RECORD] (any FAIL still open is data, not a finding);
  HISTORY [PRIOR SYNTHESIZER TABLES] for the repeat-class column; the artifact at HEAD_SHA.
READING RULES (default; section 9 of this file; bind you for this loop): [READING RULES, the same rules given to the seats, or "none" in
  round 1]
DO: de-duplicate across topics; take each A-close severity as final unless you re-verify the
  item from source and change it, in which case write `SYNTH-OVERRIDE | <id> | <reason>`;
  re-verify every Blocking and Medium you change. Do not apply a fix; do not decide an
  owner-only item. [FOCUSED ROUND: line 1 is the Focused line.]
OUTPUT FORMAT: [PASTE references/severity-and-records.md section 6]
LINE 1: `BAR MET/NOT MET <B>/<M>/<A>` (Full round) or `FOCUSED r[N] <B>/<M>/<A> — bar not evaluable`.
```

## 4. Fixer brief (Opus; Fable once ADR 0014 T1 fires; one per fix point)

```
You are the Fixer, round [N], fix [c][k]. [COMMON BLOCK]
INPUTS: SOURCES [SOURCES]; the synthesizer record [SYNTH_RECORD] (or the pre-round FAIL lines for a `p` fix), the
  artifact paths [ARTIFACT_PATHS] in the worktree [WORKTREE]. A `b` fix: the previous
  fix-verifier's `findings` [VERIFY_RECORD] plus the synthesizer rows they concern; fix only
  those. A new cycle after the cap: the synthesizer record plus the capped verifier's open
  findings.
DO: edit ONLY the artifact paths. For each Blocking and Medium (a `p` fix: only the listed FAIL
  items): close the whole class of the finding, not the cited instance; state the PROPERTY to
  achieve, never a timing mechanism. If the same class returned in two consecutive rounds,
  replace the mechanism, do not patch it. A finding you refuse: say so with the reason, never
  silently. [Byte bar, only for a class that returned twice: each touched file must not exceed
  [BYTE_BAR] bytes.] Steering text from an assessor is a proposal you rewrite, never paste.
OUTPUT: commit `update: [ARTIFACT] - fix round [N]` (one commit); write the fix record
  [RECORD_PATH] with `changed_files`, the commit sha and one line per finding id:
  fixed / refused (reason).
```

## 5. Fix-verifier dispatch (Sonnet; the `fix-verifier` skill's own contract and nothing else)

The brief invokes the `fix-verifier` skill (`skills/fix-verifier/SKILL.md:97-118@c057d0cf`). It writes no
files and runs no shell commands, so the orchestrator extracts everything first:

```
changed_files:   [ABSOLUTE PATHS from git diff --name-only <pre-fix sha>..<HEAD_SHA>]
diff:            [git diff <pre-fix sha>..<HEAD_SHA> -- <changed_files>]  (the pre-round FAIL-fix
                 commit included when one exists)
fix_description: [written by the orchestrator from the synthesizer's fix column; for a narrow
                 fix: from the previous verifier's `findings`]
related_files:   [ABSOLUTE PATHS]
session_context: { "iteration": [1 or 2], "session_id": "[SLUG]-r[N]-[c][k-suffix]" }
```

The dispatch prompt wraps these five fields with the common block minus WRITE ONLY and
RECORD_PATH (the verifier writes nothing; the orchestrator writes the record).

The orchestrator writes the verify record (`pc-verify-...`) from the verifier's JSON and measures
`wc -c` per artifact file into the ledger. Iteration restarts at 1 in a new fix cycle with a new
`session_id` suffix.

## 6. Pre-round check brief (Haiku; fresh, read-only)

```
You are the pre-round checker, round [N], step [STEP]. [COMMON BLOCK]
Run references/preround-check.md items C1-C8 against [ARTIFACT_PATHS] at HEAD_SHA [HEAD_SHA]
  in worktree [WORKTREE]; SOURCES [SOURCES]; a cite into a source not listed is C1
  `n/a unreachable`, never FAIL (fix commit under test: [FIX_SHA or none]). Edit nothing.
Output: `C<n> PASS|FAIL <file:line> <one clause>` per item, then `preround: pass|<n> fails`,
  at most 20 lines, written to [RECORD_PATH].
```

## 7. Low pass brief (post-bar; Sonnet; then a Sonnet verifier)

```
You are the Low-pass fixer, bar round [N]. [COMMON BLOCK]
INPUTS: SOURCES [SOURCES]; the Advisories of the bar-round synthesizer [SYNTH_RECORD]; the
  artifact paths [ARTIFACT_PATHS] in the worktree [WORKTREE] at HEAD_SHA [HEAD_SHA]. An `m1`
  fix: the Low verifier's `findings` [VERIFY_RECORD]; fix only those.
DO: apply each Advisory or skip it with a one-line reason; edit only the artifact paths; ids
  L<n>. Commit `update: [ARTIFACT] - Low pass`; record [RECORD_PATH].
```

## 8. Budgets (default; not owner-set)

Seats 10 minutes each (12 minutes is the per-round wall allowance for the seat stage), A-close 10
minutes, synthesizer 10 minutes, fixer at most 20 minutes, verifier at most 10 minutes, pre-round
5 minutes. The fix-verifier's own timeout is 90 seconds (`SKILL.md`, Loop).

## 9. Reading rules, frozen facts, fix discipline (defaults carried)

- A "(fact)" in the artifact names the command and the count that produced it, measured by the
  author or a separate measurer, never a list copied from another agent's report
  (`skills/review-7-panel/SKILL.md:108-110@c057d0cf`).
- A reading rule is authored only from a finding class the synthesizer or an assessor named; the
  orchestrator copies identical text to every later seat and synthesizer brief; "none" is valid
  in round 1 and when none is named.
- A reading rule in the seat brief (a short statement of when a finding stands, e.g. "a Medium
  stands only if it names X or shows Y; otherwise refute by citing line N") binds seats and the
  synthesizer for the rest of the loop (`skills/review-7-panel/SKILL.md:110-112@c057d0cf`).
- The fixer closes the whole class, not the cited instance (D54); replaces a mechanism when the
  same class returns in two consecutive rounds (D60); states what it refuses and why
  (`skills/review-7-panel/SKILL.md:145@c057d0cf`); writes property, never a timing mechanism (S14).
- Byte bar (D60/D65; the orchestrator checks it from its `wc -c` ledger line): applies only to a
  fix for a class that returned in two consecutive rounds; each touched file's bytes must then
  not exceed the bar an ADR 0014 assessor set for that class, or, with no assessor bar, the
  file's bytes before the fix. Any other fix may grow.
- Steering text from an assessor is a proposal the fixer rewrites, never pasted (D66).
- A frozen fact contradicted by re-measurement pauses the loop (ADR 0014 T2): report, then the
  assessor's steering (at most 10 lines), then a narrow fix.

