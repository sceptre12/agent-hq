# Pre-round check r3c (review-7-panel preround-check.md C1-C7), round-3 fix scope

Scope: lines changed by the round-3 fix per `reviews/interfaces-2b/fix-interfaces-r3-2026-10-26.md` (H1-H27, PR8-C5, H36 via N10), in INTERFACES.md and interfaces/part-a-state.md, part-b-desk.md, part-c-waves-control.md, part-d-enums-topics.md. Read-only except this record. Checker: fresh read-only Haiku run, not the author or fixer (Rule 4). No git commands run.
C1 FAIL INTERFACES.md:27 cite `decisions/0055-desk-verb-permission-tiers-02.md:257-271` ends before OP10 (line 273); range should be 259-273.
C1 PASS other changed-line cites open and match: part-a:16,17,37,41,85,103,277,281; part-b:22,63,69,73,74,80,119; part-c:11,20,29,31,33,37,52; part-d:37; INTERFACES.md:29,31,142-159,202; ADR 0054 :75-80, :93-96, :118-122, :174-176; ADR 0055 :164-168, :185-191; spec-format.md:120-128; owner-decisions.md:23,28,37,58-60,62-72,74.
C2 FAIL interfaces/part-c-waves-control.md:52 names owner rules "D55, M17", "(D7)" and "ADR 0023" with no path:line pointer or verbatim quote.
C2 PASS all other changed lines naming an ADR, owner message or source carry a path:line pointer (part-c:11, :20, :33, :37; part-d:37; part-b:63, :69; INTERFACES.md:31).
C3 PASS every changed hunk maps to a fix-record id (H1-H27, PR8-C5, H36/N10, H14/N11) by line content; no unmapped hunk found.
C4 PASS unit regex `^[ui][0-9]+$` in part-c:21, part-c:29, part-b:148, part-d:61, INTERFACES.md:143; `^([ui][0-9]+|-)$` at part-a:185; unit id `^u[0-9]+$` at part-a:16 and part-d:61 agree. Register states `register.consumed` / `register.refused` agree in part-a:41, part-b:22, part-c:119. Field names `merge_reach`, `merge_sha`, `ci.required_checks[]`, `done_condition` agree across files. Step-8 `merge_reach` check agrees (part-b:63, INTERFACES.md:149). C7 n/a (no sha pins in the brief).
C5 FAIL interfaces/part-c-waves-control.md:20 "never budget, budget_min or spawns, which are lead-side" and the rule-11 formula restatement carry no default/question/proposed/owner-to-decide word.
C5 FAIL INTERFACES.md:29 (N10) "keep D21 as written" recommendation and the D21 paraphrase: header "open, owner; not decided here" lacks the words.
C5 FAIL INTERFACES.md:31 (N11) paraphrase "D15 makes external publication a human step" and "Recommended answer: (a)" lack the words.
C5 PASS interfaces/part-d-enums-topics.md:13 covered by the D1.1 heading tag (line 11); INTERFACES.md:142-159 by Kind DEF (legend line 43); other changed rule sentences carry DEFAULT (integrator).
C6 PASS largest changed file interfaces/part-a-state.md 300 lines; INTERFACES.md 231; part-b 162; part-c 176; part-d 160; all under 1000.
C7 n/a no sha pins in the brief.
preround: 5 fails
