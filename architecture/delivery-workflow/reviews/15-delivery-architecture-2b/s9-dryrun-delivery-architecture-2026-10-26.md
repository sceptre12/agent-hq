# Spec 15 section 9 dry run: delivery-architecture (non-author reader)
Date: 2026-10-26. Reader: xProfWorker1 subagent a57499e51e255509e; did not author or fix the skill. Output dir: FIXTURE_DIR=/private/tmp/claude-501/-Users-xavier-claude-profiles-xProfWorker1-workspace/c17bda54-44e6-46c6-925f-f84b0491142e/scratchpad/arch15/dry (nothing written under W except this file).

## Result
- Section 9 block (copied unchanged to `/private/tmp/claude-501/-Users-xavier-claude-profiles-xProfWorker1-workspace/c17bda54-44e6-46c6-925f-f84b0491142e/scratchpad/arch15/dry/s9.sh`, run as `FIXTURE_DIR=/private/tmp/claude-501/-Users-xavier-claude-profiles-xProfWorker1-workspace/c17bda54-44e6-46c6-925f-f84b0491142e/scratchpad/arch15/dry bash s9.sh`): exit code 0.
- Last stdout line: `SKILL-15-OK`.
- unset.txt: one line, `INPUT-ERROR RUN_HOME missing`.
- release-plan.md step ids (checked by hand against the Steps table): deploy-staging, poll-staging, hand-test-staging, deploy-prod; 4 ids, unique, all match `^[a-z0-9-]+$`, owners agent|agent|human|human.
- My K1-K15 script: all pass on the final artifacts (`/private/tmp/claude-501/-Users-xavier-claude-profiles-xProfWorker1-workspace/c17bda54-44e6-46c6-925f-f84b0491142e/scratchpad/arch15/dry/kcheck-final.txt`). The stubbed round 1 is 0/0/1, no fix, no verifier. No gate file, security-audit directory, Jira call or port claim was made.

## Guess-points (8)
1. STAKES/CONTENTION/NOVELTY: neither the fixture README nor expected.md gives values. I chose reversible / contested (spike: library or native streaming) / known (orders doc exists, though the export has no precedent); NOVELTY is a coin flip. Reasons are in the record.
2. FIXTURE_DIR layout: the README sets FIXTURE_DIR=$X/repo/plans/DEMO-1; the job set it to the top and asked for copies. I ran in work/{repo,delivery} and copied outputs plus contracts/ up; no script reads contracts/ there.
3. Port 4300: contracts.md says an existing owner stays the owner, so the item 3 sub-table cites apps/admin/dev-server.json:1-6 and no contracts/ port file exists; expected.md wants the bind (127.0.0.1) named in item 3, but contracts.md and K15 keep bind in the owner only. I left the bind out.
4. The fixture gives no team or priority (written FILL_IN_BEFORE_DISPATCH), and the brief is silent on who may call the endpoint. I raised that as an open question and the single H1 decision (recommended default: existing admin auth); expected.md lists no decision, so this is my addition.
5. Item 12 was written with the architecture in step 5, not at step 10 (the stub rung was known); "item 13 blank" was read as empty Verdict/Name/Date lines without the template's explanatory sentence.
6. K1-K15 and C1-C7 have no runnable form; I wrote my own K script (a K12 first run failed on the header cell "(agent|human)", my parsing, not the doc). C5 was judged by eye; C7 is n/a (fixture is not a git repo).
7. One person played architect, decomposer, pre-round checker and ledger writer; the atomic-write rule was followed except the first move of docs/architecture/orders.md (temp file in another directory). The Spike has no Gherkin and no st row (exit = decision note); test-plan A3 omitted (all e2e none).
8. Dates: record dates use 2026-10-26 (today) while the run id says 20261102; the skill does not say which.

## Did the two known open items bite?
- (a) R3-1, review-architecture.md never states STAKES/CONTENTION/NOVELTY: partly. SKILL.md step 13's body list omits them; only references/review-handoff.md section 1 (last line) says to write each reason into the record, so a reader who follows step 13 alone leaves them out. I read section 1 at step 10 and wrote them; the cost is guess-point 1, since no source gives the values.
- (b) Others: expected.md vs contracts.md on the port bind (guess-point 3); no step says where the Low-pass skip (L1, "fixture") is recorded: I put it in the review record and ledger; the step 12 K-check has no script, so every reader re-derives it (guess-point 6); step 14 hashes the temp review record before the mv, which worked but needs the record to be final first.
