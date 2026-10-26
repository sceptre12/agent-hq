# Pre-round check r4 (review-7-panel preround-check.md C1-C7), scope = lines changed by fix r4-0 (fix-interfaces-r4-0-2026-10-26.md); owner rulings owner-decisions.md:78-84
Checker: fresh read-only agent (not author, not fixer). Artifact is uncommitted; no git commit exists, no baseline snapshot, so C3 maps record rows to the cited lines only.

C1 PASS INTERFACES.md:5,27,29,31 owner-decisions.md:1-84, :57-60, :62-72, :73-74, :78-84, :80, :81-84, :58-60 all resolve and match
C1 PASS interfaces/part-a-state.md:99,101,113-117,290 owner-decisions.md:28, :37, :80, :84 resolve; quoted text matches (:28 "HUSKY=0 skip on PR creation/first push is allowed", :37 R2-3 quote)
C1 PASS interfaces/part-b-desk.md:54,56,63,73,86,160 owner-decisions.md:80, :82-84 resolve; part-c-waves-control.md:52 part-03-personas-and-concurrency.md:35 "runs before round 1 (D55)" and owner-decisions.md:7 "ADOPT as skill rules: D35, D55, ..." match
C2 PASS owner quotes at INTERFACES.md:29,31, part-a-state.md:290, part-b-desk.md:73,86 string-match owner-decisions.md:28,37,80,82-84; part-c-waves-control.md:52 pointers present
C3 PASS (record-to-line mapping only; no baseline) INTERFACES.md:5 C1; :27 C1; :29 N10-a/C5-1; :31 N11-a/C5-2; :102 N10-b; :192,:193 N10-c/N11-b; :197-201 N11-b (R40-1); part-a:99 N11-d; :101 N11-d; :113-117 N11-c; :290 N10-d; part-b:54 N11-f; :56 N11-f; :63 N11-f; :73 N10-e; :86 N11-e; :160 N11-f; part-c:52 C5-3. Every cited changed line maps to a row. Limit: changed lines not listed in the record cannot be detected without a baseline.
C4 PASS release_tags keys identical by exact string: used / pattern / approval at part-a:113-115, part-a:99,101,117, part-b:54,86, INTERFACES.md:31,193,201. tag-push request field set {repo, tag, sha, step_id} at part-b:86 matches INTERFACES.md:201 ("gains step_id"). Note (not a FAIL): part-b:125 is the B6 result schema `tag-push | tag, sha`, a different schema by design.
C4 PASS HUSKY=0 wording "ALWAYS HUSKY=0 on desk pushes" identical at INTERFACES.md:29, :102, :192 and part-a:290 and part-b:73; the verbatim pass sentence "The recorded affected lint/test/typecheck pass before each push (D21/R2-3) still applies." identical at INTERFACES.md:29 and part-a:290.
C5 PASS INTERFACES.md:29 tagged DEFAULT (integrator) / default; prior r3d FAIL cleared (paraphrase "Part A.7 now states D21 as written" removed)
C5 PASS INTERFACES.md:31 tagged DEFAULT (integrator); prior r3d FAIL cleared ("D15 makes external publication..." removed)
C5 PASS interfaces/part-c-waves-control.md:52 rule set and invocation tagged DEFAULT (integrator); prior r3d FAIL cleared
C5 FAIL interfaces/part-a-state.md:290 "Before every push the gate runner runs the repo profile's exact affected lint, test and typecheck command once for that push or batch, at unit end, and records the pass:" states a rule, is not a verbatim quote, and has no default/question/proposed/owner-to-decide word (the verbatim quote follows the colon, so the rule itself is untagged)
C5 FAIL interfaces/part-a-state.md:290 "`--no-verify` is never used (D21)." states a rule with a design cite and no tag word; owner text at owner-decisions.md:28 is not quoted here
C5 FAIL interfaces/part-a-state.md:101 Enforcement sentence "...and a `tag-push` under `release_tags.approval: human` ... until the step's `H-prod` file exists" is a r4-0 change (N11-d) stating a rule with no tag word; only the cell at :99 is tagged
C5 FAIL interfaces/part-b-desk.md:54 policy row clause "a `tag-push` the repo profile does not allow (no `release_tags` entry, `release_tags.used` `no`, or `tag` not matching `release_tags.pattern`...)" states a rule whose used/pattern clauses are DEFAULT (R40-1) with no tag word in the cell (cite to B4 only)
C5 FAIL INTERFACES.md:193 O-N11 row paraphrases the owner ruling ("uses release tags at all; if so, its push and approval rule") without quote marks or tag word (borderline: a ledger summary of an owner ruling; verbatim text is at INTERFACES.md:31)
C6 PASS INTERFACES.md 242, part-a-state.md 303, part-b-desk.md 162, part-c-waves-control.md 176, part-d-enums-topics.md 160; all under 1000
C7 PASS n/a (no sha pin in brief)
preround: 4 fails
