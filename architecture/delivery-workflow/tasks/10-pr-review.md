# Task Spec: 10-pr-review (EXTEND `pr-review`: items b-f live, (a) `ROLES` behind the D12 flag, port guard, security-audit guidance load)

- Work item: 10 (design part-06 §7 row 9-13; card: part-02 §2.3 `pr-review` row). Tier: `execute` (part-06 §7 tier column; Sonnet-class via `tools/model-routing.md`, never pinned in skill text, M19).
- Review rung: Rung 1 trio (`doc-reviewer`, separate fixer, `fix-verifier` with `FILE_SET` = the files in §3 In scope), run by the UNMODIFIED installed skills (M29), max 3 rounds then the owner (D7). Prose skill; no script, so no code gate.
- Branch: the separate EXTEND branch (M29). RESOLVED (PC-1, plan-check): branch `ext/delivery-extends` in worktree `~/projects/agent-hq-worktrees/delivery-extends`, created by the integrator (Worker1) from `wt/delivery-w0` after the plan-check commit (so it holds the W0 item 8 ports); items 9-13 share it on directory-disjoint paths; the branch is reviewed separately and never used to review the family (M29).
- Dependencies: INTERFACES 1.1.0 (amendment AM-1, landed: port guard A.5.2, `security-audit` A.5.3, D2.1 `security_audit`, D2.3 `pr-review` row); `tools/port-check.sh` and `tools/ports.tsv` present on the EXTEND branch base (port-guard PR #9, branch `wt/port-guard`); `skills/security-audit/` present (it is); `skills/port-claim/` (item 8). No dependency on items 11-13 (directory-disjoint).
- Split: none (one agent, one integration pass by the author).

## 1. Objective
Edit `skills/pr-review/` so the six EXTEND changes (a)-(f) of the card, the port-guard bus start and the security seat's guidance-mode `security-audit` load are in place, with `ROLES` subsets refused while the D12 flag is off.

**Done condition (one, machine-checkable):** the §9 block exits 0 and its last stdout line is `EXT-10-OK`.

## 2. Context Package
- Card: part-02 §2.3 row `pr-review` (a)-(f); sources `pr-review-local-diff-bus-facts`, `pr-review-orch-reads-closed`, A4. (a) is gated by the D12 probe; (b)-(f) are bug fixes.
- D12 (part-01 item 13): subsets smaller than 7 only after a RACI remap and a 3-seat probe show no lost checks; until then every `pr-review` runs 7 seats.
- Probe result (measurements-2026-10-26.md, Item 4 (B), dry run, 35 subsets of `references/agent-roles.md`): NO 3-subset keeps a Responsible seat for all 10 checks (fewest lost: 4 checks, 5 subsets; every subset also loses at least 1 Accountable closer). Best subset: `devops-engineer`, `integration-architect`, `platform-engineer`, losing R for checks 5, 7, 8, 9 and the closer for check 8. A real bus was NOT run (pm2 EPERM, no bus `node_modules`, `/tmp` unwritable). Consequence for this item: the flag ships OFF and stays off until a RACI remap exists and a bus probe records no lost checks; this item writes the remap procedure and the refusal, never the enabling.
- Depth: seats run at depth 2 and have no Agent tool (part-03 §3.1; measurements Item 4 (A)), so a seat that loads `security-audit` can only run guidance mode WITHOUT launching focused agents.
- Port guard (AM-1, `interfaces/part-a-state.md` A.5.2; scope names "`pr-review`'s per-review bus"): order before launch (1) `tools/port-check.sh --claim <port> <bind> <container_port> <service> <project> claimed <source> <note>` through `port-claim`, `project` = `<run-id>`, `source` = `<run-id>-<subtask>`; (2) `catalog.sh register port <port> ...` (`planned`); (3) launch; (4) `catalog.sh start`. Exit 1 or 2 refuses the launch, never auto-picks; exactly one retry at candidate + 10, claimed before bind, the bus pinned to the retry port; a second refusal stops the line and is reported to the lead (INTERFACES 1.3.0 AM-3 / owner OQ-2; also standalone); exit 3 is stop-the-line. Release is cleanup only. The PreToolUse hook `tools/hooks/port-precheck.sh` is advisory and catches launches outside this path.
- security-audit (AM-1; D2.3 `pr-review` row, D2.1 `security_audit`, A.4 line 217, A.5.3): input `SECURITY_AUDIT` `guidance|full`, default `guidance`; the security seat loads `skills/security-audit` in guidance mode, diff-scoped, writes no file and launches no agent; under `full` the seat also reads the latest `RUN_HOME/<subtask>/security-audit/run-<N>/findings.json` (`DEFAULT (integrator)`), read-only. Full-mode agents are counted by the caller in the slot ledger (persona `security-auditor`), never by this skill.
- Namespacing (part-03 §4, M12): bus `data_dir` sits under `RUN_HOME/<subtask>/bus/`, never `$TMPDIR` or `/tmp`; pm2 app name carries `<run-id>-<subtask>`; `pm2 jlist` checked before start.
- Existing state: `SKILL.md` 404 lines; local-diff mode exists (lines 87-100) and seat briefs already use `peek:true` (`references/agent-briefs.md:90,143`); orchestrator, gate-checker and synthesizer reads (`SKILL.md` Steps 5, 7, 8; `references/synthesizer-brief.md:24-31`) do not.

## 3. Scope
**In scope (directory `skills/pr-review/` only):**
- `SKILL.md`: `version: 1.1.0` (RESOLVED, PC-1: the unversioned base at `c1ba30e` or the item 8 port counts as 1.0.0; an EXTEND is a minor bump); Step 0 input validation (D1: one `INPUT-ERROR <field> <reason>` line per failing field, then stop) for `ROLES`, `SECURITY_AUDIT`, `PR_REVIEW_MODE`, `STACK_BASE`, `STACK_HEAD`, `RECORD_PATH`, `BUS_PORT` (RESOLVED Q10-7); Steps 1, 2, 4-9 edits below. Body stays under about 5k tokens: move new prose into `references/`.
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
- [ ] (f) `PR_REVIEW_MODE` unset resolves to `local-diff` in sandboxed tiers; `pr` only when set explicitly. RESOLVED Q10-4 (PLAN-CHECK DEFAULT; D2.3 "`local-diff` (default in sandboxed tiers)"): every delivery session is sandboxed (OP4, ADR 0053), so unset always resolves to `local-diff`; no tier detector; `pr` only when set explicitly.
- [ ] Record: lines 1-2 of `record-<head>.md` match the A.6 regexes; `Verified-By:` still never written by this skill.
- [ ] Port guard, in A.5.2 order: Step 1 claims the bus port with `tools/port-check.sh --claim ... claimed` (through `port-claim`) BEFORE the bind, registers `port`, `pm2-app`, `bus`, `tmpdir` rows with `catalog.sh` (`planned`), launches, then `catalog.sh start`; exit 1 or 2 refuses the launch with no auto-pick, then exactly one claimed retry at `BUS_PORT + 10` before the bind, and a second refusal stops the line with a report to the lead; exit 3 is stop-the-line. RESOLVED Q10-5 (A.5.2 scope "every port a run binds"; PLAN-CHECK DEFAULT): with `RUN_HOME` unset (standalone use outside a run) Step 1 keeps today's flow unchanged and says so; inside a run the A.5.2 order applies and the bus `data_dir` is `RUN_HOME/<subtask>/bus/`. RESOLVED Q10-7 (PC-4; AM-2 rows 6-7): new input `BUS_PORT` (int, 1-65535), required inside a run (`INPUT-ERROR BUS_PORT missing`), absent standalone; `pre-pr-gate` passes the dispatch-plan port table `review-bus` candidate. Step 1 claims it (`port-check.sh --claim <BUS_PORT> ... claimed`), registers the `port`, `pm2-app`, `bus`, `tmpdir` rows (`planned`), starts the server with `PORT_RANGE_START=<BUS_PORT> PORT_RANGE_END=<BUS_PORT>` so `get-port` cannot choose another port, checks `$DATA_DIR/port` equals `BUS_PORT` (else stop and report), then `catalog.sh start`. RESOLVED (INTERFACES 1.3.0 AM-3 / owner OQ-2, D2.3 `BUS_PORT`; overrides the earlier "never re-picked" reading): on a refusal Step 1 makes exactly one retry at `BUS_PORT + 10`, itself claimed with `port-check.sh --claim` before the bind, and pins the bus to that port (`PORT_RANGE_START=PORT_RANGE_END=<BUS_PORT+10>`); a second refusal stops the line and is reported. The same one-retry rule applies standalone (the R-x "+10 and re-check" is done exactly once). No hardcoded port.
- [ ] Security seat brief: loads `security-audit` in guidance mode for `pr-check-5`, diff-scoped; brief states no output directory, no files, no agent launch (depth 2 has no Agent tool), no target-code execution; `SECURITY_AUDIT=full` only adds the read-only read of the latest `findings.json`; the full audit itself is the caller's separate invocation, never this seat's. `SECURITY_AUDIT` other than the two values is `INPUT-ERROR SECURITY_AUDIT enum`.
- [ ] `version:` present; anatomy sections `## Trigger`, `## Steps`, `## Red flags`, `## Exit criteria`, `## Provenance` still present; provenance line appended for this EXTEND. RESOLVED Q10-3 (PC-1): `version: 1.1.0`.

## 9. Verification Commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-extends; cd "$W"; B=$(git merge-base HEAD wt/delivery-w0); S=skills/pr-review
grep -q 'INPUT-ERROR ROLES enum' $S/SKILL.md $S/references/roles-subset.md
grep -qi 'no lost checks' $S/references/roles-subset.md
test "$(grep -rn 'peek' $S | grep -c .)" -ge 3; test "$(grep -rnE 'limit.*200' $S | grep -c .)" -ge 3
grep -q 'STACK_BASE\.\.' $S/SKILL.md; grep -q 'STACK_HEAD' $S/SKILL.md
test "$(grep -c 'lint and typecheck out of scope, gates attached' $S/references/agent-briefs.md)" -ge 7
grep -q 'lint and typecheck out of scope, gates attached' $S/references/synthesizer-brief.md
grep -n 'PR_REVIEW_MODE' $S/SKILL.md | grep -q 'local-diff'
for t in 'port-check.sh' '--claim' 'BUS_PORT' 'PORT_RANGE_END' 'INPUT-ERROR BUS_PORT missing'; do grep -rqF -- "$t" $S/SKILL.md $S/references || { echo "MISSING $t"; exit 1; }; done
grep -q 'security-audit' $S/references/agent-briefs.md; grep -qi 'guidance mode' $S/references/agent-briefs.md
grep -q 'INPUT-ERROR SECURITY_AUDIT enum' $S/SKILL.md
grep -qE 'Reviewed-By: ' $S/SKILL.md
test "$(wc -l < $S/SKILL.md)" -lt 500
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$h" $S/SKILL.md || { echo "MISSING $h"; exit 1; }; done
head -12 $S/SKILL.md | grep -qE '^version: 1\.1\.0$'
bash tools/check-doc-length.sh . >/dev/null
if grep -rnE '/Users/xavier|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|Notion' $S; then echo "FAIL: forbidden match"; exit 1; fi
if git status --porcelain | grep -vE '^.. (skills/(wave-execution|pr-review|fix-verifier|doc-reviewer|feature-change)/|architecture/wave-execution\.md)'; then echo "FAIL: change outside the EXTEND scopes"; exit 1; fi
echo EXT-10-OK
```
Review-time check (not machine): each `read_messages` example in `SKILL.md`, `synthesizer-brief.md` and `bus-schema.md` has `peek:true`, a fresh `agent_id` and `limit 200`; the three-field `Reviewed-By` matches A.6. RESOLVED Q10-6 (INTERFACES D2.3 `pr-review` row: "seat count 7 until the D12 remap and probe are recorded here"): there is no flag variable; that D2.3 row is the carrier. In this version the refusal of fewer than 7 seats is unconditional; enabling a subset is an INTERFACES amendment plus a skill change, never a switch, and `roles-subset.md` says so and names no flag.

## 10. Branch and worktree
Branch `ext/delivery-extends`, worktree `~/projects/agent-hq-worktrees/delivery-extends` (PC-1); the author does not git add, commit, rebase or push (build-common). Items 10-13 share this branch but write disjoint directories.

## 11. Decision Gate Reminder
If you meet any of the following, write `.decisions/10-pr-review.md` and stop: the D12 flag name or carrier is needed in executable text; a "sandboxed tier" detector is needed; the AM-1 anchors differ from §2; a change would enable any roster smaller than 7; `security-audit` would need an edit; `/tmp` is the only writable bus path. Never reword a stop condition.
