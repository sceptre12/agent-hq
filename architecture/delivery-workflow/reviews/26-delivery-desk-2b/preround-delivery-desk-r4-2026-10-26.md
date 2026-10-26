# Pre-round r4, 26 delivery-desk (checker: Haiku, read-only, fresh; after fixer r3)
Set (uncommitted, worktree HEAD 5fee2b3): SKILL.md d1adb839ab8048e8b024; references/checks.md 6c743f5e0cd9edd8ae38; verbs.md 283dfbd8afd020f26fc4; human-gates.md a545399e1f153c28f29e; schemas.json 0b7773acf785f97e3d7f; source-keys.md 4b04674843e53c997ef7 (sha256 prefixes, 20 hex)
C1 PASS skills/delivery-desk/references/verbs.md:24,49,109 and checks.md:4-5 resolve to current interface files; 60+ path:line cites resolve, none out of range; quoted text spot-checked
C2 PASS source-keys.md:4-40 and SKILL.md:214-221 external paths exist, each with a line range
C3 FAIL SKILL.md:87 and :134 hunks (r3 record "bytes" trims) carry no finding id; r2b "size" edit (SKILL.md:83) is not in the preround-r3 table; R3-M1, R3-M2, verify-r2b L1 hunks map to checks.md:76-85,102-108,141-155 and verbs.md:75-79,124-126
C4 KNOWN tasks/26-delivery-desk.md:5,125 INTERFACES 1.1.0 header (not a new failure); no other sha pins in the set
C5 FAIL SKILL.md:94 and :110 new r3 layout rules (desk-inbox/<id>.attach/, desk-inbox/<id>.derived) carry no DEFAULT/question tag; checks.md:81 new rule "lanes/ never read again" carries no tag
C6 PASS line counts: SKILL 223, checks 212, verbs 237, human-gates 77, source-keys 42, schemas.json 816 (all under 1000)
C7 FAIL record and brief pin f68f6f2; worktree HEAD is 5fee2b3 (f68f6f2 is an ancestor; no committed desk change between them)
preround: 3 fails
