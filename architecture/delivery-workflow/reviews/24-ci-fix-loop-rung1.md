# Rung 1 loop record: item 24 `ci-fix-loop`

- Date: 2026-10-26. Orchestrator: one loop orchestrator for this artifact (D35). Item: `skills/ci-fix-loop/` (pilot draft, `Provenance: pending pilot`, D14). Spec: `tasks/24-ci-fix-loop.md`.
- INTERFACES checked: 1.3.0 (AM-3 landed during the loop; the brief named 1.2.0).
- Roles, one agent each, none reused: G48 pre-round (Haiku) x2, reviewer (Sonnet, installed `doc-reviewer`), fixer (Opus, not the author), fix-verifier (Sonnet, installed `fix-verifier`, also the non-author §9 dry run).
- Rounds: 1 (D7 cap 3 not reached). Final: Blocking 0, Medium 0, Low 4.

## Round 1 findings (pre-round check + review, merged)

| Id | Sev | Finding | Status |
|---|---|---|---|
| B1 | Blocking | `classes.md` gave `timeout` a `ci-rerun`; B4 `ci-rerun` is flakes only and the desk refuses a non-flake class with `policy` (part-b-desk.md:64, :93); card 11 grants reruns to flakes only | Fixed: `timeout` -> human |
| B2 | Blocking | `timeout` had a fix path ("code-level hang") that card 11 does not grant | Fixed: a code-level hang is diagnosed `code-defect` |
| B3 | Blocking | Step 7 had the fixer record `GATE-PASS`; A.7 says the writer is the gate runner, never the author; steps were out of spec §8 order | Fixed: separate GATE-PASS step after review, gate runner writes it, A.7 linked not restated |
| M1 | Medium | `commit-message-format` was a fix class; card 11 fixes only code-caused failures, and a fix would need amend/force | Fixed: human |
| M2 | Medium | `static-analysis-gate` had a fix path and the Sonar one-retry was unreachable (step 5 rerouted only `flake`) | Fixed: the three Sonar sub-cases are diagnosed `flake` (card 11: "one-retry flake class"); a real finding in PR lines is `code-defect`; anything else is human; scan configuration added to the D23 refusal |
| M3 | Medium | D23 fallback "CI config paths the profile names" is an undefined key; `sensitive_paths[]` is a defined required A.2.2 key (AM-2 row 5), "(proposed key)" was stale | Fixed: Step 0 validates `sensitive_paths[]`; empty list -> `CI: HUMAN policy`. OWNER-Q 1 |
| M4 | Medium | The token for D23-adjacent classes (`artifact-path`, `workspace-mismatch`) was unclear against RESOLVED Q3 | Fixed: only a D23 check that fires writes `policy`; otherwise the class token is kept |
| M5 | Medium | Port-collision outcome restated and stale after AM-3 (+10 retry) | Fixed: links A.5.2 only |
| M6 | Medium | B4 `push` requires `PREPR: PASS` for `expect_head`; fix-round heads never pass `pre-pr-gate` | Fixed in item: step defers to B4 preconditions. OWNER-Q 2 (INTERFACES) |
| M7 | Medium | D7 round-3 stop, second flake failure and failed capacity retry had no D1.1 terminal token | Fixed: `CI: HUMAN <class>` / `flake` / `infra-runner`; lead sets `d7-round3` where applicable; invented "profile tolerance" removed |
| M8 | Medium | No `## Provenance` heading (skill-authoring.md:87-88) | Fixed |
| L1 | Low | provenance.md cited INTERFACES 1.1.0; angle-bracket placeholders in the description | Fixed |

Fix-verify (round 1): CLEAN, every id CLOSED; every `classes.md` action is granted by card 11 or B4; no route edits a pipeline definition, shared pipeline repo, trigger, required-check or scan configuration.

Post-fix G48 pre-round check: no Blocking. Open Lows (no action, recorded):
- L2: Step 9 says "after round 3 stop" without the D7 words "with open B/M findings" (the stop is only reached on `ISSUES_FOUND`, so the meaning holds).
- L3: card 11 says "one re-run then a quarantine proposal" and does not name a terminal; the item ends the loop `CI: HUMAN flake` after the proposal (a proposal needs a human to act on it).
- L4: Step 7 no longer names the port-collision outcome; A.5.2 holds it (by design, link not restate).
- L5: Provenance links the design card but no friction entry (skill-authoring §5); acceptable for a D14 pilot draft.

## classes.md vs design card 11 and D23 (orchestrator check)
After the fix the table has three actions only: fix (`code-defect`, `deterministic-test`), one rerun then human (`flake`, which includes the three Sonar sub-cases), and human (the other 11 classes). Each one is granted by card 11 (part-02-skill-inventory.md:70) and B4. D23 appears in Step 6, as the first Red flag, in the classes.md D23 check and in the Exit criteria. The item never edits pipeline definitions, shared pipeline repos, triggers, required-check or scan configuration, and that rule is stricter than D23 because it adds scan configuration.

## Owner questions
1. RESOLVED Q4 vs A.2.2: Q4's fallback (no `sensitive_paths[]` -> use the CI config paths the profile names) conflicts with A.2.2, where `sensitive_paths[]` is a required key and no CI-config-paths key exists. Recommended: follow A.2.2 (AM-2 row 5 is newer), retire Q4's fallback, and keep an empty list as `CI: HUMAN policy`. The item currently does this.
2. B4 `push` row (part-b-desk.md:83) requires `PREPR: PASS` for every `expect_head`, but `ci-fix-loop` fix-round heads never pass `pre-pr-gate`. Recommended: amend B4 so `PREPR: PASS` applies to the first stage-5 push only, and later fix-loop pushes need only `gate-runs/<expect_head>.md` (GATE-PASS). This needs an INTERFACES amendment (Rung 1, M21). Until then, desk pushes in a fix round would be refused.

## §9 done condition (non-author dry run by the fix-verifier; block identical to spec §9)
```
SKILL-24-OK
```
The script exited 0; the orchestrator re-ran it after the record and got the same result.
