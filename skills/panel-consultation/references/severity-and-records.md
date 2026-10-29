# Severities, record names, line shapes, hand-back

One name per loop step, one shape per line kind. Every record named here is written under
`RECORD_DIR` (outside the reviewed tree). Records are screened per `SKILL.md` (Independence and
secrets) before another role reads them or they are committed.

## 1. Severities

Pr-review and panel-review definitions merged (`skills/pr-review/references/phase-b-c-severity.md:35-45@bd87a869`,
`skills/panel-review/references/phase-b-c-severity.md:25-34`):

- **Blocking** - cannot merge or dispatch: wrong at runtime, invalid output, a security exposure,
  a contradiction an implementer cannot resolve, a rule made without an owner quote where one is
  required.
- **Medium** - must fix before the bar: unverified claim, drift from source, partial migration,
  missing clarity that would change what an agent does.
- **Advisory** - does not block: workable but confusing, future edge case, style.

Phase B carried (`skills/pr-review/references/phase-b-c-severity.md:3-19@bd87a869`): the panel
presents; the caller or owner decides on anything beyond the artifact's own text. Nothing in this
skill waits for a human inside a loop.

## 2. Placeholders

- `<slug>`: the artifact's basename without extension, lower-case, hyphens (a companion set: the
  first path's).
- `<date>`: UTC `YYYYMMDD`.
- `<N>`: round number (the Low cycle uses the bar round's N).
- `<seat-id>`: the agent-id of `references/seats-raci.md` section 1.
- `<topic>`: a topic of `references/seats-raci.md` section 2.
- `<c>`: the fix's cycle letter: `a` main fix, `b` the one narrow fix (the cap in `SKILL.md`,
  Loop), `p` pre-round-FAIL fix, `l` Low pass, `m` Low narrow fix.
- `<k>`: the fix cycle's attempt number, carried by every record of that cycle (1 = first, +1 per
  escalated cycle); for `p` alone, the ordinal of the FAIL fix within round N (a FAIL fix is never
  retried).

## 3. Record names

Shape carried from `skills/review-7-panel/SKILL.md:66-68@c057d0cf`, prefix `pc-`; they apply to loops run
by this skill.

| Step | Record |
|---|---|
| ledger (one line per step `<UTC ts> <step> <tier> <counts> -> <record>; <next>`; the tier inputs per round; NOT-REVIEWED and UNRESOLVED lines) | `pc-loop-<slug>-<date>.md` |
| pre-round check | `pc-preround-<slug>-r<N>-<step>-<date>.md`, `<step>` in {`pre`, `post-a<k>`, `post-b<k>`, `post-p<k>`, `post-l<k>`, `post-m<k>`}: `pre` is a round's check before its seats (a round after a fix enters on the previous round's last `post-*` check); `post-<c><k>` is the check after fix `<c><k>` (`post-p<k>` is the re-run). E.g. `pc-preround-build-plan-r2-post-a1-20261028.md` = the check after round 2's main fix |
| seat; topic file (the A-close appends its lines to it); synthesizer | `pc-<slug>-r<N>-s-<seat-id>-<date>.md`; `pc-<slug>-r<N>-topic-<topic>-<date>.md`; `pc-<slug>-r<N>-synth-<date>.md` |
| fix (any kind) | `pc-fix-<slug>-r<N>-<c><k>-<date>.md`. E.g. `pc-fix-build-plan-r2-b2-20261028.md` = round 2's first narrow fix in the Opus retry cycle |
| fix-verifier | `pc-verify-<slug>-r<N>-<c><k>-<date>.md`, mirroring the fix it verifies (a `p` fix has no verifier: its check is `post-p<k>`). E.g. `pc-verify-build-plan-r2-b2-20261028.md` verifies the fix above |

## 4. Finding ids

Assigned by the writer at write time: seats `<seat-id>-<n>` (n from 1 per record); A-close
additions `<topic>-A<n>` (n from 1 per topic file); synthesizer `r<N>-B<n>`, `r<N>-M<n>`,
`r<N>-A<n>`, each row mapping to seat ids; pre-round `C<n>` (the check number, `-<k>` for its
k-th hit); fix-verifier `V<n>` (the index in its JSON `findings`); Low pass `L<n>`. Pre-round C3
accepts all of these classes.

## 5. Line shapes

`|` separates fields; `/` marks alternatives, except in the written-out count triple `<B>/<M>/<A>`.

| Line | Shape |
|---|---|
| FINDING | `FINDING \| <id> \| <topic> \| Blocking/Medium/Advisory \| <file:line> \| <what> \| Fix: <property>` |
| PASS | `PASS \| <topic> \| <what was checked>` |
| C-NOTE | `C-NOTE \| <id> \| <topic> \| risk-seen/none-seen \| <evidence>` |
| SKIPPED | `SKIPPED \| <topic> \| r<N> \| focused` - a dispatched seat's R line when its R topic is out of scope (Focused round) |
| VERDICT | `VERDICT \| <id> \| validated/challenged/escalated \| <final severity> \| <evidence>` - A-close, one per existing finding id |
| CLOSED | `CLOSED \| <topic> \| <seat-id>/orchestrator \| <B>/<M>/<A> after re-measure, or PASS \| validated: <id>=<final severity>,...; challenged: <ids>` - validated (escalated included) = counted at that severity; challenged = refuted from source, not counted |
| SYNTH-OVERRIDE | `SYNTH-OVERRIDE \| <id> \| <reason>` - synthesizer; absent, the A-close severity stands |
| ledger | `NOT-REVIEWED \| <topic> \| r<N> \| focused`; `UNRESOLVED \| <topic> \| r<N> \| <reason>` (`malformed` or `transport`) |
| synthesizer line 1; hand-back line 1 | `BAR MET/NOT MET <B>/<M>/<A>` (Full round); `FOCUSED r<N> <B>/<M>/<A> — bar not evaluable`; hand-back only: `BAR NOT MET — fix-cycle cap`, `BAR NOT MET — transport`, `BAR MET — lows: transport` |

A seat's record holds exactly one kind of line for its R topic: one or more FINDING lines, or one
PASS line, or one SKIPPED line, plus one C-NOTE per C topic. More than one kind, or none, is
malformed (re-dispatch rule: `SKILL.md`, Loop).

## 6. Synthesizer table

```
id | Issue | Severity | Topic | R | A | seat ids | repeat class | Fix (property)
```

Design-specified. The row shape follows the table in `skills/pr-review/references/synthesizer-brief.md:43-46@28e7e358`,
whose columns are `# | Issue | Severity | Check | R | A | C Responses | Recommended Fix`; the
columns Topic, seat ids and repeat class are this skill's own (repeat class is named from HISTORY:
the same finding class returned in two consecutive rounds). The synthesizer's record:

1. Line 1: `BAR MET/NOT MET <B>/<M>/<A>` or the Focused line (section 5).
2. The table, one row per de-duplicated finding, final severity from the A-close unless a
   `SYNTH-OVERRIDE` line says otherwise; every Blocking and Medium it changes is re-verified
   against its source first.
3. Deliberation trail for each Blocking row: R's finding, each risk-seen C-NOTE, the A-close
   VERDICT.
4. Ledger lines it received (NOT-REVIEWED, UNRESOLVED) and any pre-round FAILs still open (data,
   not findings).
5. Then it stops. It applies no fix and decides no owner-only item.

## 7. Hand-back form

At most 10 lines to the caller (carried from `skills/review-7-panel/SKILL.md:120-125@c057d0cf`):

1. Line 1: the hand-back line of section 5.
2. Rounds and tiers (for example `r1 Full, r2 Focused, r3 Full`).
3. Final B/M/A.
4. Ledger, last synthesizer and last fix-verifier record paths.
5. ADR 0014 T1 and T2 fires (time and round).
6. Artifact sizes (`wc -l`, `wc -c` per file).
7. `lows: applied <n> / open <n> / reverted yes|no`.
8. Unpushed fix commit shas when no push occurred (PR forms).
9. `owner notes:` items that need the owner's notice or decision, named, not decided.

The orchestrator never decides an owner-only item (rules, money, external publication, deletion).

## 8. Screening (record-identity grep)

Pr-review's grep (`skills/pr-review/SKILL.md:334@28e7e358`), run by the orchestrator:

```
grep -cE 'sk-ant-|gh[opsu]_|github_pat_' "$RECORD_PATH"
```

(i) on each seat, A-close (topic file) and synthesizer record once it lands, before another role
reads it or it is committed; (ii) on every other hand-back text before it is persisted; (iii) on
`git show <fix sha>` of each fixer commit before the verifier and before any push. Any count other
than 0 is stop-the-line; a flagged fix commit is reverted with `git revert`.
A match whose line (`grep -n`) is only the quoted screening pattern is reported to the owner as a
pattern quote, not a leaked token; briefs tell seats and fixers to write "the screening pattern",
never the literal.
