# Rung 1 loop record: item 27 template pack (12 templates, one artifact)

- Date: 2026-10-26. Orchestrator: one loop orchestrator for this artifact (D35). Item: the 12 files under `skills/*/references/templates/` listed in `tasks/27-template-pack.md` §3 (committed 569139c, AM-3 reconciled 8cba98e). Spec: `tasks/27-template-pack.md`.
- Sources: design `part-04-templates.md` §5.0-§5.11; INTERFACES 1.3.0 (`INTERFACES.md`, `interfaces/part-a..d`); owner rulings `architecture/delivery-workflow-sources/owner-decisions.md`.
- Roles, one agent each, none reused: G48 pre-round (Haiku) x2 (before round 1 and post-fix), reviewer (Sonnet, installed `doc-reviewer`), fixer (Opus, not the author), fix-verifier (Sonnet, installed `fix-verifier`, also the non-author §9 dry run).
- Fixer scope: only the 12 template files. Diff after the fix: 12 files, 83 insertions, 60 deletions.
- Rounds: 1 (D7 cap 3 not reached). Final: Blocking 0, Medium 0, Low 4 (open, recorded below).

## Round 1 findings (pre-round screen + review, merged)

| Id | Sev | File | Finding | Status |
|---|---|---|---|---|
| F1 | Blocking | `catalog.tsv.md` | Port collision text was the old PC-4 rule ("never add 10"). It contradicted AM-3 OQ-2 (A.5.2) and `dispatch-plan.md`. | Fixed: A.5.2 wording (one claimed retry at candidate+10, then stop), with a link to A.5.2 |
| F2 | Blocking | `repo-profile.md` | Ports were nested under `lane_profile.ports.*`; A.2.2 has them at top level as `ports.bus_base` / `ports.lane_base` | Fixed: top-level `ports:` |
| F3 | Blocking | `repo-profile.md` | Key was `sensitive_path_deny_list` of globs; A.2.2 has `sensitive_paths[]` as an ERE list | Fixed |
| F4 | Blocking | `repo-profile.md` | Key was `zephyr.execute_tool_name`; A.2.2 has `zephyr.execute_tool` | Fixed; every key checked against the A.2.2 list |
| F5 | Blocking | `state-and-substate.md` | `orchestrator_tier` (AM-3, A.2 / D2.2 row 4) was missing | Fixed: skeleton, rule row, example |
| F6 | Blocking | `step-completeness-checklist.md` | C21 required lease, port and bus rows to be released, but cleanup is the only thing that releases them (A.5.1/A.5.2), so every PR would get `STOP C21`. §5.7 asks only for "no `planned` rows". | Fixed |
| F7 | Medium | `architecture.md` | §3 had no slot for the primary and other repos (A.1) | Fixed |
| F8 | Medium | `test-plan.md` | No sub-task column and no batched `.feature` list per sub-task, which the H-e2e `ref=` hashes (A.2.1) | Fixed |
| F9 | Medium | `artifact-to-plane.md` | Retro was on the repo plane; A.6/D6 put it on RUN | Fixed: RUN row for `retro.md`, `execution-log.md` and `release-plan.md` v1; the departure from the design table is noted |
| F10 | Medium | `dispatch-plan.md` | Out-of-scope and Do-NOT-create `- ` bullets under `## 3` would be read as allowed globs by scope-check (C1.2) | Fixed: numbered lines plus a warning; 11 sections kept |
| F11 | Medium | `step-completeness-checklist.md` | "Third round is `ESCALATE`" had no source; `PREPR:` is PASS or STOP only | Fixed: `stop_reason: d7-round3`, the owner decides (D7) |
| F12 | Medium | `repo-profile.md` | `blocking_rules` was a scalar sentinel; A.2.2 makes it a list and treats an absent key as none | Fixed |
| F13 | Medium | `state-and-substate.md`, `artifact-to-plane.md` | Cited INTERFACES 1.1.0 | Fixed: 1.3.0; no stale version is left in any of the 12 files |
| P1 | Medium | `dispatch-plan.md` | Local headings A.0-A.11 collided with the INTERFACES A.x anchors | Fixed: P0-P11; citations now read "INTERFACES A.x" |
| F14-F23, P2 | Low | several | correlation_id shape, sentinel used as a port handle, `lane-unavailable` scope, D4 anchor that should be A.4, unsourced keys not marked template-local, `decision-gate` reason, `UNMEASURED` source, duplicate Brief line, `interfaces_version` in substate, D63 location | Fixed (all closed by the verifier; F21 partly, see L1) |

Not a finding: the §5.8b seed in `repo-profile.md` names a work repo and org. Design §5.8b (`part-04-templates.md:35`) and INTERFACES part A carry the same names, and the design is authoritative.

Fix-verify (round 1): every Blocking and Medium id is CLOSED, with no regressions. Remaining items are Low only.

Post-fix G48 screen: every cited anchor resolves, including the P0-P11 headings; there are no undefined tokens, stale versions, cost wording, personal-project or Notion text. The screen flagged two items as "Medium, unverified". The orchestrator checked both against the sources and downgraded or dismissed them:
- "AM-3 errata (g)" is not missing. The INTERFACES.md:25 AM-3 row lists W1 errata (a)-(g), and the new `orchestrator_tier` row is among them. The template's single letter cannot be traced to one row, so it is recorded as L3.
- The `FILL_IN_BEFORE_DISPATCH` sentinels on unmeasured profile keys are within design. §5.8 (`part-04-templates.md:33`) gives the profile a "pre-dispatch checklist with `FILL_IN_BEFORE_DISPATCH` sentinels" and no closed field list. Not a finding.

## Open Lows (no action, recorded)
- L1 (N1): `retro-and-execution-log.md:8` cites `XC/_templates/retrospective.md` without saying what "XC" is. Spec §5 gives the source as `~/projects/x-context-docs/_templates/`.
- L2 (N3): `dispatch-plan.md:68,79` repeat the A.5.2 retry rule rather than only linking it. The wording matches A.5.2 and `catalog.tsv.md:58`, so this is a drift risk, not a contradiction.
- L3: `state-and-substate.md:29,64` cite "AM-3 errata (g)" for `orchestrator_tier`. INTERFACES lists the errata (a)-(g) as one set, so a plain "AM-3 errata" citation would be safer.
- L4: `repo-profile.md:83` `lane_profile:` is the design's "lane resource profile" (A5, §5.8). Its keys are marked template-local; the container key is not.

## Out of scope, for the INTERFACES owner
- The example in `interfaces/part-a-state.md` A.2 (about line 145) still shows `interfaces_version: 1.1.0@...`. The fixer reported this and did not edit it; its write scope was the 12 templates.

## Owner questions
None. No finding needed an owner decision.

## §9 done condition (non-author dry run by the fix-verifier; block identical to spec §9)
```
files=12
check-doc-length.sh: 0 blocking file(s) over 500 lines; 0 allowlisted file(s) over 500 lines; 3 file(s) over 40000 bytes (informational only, not blocking)
67
EXEC-COLUMN
exit=0
```
- No `MISSING`, `EXTRA-FILE`, `RECORD-MISSING`, `AM1-*`, `AM3-*`, `PC-*` or `KIND-MISSING` line, and no output from the `grep -L` / `grep -l` lines. `67` is the `FILL_IN_BEFORE_DISPATCH` count in `repo-profile.md` (the check needs at least 1).
- `EXEC-COLUMN` is acceptable: `verify_cmd` appears only in the dropped-column note at `catalog.tsv.md:23`.
- Extra checks: `00-constitution` has no match in the 12 files. `grep -cxF 'security_sensitive: yes|no' architecture.md` = 1. `catalog.tsv.md` has 17 kinds, 12 columns and no executable column.
- Integration sub-check: `grep -rho 'references/templates/[A-Za-z0-9._-]*' skills | sort -u` names `decisions-fork.md`, `dispatch-plan.md`, `repo-profile.md`, `step-completeness-checklist.md` and `ticket.md`, all among the 12.

Result: done condition met (0 Blocking / 0 Medium after round 1).
