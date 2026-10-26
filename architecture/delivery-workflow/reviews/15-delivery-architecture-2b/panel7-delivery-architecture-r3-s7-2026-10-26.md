# Panel7 r3 seat s7 (cold implementer dry run), arch15-r3-s7

Spec section 9 mechanical greps (tokens, forbidden words, word count 2906, symlinks, doc length) pass; fixture profile blob id matches; facts count 6 matches.

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s7-1 | L | references/fixtures/README.md:20 ; references/review-handoff.md:12 | STAKES/CONTENTION/NOVELTY have no fixture value; one-way would give floor 4 > stub rung 2b and stop at step 10 | references/fixtures/expected.md (silent) | add the three values to expected.md |
| s7-2 | L | references/fixtures/expected.md:9 | expects item 3 to name 127.0.0.1; skill puts bind only in the owning file | references/tree-rules.md K15 | say item 3 cites apps/admin/dev-server.json for the bind |
| s7-3 | L | references/fixtures/README.md:20 | no path for the round-1 stub record; the review record needs every round record path | references/review-handoff.md:19 | name RUN_HOME/review/run-doc-1/ for the stub copy |
| s7-4 | L | SKILL.md:20 | step 0 omits DELIVERY_ROOT and says all durations.* while step0-inputs checks only unit_median_min | references/step0-inputs.md rows 1, 6 | name them in step 0 |
| s7-5 | L | references/tree-rules.md K7 ; SKILL.md Exit criteria | observability scenario required by step 3 and expected.md but not gated | SKILL.md step 3 | add to K7 |

totals B/M/L 0/0/5
