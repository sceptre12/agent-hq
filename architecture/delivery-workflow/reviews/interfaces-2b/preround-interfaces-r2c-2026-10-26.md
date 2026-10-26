# Pre-round check r2c (review-7-panel preround-check.md C1-C7), fix r1e only

Scope: fix r1e (diff-r1e.patch, 159 lines; record reviews/interfaces-2b/fix-interfaces-r1e-2026-10-26.md, ids V1-V8). Read-only except this record. Checker: fresh read-only Haiku run, not the fixer or author (Rule 4).

Pins (C7, shasum -a 256, first 12 hex): INTERFACES.md caa8944e1537 (match); interfaces/part-a-state.md a4bb78f3f5c1 (match); part-b-desk.md ffab25849d9d (match); part-c-waves-control.md 69327ba92a2d (match); part-d-enums-topics.md feb05230d374 (match).

C1 PASS INTERFACES.md:33,57,83,111-114; part-a-state.md:208; part-b-desk.md:18,36,47,62,105; part-c-waves-control.md:68,110,118; part-d-enums-topics.md:54,69 open and quoted text matches the diff. Cites to architecture/delivery-workflow-sources/owner-decisions.md (:58,:63-:72) and decisions/0055-desk-verb-permission-tiers-02.md resolve as files; their line-level text was not string-matched in this run.

C2 PASS no new sentence in the r1e hunks names an external source (ADR, owner message) without a pointer; "(r1e V3)" style tags are finding ids, not sources.

C3 PASS 16 hunks, each mapped: INTERFACES @-30 V6; @-54 V2; @-80 V1; @-108 V3 (B2,B6 row), V4 (B1,B2.1,B3 row), V5 (C5.1,B4,D2.2 row), V6 (I row). part-a @-205 V7. part-b @-15 V4; @-33 V3; @-44 V4; @-59 V4; @-82 V5; @-102 V3. part-c @-65 V8; @-107 V5; @-114 V5. part-d @-51 V5; @-66 V5. Ids V1-V8 exist in reviews/interfaces-2b/verify-fix-interfaces-r1-2026-10-26.md.

C4 FAIL part-a-state.md:210 uses `catalog.sh register lane-lease <handle>` (2 args); INTERFACES.md:33 and :114 now require `register <kind> <handle> <unit|-> <correlation_id> <source> <subtask|run> <owner_agent>`. Same command is stated two ways across the five files. Fixer: align the example to the INTERFACES.md:33 signature or mark it as a partial form.
C4 PASS (other items) CONDUCTOR-REQUEST: same form and regex in INTERFACES.md:113, part-b-desk.md:59/85-87/97-99, part-c-waves-control.md:127/136, part-d-enums-topics.md:54,147/156; path pm/outbox/<seq>.conductor-request with .sent-<id> suffix consistent. Machine row: `session= pid= live_count= build= utc=` in INTERFACES.md:57 and part-a-state.md:183 (the INTERFACES.md:95 row lists pid/build/reaper only, no string conflict). .inflight `<verb> <target>` consistent in INTERFACES.md:111, part-b-desk.md:36,62,105. Step order and sha pins unchanged by r1e.

C5 PASS new rule sentences carry DEFAULT (integrator) or FROZEN/DEF labels (part-b-desk.md:36,59,62,68,78,105,107; part-c-waves-control.md:136; part-d-enums-topics.md:147). Note only: table cells part-b-desk.md:96-99 and part-d-enums-topics.md:156 restate conductor-only rules without the word in the cell; they cite B1/C5.1, which carry DEFAULT. Not counted as FAIL.

C6 PASS line counts INTERFACES.md 182, part-a-state.md 278, part-b-desk.md 158, part-c-waves-control.md 174, part-d-enums-topics.md 155; all under 1000. The brief sets no loop line cap.

C7 PASS pins above match the record and the brief.

Observation, not a checklist item: part-d-enums-topics.md:100 says "these seven events" and then maps archive as an eighth arrow. INTERFACES.md:83 says "seven events plus archive". Wording only; not a C1-C7 fail.

Output:
C1 PASS INTERFACES.md:33,57,83,111-114 and part files; owner-decisions/0055 line text not string-matched
C2 PASS no external-source sentence without pointer
C3 PASS 16 hunks mapped to V1-V8
C4 FAIL part-a-state.md:210 catalog.sh register example omits new args (INTERFACES.md:33)
C5 PASS DEFAULT/FROZEN labels present on new rules
C6 PASS max 278 lines
C7 PASS five pins match
preround: 1 fail
