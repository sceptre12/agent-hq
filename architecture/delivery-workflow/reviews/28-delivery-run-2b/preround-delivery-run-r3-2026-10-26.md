# Pre-round check: item 28 delivery-run, round 3 (2026-10-26)

Artefact: skills/delivery-run/SKILL.md + references/{bus-and-ports,control-channel,handoffs-and-modes,ledger,resume,tick,verdicts}.md, current working tree (HEAD 71a4684; fix r2 uncommitted, 39 hunks, diff SCRATCH/fix28-r2.diff). Scope per brief: C1, C2, C5 on the + lines of fix r2; C3 maps each hunk to a finding id in fix-delivery-run-r2-2026-10-26.md. Checker: Haiku pre-round, read-only.

C1 FAIL skills/delivery-architecture/references/review-handoff.md:19 cited for "delivery-architecture does not yet write that block"; line 19 only says STAKES/CONTENTION/NOVELTY are "chosen here"; the header-block instruction is at :21 and the claim is not in the cited text.
C1 FAIL skills/release-track/SKILL.md:20 cited for "S1 hook refusal"; line 20 is step 0 (INPUT-ERROR rule). S1 is at :44 (red-flag table). :24 (G3), :35 and :54 (d7-round3) resolve.
C1 FAIL skills/delivery-run/references/briefs/implementer.md:8 cited for "reads only .tasks/<unit>-<slug>.md"; line 8 is blank. The Inputs line is :9. Off by one.
C1 PASS skills/delivery-pipeline/references/stages.md:73 (sub-task worktree for claude-p, proposed 29-22).
C1 PASS skills/release-track/SKILL.md:17 (STAKES, CONTENTION, NOVELTY as inputs), :37 (WAITING-HUMAN not terminal).
C1 PASS architecture/delivery-workflow/interfaces/part-b-desk.md:22 (.out polling; resolves from architecture/delivery-workflow/, not from the skill root).
C1 PASS wave-execution W' copy, skills/wave-execution/SKILL.md in ~/projects/agent-hq-worktrees/delivery-extends: :149-151 (barrier wave exhaustion post), :190-196 (checkpoint authority), :197 ("All passed"). Note: the delivery-w0 copy of wave-execution has different text at these lines; these cites resolve only against the W' copy.
C2 FAIL SKILL.md:10 "(live files only, AM4-4)" and tick.md step 1 "(AM-5 row 21)", handoffs-and-modes.md pm step 3 "(AM-5 row 15, with row 17 ...)": each names an external source (INTERFACES/AM rows) with no path:line-range pointer or verbatim quote. Same class in handoffs step 6 "(AM4-2)" and ledger "(AM-4 9)" (context lines; listed for the fixer, not charged to r2 alone).
C3 FAIL SKILL.md hunk @@-34 (INPUT-ERROR interfaces_version: "(live files only, AM4-4)") has no finding id: AM4-4 is absent from the r2 fix table and from panel7-delivery-run-r2 (grep 1.1.0 / AM4-4 empty). Also silent deletion in SKILL.md hunk @@-228 of "from any skill you invoke" and "no fix-verifier iteration" (hunk maps to R2-14 but the deletion is not in the fix record).
C4 KNOWN not re-failed (spec has no numbered step list; pins 297a8dc/6092662).
C5 FAIL + lines state rules with no "default|question|proposed|owner to decide" in the same sentence: SKILL.md step 3 "require RUN_HOME/catalog.tsv (else stop_reason: human, C1)"; ledger.md "Before each invocation: spawns + 1 + ... <= cap - 5" (+ line; cap formula); SKILL.md 10.2 lease rule (+ line before its tag). Tags sit at bullet or heading level in most other cases; these three do not.
C6 PASS SKILL.md 328 lines; references max 181 (handoffs-and-modes); all under 1000. No loop-brief cap.
C7 KNOWN not re-failed: fix r1 in WIP 103cb53; fix r2 uncommitted; HEAD 71a4684 touches no delivery-run skill file.
preround: fail | 6 fails (C1 x3, C2 x1, C3 x1, C5 x1)

## C3 hunk map (39 hunks; fix r2 table ids)
SKILL.md
1 @@-34 INPUT-ERROR interfaces_version: NONE (FAIL)
2 @@-56 L16, L17
3 @@-82 R2-05, R2-07, R2-18 (CV31 via L12)
4 @@-94 L16
5 @@-111 R2-18
6 @@-134 R2-06, R2-07, L10
7 @@-156 R2-11, R2-01
8 @@-169 R2-04, R2-03, R2-12, R2-07, L2
9 @@-196 R2-02, L1, R2-16
10 @@-212 R2-01
11 @@-228 R2-14
12 @@-244 R2-08
13 @@-258 R2-14, R2-07, R2-08
14 @@-268 R2-04
15 @@-283 R2-02
bus-and-ports.md
16 @@-18 R2-18
control-channel.md
17 @@-28 R2-04, R2-07
18 @@-56 R2-11
19 @@-70 R2-08
handoffs-and-modes.md
20 @@-6 R2-05, L16
21 @@-28 R2-01, R2-04, L19
22 @@-37 R2-14
23 @@-65 R2-14
24 @@-82 R2-07, R2-08
25 @@-93 R2-09
26 @@-102 R2-15, R2-17
27 @@-113 R2-04, R2-13
28 @@-125 L19
29 @@-140 R2-01, R2-02, R2-03, R2-04, R2-05, R2-06, R2-07, R2-08, R2-09, R2-11, R2-12, R2-13, R2-15, R2-16, R2-18
ledger.md
30 @@-39 R2-01, R2-12
31 @@-63 L2, R2-10
32 @@-79 R2-03
resume.md
33 @@-42 L12, L18, R2-07, R2-18
34 @@-61 R2-07
tick.md
35 @@-19 R2-06, R2-07, L10
36 @@-35 R2-01, R2-10, R2-11, L6
37 @@-69 L20, R2-04, R2-12
verdicts.md
38 @@-34 R2-02, L1
39 @@-58 R2-04, R2-16

Unmapped: hunk 1 only. Ids not carried by any hunk: none found except L4, L7-L9, L11, L14, L15 (listed as not touched in the fix record).
