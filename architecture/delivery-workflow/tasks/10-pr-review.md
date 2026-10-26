# Task Spec: 10-pr-review (EXTEND `pr-review`: items b-f live, (a) `ROLES` behind the D12 flag, port guard, security-audit guidance load)

- Work item: 10 (design part-06 §7 row 9-13; card: part-02 §2.3 `pr-review` row). Tier: `execute` (part-06 §7 tier column; Sonnet-class via `tools/model-routing.md`, never pinned in skill text, M19).
- Review rung: Rung 1 trio (`doc-reviewer`, separate fixer, `fix-verifier` with `FILE_SET` = the files in §3 In scope), run by the UNMODIFIED installed skills (M29), max 3 rounds then the owner (D7). Prose skill; no script, so no code gate.
- Branch: the separate EXTEND branch (M29). SPEC-QUESTION Q10-1: branch name and base are not named in the design or INTERFACES; the integrator (Worker1) names them.
- Dependencies: INTERFACES 1.1.0 (amendment AM-1, landed: port guard A.5.2, `security-audit` A.5.3, D2.1 `security_audit`, D2.3 `pr-review` row); `tools/port-check.sh` and `tools/ports.tsv` present on the EXTEND branch base (port-guard PR #9, branch `wt/port-guard`); `skills/security-audit/` present (it is); `skills/port-claim/` (item 8). No dependency on items 11-13 (directory-disjoint).
- Split: none (one agent, one integration pass by the author).

## 1. Objective
Edit `skills/pr-review/` so the six EXTEND changes (a)-(f) of the card, the port-guard bus start and the security seat's guidance-mode `security-audit` load are in place, with `ROLES` subsets refused while the D12 flag is off.

**Done condition (one, machine-checkable):** the §9 block prints each of `OK-a OK-a2 OK-d OK-f OK-port OK-sec`, prints no `MISSING` line, the sanitization grep and the out-of-scope `git diff --stat` print nothing, and `tools/check-doc-length.sh .` exits 0.

## 2. Context Package
- Card: part-02 §2.3 row `pr-review` (a)-(f); sources `pr-review-local-diff-bus-facts`, `pr-review-orch-reads-closed`, A4. (a) is gated by the D12 probe; (b)-(f) are bug fixes.
- D12 (part-01 item 13): subsets smaller than 7 only after a RACI remap and a 3-seat probe show no lost checks; until then every `pr-review` runs 7 seats.
- Probe result (measurements-2026-10-26.md, Item 4 (B), dry run, 35 subsets of `references/agent-roles.md`): NO 3-subset keeps a Responsible seat for all 10 checks (fewest lost: 4 checks, 5 subsets; every subset also loses at least 1 Accountable closer). Best subset: `devops-engineer`, `integration-architect`, `platform-engineer`, losing R for checks 5, 7, 8, 9 and the closer for check 8. A real bus was NOT run (pm2 EPERM, no bus `node_modules`, `/tmp` unwritable). Consequence for this item: the flag ships OFF and stays off until a RACI remap exists and a bus probe records no lost checks; this item writes the remap procedure and the refusal, never the enabling.
- Depth: seats run at depth 2 and have no Agent tool (part-03 §3.1; measurements Item 4 (A)), so a seat that loads `security-audit` can only run guidance mode WITHOUT launching focused agents.
- Port guard (AM-1, `interfaces/part-a-state.md` A.5.2; scope names "`pr-review`'s per-review bus"): order before launch (1) `tools/port-check.sh --claim <port> <bind> <container_port> <service> <project> claimed <source> <note>` through `port-claim`, `project` = `<run-id>`, `source` = `<run-id>-<subtask>`; (2) `catalog.sh register port <port> ...` (`planned`); (3) launch; (4) `catalog.sh start`. Exit 1 or 2 refuses the launch, never auto-picks, reports to the lead; exit 3 is stop-the-line. Release is cleanup only. The PreToolUse hook `tools/hooks/port-precheck.sh` is advisory and catches launches outside this path.
- security-audit (AM-1; D2.3 `pr-review` row, D2.1 `security_audit`, A.4 line 217, A.5.3): input `SECURITY_AUDIT` `guidance|full`, default `guidance`; the security seat loads `skills/security-audit` in guidance mode, diff-scoped, writes no file and launches no agent; under `full` the seat also reads the latest `RUN_HOME/<subtask>/security-audit/run-<N>/findings.json` (`DEFAULT (integrator)`), read-only. Full-mode agents are counted by the caller in the slot ledger (persona `security-auditor`), never by this skill.
- Namespacing (part-03 §4, M12): bus `data_dir` sits under `RUN_HOME/<subtask>/bus/`, never `$TMPDIR` or `/tmp`; pm2 app name carries `<run-id>-<subtask>`; `pm2 jlist` checked before start.
- Existing state: `SKILL.md` 404 lines; local-diff mode exists (lines 87-100) and seat briefs already use `peek:true` (`references/agent-briefs.md:90,143`); orchestrator, gate-checker and synthesizer reads (`SKILL.md` Steps 5, 7, 8; `references/synthesizer-brief.md:24-31`) do not.

## 3. Scope
**In scope (directory `skills/pr-review/` only):**
- `SKILL.md`: `version:` in frontmatter (Q10-3); Step 0 input validation (D1: one `INPUT-ERROR <field> <reason>` line per failing field, then stop) for `ROLES`, `SECURITY_AUDIT`, `PR_REVIEW_MODE`, `STACK_BASE`, `STACK_HEAD`, `RECORD_PATH`; Steps 1, 2, 4-9 edits below. Body stays under about 5k tokens: move new prose into `references/`.
- `references/roles-subset.md` (NEW): the (a) RACI-remap procedure and the flag refusal.
- `references/agent-briefs.md`, `references/synthesizer-brief.md`, `references/bus-schema.md` (read idiom), `references/agent-roles.md` (only if (a) needs a mapping table; otherwise untouched).
**Out of scope:** `skills/security-audit/` (read-only, never edited); `tools/` (the port-check script and hook are another PR); `INTERFACES*` and ADRs; the 7-seat roster and the RACI rows themselves (no change to `agent-roles.md` R/A/C lists); any enabling of a smaller roster.
**Do NOT create:** a probe result file, a remap table for any 3-seat or other subset (none exists; not invented here), a second bus or port registry, a symlink, or any file outside `skills/pr-review/`.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| D2.3 `pr-review` row | named inputs `ROLES` (comma list of seat ids), `SECURITY_AUDIT` (`guidance`\|`full`, default `guidance`), `PR_REVIEW_MODE` (`local-diff`\|`pr`), `STACK_BASE`, `STACK_HEAD` (40-hex sha), `RECORD_PATH`; seat count 7 until the D12 remap and probe are recorded | `interfaces/part-d-enums-topics.md` D2.3 |
| D1 | Step 0 prints `INPUT-ERROR <field> <reason>`, reason in `missing\|enum\|path\|unset\|format`, regex `^INPUT-ERROR [A-Za-z_][][A-Za-z0-9_.]* (missing\|enum\|path\|unset\|format)$` | part-d D1 |
| D1.1 `RUNG:` | `ROLES` derives from the seat table in `review-tailor-<slug>.md` lines 2+ (`seat-id<TAB>role<TAB>reason`) | part-d D1.1 |
| A.6 review record | `RUN_HOME/review/<subtask>/record-<head>.md`; line 1 `^CODE-GATE-REVIEW: PASS head=([0-9a-f]{40}) blocking=0 medium=0$`; line 2 `^Reviewed-By: ([a-z0-9-]+) ([a-z0-9-]+) ([A-Za-z0-9_-]+)$` (`seat-id session TASK-id`); line 3 `Verified-By:` is NOT written by `pr-review` | `interfaces/part-a-state.md` A.6 (lines 282, 300) |
| A.5 / A.5.1 | catalog kinds `pm2-app`, `bus`, `port`, `tmpdir`; `catalog.sh register` before start, `start` after | part-a A.5, A.5.1 |
| C2 reader idiom | `peek:true`, fresh `agent_id` per read, `limit 200`, topics read separately | part-c C2 (line 84), part-d D4 (line 118) |
| A.5.2 port guard | claim before bind; refuse on exit 1/2; exit 3 stop-the-line; hook advisory | `interfaces/part-a-state.md` A.5.2 (line 272) |
| `security-audit` modes | guidance mode: no output directory, no audit artifacts, no automatic six phases; universal execution safety applies (no target code execution without full sandbox) | `skills/security-audit/SKILL.md` "Operating modes" |

## 5. Inherited Module API
- `references/bus-schema.md` topics `pr-check-cold-read`, `pr-check-1`..`9` and `-closed`; `read_messages` args `session_id` (mandatory), `agent_id`, `topics` (array), `peek`, `limit`.
- `tools/port-check.sh <port>` exits 0 free, 1 taken, 2 disagree (hard stop), 3 usage/registry unusable; `--claim <port> <bind> <container_port> <service> <project> <status> <source> <note>`; `skills/port-claim/SKILL.md` Steps 1-4.
- `catalog.sh register <kind> <handle> <unit|-> <correlation_id> <source> <subtask|run> <owner_agent>` (INTERFACES script table).

## 6. What You Inherit
| Thing | Source | Notes |
|---|---|---|
| Local-diff mode, `RECORD_PATH` writer, identity grep | `SKILL.md` lines 87-100, 300-335 | edit, do not rewrite |
| 7 seat briefs with `peek:true` | `references/agent-briefs.md` | seats already conform to (b)/(c) |
| Port-check CLI and registry | port-guard PR #9 | use as-is; Step 1 must call it, not reimplement it |
| `security-audit` guidance mode | `skills/security-audit/SKILL.md` | load by name; edit nothing there |

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Stacked diff | `git diff <STACK_BASE>..<STACK_HEAD>` (card (d)) | the existing local-diff three-dot `BASE...HEAD` for a stacked PR | part-02 §2.3 (d) vs `SKILL.md` Step 2 |
| `PR_REVIEW_MODE` unset | `local-diff` in sandboxed tiers (card (f)) | `pr` (today's unset default, `SKILL.md:73`) | D2.3 |
| Bus `DATA_DIR` | `RUN_HOME/<subtask>/bus/` | `/tmp/${SESSION_ID}` (`SKILL.md:135`; `/tmp` unwritable in executor tier, measurements) | part-03 §4 M12 |
| Step 9 `rm -rf` guard | the new `data_dir` prefix, literal path | `== /tmp/*` (`SKILL.md:345`) | catalog `bus` cleanup (A.5.1) |
| Orchestrator `agent_id` | fresh per reader and per read | one reused id (consumes unread state without `peek`) | C2 line 84 |
| Seat count | 7 | any smaller list while the flag is off | D12 |

## 8. Acceptance Criteria
- [ ] (a) Step 0 refuses a `ROLES` list of fewer than 7 seats with `INPUT-ERROR ROLES enum` while the D12 flag is off; `references/roles-subset.md` states the remap procedure (each omitted seat names the kept seat absorbing its R and A checks or marks them N/A to the synthesizer; Consulted lists and synthesizer expectations derived from the subset; computed before dispatch; hard gate timeout) and records that the 3-seat probe (dry run) found lost checks, so the flag stays off.
- [ ] (b) every orchestrator, gate-checker and synthesizer `read_messages` call carries `peek:true`.
- [ ] (c) each reader uses a fresh `agent_id`, reads topics in separate calls, `limit` 200.
- [ ] (d) `STACK_BASE`/`STACK_HEAD` (both 40-hex or both unset) switch the diff to `git diff <STACK_BASE>..<STACK_HEAD>`; one set without the other is `INPUT-ERROR STACK_HEAD missing` (or `STACK_BASE`).
- [ ] (e) every seat brief and the synthesizer brief open with the preamble "lint and typecheck out of scope, gates attached".
- [ ] (f) `PR_REVIEW_MODE` unset resolves to `local-diff` in sandboxed tiers; `pr` only when set explicitly. SPEC-QUESTION Q10-4: how a "sandboxed tier" is detected is not defined in the design or INTERFACES; use the explicit-set rule above and do not invent a detector.
- [ ] Record: lines 1-2 of `record-<head>.md` match the A.6 regexes; `Verified-By:` still never written by this skill.
- [ ] Port guard, in A.5.2 order: Step 1 claims the bus port with `tools/port-check.sh --claim ... claimed` (through `port-claim`) BEFORE the bind, registers `port`, `pm2-app`, `bus`, `tmpdir` rows with `catalog.sh` (`planned`), launches, then `catalog.sh start`; exit 1 or 2 refuses the launch with no auto-pick and a report to the lead; exit 3 is stop-the-line. Q10-5: A.5.2 needs `<run-id>`/`<subtask>` for `project`/`source`; when `RUN_HOME` is unset (standalone use) the spec keeps today's flow and says so; the integrator confirms. Q10-7: today the bus server resolves its own port with `get-port` and the skill reads `$DATA_DIR/port` after launch, which cannot be claimed before bind; passing a pre-claimed port to the server is not specified in the design or AM-1, so the integrator chooses the mechanism. Bus `data_dir` moves per §7. No hardcoded port.
- [ ] Security seat brief: loads `security-audit` in guidance mode for `pr-check-5`, diff-scoped; brief states no output directory, no files, no agent launch (depth 2 has no Agent tool), no target-code execution; `SECURITY_AUDIT=full` only adds the read-only read of the latest `findings.json`; the full audit itself is the caller's separate invocation, never this seat's. `SECURITY_AUDIT` other than the two values is `INPUT-ERROR SECURITY_AUDIT enum`.
- [ ] `version:` present; anatomy sections `## Trigger`, `## Steps`, `## Red flags`, `## Exit criteria`, `## Provenance` still present; provenance line appended for this EXTEND. Q10-3: the baseline `version:` value and bump rule are not specified; the integrator sets them.

## 9. Verification Commands
```bash
cd ~/projects/agent-hq-worktrees/delivery-w0   # on the EXTEND branch
S=skills/pr-review
grep -c 'INPUT-ERROR ROLES enum' $S/SKILL.md $S/references/roles-subset.md | grep -v ':0' >/dev/null && echo OK-a
test -f $S/references/roles-subset.md && grep -q -i 'no lost checks' $S/references/roles-subset.md && echo OK-a2
# (b)(c): every read_messages invocation outside seat briefs has peek and limit
for f in $S/SKILL.md $S/references/synthesizer-brief.md $S/references/bus-schema.md; do grep -n 'read_messages' $f; done   # human-read: each hit's example has peek:true and limit 200
grep -rn 'peek' $S | grep -c . ; grep -rn 'limit.*200' $S | grep -c .   # both >= 3
grep -q 'STACK_BASE\.\.' $S/SKILL.md && grep -q 'STACK_HEAD' $S/SKILL.md && echo OK-d
grep -c 'lint and typecheck out of scope, gates attached' $S/references/agent-briefs.md $S/references/synthesizer-brief.md  # >= 7 and >= 1
grep -n 'PR_REVIEW_MODE' $S/SKILL.md | grep -q 'local-diff' && echo OK-f
grep -q 'port-check.sh' $S/SKILL.md && grep -q -- '--claim' $S/SKILL.md && ! grep -n 'DATA_DIR="/tmp' $S/SKILL.md && echo OK-port
grep -q 'security-audit' $S/references/agent-briefs.md && grep -q -i 'guidance mode' $S/references/agent-briefs.md && grep -q 'INPUT-ERROR SECURITY_AUDIT enum' $S/SKILL.md && echo OK-sec
grep -n -E 'CODE-GATE-REVIEW: (PASS|FAIL) head=|Reviewed-By: ' $S/SKILL.md          # three-field Reviewed-By per A.6
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$h" $S/SKILL.md || echo MISSING $h; done
head -12 $S/SKILL.md | grep -E '^version:'
wc -l $S/SKILL.md                                  # stays under 500
grep -rn -E '/Users/[a-z]+|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|Notion' $S   # must print nothing
bash tools/check-doc-length.sh . ; git diff --stat -- . ':!skills/pr-review'   # second: empty (disjoint scope)
```
Review-time check (not machine): the enabling flag name and carrier (Q10-6: D12 flag is named in the card but its name, location and value are not defined anywhere; the integrator names it in `roles-subset.md`; do not invent it in `SKILL.md` prose beyond "the D12 flag").

## 10. Branch and worktree
Separate EXTEND branch (Q10-1), a worktree of its own under `~/projects/agent-hq-worktrees/`; the author does not git add, commit, rebase or push (build-common). Items 10-13 share this branch but write disjoint directories.

## 11. Decision Gate Reminder
If you meet any of the following, write `.decisions/10-pr-review.md` and stop: the D12 flag name or carrier is needed in executable text; a "sandboxed tier" detector is needed; the AM-1 anchors differ from §2; a change would enable any roster smaller than 7; `security-audit` would need an edit; `/tmp` is the only writable bus path. Never reword a stop condition.
