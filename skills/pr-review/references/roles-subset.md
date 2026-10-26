# PR Review — Roles subset (D12): remap procedure and refusal

Status in this version: **refused**. Step 0 rejects any `ROLES` list of fewer than 7 seats with
`INPUT-ERROR ROLES enum`. Every `pr-review` runs the 7 seats of `agent-roles.md`. The refusal is
unconditional: there is no switch. Enabling a smaller roster is an INTERFACES amendment (the D2.3
`pr-review` row, "seat count 7 until the D12 remap and probe are recorded") plus a change to this
skill, never a variable set by a caller.

## Probe record (2026-10-26, measurements Item 4 (B), dry run)

All 35 subsets of three seats from `agent-roles.md` were scored against the 10 checks
(`pr-check-cold-read`, `pr-check-1` to `pr-check-9`). Result: no 3-seat subset keeps a Responsible seat
for all 10 checks. The fewest lost: 4 checks (5 subsets); every subset also loses at least 1 Accountable
closer. Best subset: `devops-engineer`, `integration-architect`, `platform-engineer`, which loses R for
checks 5, 7, 8, 9 and the closer for check 8. A real bus was not run (pm2 EPERM, no bus `node_modules`,
`/tmp` unwritable). So the 3-seat probe found lost checks, and the refusal stays. This file records the
procedure only; it contains no remap table for any subset.

## Remap procedure (for the future amendment; computed before dispatch)

For a proposed subset S of seats, before any bus starts:

1. For every omitted seat, name the kept seat that absorbs each of its Responsible checks, or mark the
   check N/A to the synthesizer (the synthesizer reports it as "not reviewed", never as PASS).
2. For every omitted seat, name the kept seat that absorbs each of its Accountable closers
   (`pr-check-N-closed`), or mark the closer N/A. A check with an R seat and no A seat is not allowed.
3. Rebuild each Consulted list from the kept seats only. The quorum rule (`bus-schema.md`) is computed
   from the rebuilt lists; an omitted seat is never waited for.
4. Rebuild the synthesizer expectations: the gate quorum is `|S|` distinct agent ids (not 7), the table
   marks N/A checks, and `timed_out_checks` only names seats in S.
5. Hard gate timeout: the Phase 1 gate (8 minutes) and Phase 2 gate (10 minutes) stay; a kept seat that
   does not signal is a timed-out seat, never silently dropped.
6. Probe: run a real bus on the subset and record that there are no lost checks (every check has an R
   seat and an A closer, or is explicitly N/A). A dry run of the roster alone is not enough.

Only when step 6 is recorded, in the INTERFACES amendment, may the skill accept that subset.

## Red flags

- "The diff only touches docs, drop four seats." Refused: `INPUT-ERROR ROLES enum`. Use Rung 1 instead.
- Hand-writing a remap table in a caller prompt. The remap is not enabled; the seat list stays 7.
