# Rung 1 loop record: item 18 `resource-catalog` (with the `port-claim` amendment)

- Date: 2026-10-26. INTERFACES 1.3.0. Spec: `tasks/18-resource-catalog.md`.
- Artifact: `skills/resource-catalog/SKILL.md`, `references/ports.md`, `references/kinds-and-handles.md`, `skills/port-claim/SKILL.md`. Not in scope: `references/templates/` (item 27).
- Script truth: `tools/delivery/catalog.sh` and `catalog-audit.sh` (a0122a3), and agent-hq main `tools/port-check.sh` and `tools/hooks/port-precheck.sh` (42a5198).
- Roles (D35): one agent per role, never reused.
  - Pre-round checker (Haiku, G48): one fresh agent per screen.
  - Reviewer (Sonnet): the installed `doc-reviewer`.
  - Fixer (Opus): a fresh agent each round.
  - Fix-verifier (Sonnet): the installed `fix-verifier`.
- Note: the round 1 pre-round screen ran in parallel with the round 1 review instead of before it. Both sets of findings went to the round 1 fixer together.

## Round 1
- Pre-round screen, 6 findings:
  - PR-1: the `port-claim` exit-2 retry was missing.
  - PR-2: run-ids were uppercase.
  - PR-3: C1, C6 and C7 had no stated source.
  - PR-4: a placeholder in the Provenance section.
  - PR-5: the SQUATTER scope was wrong.
  - PR-6: Steps 0 and 9 were not written as imperatives.
- Review: B=0, M=4 (the reviewer's total line said M=3; four findings carry M), L=7.
  - R1-1 (M): SQUATTER is reported for worktrees only (`catalog-audit.sh`).
  - R1-2 (M): `audit` needs `WORKTREE_BASE`.
  - R1-4 (M): the one +10 retry applies to exit 1 and exit 2 alike (A.5.2).
  - R1-5 (M): the skill gave no rule on `--force`. Ruling: never in a run.
  - R1-3, R1-6 to R1-11 (L): the audit line format, the status-field wording, lowercase run-ids, handle roots, `pm2-app` naming as a convention, and the bus port pin.
  - R1-7 (L): the `port-claim` additions to version, description and Trigger. Left for the integrator.
- Fix: everything except R1-7 was fixed. §9 printed SKILL-18-OK.
- Fix-verify: ISSUES_FOUND.
  - FV-1 (M, scope): the `port-claim` edits went beyond spec §3.
  - FV-2 (L): the Provenance section credited rules to C1, C6 and C7 that come from the design instead.
- Pre-round re-check found PR2-1 to PR2-5:
  - Releasing a `port` follows the Release order in `ports.md`.
  - `PORT_RANGE_START=PORT_RANGE_END=<port>` is not valid shell.
  - M26, C1, C6 and C7 were not glossed.
  - The friction link was missing.
  - Steps 6 and 8 were not written as imperatives.

## Round 2
- Orchestrator ruling on FV-1:
  - Kept: the Step 1 exit-1/exit-2 retry, "the status field (here `claimed`)" (a result of the reorder), and "In a delivery run never pass `--force`" (text about the retry rule).
  - Reverted to the committed wording: `note=forced`, and the sentence that `--force` overrides exit 1 and exit 2 only. That fact stays in `resource-catalog/references/ports.md`.
- Fix: FV-1, FV-2 and PR2-1 to PR2-5 were all fixed. §9 printed SKILL-18-OK.
- Fix-verify: CLEAN.
- Fresh review: **B=0, M=0, L=8** (R2-1 to R2-8). The mandatory checks passed:
  - every `catalog.sh` example was run against a scratch RUN_HOME and behaved as the skill says;
  - the port rules match A.5.2, `port-check.sh` and the hook.
- Pre-round re-check:
  - PR3-1 is another item's uncommitted edit to `references/templates/catalog.tsv.md`. It is not this loop's. Left for the integrator and item 27.
  - PR3-2 says `note=forced` is not the literal output: the script writes `forced` or `forced: <note>`. This is committed text that §3 scope keeps unchanged. It is listed below.

## Round 3 (Lows)
- Fix of R2-1 to R2-6 and R2-8:
  - A failed launch releases the claim at once, then runs `catalog.sh fail port`.
  - A held lease is reported to the lead, with no C2 mapping.
  - An unregistered live resource is registered, then `start`ed.
  - Rows are at most 400 bytes including the newline.
  - The bus handle is `$RUN_HOME/st1/bus`.
  - Exit 3 is split into a usage error and an unusable registry.
  - The field grammars are stated.
- R2-7 was left for the integrator. Fix-verify: CLEAN.

## Final
- **B=0 M=0.** Open Lows: R1-7 and R2-7 (the scope of the `port-claim` amendment), and PR3-2. All go to the integrator or the owner below.
- §9 done-condition, re-run by the round 3 fix-verifier and by the orchestrator:
```
SKILL-18-OK
exit=0
```

## Owner / integrator questions
1. Scope of the `port-claim` amendment (R1-7, R2-7, PR3-2). Spec §3 allows only claim-before-bind and the +10 retry text. Three changes go further:
   - the `version: 1.1.0`, description and Trigger additions;
   - "status field (here `claimed`)";
   - the committed "recorded as `note=forced`", which is inaccurate: `port-check.sh` writes the note `forced` or `forced: <note>`.
   **Recommended:** accept the additions, and allow a one-line correction of `note=forced` to "a `forced` note prefix" as an erratum.
2. INTERFACES A.5.2 has the same `PORT_RANGE_START=PORT_RANGE_END=<port>` notation that was fixed in `ports.md`. It reads as invalid shell. **Recommended:** add an erratum to a later amendment that writes `PORT_RANGE_START=<port> PORT_RANGE_END=<port>`.
