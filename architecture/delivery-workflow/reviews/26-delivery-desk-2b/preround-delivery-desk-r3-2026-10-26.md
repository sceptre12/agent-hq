# Pre-round check r3: 26 delivery-desk (G48, read-only, 2026-10-26)
Pin f68f6f2 (ancestor of worktree HEAD 6077dfc; no commit touches skills/delivery-desk between them). Set: skills/delivery-desk/{SKILL.md, references/checks.md, verbs.md, human-gates.md, schemas.json, source-keys.md (untracked)}.
C1 FAIL verbs.md:23-24 "(the profile `clones[]` entry is a path only, `part-a-state.md:115`)": at f68f6f2 the `clones[]` row is part-a-state.md:114 (worktree :116); :115 is `linked_profiles[]`.
C1 PASS all other cites open and match: SKILL:12-20, :113-114, :129-130, :154-156 (A.7 range 325-342 holds the :333 statement at the pin); checks:4-5, :111-112 (part-b:83), :170-174 (OD:67 and part-b:54 quotes), :178-180, :182-184; verbs:12 (ADR :198 quote), :15-16 (desk-req-schema.sh:23-24), :98 (part-b:110), :176 (part-b:98 quote); human-gates:5-7; schemas $comment (part-b:116).
C2 FAIL SKILL.md:154-155 `(N10, "every desk push")` does not string-match owner-decisions.md:80 "ALWAYS HUSKY=0 on desk pushes".
C2 FAIL bare ids not keyed in references/source-keys.md: "C5.1" human-gates.md:58 and verbs.md:150; "C5.3" checks.md:16; "AM-2" verbs.md:174; "R1-6" checks.md:67; "R1-7" checks.md:76.
C3 PASS every r2 hunk maps to r2-1/2/3/5/7/11/12/17/19/21/22 per the fix record hunk map (SKILL 65-70, 84-88, 113-114, 122, 131-134, 154-156, 174-177, 205-206; checks 28, 53, 59-61, 97-98, 115-128, 155-180; verbs 21-28, 45-46, 57, 72, 78-79, 96, 107, 119, 128-129, 140, 160; schemas envelope.verb). No fix commit: mapped against the working tree.
C4 KNOWN tasks/26-delivery-desk.md:5 "INTERFACES version read: `1.1.0`" vs SKILL.md:14 and checks.md:3 "1.2.0" (carried item; only the version line was compared).
C5 FAIL SKILL.md:131-134 "every other `DESK` ... line is queued until the current id has its `.out`" and :65-67 "requests run one at a time": no tag word in SKILL; the only tag is checks.md:122 "author default".
C5 FAIL SKILL.md:113-114 "`<remote>` = `origin`" and checks.md:97-98 "every `<remote>` is the clone's `origin`": pointer to verbs.md §Repository binding only, no tag word (the tag is at verbs.md:21).
C5 PASS verbs.md:21-28 (under "author default" lead); checks.md:115-116, :122, :28, :59-61 carry tags.
C6 PASS SKILL.md 223, checks.md 187, verbs.md 207, human-gates.md 69, schemas.json 898 lines (all under 1000).
C7 PASS sha256 12-hex (was): SKILL.md f93a013b6432 (80b83c173b5a); checks.md 87d7bc73cd3b (d09cf016baff); verbs.md 77272bacf174 (444e4969d89d); human-gates.md 0cbdc591c919 (same); schemas.json c45a1896a549 (4d18c98118da); source-keys.md c22000bd16c1 (new).
preround: 5 fails
