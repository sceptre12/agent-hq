# Task 15: `delivery-architecture` (NEW skill, stage 2, HEAVY)

- **Header:** item 15 (part-06 §7); wave W1; authoring tier `execute` (§7 row 14-22); runtime personas Architect (design) and Ticket decomposer (execute); review rung: `review-7-panel` loop, 2b (item 31; one bus of 12 slots: 7 seats, orchestrator, synthesizer, fixer, verifier, gate checker; up to round 3, D7), run from Worker1 (build-common); not a Rung 1 trio. Interfaces: `INTERFACES.md` + `interfaces/part-a..d` (FROZEN, INTERFACES 1.5.0) and amendment AM-1 (INTERFACES 1.1.0: port guard A.5.2, security-audit A.5.3, `security_audit` D2.1).
- **Dependencies:** INTERFACES frozen; item 16 `review-tailor` (called by name, no file dependency); item 14 only through files it produces at runtime (`brief.md`, `facts.md`, profile); `doc-reviewer` EXTEND (part-06 items 9-13, `references/delivery-doc-checks.md`) is named, not edited. Template files are item 27, piece T-B (RESOLVED Q1).
- **Split:** none planned (1 author, then the heavy loop). If the author exceeds its budget the split is `SKILL.md` versus `references/` (two agents); one integration step: an agent runs the section 9 script and resolves every cross-reference between the halves.

## 1. Objective
Write `skills/delivery-architecture/SKILL.md` plus references (card 3, part-02 §2.2): a confirmed brief becomes an epic tree of local ticket drafts, `architecture.md`, `contracts/`, `test-plan.md` v0, `release-plan.md` v0, a review record and a one-page H1 packet. **Done condition (single, machine-checkable):** the section 9 block exits 0 and its last stdout line is `SKILL-15-OK`, and the `review-7-panel` synthesizer's first line is `APPROVAL BAR MET 0/0/<L>` (or the loop stopped at round 3 and the open findings went to the owner, D7).

## 2. Context package
- Card 3 (part-02 line 54); stage 2 row (part-01 line 67); review table rows for architecture and dispatch (part-02 §2.4); templates §5.1 (tickets), §5.2 (`architecture.md`, 14 sections), §5.4 (`test-plan.md`), §5.5 (`release-plan.md`) (part-04).
- Persona rows Architect and Ticket decomposer (part-03 lines 33-34); E2E scope rule §3.6 step 1 and D17; G48, D7, D35, D55, D57, D59, D60, D62 as adopted (part-03 line 94).
- `skills/review-7-panel/SKILL.md` and `preround-check.md` (the runtime loop reached through `review-tailor`).
- Anatomy and sizing: `tools/skill-authoring.md` §2-§5; deviations as in task 14 (D16 model-invocable; `version:`; Step 0).
- security-audit (AM-1): `skills/security-audit/SKILL.md`. Guidance mode is the default; full mode only on an explicit operator request or when `architecture.md` carries the header line `security_sensitive: yes` (part A.2 `security_audit`, D2.1); the conductor sets `SECURITY_AUDIT`, this skill does not. Full-mode output is `RUN_HOME/<subtask>/security-audit/run-<N>/` (A.5.3), its agents get slot rows (A.4), and `validate-findings.cjs` is a `pre-pr-gate` row.

## 3. Scope
- **In (directory `W/skills/delivery-architecture/`, nothing else):** `SKILL.md`; `references/step0-inputs.md`; `references/tree-rules.md` (typed tree, spikes first, child-coverage and template-format checks, slug minting); `references/contracts.md` (one owning document per cross-unit contract, siblings cite by pin, D63/D67); `references/h1-packet.md` (one-page layout); `references/architect-brief.md` and `references/decomposer-brief.md` (persona briefs with the COMMON block); `references/review-handoff.md` (what is passed to `review-tailor`, G48 pre-round check, D57 trigger relay); `references/security-sensitive.md` (criterion placeholder, item 7); `references/fixtures/` (a fake brief, facts, profile and expected outputs for the dry run).
- **Out:** `references/templates/*` (item 27); other skills' directories; INTERFACES, ADRs, design parts; `delivery-dispatch-plan` content; any real run artifact; commits.
- **Do-not-create:** symlinks, installs, web fetches, gate files (H1 is the desk's), Jira tickets (publishing waits for `H1.ok`, then `ticket-clerk` through the desk), any script, cost metrics.

## 4. Contracts table (cite anchors; do not restate)
| Contract | Anchor | Role |
|---|---|---|
| Inputs `RUN_HOME`, `PLANS_DIR` (holds `brief.md`, `facts.md`), `REPO_PROFILE` (`@sha`) as `NAME=value` | part D2.2 row 3; D1 | Step 0; `INPUT-ERROR <NAME> <reason>`, one line per failing field, then stop |
| Enumerated fields `rung`; issue type `Epic\|Spike\|Story\|Task\|Subtask` | part D2.1 | validate; bad value is `INPUT-ERROR <field> enum` |
| `ARCH: ready` as line 1 of `review-architecture.md`, then a fixed header block of three `key: value` lines `STAKES`, `CONTENTION`, `NOVELTY` (consumed by D2.2 rows 5 and 13; amended: AM-5 15/17, D8) | part D1.1; D8 | producer; written last, after 0B/0M or the D7 stop (open findings then go in the packet) |
| `DRAFTS: <n> drafts` as line 1 of `drafts/index.md`; `index` reserved | part D1.1; A.1 `<slug>`; A.6 | producer; slug `^[a-z0-9][a-z0-9-]*$` minted here |
| Artifact names and planes: `architecture.md`, `contracts/` (repo root), `test-plan.md`, `release-plan.md`, `review-architecture.md`, `h1-packet.md`, `drafts/<slug>.md` in `PLANS_DIR` | part A.6 row 3; D6 | producer; atomic writes (A.1) |
| `release-plan.md` step table: first column `step_id` `^[a-z0-9-]+$` unique, then step, owner `agent\|human`, `tag` | part A.6 (R4-J3) | minter of the ids; `release-track` keeps them |
| Ticket template with Gherkin AC; drafts local until `H1.ok` | part-04 §5.1; part A.2.1 | producer; no `jira-create` here |
| Rung and seats | part D2.2 row 4; D1.1 `RUNG:`, file `RUN_HOME/review-tailor-<slug>.md` | caller: mints `SLUG`, passes `ARTIFACTS`, `KIND=doc`, `STAKES`, `CONTENTION`, `NOVELTY`; reads the table, runs the named mechanism |
| H1 | part A.2.1 (`H1.<run-id>.ok\|.changes\|.reject` (gate-file names carry the run id; amended: AM-5 26, A.2.1)); part B8 (`GATE <run-id> H1 <verdict>`) | hands the packet only; verdicts are the desk's and the human's |
| Profile keys read (`e2e.harness`, `durations.*`, review profile) | part A.2.2; part-04 §5.8 | reader; link `@<sha>`, never copy (D22) |
| E2E harness statement | part-04 §5.2 item 8; D17; part-03 §3.6 step 1 | `nlta`: each user-visible story gets an e2e unit; `none`: name the gap, `test-plan.md` carries human hand-test rows post-merge |
| Cross-unit contracts | D63, D67 | one owning document each, cited by pin |
| `security_sensitive: yes\|no` header line of `architecture.md` | part A.2 `security_audit` row; D2.1 `security_audit`; AM-1 | producer; read by the conductor |
| Port guard | part A.5.2 (AM-1) | item 6 of section 8 |

## 5. Inherited module API
`review-tailor` (task 16) is invoked by name with the D2.2 row 4 inputs; `review-7-panel`, `doc-reviewer` (+ `references/delivery-doc-checks.md`), `panel-consultation`, `panel-review` run as that table names. `fix-verifier` runs after each fix. The fixer is never the author; reviewers never hunt lint (part-03 §3.4).

## 6. What you inherit
- Step order from card 3: find and update existing architecture docs (Rule 5); draft the tree spikes first; contracts for every shared value; name the e2e gap where no harness exists (D17); `review-tailor`; loop to 0B/0M or round 3 (D7); child-coverage and template-format checks; hand the packet.
- Rung rule: 1 for a story, 2b for an epic (an epic's rung is at least `2b`, card 3 wins over the generic table; amended: AM-5 15, D8 D2.2 row 4), 4 for a one-way door (card 3). Stop condition: the doc contradicts source, so measure (part-03 line 33).
- Evidence: about 55% of serious light-review findings were cross-document conflicts (`RLM:32`); friction sources Hermes `wave-execution-independent-review`, efficiency study G25.

## 7. Known risky values
- `ARCH: ready` and `DRAFTS: n drafts` exact strings (D1.1 regexes). Issue types capitalised as in D2.1.
- Round limit 3 (D7); a finding arriving mid-round is queued, never injected (G46); G48 pre-round check before round 1 and after every fix; the D57 freeze trigger is stated by `review-tailor` and relayed here.
- The H1 packet is one page: decisions needed, risks, open findings if round 3 was reached, what the human is accepting. The human block (`architecture.md` item 13) is written blank.
- `/Users/<name>`, personal-project names and Notion paths must be absent (SUB rules).

## 8. Acceptance criteria
1. Frontmatter: `name`, `version: 0.1.0`, description under 1024 chars with the card trigger and "Use when"; model-invocable.
2. Sections `## Trigger`, `## Steps` (numbered, Step 0 first), `## Red flags`, `## Exit criteria`, `## Provenance`; body under 5k tokens and 500 lines; depth in `references/`.
3. Steps in order: Step 0; find existing docs and update rather than duplicate; draft tree spikes first; mint slugs, write `drafts/*.md`, then `drafts/index.md`; write `contracts/`; write `architecture.md` in the §5.2 order (large epics: landing page plus parts); `test-plan.md` v0 with the e2e statement; `release-plan.md` v0 with step table and `agent|human` marks; verify claims against source; call `review-tailor`; run the loop it names; child-coverage and template-format checks; write `review-architecture.md` with `ARCH: ready` on line 1; write `h1-packet.md`; stop.
4. Exit criteria include: every draft Story has Gherkin AC with happy and failure paths; every cross-unit contract has exactly one owner; every user-visible story has an e2e unit or an architecture gap line; no draft was published.
5. Red flags include: restating a sibling's contract instead of citing it; publishing before `H1.ok`; skipping the loop because the epic "looks small"; a fact without a measured source; injecting a finding into a running round.
6. Port guard (AM-1, A.5.2): the doc names any fixed port a component needs (§5.2 item 3) so the dispatch plan and lanes can claim it with `tools/port-check.sh --claim` before launch; this skill binds nothing, claims nothing and writes no catalog `port` row.
7. Security (AM-1): `architecture.md` carries a header line `security_sensitive: yes` or `security_sensitive: no`, set by the Architect from `references/security-sensitive.md`. This skill passes `SECURITY_AUDIT=guidance` to `review-tailor` unless the conductor or operator says `full`. It does not run `security-audit` itself and writes no audit files. The criterion for `yes` is the plan-check default of RESOLVED Q2 (owner question OQ-1 open, non-blocking).
8. No cost figures; no web.

## 9. Verification commands (W = `~/projects/agent-hq-worktrees/delivery-w0`)
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/delivery-architecture; R=${FIXTURE_DIR:?the non-author verifier sets FIXTURE_DIR to its dry-run output directory}
test -f $S/SKILL.md
test "$(grep -c '^## \(Trigger\|Steps\|Red flags\|Exit criteria\|Provenance\)$' $S/SKILL.md)" -eq 5
grep -q '^version: 0\.1\.0$' $S/SKILL.md
if grep -q 'disable-model-invocation' $S/SKILL.md; then echo "FAIL: disable-model-invocation"; exit 1; fi
sed -n '/^description:/p' $S/SKILL.md | grep -q 'Use when'
[ "$(wc -w < $S/SKILL.md)" -le 3500 ]; [ "$(wc -l < $S/SKILL.md)" -le 500 ]
for t in 'ARCH: ready' 'DRAFTS:' 'review-tailor' 'H1' 'INPUT-ERROR' 'security-audit' 'security_sensitive' 'port' 'run-doc-' 'issuetype' 'parent'; do grep -rq --exclude-dir=templates -- "$t" $S || { echo "MISSING $t"; exit 1; }; done
grep -q 'plan-check default' $S/references/security-sensitive.md
if grep -rEi --exclude-dir=templates '/Users/[a-z]+|touri|ofw|runfrist|jetblue|notion|\$[0-9]+|cost' $S; then echo "FAIL: forbidden match"; exit 1; fi
if find $S -type l | grep -q .; then echo symlink; exit 1; fi
bash $W/tools/check-doc-length.sh $W >/dev/null
# dry run: a reader follows the steps on references/fixtures/ and saves its PLANS_DIR output plus the output of a run with RUN_HOME unset (unset.txt) into $R
head -1 $R/review-architecture.md | grep -qx 'ARCH: ready'
head -1 $R/drafts/index.md | grep -qE '^DRAFTS: [0-9]+ drafts$'
for d in $R/drafts/*.md; do b=$(basename "$d" .md); [ "$b" = index ] && continue; printf '%s\n' "$b" | grep -qE '^[a-z0-9][a-z0-9-]*$'; head -5 "$d" | grep -q '^issuetype: '; done
# release-plan.md step ids unique: checked by the reviewer against the A.6 step table (the table position is not fixed)
grep -qx 'INPUT-ERROR RUN_HOME missing' $R/unset.txt
echo SKILL-15-OK
```
Every INTERFACES anchor the skill names must resolve (item 33 resolver). Heavy loop: `review-7-panel` per its SKILL.md with the pre-round check, up to 3 rounds, then the D7 stop.

## 10. Branch and worktree
Worktree W, branch `wt/delivery-w0`; write only section 3 paths; no git add, commit, branch, push or rebase; the loop's fixer edits only this directory. No symlinks, installs or web.

## 11. Decision Gate reminder
Write `.decisions/15-delivery-architecture.md` (fork, options, recommendation, `Outcome: Blocked`) instead of choosing when the card and INTERFACES leave a value open (for example the security-sensitive criterion), or when a fix would change a frozen grammar (that is an INTERFACES amendment with a consumer re-check list, M21).

## Open points
- RESOLVED Q1 (spec 27 §3 piece T-B; PC-3): item 27 writes `skills/delivery-architecture/references/templates/{ticket,architecture,test-plan,release-plan}.md`; this item cites those paths and never writes `references/templates/`.
- RESOLVED Q2 (PLAN-CHECK DEFAULT; owner question OQ-1 in the plan-check report): `references/security-sensitive.md` states that the Architect writes `security_sensitive: yes` when the epic changes any of: authentication or authorization, session or token handling, secrets or credential sources, payment or money flows, personal data, the e2e mock or auth-bypass gate (M25, M26), input parsing reachable from the network, or a new third-party dependency; else `no`; when unsure, `yes`. The file marks the list "plan-check default, pending owner OQ-1". A `yes` only adds the full audit; it never removes a control.
- RESOLVED Q3 (PLAN-CHECK DEFAULT; D22 link, never copy): `review-architecture.md` is line 1 `ARCH: ready`, then the `STAKES`/`CONTENTION`/`NOVELTY` header block (amended: AM-5 15), then the review record body and a link to `RUN_HOME/review-tailor-<slug>.md`; the seat table is not copied.
- RESOLVED Q4 (INTERFACES A.1 `<slug>`: "minted by the caller"; PLAN-CHECK DEFAULT for the counter): this skill is the stage 2 caller and mints `run-doc-<n>`, `n` = 1 + the number of existing `RUN_HOME/review-tailor-run-doc-*.md`. The same rule binds `delivery-dispatch-plan` (`run-plan-<n>`) and `pre-pr-gate` (`<subtask>-diff-<n>`).
- RESOLVED (cross-spec, spec 22 Q4; AM-2 row 10; PLAN-CHECK DEFAULT): every `drafts/<slug>.md` opens with a YAML front matter of exactly `slug`, `issuetype` (D2.1 ticket issue type) and `parent` (the parent's slug, `-` for the epic); `ticket-clerk` reads it and item 27's `ticket.md` template carries it.
