# Rung 1 loop record: item 27b `persona-briefs`

- Date: 2026-10-26. Orchestrator: one loop orchestrator for this artifact (D35). Item: the 32 briefs in `skills/delivery-run/references/briefs/`, reviewed as one artifact. Spec: `tasks/27b-persona-briefs.md`.
- INTERFACES checked: 1.3.0 (Amendments AM-1 to AM-3; there is no newer amendment at close). The rung1 brief named 1.2.0, and the dispatch named 1.3.0.
- Roles, one agent each, none reused:
  - G48 pre-round (mechanical tier) x2, before round 1 and after the fix.
  - Reviewer (verify tier), using the installed `doc-reviewer`.
  - Fixer (design tier, E25), not the author.
  - Fix-verifier (verify tier), using the installed `fix-verifier`; it also ran the non-author §9 dry run.
- Rounds: 1 (the D7 cap of 3 was not reached). Final: Blocking 0, Medium 0, Low 12 (recorded below). Owner questions: 3.
- COMMON block: the fixer never edited inside it. No diff hunk touches the COMMON line, and all 32 copies are byte-identical to design §3.0 (checked by §9 and by both screens).

## Round 1 findings (pre-round check G + review R, merged)

| Id | Sev | Finding | Status |
|---|---|---|---|
| R1/G1 | Blocking | `lead.md:19` said "never auto-pick another port: report to the lead": no AM-3 +10 retry, and the lead reported to itself | Fixed: candidate from C1.1, bus pinned with `PORT_RANGE_START=PORT_RANGE_END`, exactly one claimed retry at +10, second refusal stops the line (part-01 stop-the-line), exit 3 stop-the-line (A.5.2, AM-3, OQ-2) |
| R2/G2 | Blocking | `review-orchestrator.md:19`, same defect on the per-review bus | Fixed: `BUS_PORT`, pinned, exactly one claimed retry at `BUS_PORT + 10`, then stop the line (D2.3, C1.1, AM-3) |
| class | (R1) | `catalog-keeper.md:19` "never auto-pick" without the retry | Fixed: retry clause added. A grep finds no "auto-pick" without +10 in any brief |
| R3 | Medium | `review-seat.md:3` "do not read other seats' output" conflicts with `pr-review` Phase 2 deliberation | Fixed: the rule now applies to the independent phase only |
| R4 | Medium | `security-auditor.md`: stop rule said "none stated" although `security-audit` SKILL.md states a terminal-state rule; the starts-agents text contradicted itself | Fixed: the skill's terminal-state rule is the Stop line; the auditor starts no agent (A.4) |
| G8 | Medium | `security-auditor.md` cited A.5.3 for `agents/<own-id>/` and `scratch/` | Fixed: cites A.6 (own `agents/<agent-id>/`) and the skill's Write isolation section for `scratch/` |
| R5 | Medium | `lead.md` was missing three duties: the merged tick with the STALLED/PROMPT-OPEN actions, lane leases, and H-e2e batching | Fixed: three cited rules (C7, C1.1, §3.6 step 4, A.2.1) |
| R6/G3 | Medium | `lane-runner.md:20` had no C2 reason mapping; `e2e-writer.md` used `ESCALATE` + `env-bug`, a pair C2 does not allow | Fixed: `SOURCE_BUG` -> `ESCALATE source-bug`, `ENV_BUG` -> `ROLLED env-bug` (part-d :91, part-c :71) |
| G4 | Medium | `integrator.md:11` mixed `INTEGRATED:` with the C2 record | Fixed: the integrator posts one C2 record per merged unit (`i<N>`); the lead writes `INTEGRATED: u<N> <sha>` (A.3, D1.1) |
| G6 | Medium | `desk.md:10` used the short `DONE` form | Fixed: the long form, per B2 and owner OP2 A |
| G7 | Medium | `fixer.md:5` and `review-orchestrator.md:21`: the fixer is design tier, but the text says "escalate one tier" | Now restates E25 in substance. The target is undefined in the sources, so this is OWNER-Q 1 (not an item defect) |
| G5 | Low | `APPROVAL BAR MET/NOT MET` has no D1.1 row | Kept as §3.4 design prose, cited |
| R7-R10, G13-G15 | Low | gate-runner "wait"; migration-specialist status-file sentence; implementer/test-writer frozen-interface consistency; catalog-keeper tier wording; explorer tier; fix-verifier iteration wording; `AHQ/` path key | Fixed |
| G9-G11 | Low | `H0 recorded`, `CYCLE DONE` and `CLEAN`/`ISSUES_FOUND` have no D1.1 rows | No action: each brief is consistent and cites its design source |
| G12 | Low | the word "budget" in shepherd, gate-runner, review-tailor and security-auditor | No action: these are INTERFACES time and agent-count fields (`budget_min`, C2 `budget`, A.4), not cost metrics (B-4 bans cost) |

Fix-verify (round 1): CLEAN. Every Blocking and Medium is CLOSED. Each new rule traces to its cited row, including the C1.1 bus-port formulas `k = 2N` / `2N+1`.

Post-fix G48 screen: 0 Blocking. It raised two Mediums, which the orchestrator triaged as source gaps (the owner questions below) because the brief text matches its sources:
- P1: explorer tier narrowed to `mechanical`.
- P2: fixer escalation target.

Open Lows (no action, recorded):
- N1: the `desk.md:3` role statement abbreviates the reply as `DONE <id>`. The long form is in Persona facts on lines 9-10.
- P3: `implementer.md:21` lost the invented `contract-gap` action (R9: design §4 rule 4 gives the condition only).
- P4: `catalog-keeper.md:19` restates the launcher's +10 retry, although the keeper binds no port.
- P5: the catalog-keeper tier comes from its position in the §3.1 cell.
- P6: the `integrator.md` done token follows INTERFACES A.3/D1.1 rather than the literal §3.3 cell. INTERFACES ranks first, and the cell is not contradicted.
- P7: `security-auditor.md` hands the free-slot rule to the launching skill (A.4 :222) instead of restating spec §4b.
- P8: `tools/port-check.sh` is not yet in W. It is a planned artifact named by A.5.2, outside 27b.
- G9-G12: as listed in the table above.

## Owner questions (each with a recommended answer)
1. **E25 / ADR 0014 T1, fixer escalation.**
   - Problem: E25 makes the fixer `design`, the highest persona tier, and keeps "one tier up on the second Medium-adding round". ADR 0014 T1 is a model-ladder rule ("no third Opus attempt" -> next model), not a persona-tier rule.
   - Recommended: errata to E25 / D2.1 that reads "escalate one model step per `tools/model-routing.md` (ADR 0014 T1); never a third attempt at the top model". The briefs stay tier-name only (M19).
2. **Explorer tier.**
   - Problem: §3.2 gives `mechanical / execute` with no condition, and the fixer set `mechanical` from the §3.1 position.
   - Recommended: `mechanical` by default, and `execute` when a fact needs a multi-step derivation. Add this to the design §3.2 cell, and the brief then states it.
3. **Port refusal recipient for the lead.**
   - Problem: the part-01 stop-the-line row says the lead "reports" without naming a recipient, and A.3 has no `stop_reason` row id for a port refusal.
   - Recommended: the lead writes `stop_reason` in `substate.md`, and the conductor's status post reports it to the owner. Add a port row id to the A.3 stop-the-line table (INTERFACES amendment, Rung 1).

## §9 done condition (non-author dry run by the fix-verifier; block identical to spec §9)
```
BRIEFS-OK
(grep for personal-project / Notion / $HOME: no output)
check-doc-length.sh: 0 blocking file(s) over 500 lines; 0 allowlisted file(s) over 500 lines (visible debt, not blocking); 3 file(s) over 40000 bytes (second dimension, informational only, not blocking)
```
Exit 0. The orchestrator re-ran the block after the record and got the same result. Integration step (spec §9, serial, by the integrator): not part of this loop; it is left to Worker1.

Working files (scratchpad):
- Findings: `27b-r1-g48.md`, `27b-r1-review.md`.
- Fix: `27b-r1-fixlog.md`, `27b-r1.diff` (pre-fix snapshot `snap-27b-r0/`).
- Verification: `27b-r1-verify.md`, `27b-r1-g48post.md`.
