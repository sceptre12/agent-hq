# Pre-round check r4b (G48), review-7-panel preround-check.md C1-C7; scope = round-4 fix rows J1-J23, PR10-C5, R4-J1..R4-J23, E16, E17
Checker: fresh read-only agent a9f84be20bf0c99fa (not author, not fixer). Artifact uncommitted, no baseline: C3 maps cited lines only.
C1 FAIL reviews/interfaces-2b/fix-interfaces-r4-2026-10-26.md J11 cites interfaces/part-c-waves-control.md:181 and J13 cites :183; the file has 180 lines (bus-down rule is at :178). Other sampled cites resolve (part-a:16,50,55,87,128,130,150,161,162,174,296,298; part-b:14,22,33,41,47,64,79,83,84,96; part-c:21,23,173; part-d:8,10,27,79,94,98,139,147,162).
C2 PASS INTERFACES.md:29,31,197 and part-a:312 owner quotes string-match owner-decisions.md:80 and :81-84.
C3 PASS (limit: no baseline) every row J1-J23, PR10-C5, R4-J1..R4-J23, E16, E17 present; sampled cited hunks carry a row id.
C4 FAIL interfaces/part-d-enums-topics.md:38 persona closed set names both `gate-checker` and `gate-runner` (A.7) for the gate role; fix J12 says one name per thing; INTERFACES.md:222 and part-c-waves-control.md:21 use `gate-checker`.
C4 PASS new names spelled identically wherever used: invocation, tier_override, step_id, release_tags.used/pattern/approval, primary_repo, linked_profiles[], clones[], interfaces_version, worktree_base, FILE_SET.
C5 PASS all five r4 fails cleared: part-a:312 (was :290, gate-runner sentence and --no-verify sentence) tagged DEFAULT (integrator); part-a:101 tagged DEFAULT per R40-1; part-b:64 (was :54) tagged; INTERFACES.md:197 (was :193) O-N11 row now verbatim-quoted. Limit: no full-file sentence sweep of r4 lines.
C6 PASS INTERFACES.md 276, part-a-state.md 325, part-b-desk.md 172, part-c-waves-control.md 180, part-d-enums-topics.md 164 lines (wc -l).
C7 PASS n/a (no sha pin in brief).
preround: 2 fails
