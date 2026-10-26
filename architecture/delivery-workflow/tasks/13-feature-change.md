# Task Spec: 13-feature-change (EXTEND `feature-change`: `UNIT_MODE=team`, agent-hq port from W0)

- Work item: 13 (part-06 §7 row 9-13; card: part-02 §2.3 `feature-change` row; stage map row "One unit end to end"). Tier: `execute` (part-06 §7). The unit agents it drives run at the tiers of the unit table (part-03 §3.3).
- Review rung: Rung 1 trio by the UNMODIFIED installed skills (M29), max 3 rounds then the owner (D7). Prose skill; no script.
- Branch: the separate EXTEND branch (M29), shared with items 10-12, own directory. SPEC-QUESTION Q13-1: branch name and base are not named in the design; the integrator names them. The base must contain the W0 item 8 port of `skills/feature-change/` (it is untracked in `wt/delivery-w0` today, measurements Row 6).
- Dependencies: W0 item 8 (port-and-strip) landed and reviewed; INTERFACES D2.3, part C C2/C3/C4, part A A.5/A.6/A.7; AM-1 (1.1.0) A.5.2 only where a port is bound (feature-change binds none; recorded as a no-op, see §8). Item 8b sources are not touched.
- Split: none (one agent, one pass).

## 1. Objective
Add a `UNIT_MODE` input to `skills/feature-change/` (`solo` default = today's behaviour, `team` = one unit inside a delivery run) without changing `solo`.

**Done condition (one, machine-checkable):** the §9 block prints `OK-input OK-skip OK-emit OK-catalog OK-solo`, prints no `MISSING` line, the sanitization grep and the out-of-scope `git diff --stat` print nothing, and `tools/check-doc-length.sh .` exits 0.

## 2. Context Package
- Card (part-02 §2.3): "port-and-strip first (W0 item 8: Notion paths and personal-project text removed, verified by grep, M10), then `UNIT_MODE=team`: branch name `<JIRA-KEY>-<slug>` from the repo profile, skip ticket creation, skip integration and cleanup steps, emit `UNIT-VERDICT:` bus post and `NEXT:` line, register the worktree in the catalog, run affected lint+test+typecheck once per push or batch and record `GATE-PASS` (D21, R2-3)" | "conductor owns tickets, integration, cleanup" | no owner ask.
- The port-and-strip half is W0 item 8 and is a precondition here; this item re-runs its grep as a guard and fixes any residue it finds in `skills/feature-change/` only.
- INTERFACES D2.3: input `UNIT_MODE` = `team` or `solo`, default `solo`; branch `<JIRA-KEY>-<slug>`. Step 0 prints `INPUT-ERROR UNIT_MODE enum` for any other value (D1).
- Current skill (`skills/feature-change/SKILL.md`, 110 lines): Inputs `REPO`, `SLUG`, `AC`, `PROJECT`; Step 0 repo policy lookup (reads `<REPO>/CLAUDE.md`, a project record under `$HOME/projects/agent-hq/projects/<slug>.md`, owner ruling or one owner question); Steps 1 ticket, 2 worktree `wt/<SLUG>`, 3 implement, 4 tests, 5 repo gates, 6 distinct verifier, 7 review rung, 8 integrate per `ROUTE`, 9 cleanup, 10 record, 11 no scope creep.
- In `team` mode the lead has already fixed everything Step 0, 1, 8, 9 and 10 decide: gates from the repo profile (`gates.command`, A.7), branch from the ticket key (tickets.tsv, A.6 line 306: readers include `feature-change`), integration by the Integrator persona (M20, single writer of the sub-task branch), cleanup by `delivery-cleanup`, tickets by `ticket-clerk` in the conductor session.

## 3. Scope
**In scope (directory `skills/feature-change/` only):** `SKILL.md` (frontmatter `version:`, Inputs, a `## Team mode` section or short subsection, Step 0 input validation, per-step "team: skip/do" markers, Red flags rows, Exit criteria rows, Provenance line). If the body would pass about 5k tokens, put the team-mode detail in `skills/feature-change/references/team-mode.md` (NEW, allowed) and link it.
**Out of scope:** `solo` behaviour (byte-identical for every step when `UNIT_MODE` is unset or `solo`, other than the new input line); `wave-execution`, `delivery-run`, `delivery-cleanup`, `ticket-clerk`, `delivery-desk`, `pre-pr-gate`; persona briefs (item 27b); the gate runner; INTERFACES; any other skill.
**Do NOT create:** a script, a bus client, a second branch-naming rule, a `UNIT_MODE` value other than the two, ticket or Jira calls, a desk request, a `Verified-By` line, an `INSTALL` path, a file outside `skills/feature-change/`.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| D2.3 `feature-change` | `UNIT_MODE` `team`\|`solo`, default `solo`; branch `<JIRA-KEY>-<slug>` | `interfaces/part-d-enums-topics.md` D2.3 (line 102) |
| D1 | one `INPUT-ERROR <field> <reason>` line per failing field, then stop | part-d D1 |
| C2 `UNIT-VERDICT` | bare JSON `{"unit":"<id>","verdict":"PASS\|ROLLED\|ESCALATE","head":"<sha>","reason":"<code>"}`, exactly four keys, posted on topic `<run-id>-<subtask>-rendezvous`, `session_id = <run-id>-<subtask>`; `PASS` takes reason `none`; `head` = unit worktree head at posting; "`UNIT-VERDICT:`" is the prose name, not a text prefix | `interfaces/part-c-waves-control.md` C2 (lines 56-84) |
| C2 reasons | closed set; the ones this skill emits: `none`, `decision-gate`, `spec-gap`, `contract-gap`, `tier-exhausted`, `budget`, `env-bug`, `merge-conflict`, `human-step`, `gherkin-checkpoint` | C2 table |
| C4 fallback | bus unreachable at posting: write the exact C2 record to `RUN_HOME/<subtask>/status/<agent-id>.verdict` and stop | part-c C4 |
| C3 `NEXT:` | `^NEXT: (u[0-9]+)\.([0-9]+) .+$`, one current line overwritten in `RUN_HOME/<subtask>/status/<agent-id>.md`; `<n>` is the step number in the unit's `.tasks/<unit>-<slug>.md` §9, `0` before the first step | part-c C3 |
| D5 `bus.endpoint` | bus coordinates read from `RUN_HOME/<subtask>/bus.endpoint`, never guessed | part-d D5 |
| A.5 / A.5.1 | `catalog.sh register worktree <handle> <unit> <correlation_id> <source> <subtask> <owner_agent>` before `git worktree add`, `start` after; handle under the registered worktree base | part-a A.5, script table in `INTERFACES.md` |
| A.7 | `GATE-PASS <sha> <cmds>` at `RUN_HOME/<subtask>/gate-runs/<sha>.md`, written ONLY by the gate runner (separate mechanical agent), once per push or batch; commits outside a desk push run hooks; `HUSKY=0` is never set by this skill | part-a A.7 (lines 308-325) |
| A.1 | `<JIRA-KEY>` is a profile/ticket fact (`^[A-Z][A-Z0-9]+-[0-9]+$`); branch created only after the key is read back from the desk (COMMON block §3.0) | part-a A.1, part-03 §3.0 |

## 5. Inherited Module API
`catalog.sh` (kinds incl. `worktree`, `branch`); `status/<agent-id>.md` and `.verdict` file conventions; `tickets.tsv` (`slug key parent status utc`, latest row per slug governs, `-` = key absent) read-only here.

## 6. What You Inherit
| Thing | Source | Notes |
|---|---|---|
| Unit brief + `.tasks/<unit>-<slug>.md` | dispatched by `delivery-run` | gives `AC`, scope globs, `SLUG`, unit id, `DONE` token; Step 0 policy lookup is replaced by the repo profile (Q13-2 below) |
| Distinct verifier (Step 6) and review rung (Step 7) | unchanged | in team mode the rung is the unit table's `review path`; `pre-pr-gate` owns the PR-level `pr-review` |
| COMMON block | part-03 §3.0 | any agent holding the Agent tool passes it verbatim into briefs it writes |

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Branch (team) | `<JIRA-KEY>-<slug>` read from `tickets.tsv`/desk read-back | `wt/<SLUG>` (the solo form) | D2.3, card |
| `UNIT-VERDICT` post | bare JSON object, four keys | `UNIT-VERDICT: {...}` text prefix; extra keys | C2 |
| `head` | `git rev-parse HEAD` in the unit worktree at posting | the base sha or a pushed-remote sha | C2 lead handling |
| `reason` with `PASS` | `none` | omitted | C2 |
| `GATE-PASS` writer | the gate runner (A.7) | this skill (author claim) | A.7, card wording (see Q13-3) |
| `HUSKY=0` | not set here (desk push and PR creation only) | exported or on a local commit | A.7 |
| `NEXT:` file | own `status/<agent-id>.md` only | another agent's file | C3, §3.0 |
| Unit id | `^u[0-9]+$`; Integrator `i<N>` is not this skill | `U1`, `unit-1` | A.1 |

## 8. Acceptance Criteria
- [ ] Inputs list adds `UNIT_MODE`; Step 0 validates it (`INPUT-ERROR UNIT_MODE enum`); unset = `solo`.
- [ ] `team`: Step 1 (ticket) skipped with the line "ticket owned by the conductor"; Step 8 (integrate) and Step 9 (cleanup) skipped; branch is `<JIRA-KEY>-<slug>` from the ticket read-back, created only after the key exists; if the key is absent, emit `ESCALATE` reason `spec-gap` (SPEC-QUESTION Q13-4: the design says "created only after the Jira key is read back" but names no reason code for a missing key; `spec-gap` is the nearest C2 code, integrator confirms).
- [ ] `team`: before `git worktree add`, `catalog.sh register worktree ...`; `start` after; the same for the branch row. A catalog failure (exit 2, 3, 4) stops the unit (no add).
- [ ] `team`: `NEXT:` line written to the agent's own `status/<agent-id>.md` after each step of the unit's §9 list, matching C3's regex.
- [ ] `team`: affected lint+test+typecheck is requested from the gate runner once per push or batch at unit end; the skill reads `gate-runs/<head>.md` and cites it; it never writes `GATE-PASS`. Q13-3: the card says "record `GATE-PASS`"; A.7 (frozen) fixes the writer as the gate runner, never the author; this spec follows A.7 and the integrator confirms the card wording is read as "obtain and cite".
- [ ] `team`: ends by posting the C2 record on the bus named in `bus.endpoint` (or writing `status/<agent-id>.verdict`, C4), `PASS` only after a distinct verifier reported every AC MET and `head` is the worktree head; else `ROLLED`/`ESCALATE` with a C2 reason. Step 10 (ledger row, ticket update): skipped in team mode, the lead owns the record (Q13-5: the card does not list Step 10; skipping follows "conductor owns tickets" and the C2 handling; integrator confirms).
- [ ] Step 0 repo policy lookup in team mode reads `GATES` from the repo profile `gates.command` and `ROUTE` is moot (Q13-2: the card is silent on Step 0; the profile is the A.7 authority; integrator confirms).
- [ ] Port guard (AM-1, A.5.2 scope "e2e lanes, dev servers"): recorded as a no-op line, "this skill binds no port; any dev server a unit starts is claimed per A.5.2 through `port-claim` first" (no new step). `security-audit` (AM-1): not used by this skill (the security seat belongs to the review step).
- [ ] `solo` path unchanged; `version:` set (Q13-6: baseline and bump rule unspecified; integrator sets them); five anatomy sections present; ported residue grep empty; Provenance appended ("extended 2026-10-26 for the delivery workflow, design §2.3").

## 9. Verification Commands
```bash
cd ~/projects/agent-hq-worktrees/delivery-w0   # on the EXTEND branch
S=skills/feature-change; F="$S/SKILL.md $(ls $S/references/*.md 2>/dev/null)"
grep -q 'UNIT_MODE' $S/SKILL.md && grep -q 'INPUT-ERROR UNIT_MODE enum' $F && echo OK-input
grep -n -i -E 'team' $F | grep -i -E 'skip' | grep -i -E 'ticket|integrat|cleanup' | grep -c . | awk '$1>=3{print "OK-skip"}'
grep -q 'rendezvous' $F && grep -q 'NEXT:' $F && grep -q '\.verdict' $F && grep -q 'bus.endpoint' $F && echo OK-emit
grep -q 'catalog.sh register worktree' $F && echo OK-catalog
grep -n 'GATE-PASS' $F | grep -v -i 'runner\|gate-runs\|read\|cite' ; true   # any hit here is a candidate author-writes-GATE-PASS line: review by hand, expect none
git diff -- $S/SKILL.md | grep -E '^-[^-]' | grep -v -E '^-(version|description)' ; true   # removed solo lines: expected none besides reworded Inputs
echo OK-solo     # printed by the verifier after the diff review shows solo steps 1-11 unchanged
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$h" $S/SKILL.md || echo MISSING $h; done
head -12 $S/SKILL.md | grep -E '^version:'
grep -rn -E '/Users/xavier|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|Notion' $S   # nothing (also the item 8 guard)
grep -n -E 'HUSKY|--no-verify' $F   # only "never set here" statements
bash tools/check-doc-length.sh . ; git diff --stat -- . ':!skills/feature-change'   # second: empty
# fixture (verifier, $TMPDIR): dispatch a feature-change agent on a 1-AC toy repo with UNIT_MODE=team, a stub RUN_HOME, bus.endpoint pointing nowhere:
# expected: catalog rows, NEXT lines matching ^NEXT: (u[0-9]+)\.([0-9]+) .+$, a status/<id>.verdict equal to a four-key C2 record, no push, no ticket call, no worktree removal.
```

## 10. Branch and worktree
Separate EXTEND branch (Q13-1); no add, commit, rebase or push by the author. The unit worktrees feature-change itself creates are unrelated to this build branch.

## 11. Decision Gate Reminder
Write `.decisions/13-feature-change.md` and stop if: the item 8 port still carries Notion or personal-project text you cannot remove with a whole-block deletion; a `solo` step would change; a C2 reason is needed that is not in the closed set; the skill would have to write `GATE-PASS`, call Jira, or push; the bus cannot be reached and `RUN_HOME` is unset (stop, no guess).
