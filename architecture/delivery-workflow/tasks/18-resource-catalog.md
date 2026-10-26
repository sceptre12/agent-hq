# Task Spec: T18 `resource-catalog` (W1 item 18, stage 4 and all)

> Written 2026-10-26 (W0 item 2b) from design card 8 (`part-02-skill-inventory.md` §2.2), `part-04` §5.6, INTERFACES `1.1.0` (FROZEN; amendment AM-1 landed: A.5.1 `port` row, new A.5.2 port claims), `skills/port-claim/SKILL.md`, `reviews/pr9-port-guard-pr-review.md`.
> Author: one execute-tier agent, about 1 h. Not split, no integration step. Reviewer path: Rung 1 trio, at most 3 rounds, then the owner (D7). The script it wraps (`catalog.sh`, item 5) has its own code gate (PR, `pr-review` 7 seats, mapped tests) and is NOT in this item.

**Done condition (one, machine-checkable):** the command block in section 9 exits 0 and its last stdout line is `SKILL-18-OK`.
**Tier:** execute. **Rung:** 1 for the SKILL.md prose.
**Depends on:** INTERFACES 1.1.0 (done); item 5 (`catalog.sh`, only for the real path and argument list; no runtime dependency in the checks); item 8 (`port-claim` ported, present at `skills/port-claim`).

## 1. Objective
Write the skill `resource-catalog`: the rules for registering, starting, releasing, keeping and auditing every resource a delivery run creates through `catalog.sh`, including the port rows the port guard adds (A.5.2): a `port-check.sh` check and `--claim` before any launch, a catalog `port` row `planned` then `live`, and a `released` claim plus catalog `released` at cleanup.

## 2. Context package
- Card 8: Trigger "Use before and after starting any worktree, branch, process, port, bus, temp dir, container, lease, cron or background task in a run." In: `kind`, `handle`, `unit`, `correlation_id`. Out: one append-only TSV row. Rules: `register` before start (`planned`), `start` after, `released` supersedes; rows hold kind plus handle only, the cleanup command comes from a fixed per-kind table inside the script (M26); handle realpath under `RUN_HOME` or the registered worktree base; control characters rejected; 400-byte row cap; only the script appends. Ports via `port-claim` and the +10 rule with `lsof` (measured). Stop: unregistered resource found (register, flag, never kill by pattern).
- Catalog: `part-04` §5.6; INTERFACES A.5 (columns, handle grammar, lifecycle, leases), A.5.1 (per-kind table), Script interfaces table (`catalog.sh` call, stdout, exit codes 0/2/3/4).
- Port guard (AM-1, INTERFACES A.5.2 is the single statement; agent-hq PR #9, reviewed in `reviews/pr9-port-guard-pr-review.md`): `tools/port-check.sh` exit codes 0 free, 1 taken, 2 registry and `lsof` disagree, 3 usage or unusable registry; `--claim` takes 8 positional fields and re-runs the check first; the registry is append-only and a stale row is superseded by a `released` row of the same port and source; the PreToolUse hook `tools/hooks/port-precheck.sh` is advisory (asks the human, always exit 0) and catches launches outside this path.

## 3. Scope
**In (write only under `skills/resource-catalog/`):**
- `SKILL.md` (body under 5k tokens): frontmatter (`name`, "Use when" description of 1024 characters or fewer, `version: 0.1.0`), `## Trigger`, `## Steps` (Step 0 first), `## Red flags`, `## Exit criteria`, `## Provenance`.
- `references/kinds-and-handles.md` (one line per catalog `kind`: handle form, register/start/release example; points to A.5 and A.5.1 for the table, no restatement of cleanup commands).
- `references/ports.md` (the port rows in A.5.2 order: candidate from the dispatch-plan port table, claim, register, launch, start; release; failure branches by `port-check.sh` exit code; the "+10 rule" as the plan-time candidate formula plus exactly one claimed retry at candidate + 10 after a refusal, then stop the line, RESOLVED Q4).
- `skills/port-claim/SKILL.md` (amend only, RESOLVED Q2): Steps 3-4 reordered to A.5.2: `--claim ... claimed` before the bind, then the bind; on a failed bind a `released` row of the same port and source; Exit criteria and Provenance lines updated ("amended 2026-10-26, AM-1 A.5.2: claim before bind"); "Do not auto-pick" kept verbatim; the one claimed +10 retry after a refusal, then stop (INTERFACES 1.3.0 AM-3 / owner OQ-2), added to Step 1, the Red flags row, Exit criteria and Provenance. No other `port-claim` text changes.

**Out:** `tools/delivery/**` (`catalog.sh` and its tests, item 5), `skills/resource-catalog/references/templates/` (item 27), `skills/port-claim/` files other than `SKILL.md`, `skills/delivery-cleanup/**`, INTERFACES, any ADR, `ports.tsv`.
**Do NOT create:** a copy of `catalog.sh`, a symlink, a cleanup-command table (the script owns it, M26), a column or kind not in A.5, a hand edit of `RUN_HOME/catalog.tsv` or `tools/ports.tsv`, cost metrics.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| Transport | `RUN_HOME` is the environment variable (the named exception to `NAME=value`), then `catalog.sh` positional arguments; unset `RUN_HOME` is exit 2; `DELIVERY_ROOT` unset is `INPUT-ERROR DELIVERY_ROOT unset` | D2.2 row 8, preamble; Script interfaces table; A.1 |
| Call forms | `register <kind> <handle> <unit\|-> <correlation_id> <source> <subtask\|run> <owner_agent>`; `start\|release\|fail <kind> <handle>`; `keep <kind> <handle> <reason>`; `list --live [--subtask <st>]`; `audit` | Script interfaces table |
| Output | stdout is the `row_id` (register/start/release/keep/fail), TSV rows (`list`), `MATCH`/`GHOST`/`SQUATTER` lines (`audit`) | same |
| Exit codes | 0 ok; 2 usage or rejected row; 3 lane-lease held; 4 lock timeout (1 s retry, 60 s) | same; R4-J10 |
| Row limits | 12 tab fields; control characters rejected; 400 bytes; path-kind handle realpath under `RUN_HOME` or `worktree_base`; only `catalog.sh` appends | A.5 |
| Kinds | `worktree branch tag process pm2-app port bus tmpdir container image lane-lease db clone cron bgtask file workspace`; states `planned live released failed kept` | A.5 |
| Handles | `port` an int; `worktree` `<abs-path>#<repo>@<base>`; `branch`/`tag` `<repo>#<ref>@<base>`; `lane-lease` `gate-runner/<n>` or `lane/<name>`; others per A.5 | A.5 handle grammar |
| Supersede key | `kind` + `handle`, latest row wins | A.5 |
| Lease | `lane-lease` register writes `live` directly; exit 3 when the latest row is `planned` or `live` | A.5 |
| `unit` column | `^([ui][0-9]+\|-)$` | A.5 col 9 |
| Port order | (1) `port-check.sh --claim <port> <bind> <container_port> <service> <project> claimed <source> <note>` through `port-claim`, `project` = `<run-id>`, `source` = `<run-id>-<subtask>`; (2) `catalog.sh register port <port> ...` (`planned`); (3) the launch; (4) `catalog.sh start port <port>` (`live`) | A.5.2 |
| Port collision | exit 1 or 2 refuses the launch, never auto-pick; exactly one retry at candidate + 10, claimed before bind; a second refusal stops the line and is reported to the lead (a lane maps to C2 `lane-unavailable`); exit 3 is stop-the-line | A.5.2 (AM-3, OQ-2); C1.1 lane lease row; C2 |
| `port` kind | verify `lsof -nP -iTCP:<port> -sTCP:LISTEN`; release only after the listener is stopped: `port-check.sh --claim <port> <bind> <container_port> <service> <project> released <source> <note>` (same `port` and `source`), then `catalog.sh release`; the release itself is run by cleanup | A.5.1 `port` row; A.5.2 |
| Audit | classes `MATCH GHOST SQUATTER` against `kill -0`, `lsof`, `git worktree list` | A.5, Script interfaces |

## 5. Inherited module API
- `catalog.sh` (item 5, `tools/delivery/catalog.sh`): the only appender. The skill calls it, never reimplements it.
- `tools/port-check.sh` (port guard): `<port>` check; `--claim <port> <bind> <container_port> <service> <project> <status> <source> <note>` (status in `live claimed reserved unmerged released UNVERIFIED`); `--audit`. Use through `skills/port-claim` rules, do not copy them.
- `lsof`, `kill -0`, `git worktree list` for liveness; no `ps`/`pgrep` (blocked in some sessions, measured).

## 6. What you inherit
| Thing | Source | Note |
|---|---|---|
| Worktree | `~/projects/agent-hq-worktrees/delivery-w0`, branch `wt/delivery-w0` | write only your paths |
| Standards | `STANDARDS.md`, `tools/skill-authoring.md`, `tools/check-doc-length.sh` | |
| SUB rules | build-common (paths to `$HOME`, "the owner", no personal-project text) | |
| Register | `skills/port-claim/SKILL.md` is the installed text of the port rules | cite by name |

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| `register` arguments | 7 after `register` | the older 5-argument form | Script interfaces table (r1e V6) |
| Run input | env `RUN_HOME` | `RUN_HOME=<path>` argument | D2.2 row 8 |
| Row owner of cleanup | the per-kind table inside the script | a command in a row or in the skill | M26 |
| Port release | a `released` registry row (same port and same source) plus a catalog `released` row | editing `ports.tsv`, `kill` by port | `skills/port-claim` red flags |
| Port exit 2 | hard stop for the candidate; one claimed retry at candidate + 10, then stop and report | warning; an unclaimed or second retry | `skills/port-claim` Steps 1; A.5.2 (AM-3) |
| `unit` for run-level rows | `-` | empty | A.5 col 9 |
| Stale row | superseded by a later row | deleted or edited | A.5, port-claim |

## 8. Acceptance criteria
- [ ] SKILL.md has the five required sections and a Step 0 that fails with `INPUT-ERROR` on unset `DELIVERY_ROOT` or `RUN_HOME`.
- [ ] Steps cover `register` before start, `start` after, `released` supersedes, `keep` with reason (D8 flag), `fail`, `list --live`, `audit` and the three audit classes; the exit codes are named with the action for each.
- [ ] The port rows follow A.5.2 order exactly: `port-check.sh <port>` and `--claim ... claimed` before the launch, then `catalog.sh register port <port> ...` (`planned`), the launch, `catalog.sh start port <port>` (`live`); exit 1 or 2 refuses (never auto-picked; exactly one claimed retry at candidate + 10, a second refusal stops the line and is reported), exit 3 is stop-the-line; release (cleanup only) pairs the `released` claim with `catalog.sh release`; the PreToolUse hook is described as advisory and not a substitute for the claim.
- [ ] Rule text for the stop row: an unregistered resource found is registered, flagged, and never killed by pattern; cleanup acts only on catalog rows (D9).
- [ ] Every example line that calls `catalog.sh register` has exactly 7 arguments after `register` (code-block lines, checked in section 9).
- [ ] The skill states that it never writes a command into a row and never touches `RUN_HOME/catalog.tsv` or `tools/ports.tsv` directly.
- [ ] Provenance cites the cleanup facts C1, C6, C7 and the port-registry collision incident (2026-09-04, via `skills/port-claim`).

## 9. Verification commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/resource-catalog; F=$S/SKILL.md
test -f "$F"; head -1 "$F" | grep -qx -- '---'
grep -qE '^name: resource-catalog$' "$F"; grep -qE '^version: ' "$F"
d=$(grep -E '^description:' "$F"); [ "${#d}" -le 1040 ]; printf '%s' "$d" | grep -q 'Use when'
if grep -q 'disable-model-invocation' "$F"; then echo "FAIL: forbidden match"; exit 1; fi
for h in Trigger Steps 'Red flags' 'Exit criteria' Provenance; do grep -qE "^## $h" "$F"; done
[ "$(wc -c < "$F")" -le 20000 ]; [ "$(wc -l < "$F")" -le 500 ]
for t in RUN_HOME INPUT-ERROR 'catalog.sh' register start release keep audit MATCH GHOST SQUATTER 'list --live' \
  'port-check.sh' '--claim' lsof 'kind' realpath 400 'planned' 'D9' 'A.5.2'; do
  grep -rqF -- "$t" "$S" || { echo "missing: $t"; exit 1; }; done
# every catalog.sh register example has 7 arguments after "register"
grep -rhE '^[[:space:]]*(\$ )?[^ ]*catalog\.sh register ' "$S" | while IFS= read -r l; do
  set -- ${l#*catalog.sh register }; [ "$#" -eq 7 ] || { echo "bad arg count ($#): $l"; exit 1; }; done
# port rows present in A.5.2 order (first mentions in ports.md): claim, register, start
awk '/--claim/ && !c{c=NR} /register port/ && !b{b=NR} /start port/ && !d{d=NR}
  END{exit !(c&&b&&d&&c<b&&b<d)}' "$S/references/ports.md"
for t in 'port-check.sh' claimed released never port-precheck 'A.5.2' lane-unavailable; do grep -qF -- "$t" "$S/references/ports.md" || { echo "ports.md missing: $t"; exit 1; }; done
if grep -rniE --exclude-dir=templates 'notion|touri|ofw|runfrist|jetblue|/Users/xavier|brain(Alpha|Beta|Gamma)|hermesAuth|cost' "$S"; then echo "FAIL: forbidden match"; exit 1; fi
find "$S" -type l | grep -q . && { echo symlink; exit 1; }
for f in $(find "$S" -name '*.md'); do [ "$(wc -l < "$f")" -le 500 ] || { echo "over 500: $f"; exit 1; }; done
# port-claim amended to claim before the bind (A.5.2); "Do not auto-pick" kept
P=$W/skills/port-claim/SKILL.md
awk '/--claim/ && !c{c=NR} /[Bb]ind the port/ && !b{b=NR} END{exit !(c&&b&&c<b)}' "$P"
grep -q 'Do not auto-pick' "$P"; grep -q 'A.5.2' "$P"; grep -qF 'WORKTREE_BASE' "$S/SKILL.md" "$S/references/kinds-and-handles.md"
bash "$W/tools/check-doc-length.sh" "$W" >/dev/null
echo SKILL-18-OK
```

## 10. Branch and worktree
Write in `~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`). No `git add`, commit, branch or push (integrator Worker1 commits). No symlinks, installs or web.

## 11. Decision Gate reminder
Stop and report `STUCK` (or write `.decisions/T18.md`) if: the 1.1.0 amendment changes the call forms, kinds or port steps above; a step needs a `catalog.sh` subcommand the Script interfaces table does not list; the card and INTERFACES disagree beyond section 7; a criterion cannot be checked with section 9; you must edit outside section 3.

## Plan-check resolutions (2026-10-26; report `reviews/plan-check-w1-specs.md`)
1. RESOLVED (INTERFACES A.5.1 `port` row and A.5.2 order; Script interfaces gives `catalog.sh` no side effect; identical to T05 Q6 and T19 Q3): the caller runs `port-check.sh --claim` and `catalog.sh` as separate commands; `catalog.sh` never calls `port-check.sh`.
2. RESOLVED (INTERFACES A.5.2 is the single statement; AM-1 consumer list names `port-claim`; PC-4): A.5.2 governs. The installed `skills/port-claim` Step 4 (claim after the bind) is amended by this item (scope line above), so the rule has one wording in agent-hq.
3. RESOLVED (PLAN-CHECK DEFAULT; the installed `port-claim` convention): skills cite scripts as `~/projects/agent-hq/tools/...` (`~/projects/agent-hq/tools/delivery/catalog.sh`, `~/projects/agent-hq/tools/port-check.sh`); INTERFACES names stay repo-relative; item 33's resolver checks every path at the move. `WORKTREE_BASE` is passed inline from the profile on calls that register worktrees (T05 Q2).
4. RESOLVED (INTERFACES 1.3.0 AM-3 / owner OQ-2; A.5.2 "never auto-picks"; overrides the PC-4 / AM-2 row 6 "never applied" default): the "+10 rule" is the dispatch plan's candidate formula `<base> + 10·k`, fixed before any check (spec 17 Q4), plus exactly one retry: a refusal at the claim makes one retry at candidate + 10, itself claimed with `port-check.sh --claim` before any bind (the tool never auto-picks); a second refusal stops the line and is reported (a lane maps to `lane-unavailable`). Never a second +10.
