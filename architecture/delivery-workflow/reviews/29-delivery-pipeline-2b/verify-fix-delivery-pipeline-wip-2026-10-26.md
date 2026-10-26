ISSUES_FOUND 0/1/0

WIP-coherence check of commit 103cb53 vs fix r1 and fix r1b (change set `git diff 2c10079 103cb53 -- skills/delivery-pipeline`). `git diff --stat 103cb53 -- skills/delivery-pipeline` is empty, so the tree equals 103cb53. `s9-29.sh` ends PIPELINE-29-OK with no failure words.

Checks:
- Every row marked FIXED in r1 and r1b was found at the cited place (the key tokens, steps and `29-n` markers).
- Section ids 29-1..29-24 all resolve to provenance rows. SKILL steps 0-14, resume steps 1-11, tick steps 0-10/4b-4d and stages 5b/6-7/8 resolve.
- No truncated sentence: sentence-end scan found only front matter and the launcher command block.
- SKILL.md rules (R1-R4, 9f, 9h, 9i, step 12) match their reference texts. Cross-references to `delivery-cleanup`, `post-merge-verify` and `delivery-dispatch-plan` carry path:line or a "question" marker.
- Scope: seven skill files only.

| id | sev | file:line | issue | source | fix |
|---|---|---|---|---|---|
| r1b-01 | M | references/tick-relay.md:9 (step 0); SKILL.md:22 (R4); references/provenance.md:51 (29-16) | Known and already carried. The send gate blocks every `REGISTER-SENDER`, including the `run` claim (stage 1, resume step 7) that is the only way to obtain `REGISTERED run ok`, and its 5 + 5 re-send, so the gate is self-blocking. Not fixed in 103cb53. | verify-fix r1b | Exempt the `run` `REGISTER-SENDER` and its no-reply re-send in step 0, R4 and 29-16. |
