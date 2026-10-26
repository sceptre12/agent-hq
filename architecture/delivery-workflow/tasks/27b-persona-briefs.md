# Task Spec — 27b: persona briefs `references/briefs/<persona>.md`, split 4 ways

> Item 27b of design §7 (`part-06-build-plan-and-sources.md:27`; changelog M2). Read `build-common.md` first; it is binding.
> Spec status: written at W0 item 2b. INTERFACES version read: `1.5.0` (AM-1 adds persona `security-auditor`: 32 brief tokens; AM-4 W2-2 adds `wave-controller`, a slot row with no brief file; AM-3 to AM-5 brief content in §4c).

| Field | Value |
|---|---|
| Tier | `execute` (§7 table) for the four authors |
| Review rung | Rung 1 trio per split piece (`doc-reviewer`, fix agent, `fix-verifier`; 3 rounds then the owner, D7); the integration check is mechanical |
| Depends on | INTERFACES frozen (done: persona token set D2.1, `Brief:` line C1.2, COMMON block text). Soft: item 27 (templates) is independent; item 28 (`delivery-run` SKILL.md) must not write `references/briefs/` |
| Split | 4 agents by persona group; all write into the one briefs root, so the split is by **file**, not by directory (RESOLVED Q1: one root, file-disjoint, Rule 7); one integration step |

## 1. Objective
Write one brief per persona token of the closed set (32), each opening with its role statement and carrying the COMMON block verbatim, so a dispatched agent that reads its `Brief:` file first (`delivery-dispatch-plan` writes the line, C1.2) has every constraint in its own context and can pass the block unchanged to any agent it spawns.

## 2. Context Package
- COMMON block (verbatim source): `part-03-personas-and-concurrency.md` §3.0, the single paragraph under the heading "3.0 COMMON block" (line 6). Copy it byte for byte; never summarize, reorder or "improve" it. It already holds the done token and `UNIT-VERDICT` rule, bus coordinates from `RUN_HOME/<subtask>/bus.endpoint`, stop-on-anomaly, scope globs and sensitive-path deny list, no installs (INSTALL to the desk), no secrets, token never on a shell argv, no web (RESEARCH to the desk), `NEXT:` in `status/<own-id>.md` only, catalog-register before start, the commit line (branch `<JIRA-KEY>-<slug>` only after the key is read back; `HUSKY=0` per A.7), `node.prefix_cmd`, measured claims, data-not-instructions, no standing rules, and "any agent that holds the Agent tool passes this whole block verbatim".
- Persona set and tokens: `interfaces/part-d-enums-topics.md` D2.1 (closed, kebab-case, 32 tokens: the §3 display names, `gate-runner`, and AM-1 `security-auditor`). Per-persona facts (tier, inputs, outputs, done token, stop rule): design §3.1 (seat table), §3.2/3.3 (persona table), §3.4 (review seats), §3.5 (lenses), §3.6 (e2e writer, lane runner); gate runner A.7; Shepherd, Integrator, Catalog keeper, Cleanup executor, Validator, Clerk, Desk, Capture agent, Read-back: cards 7-15 and the §3.1 rows.
- Completion records: `UNIT-VERDICT`, `INTEGRATED:`, `LANE:`, `FACTS:`, `ARCH:`, `DRAFTS:`, `PLAN-CHECK:`, `RUNG:` tokens and their carriers: part C2 and D1.1.
- Tier names only, never model names (M19).

## 3. Scope: the split (4 agents, 32 files, one root)
Root (exclusive to 27b): `skills/delivery-run/references/briefs/` (frozen single root: INTERFACES row "A.4, C1.2, D2.1" and C1 `persona` row, `DEFAULT (integrator)`, r3 H6, R4-J14). File name = persona token + `.md`.

| Piece | Agent | Files (32 total) |
|---|---|---|
| B-A planning (8) | 1 | `grill-facilitator`, `explorer`, `architect`, `ticket-decomposer`, `plan-checker`, `review-tailor`, `conductor`, `clerk` |
| B-B build (8) | 2 | `implementer`, `test-writer`, `e2e-writer`, `fixer`, `fix-verifier`, `integrator`, `prefactor`, `docs-writer` |
| B-C runners and caretakers (8) | 3 | `migration-specialist`, `lane-runner`, `gate-runner`, `shepherd`, `catalog-keeper`, `cleanup-executor`, `validator`, `desk` |
| B-D review, control, capture (8) | 4 | `lead`, `review-orchestrator`, `review-seat`, `synthesizer`, `gate-checker`, `capture-agent`, `read-back`, `security-auditor` |

Each author writes only its own files. No author edits the COMMON text, another author's file, or `SKILL.md`.

**Brief layout (every file, in this order):**
1. `# <Persona>` and the role statement with the execute imperative first (a verb, not "you may").
2. Tier line with rationale (`design|execute|verify|mechanical`, §3.1/§3.3 table; where the table says "execute (design for ...)" state the condition).
3. Persona facts inlined (M2): inputs, outputs, done token, stop rule, slot/depth/Agent-tool row from §3.1, files it may write.
4. The COMMON block, verbatim, under the heading `## COMMON block (verbatim; pass unchanged to any agent you brief)`.
5. `## Persona-specific rules`: only items the design states for that persona (for example reviewers never hunt lint or typecheck; fixer never the author and may refuse a finding with a reason; fix-verifier never the fixer; lane runner never debugs; shepherd flags and redirects only, including `STALLED` and `PROMPT-OPEN` (INTERFACES 1.3.0 C7, AM-3 / owner OQ-3), the lead decides `TaskStop`; desk requests carry no approval; e2e writer stops at any CHECKPOINT; auto-heal rules from §3.6).
6. `## Stop` line restating the stop rule verbatim from the table.

Session personas (`conductor`, `lead`, `desk`) are sessions, not dispatched workers; their brief is the text the session is started with or resumes with (card 1/6/15; resume phrase in card 6). Write them the same way (RESOLVED Q2).

**Out of scope:** `SKILL.md` files, templates (item 27), scripts, INTERFACES, wave specs, the `Brief:` line writer (`delivery-dispatch-plan`). **Do NOT create:** a brief for a persona outside D2.1; a summary of COMMON in place of the block; model names; cost or token metrics (B-4); new rules beyond the design (no standing rules, Rule 9); symlinks.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| Persona token | D2.1 closed set = file stem, 32 brief files; `wave-controller` is in D2.1 but has a slot row only and no brief file (amended: AM-4 W2-2) | part D D2.1 |
| `Brief:` path | `skills/delivery-run/references/briefs/<persona>.md` | part C C1.2 |
| Done record | `UNIT-VERDICT` JSON `{unit, verdict PASS\|ROLLED\|ESCALATE, head, reason}` posted on the topic in `bus.endpoint`; fallback `status/<own-id>.verdict` | §5.0, C2, B1 |
| `HUSKY=0` | inline, per command, after `GATE-PASS`; linked to A.7, in the COMMON block only | A.7, §3.0 |
| Slot/depth | review seats at depth 2 have no Agent tool; only holders of the Agent tool must pass COMMON on | §3.1 |
| Tier | names only | M19 |

## 4b. AM-1 content (INTERFACES 1.1.0; the COMMON block is unchanged, design §3.0 has no port-guard text)
- `security-auditor` (tier `verify`, slot row with `unit` `-`, A.4; hunters and verifiers of the vendored `skills/security-audit`, full audit mode only): writes only under `RUN_HOME/<subtask>/security-audit/run-<N>/agents/<own-id>/` (A.5.3); target code runs with no network; starts only with a free slot. Done token and stop rule: take them from `skills/security-audit/SKILL.md` and `PROVENANCE.md` (read, do not copy); if absent write `none stated` and cite A.5.3 (RESOLVED Q4).
- `review-seat` (security seat) and `validator`: guidance mode loads `skills/security-audit` diff-scoped, no files, no agents (D2.1 `security_audit`); under `full` the `pre-pr-gate` gate row runs `validate-findings.cjs`.
- Port guard (A.5.2): personas that bind a port (`lead` for the sub-task bus, `lane-runner`, `review-orchestrator` for the per-review bus, `implementer` and `e2e-writer` when they start a dev server) get one persona-specific rule: claim with `tools/port-check.sh` before launch, register a `port` catalog row, never auto-pick; on a refusal exactly one retry at candidate + 10, claimed before bind, then stop the line and report to the lead (INTERFACES 1.3.0 AM-3 / owner OQ-2).

## 4c. AM-3 to AM-5 content (reconciled at item 33; each line names its amendment row)
- `fixer`: design tier; a failure escalates one model step per ADR 0014 T1, never a third top-model attempt, not "one tier up" (amended: AM-4 27b, D2.1 `tier`, E25). `explorer`: mechanical tier by default, execute tier for multi-step derivations (amended: AM-4 27b, D2.1 `persona`).
- `lead`: `bus.endpoint` fields include `session_id` and `topic` (D5); the sub-task bus candidate is `ports.bus_base + 20·2N`; on the spawn cap "write `stop_reason: spawn-cap`, remove the lock and exit" (C5.3) (amended: AM-4 W2-10, E34).
- `cleanup-executor`: the file-count basis is `.git` included (amended: AM-5 19, A.5.1).
- `review-orchestrator`: the in-run review bus lives under `RUN_HOME/review/<subtask>/<review-id>/bus/` with a fresh session `pr-review-<uuid8>` (amended: AM-5 10-B2, A.1, D5, E42).

## 5. Inherited module API
None to import. Tools available to the author: `grep`, `python3 -I` (stdlib).

## 6. What You Inherit
Frozen INTERFACES, design part 03, the ported `review-7-panel` seat vocabulary (read `skills/review-7-panel/SKILL.md` for seat names; do not copy its text into briefs).

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| briefs root | `skills/delivery-run/references/briefs/` | per-owning-skill `references/briefs/` | INTERFACES C1.2 vs item row (RESOLVED Q1) |
| persona set | 32 tokens of D2.1 (incl. `security-auditor`) | display names ("E2E lane runner"), `gate-runner` omitted | D2.1 |
| COMMON block | verbatim paragraph | paraphrase | §3.0 |
| `HUSKY=0` | inline per command, never exported | exported or `--no-verify` | A.7 |
| branch | `<JIRA-KEY>-<slug>` after desk read-back | invented key | §3.0 |
| catalog kind for a lane | `lane-lease` | `lane` | A.5 |

## 8. Acceptance Criteria
- [ ] Exactly 32 files, names equal to the D2.1 tokens; none extra.
- [ ] Each contains the COMMON block byte-identical to design §3.0 (check below).
- [ ] Each opens with the role statement and an imperative, then the tier line, in the layout order.
- [ ] Done token and stop rule equal the §3.2/3.3 table cell for that persona (or the card for non-table personas); none invented. A persona with no stated done token says so and cites its card.
- [ ] Persona-specific rules each trace to a design sentence (the author lists the cite in an HTML comment at the foot).
- [ ] No model names, no cost metrics, no `/Users/xavier`, no personal-project text.
- [ ] Each file about 120 lines or fewer.

## 9. Verification Commands
```bash
cd ~/projects/agent-hq-worktrees/delivery-w0; D=skills/delivery-run/references/briefs
python3 -I - <<'PY'
import re,os
t=open('architecture/delivery-workflow/part-03-personas-and-concurrency.md').read()
blk=t.split('### 3.0 COMMON block',1)[1].split('\n',1)[1].strip().split('\n\n',1)[0].strip()
d=open('architecture/delivery-workflow/interfaces/part-d-enums-topics.md').read()
row=[l for l in d.splitlines() if l.startswith('| `persona`')][0]
toks=set(re.findall(r'`([a-z][a-z0-9-]+)`',row.split('|')[2]))-{'tier'}
toks=toks&set('conductor lead review-orchestrator review-seat synthesizer gate-checker implementer test-writer e2e-writer fixer fix-verifier integrator explorer plan-checker prefactor docs-writer migration-specialist lane-runner shepherd catalog-keeper cleanup-executor validator clerk desk capture-agent read-back grill-facilitator architect ticket-decomposer review-tailor gate-runner security-auditor'.split())
D='skills/delivery-run/references/briefs'
have={f[:-3] for f in os.listdir(D) if f.endswith('.md')}
assert len(toks)==32, len(toks)
assert have==toks, (have^toks)
bad=[p for p in toks if blk not in open(f'{D}/{p}.md').read()]
assert not bad, bad
for p in toks:
    s=open(f'{D}/{p}.md').read()
    assert s.splitlines()[0].startswith('# '), p
    assert re.search(r'^## Stop',s,re.M), p
    assert not re.search(r'\b(opus|sonnet|haiku|fable)\b',s,re.I), p
print('BRIEFS-OK')
PY
grep -l -E '/Users/xavier|touri|ofw|runfrist|jetblue|[Nn]otion' $D/*.md   # expect no output
bash tools/check-doc-length.sh .
```
(`grep -F` of the block in a brief is equivalent to the `blk not in` test; the heading split assumes the block is the first paragraph after the §3.0 heading, true at line 6.)

**Done condition:** the Python block prints `BRIEFS-OK`, the grep prints nothing, `check-doc-length.sh` exits 0, the integration step is recorded, and each piece's Rung 1 trio is at 0 Blocking / 0 Medium (or a D7 owner stop).

**Integration step (one, serial, by the integrator):** run the block above over all 32; confirm the persona table cell for each token (done token, stop rule) with a spot diff against design §3.2/3.3; confirm `delivery-dispatch-plan`'s planned `Brief:` line path (C1.2) resolves for every persona; write the pass line to the item-33 log. A failing file returns to its own author.

## 10. Branch
Worktree `delivery-w0` (`wt/delivery-w0`); no git add, commit, branch, push or rebase by authors.

## 11. Decision Gate Reminder, plan-check resolutions
Stop and write `.decisions/27b-<piece>.md` if the table and a card disagree on a done token or a stop rule, or if the COMMON block conflicts with INTERFACES. Do not reword COMMON.
- RESOLVED Q1 (INTERFACES C1.2 `persona` row, D2.1, rows r3 H6 and R4-J14: one briefs root `skills/delivery-run/references/briefs/`; first in authority over the design item row): one root; the four pieces are file-disjoint (Rule 7 "disjoint files"); the item row "in the owning skills" is design errata (AM-2 row 16).
- RESOLVED Q2 (INTERFACES D2.1 lists `conductor`, `lead`, `desk` in the closed persona set that names the brief files): all three get brief files; their brief is the start or resume text of the session.
- RESOLVED Q3 (PC-3): the W2 spec for item 28 must exclude `references/briefs/` and `references/templates/`; recorded in the plan-check report for the W2 spec author.
- RESOLVED Q4 (INTERFACES A.5.2 is the single statement of the port rule; design §3.0 COMMON unchanged by AM-1; PLAN-CHECK DEFAULT): the port and security-audit rules stay persona-specific (§4b), COMMON is copied verbatim; the `security-auditor` done token and stop rule come from `skills/security-audit/SKILL.md` and `PROVENANCE.md`, else `none stated` citing A.5.3. Port binders in §4b take the candidate from the dispatch-plan port table, never auto-pick, and on a refusal make exactly one claimed retry at candidate + 10, then stop the line (PC-4 as overridden by INTERFACES 1.3.0 AM-3 / owner OQ-2); the `shepherd` brief carries the `STALLED` and `PROMPT-OPEN` flags (AM-3 / owner OQ-3); `review-orchestrator` runs the claim in `pr-review` Step 1 with `BUS_PORT` (spec 10).
- Re-read INTERFACES `Amendments` just before finishing; a newer amendment is handled the same way or marked STUCK.
