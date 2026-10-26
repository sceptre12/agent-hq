# Pre-round check r3d (review-7-panel preround-check.md C1-C7), scope = lines changed by narrow fix r3b (fix-interfaces-r3b-2026-10-26.md)
C1 PASS INTERFACES.md:27 ADR 0055 cite :259-273 and ADR 0054 :267-284, owner-decisions.md:58-74 all open and match (prior fail fixed)
C1 PASS interfaces/part-c-waves-control.md:20,52 cites spec-format.md:120-128, 0054:118-122, 0023:137-138, part-03:35, changelog.md:199, owner-decisions.md:7,8,74 all open and match
C1 PASS INTERFACES.md:29,31 cites owner-decisions.md:23,28,37 and part-02-skill-inventory.md:74 open and match
C2 PASS interfaces/part-c-waves-control.md:52 pointers now present for D55, M17, ADR 0023, D7 (prior fail fixed)
C2 PASS all other r3b-changed lines naming an ADR, owner rule or source carry a path:line pointer
C3 PASS hunks mapped by content: INTERFACES.md:37,125,163,164,165 = V3-2/V3-1/V3-4/V3-2/V3-3; part-a:16,50,62,219 = V3-2/V3-4/V3-4/V3-2; part-c:20,52 = C5/C2; part-d:69,73,74 = V3-3/V3-4/V3-4; INTERFACES.md:27,29,31 = C1/N10/N11; no unmapped hunk (part-d:80 not in fix record, treated as unchanged)
C4 PASS unit regex `^([ui][0-9]+\|-)$` identical at INTERFACES.md:37,125,164 and part-a:185,219; `^[ui][0-9]+$` identical at INTERFACES.md:143, part-c:21, part-d:61; `^u[0-9]+$` at part-a:16 and part-d:61; PRIMARY_REPO/primary_repo spelled identically at INTERFACES.md:163, part-a:50,62, part-d:73,74 (part-b:148 embeds unanchored group in ANSWER pattern, not compared)
C5 PASS interfaces/part-c-waves-control.md:20 "never budget, budget_min or spawns" sentence now carries DEFAULT (integrator) (prior fail fixed)
C5 FAIL INTERFACES.md:29 "Part A.7 now states D21 as written: the hook skip only on PR creation and the first push" is an owner-rule paraphrase; no default/question/proposed/owner-to-decide word in that sentence (prior fail, recommendation tag fixed, paraphrase not)
C5 FAIL INTERFACES.md:31 "D15 makes 'external publication' a human step" is an owner-rule paraphrase with no tag word (prior fail, recommendation tag fixed, paraphrase not)
C5 FAIL interfaces/part-c-waves-control.md:52 "The Plan-checker runs rules 1-11 and 13-15 before round 1 (D55 ...)" paraphrases an adopted owner rule with no tag word; the DEFAULT tag sits in the next sentence (new finding, same class as INTERFACES.md:29)
C6 PASS largest changed file interfaces/part-a-state.md 300 lines; INTERFACES.md 234; part-b 162; part-c 176; part-d 160; all under 1000
C7 PASS n/a (no sha pin in brief)
preround: 3 fails
