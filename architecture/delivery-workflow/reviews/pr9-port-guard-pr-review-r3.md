CODE-GATE-REVIEW: PASS head=600ba03 blocking=0 medium=0
Reviewed-By: xProfWorker1 PR9-port-guard-r3

# PR #9 port guard — code-gate review round 3 (final, D7)

- Date: 2026-10-26
- Head: 600ba03 (600ba033a2d1bf7501576b96c233a99a0b0cb4d4)   Base: c1ba30e   Round-2 head: 651e7ea
- Mode: local-diff (repo_dir `~/projects/agent-hq-worktrees/port-guard`, read-only)
- Bus session: swarm-pr-review-20261026-64a7b61b (all `pr-check-cold-read`, `pr-check-1`..`9`, all `-closed` topics, `rendezvous`, `phase2-rendezvous` read with peek)
- Gates: gate1 7/7, gate2 7/7; timed_out_checks = { gate1: [], gate2: [] }
- Panel: strategic-reviewer, integration-architect, platform-engineer, devops-engineer, security-engineer, fullstack-engineer, technical-writer, plus independent synthesizer

## 1. Severity summary

0 Blocking, 0 Medium, 5 Advisory (13 raw FINDING messages on the bus, of which 3 security FINDINGs in pr-check-5 only restate "M1/M2/M3 verified fixed"; remaining items merged to 5 Advisory rows). Severity is the bus consensus: no seat raised or escalated anything above Advisory and no CHALLENGE or ESCALATE was posted.

## 2. Round-2 M1-M4 verification

| r2 id | Status at 600ba03 | Evidence (seats) |
|---|---|---|
| M1 `--claim --force` bypasses fail-closed lsof (exit 3) | FIXED | strategic: `--force` with broken lsof gives exit 3, registry unchanged. platform: fake lsof exit 7 gives rc 3, registry unchanged. devops: fake lsof exit 2 plus `--force` gives exit 3, no append. fullstack: rc 3, no append (`port-check.sh:196-200`). security: fake lsof exit 2 with output and lsof killed by signal both give exit 3 with no row (`port-check.sh:195-200`, lib 79-91); only rc 1 with empty output maps to FREE. integration and technical-writer: header, doc SS4 and code agree. |
| M2 release path needs `--force` | FIXED | `held_only_by` in lib (41-49) and `port-check.sh:203`: self-release by the same project works without `--force` (rc 0, note kept; platform, devops, fullstack, security, strategic, integration reproduced); foreign release without `--force` is refused rc 1; forced takeover note is `forced: <note>`. Residual: ownership is the free-text project argument (accident guard, A4). |
| M3 non-canonical ports read FREE | FIXED for `--claim` and CLI input | `validate_port` requires `^[1-9][0-9]{0,4}$` plus range, and each container_port end is validated. Reproduced exit 3 for `045010`, `0`, `65536`, `+80`, `0x50`, `1e3`, 20 digits, trailing space/newline, `4501;id`, `$(id)`, empty, container_port `99999` (strategic, integration, devops, fullstack, security). Residual: the same rules are not applied to rows read from a hand-edited registry (`validate_rows`, A1). |
| M4 Hermes row citations unsupported | FIXED for 8642, MOSTLY FIXED for 11330 | 8642 now cites `architecture/hermes-agent.md:94` and `:208`, both contain it (platform, devops, fullstack, technical-writer, strategic). Row 11330 now says the README does not restate the port, so the cell is honest but still has no file:line basis (A3). Also verified: swarm-communication-layer.md:79-81 range 7777-7800 resolves (technical-writer). |

No regression was reported by any seat. Tests as reported by seats: `tools/test_port-check.sh` 57/57 pass and `tools/hooks/tests/port-precheck/test_port-precheck.sh` 43/43 pass (security, platform, fullstack, devops under `/bin/bash` 3.2.57, strategic, technical-writer, integration in a fresh archive); doc length check clean, line caps 290/105/288 (technical-writer, integration).

## 3. Findings table

R = Responsible (raiser), A = Accountable (closer of the topic). C markers: ✓ VALIDATE, ⬆ ESCALATE, ↩ CHALLENGE, + ADD. No ↩, ⬆ or + was posted on any finding. PASS-only topics: pr-check-cold-read, pr-check-1, pr-check-3.

| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| A1 | `validate_rows` (`port-check.sh:103-107`) and `validate_claim_fields` are weaker than the `--claim` host-port rule. (a) A hand-edited row with a reversed range (`9999-9000`) never matches and reads `RESULT: FREE` for 9500; (b) a non-canonical or overflowing row port (`045010`, `9000-99999999999999999999`) reads FREE; (c) an empty middle field passes `NF==9` but the `IFS=tab read` readers collapse it and shift columns (status read as source; verdict stays TAKEN, never FREE); (d) `--claim` container_port `9000-8000` or `80-70` is stored (informational, never feeds a verdict). All need a hand edit of the registry or an informational field; `--claim` cannot write (a)-(c). | Advisory | pr-check-2, 4, 5, 6, 7 | integration (reversed range), devops (container_port), security (container_port lo>hi), platform (non-canonical, empty field), fullstack (empty field) | platform (2, 4, 5), devops (6), integration (7) | pr-check-2: platform ✓, devops ✓, fullstack ✓, security ✓. pr-check-4: platform ✓, fullstack ✓, integration ✓, security ✓. pr-check-5: platform ✓, devops ✓, integration ✓. pr-check-6: devops ✓, integration ✓, security ✓. pr-check-7: platform ✓, integration ✓, security ✓, technical-writer ✓ (also asks the doc to say fields must be non-empty and tab-separated). pr-check-8: fullstack, strategic confirm Advisory. | One combined hardening: canonical ends `^[1-9][0-9]{0,4}$`, `lo <= hi`, non-empty fields, in `validate_rows` and `validate_claim_fields` (exit 3); one doc sentence on field rules |
| A2 | Exit-code label drift: `port-check.sh` header lines 29-30 (the seat also cites 33-34) and `architecture/port-registry.md` line 230 (SS5.3) say exit 1 means registry-vs-live disagreement; code and the EXIT CODES block use exit 1 = taken, exit 2 = disagreement (`EXIT_DISAGREE=2`, `port-check.sh:67,163`). Label only; the conclusion (malformed row is exit 3) is right. | Advisory | pr-check-8 | technical-writer | fullstack | fullstack ✓, integration ✓ (concedes it missed this in pr-check-3), strategic ✓ | Reword to "exit 1 = taken/found conflict, exit 2 = disagreement" in both places |
| A3 | `tools/ports.tsv` row 11330 (H1 proxy, released): source cell cites `tools/hermes/README.md` while saying it does not restate the port; no in-repo file:line, so doc SS7's rule is unmet for this one row. Honest, cannot affect a verdict. 8642 is fully fixed. | Advisory | pr-check-9 | strategic | integration | integration ✓, security ✓, technical-writer ✓ (prefers marking "hq-only, not mirrored" over dropping the row) | Mark the source "hq-only record, not mirrored" or drop the released row |
| A4 | Release ownership is the free-text project argument: any caller can release another project's claim by passing its name (and `--force` bypasses the guard anyway). An accident guard, not an access boundary; acceptable for a same-user local registry. | Advisory | pr-check-5 | security | platform | platform ✓, devops ✓, integration ✓ | One line in `port-registry.md` SS4 stating that |
| A5 | Backslashes in `source`/`note` are stored literally while `awk -v` at `port-check.sh:210` interprets escapes; affects only the release WARNING test. | Advisory | pr-check-5 | security | platform | platform ✓ ("only affects the WARNING test, Advisory") | Optional: pass via `ENVIRON` instead of `-v` |

Informational, not findings: devops noted that under a broken lsof even a self-release is refused (exit 3), by design and consistent with M1 fix. Security's three "verified fixed" FINDINGs (Fix: none) and devops's pr-check-4 env-parity note are verification records, folded into section 2.

## 4. Deliberation trails

No Blocking or Medium findings, no ESCALATE or CHALLENGE. One severity discussion worth recording, resolved by consensus without dissent:

> **A1 (validate_rows hardening) severity:** integration-architect (R, pr-check-2) filed Advisory; platform (R, pr-check-6), fullstack (R, pr-check-7), devops (R, pr-check-4) and security (R, pr-check-5) filed Advisory on overlapping items. Every C response across five topics said Advisory and explicitly "not Medium": reachable only by hand-editing the registry (or an informational field), the same local user could equally delete the row, `--claim` cannot write the bad rows, and the CLI check is identical across environments. Accountable closers (platform, devops, integration) all closed at Advisory with a single combined fix. Recorded as Advisory per bus consensus.

## 5. Timed-out threads

None. All 10 Accountable closing topics carry a CLOSED: `pr-check-cold-read-closed` (integration), `pr-check-1-closed` (devops, PASS), `pr-check-2-closed`, `3`, `4`, `5` (platform), `pr-check-6-closed` (devops), `pr-check-7-closed` (integration), `pr-check-8-closed` (fullstack), `pr-check-9-closed` (integration). Minor notes: security posted one empty message on pr-check-6 immediately before its real VALIDATE (no effect); on pr-check-1/3/cold-read some C seats were silent but those topics are PASS-only so no FINDING lacked quorum; devops (pr-check-7) and other C seats silent on topics where no Consulted duty applies.

## 6. Overall verdict

READY. 0 Blocking, 0 Medium. All four round-2 Mediums are verified fixed at 600ba03 by multiple independent reproductions, with no regression reported and both suites green (57/57, 43/43). The five Advisories are hand-edit-only hardening, label drift, one source cell, and two small notes; they may ride along or be deferred. Under D7 this is the final round; no further review loop is needed.

## 7. Confidence notes

- Validated by 3+ C members: A1 (4 C in pr-check-2, 4 in pr-check-4, 3 in pr-check-5/6, 4 in pr-check-7), A2 (3), A3 (3), A4 (3); the M1-M4 fixed claims (each reproduced by 4 or more seats).
- Thinner: A5 (1 C, platform), by nature a cosmetic quirk.
- Synthesizer did not re-run tests or repros; the evidence above is the seats' own, read from the bus.

CODE-GATE-REVIEW: PASS head=600ba03 blocking=0 medium=0
