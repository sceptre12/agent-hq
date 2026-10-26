# Fix r1b: delivery-architecture pre-round r2 FAILs (2026-10-26)

Source: `preround-delivery-architecture-r2-2026-10-26.md` (8 FAIL lines). Fixer: Opus, not the author. Text-only; no behaviour change.

| finding id | file:line changed | change (one clause) | status |
|---|---|---|---|
| PR3-C2a | SKILL.md:16, SKILL.md:46, references/fixtures/expected.md:10 | added pointer `config/CLAUDE.md:32` (global Rule 5 heading) after "Rule 5" | fixed |
| PR3-C2b | references/review-handoff.md:55 | added pointer `decisions/0014-model-tier-operating-policy.md:55` (T1 row) | fixed |
| PR3-C5a | references/decomposer-brief.md:8 | tagged the 5-line reply cap "a default of this skill" | fixed |
| PR3-C5b | SKILL.md:24 | anchored "always on the first pass" to K14 (`references/tree-rules.md` K14: no `PIN-TBD:` may remain) | fixed |
| PR3-C5c | references/step0-inputs.md:46 | tagged the draft deletion "a default of this skill", citing the binding notes (step 2) | fixed |
| PR3-C5d | references/review-handoff.md:13 | tagged the one-way example list "a default of this skill"; axis values anchored to `interfaces/part-d-enums-topics.md:46` | fixed |
| PR3-C5e | references/security-sensitive.md:32 | anchored "never removes a control" to spec 15 RESOLVED Q2 (`tasks/15-delivery-architecture.md:96`) | fixed |
| PR3-C5f | references/contracts.md:11 | tagged "never secret values" "a default of this skill" | fixed |

## Checks
- `wc -w SKILL.md` 2731 (<=3500); `wc -l SKILL.md` 68 (<=500); largest reference file 85 lines.
- `bash tools/check-doc-length.sh .`: 0 blocking files over 500 lines.
- Forbidden grep (`$HOME|touri|ofw|runfrist|jetblue|notion|\$[0-9]+|cost`, -i, excluding templates/): no hits.
- Spec §9 tokens: all present; `plan-check default` present in references/security-sensitive.md.
- templates/ untouched.
