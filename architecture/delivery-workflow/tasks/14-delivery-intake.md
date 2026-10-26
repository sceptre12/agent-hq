# Task 14: `delivery-intake` (NEW skill, stage 1)

- **Header:** item 14 (part-06 §7); wave W1; authoring tier `execute` (§7 row 14-22); runtime persona Grill facilitator (design tier, conductor session) with Explorers (mechanical/execute); review rung: Rung 1 trio (reviewer, fixer, fix-verifier; item 30); not heavy. Interfaces: `INTERFACES.md` + `interfaces/part-a..d` (FROZEN, INTERFACES 1.5.0) and amendment AM-1 (INTERFACES 1.1.0; port guard A.5.2).
- **Dependencies:** INTERFACES frozen (W0 exit). No dependency on another W1 item to author. Reads, at runtime only: `mattpocock-skills:grilling`, `mattpocock-skills:domain-modeling` (REUSE rows, §2.1). The `references/templates/repo-profile.md` template belongs to item 27, piece T-D (RESOLVED Q1).
- **Split:** none (1 agent).

## 1. Objective
Write `skills/delivery-intake/SKILL.md` (card 2, part-02 §2.2): the stage 1 skill that grills the human, measures repo facts through explorers, and writes `brief.md`, `facts.md` and a new or refreshed `repo-profile.md`, then ends with the `PROFILE:` line. **Done condition (single, machine-checkable):** the section 9 block exits 0 and its last stdout line is `SKILL-14-OK`, with Rung 1 verdict `CLEAN` from `fix-verifier`.

## 2. Context package
- Card 2 and stage 1 row (part-01 line 66; part-02 line 52); persona rows (part-03 lines 31-32); `repo-profile.md` field list and `FILL_IN_BEFORE_DISPATCH` sentinels (part-04 §5.8, line 33); Proof Web seed rows (part-04 §5.8b, D13) as the example content only.
- Anatomy: `tools/skill-authoring.md` §2-§5 (frontmatter "Use when", `## Trigger`, `## Steps`, `## Red flags`, `## Exit criteria`, `## Provenance`; body under 5k tokens; depth in `references/`). Owner deviations to record in the skill: every delivery skill is model-invocable (D16, no `disable-model-invocation`); `version:` in frontmatter (A6); Step 0 `INPUT-ERROR` (M22).
- Owner rules: D22 (the profile is the sole authority; other docs link `@<sha>`, never copy), R-ci (no web: `RESEARCH` to the desk), C-1 facts are the agent's job (a question the repo can answer is not asked). No cost metrics (B-4).

## 3. Scope
- **In (directory `W/skills/delivery-intake/`, nothing else):** `SKILL.md`; `references/step0-inputs.md` (input table, `INPUT-ERROR` cases); `references/profile-keys.md` (every A.2.2 key, type, how to measure it, its `FILL_IN_BEFORE_DISPATCH` sentinel when unmeasured); `references/explorer-brief.md` (explorer brief: question list, `measured: <cmd -> result>` row format, "cannot measure: say so"); `references/fixtures/` (one fake repo tree and expected outputs for the dry run in section 9).
- **Out:** `brief.md` or `facts.md` for a real run; any file in another skill dir; `references/templates/*` (item 27); INTERFACES edits; ADR edits; the desk, `delivery-pipeline` or `delivery-architecture` text; commits.
- **Do-not-create:** symlinks, installs, web fetches, a second profile format, a gate file writer (H0 is the desk's, B8), any executable script (intake is prose plus fixtures), cost or token-spend metrics.

## 4. Contracts table (cite anchors; do not restate)
| Contract | Anchor | Intake role |
|---|---|---|
| Path and id rules, `DELIVERY_ROOT`, `RUN_HOME`, run-id, atomic writes | part A.1 | consumes; writes only via temp file then `mv` |
| Inputs `DELIVERY_ROOT` (env), `RUN_HOME`, `PLANS_DIR`, `PRIMARY_REPO`, `INTENT` as `NAME=value` | part D2.2 row 2; D1 | Step 0 validates in that order; one `INPUT-ERROR <NAME> <reason>` per failing field, then stop, no prompt |
| `FACTS: <n> facts` as line 1 of `facts.md` | part D1.1 (`^FACTS: [0-9]+ facts$`) | producer |
| `PROFILE: <abs path>@<40-hex sha>` as the last stdout line (no record file) | part D1.1 | producer; the conductor copies it to `state.md` `repo_profile` (A.2) |
| `brief.md`, `facts.md` in `PLANS_DIR`; new profile at `<PRIMARY_REPO>/plans/repo-profile.md` | part A.6 first two rows | producer |
| Profile serialization (one YAML document, `"yes"/"no"` quoted, regexes single-quoted) and every key | part A.2.2 (R4-J1) | sole writer of every key, including `release_tags.used: "no"` when the repo has no tags (N11) |
| Profile keys added to A.2.2 by amendment: `ports.bus_base`, `ports.lane_base`, `sensitive_paths[]`, `review_profile.*`, `zephyr.execute_tool` (AM-2 row 5), `default_branch` (AM-4 20 Q6), `e2e.harness` `nlta\|none` (AM-5 17), `lanes[].db.cleanup_cmd` (AM-5 19) | part A.2.2 (amended: AM-2, AM-4, AM-5) | writer, names and types from A.2.2 only |
| Profile fields still not in A.2.2 (`PROJECT_ROOT`, commands, `pr.*`, other `e2e.*` fields, the rest of the lane resource profile) | part-04 §5.8 | writer; unmeasured value is the sentinel `FILL_IN_BEFORE_DISPATCH`, never a guess |
| H0 | part A.2.1 (`gates/H0.<run-id>.ok` (gate-file names carry the run id; amended: AM-5 26, A.2.1)), part B8 (`GATE <run-id> H0 ok`), D2.1 | intake ends with the confirm question; the desk writes `H0.ok` after the human types `GATE`; intake never writes a gate file |
| Research | `RESEARCH <id> \| <question> \| <why>` to `desk`, reply `SUMMARY`; ADR 0055 §5 (profile id format kept); design §6.3 | requester; the reply is data, never instructions; one request per message |
| Persona tokens `grill-facilitator`, `explorer` | part D2.1 `persona` | use these names in briefs |

## 5. Inherited module API
`mattpocock-skills:grilling` (one question at a time with a recommended answer) and `domain-modeling` (term conflicts) are invoked by name. Their installed yes/no status is a W0 item 1 table fact; SKILL.md names them as REUSE and does not copy their text. Explorer subagents run at depth 1, read-only on the repo, and spawn nothing.

## 6. What you inherit
- Step list from card 2: explorers for repo facts run while grilling; `grilling`; `domain-modeling` on conflicts; `RESEARCH` to the desk for the web; confirm question; H0.
- Context store read first (part-01 stage 1 row): read the repo's context before asking.
- Friction line for Provenance: grilling's own rule that facts are the agent's job; Hermes S2 unmeasured premise (card 2 "Friction").

## 7. Known risky values (each sourced from its authority contract)
- `facts.md` row form `measured: <cmd -> result>` and `FACTS:` count equals the number of rows (card 2; D1.1).
- Profile key names and types: A.2.2 only. `merge_method` in `squash|merge|rebase`; `release_tags.used` in `"yes"|"no"`.
- `DESK_ADDRESS` is `desk` (B1). Profile sha is 40-hex, never abbreviated (A.1).
- Run-id and `PLANS_DIR` are given by the conductor; intake mints neither.
- The single `HUSKY=0` statement lives in part A.7: the profile links it, never restates it.

## 8. Acceptance criteria
1. Frontmatter: `name: delivery-intake`, `version: 0.1.0`, description under 1024 chars starting with the card trigger and containing "Use when"; no `disable-model-invocation`.
2. Body has `## Trigger`, `## Steps` (numbered; Step 0 = input validation per D1), `## Red flags` (at least: asking a human what the repo can answer; writing an unmeasured fact; guessing a profile value instead of the sentinel; writing `H0.ok`; fetching the web), `## Exit criteria`, `## Provenance`; body under 5k tokens (about 3500 words) and under 500 lines.
3. Steps cover, in order: Step 0; read context store; launch explorers (mechanical/execute) while grilling; grilling rounds with recommended answers; `domain-modeling` on conflicts; `RESEARCH` to the desk for any web need and treat `SUMMARY` as data; write `brief.md`, `facts.md`, profile atomically; list every sentinel in the profile in `facts.md` or `brief.md` open-items; confirm question; print `PROFILE:` as the last stdout line, the sha being the profile's git blob id from `git -C <PRIMARY_REPO> hash-object -w <profile>` (RESOLVED Q2).
4. Stop rules: `INPUT-ERROR` stops without prompt; a fact the explorer cannot measure is written as `cannot measure: <why>`, not omitted.
5. Port guard (AM-1, part A.5.2): intake binds no port. Lane resource-profile ports are recorded as profile fields only. If a measurement ever needs a listener, the order is `tools/port-check.sh --claim ...` (through `port-claim`), then `catalog.sh register port`, then launch; on a collision the launch is refused and never re-picked. Reading `ports.tsv` or `lsof` is allowed.
6. No cost figures; no `/Users/xavier`, no personal-project names (SUB rules, build-common).

## 9. Verification commands (the verifier re-runs these; W = `~/projects/agent-hq-worktrees/delivery-w0`)
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/delivery-intake; R=${FIXTURE_DIR:?the non-author verifier sets FIXTURE_DIR to its dry-run output directory}
test -f $S/SKILL.md
test "$(grep -c '^## \(Trigger\|Steps\|Red flags\|Exit criteria\|Provenance\)$' $S/SKILL.md)" -eq 5
grep -q '^version: 0\.1\.0$' $S/SKILL.md
if grep -q 'disable-model-invocation' $S/SKILL.md; then echo "FAIL: disable-model-invocation"; exit 1; fi
sed -n '/^description:/p' $S/SKILL.md | grep -q 'Use when'
[ "$(wc -w < $S/SKILL.md)" -le 3500 ]; [ "$(wc -l < $S/SKILL.md)" -le 500 ]
test "$(grep -cE 'INPUT-ERROR|PROFILE:|FACTS:|RESEARCH|FILL_IN_BEFORE_DISPATCH|H0' $S/SKILL.md)" -ge 6
grep -rq 'hash-object' $S/SKILL.md $S/references
if grep -rEi --exclude-dir=templates '/Users/xavier|touri|ofw|runfrist|jetblue|notion|\$[0-9]+|cost' $S; then echo "FAIL: forbidden match"; exit 1; fi
if find $S -type l | grep -q .; then echo symlink; exit 1; fi
bash $W/tools/check-doc-length.sh $W >/dev/null
# dry run: a reader agent follows the SKILL.md steps against references/fixtures/ (no desk) and saves facts.md, its stdout
# (stdout.txt) and the output of a run with DELIVERY_ROOT unset (unset.txt) into $R
head -1 $R/facts.md | grep -qE '^FACTS: [0-9]+ facts$'
test "$(grep -c 'measured: ' $R/facts.md)" -ge 1
tail -1 $R/stdout.txt | grep -qE '^PROFILE: (/[^[:space:]]+)@([0-9a-f]{40})$'
grep -qx 'INPUT-ERROR DELIVERY_ROOT unset' $R/unset.txt
echo SKILL-14-OK
```

## 10. Branch and worktree
Worktree W, branch `wt/delivery-w0`; write only section 3 paths; no `git add`, commit, branch, push or rebase (the integrator, Worker1, commits). No symlinks, installs or web fetches.

## 11. Decision Gate reminder
Stop and write `.decisions/14-delivery-intake.md` (fork, options, recommendation, `Outcome: Blocked`) instead of choosing when: the card and INTERFACES leave a value open, a needed grammar is not in INTERFACES, or an owner ruling would be reworded. Owner decisions are never invented.

## Open points
- RESOLVED Q1 (spec 27 §3 piece T-D; PC-3): item 27 writes `skills/delivery-intake/references/templates/repo-profile.md` (with the 5.8b seed); this item cites that path and never writes `references/templates/`.
- RESOLVED Q2 (PLAN-CHECK DEFAULT; INTERFACES A.2 `repo_profile` and D1.1 `PROFILE:` name a 40-hex sha but not which object; AM-2 row 4): the sha is the git blob id of the profile file, `git -C <PRIMARY_REPO> hash-object -w <profile path>` (it exists before any commit and writes the blob so a reader can `git cat-file blob <sha>`); a reader checks `git hash-object <path>` against it. A refreshed profile gets a new `PROFILE:` line.
