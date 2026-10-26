# Task 15: `delivery-architecture` (NEW skill, stage 2, HEAVY)

- **Header:** item 15 (part-06 §7); wave W1; authoring tier `execute` (§7 row 14-22); runtime personas Architect (design) and Ticket decomposer (execute); review rung: `review-7-panel` loop, 2b (item 31; one bus of 12 slots: 7 seats, orchestrator, synthesizer, fixer, verifier, gate checker; up to round 3, D7), run from Worker1 (build-common); not a Rung 1 trio. Interfaces: `INTERFACES.md` + `interfaces/part-a..d` (FROZEN) and amendment AM-1 (INTERFACES 1.1.0: port guard A.5.2, security-audit A.5.3, `security_audit` D2.1).
- **Dependencies:** INTERFACES frozen; item 16 `review-tailor` (called by name, no file dependency); item 14 only through files it produces at runtime (`brief.md`, `facts.md`, profile); `doc-reviewer` EXTEND (part-06 items 9-13, `references/delivery-doc-checks.md`) is named, not edited. Template files are item 27 (SPEC-QUESTION 1).
- **Split:** none planned (1 author, then the heavy loop). If the author exceeds its budget the split is `SKILL.md` versus `references/` (two agents); one integration step: an agent runs the section 9 script and resolves every cross-reference between the halves.

## 1. Objective
Write `skills/delivery-architecture/SKILL.md` plus references (card 3, part-02 §2.2): a confirmed brief becomes an epic tree of local ticket drafts, `architecture.md`, `contracts/`, `test-plan.md` v0, `release-plan.md` v0, a review record and a one-page H1 packet. **Done condition (single, machine-checkable):** the section 9 script prints no `MISSING` line and exits 0, and the `review-7-panel` synthesizer's first line is `APPROVAL BAR MET 0/0/<L>` (or the loop stopped at round 3 and the open findings went to the owner, D7).

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
| `ARCH: ready` as line 1 of `review-architecture.md` | part D1.1 | producer; written last, after 0B/0M or the D7 stop (open findings then go in the packet) |
| `DRAFTS: <n> drafts` as line 1 of `drafts/index.md`; `index` reserved | part D1.1; A.1 `<slug>`; A.6 | producer; slug `^[a-z0-9][a-z0-9-]*$` minted here |
| Artifact names and planes: `architecture.md`, `contracts/` (repo root), `test-plan.md`, `release-plan.md`, `review-architecture.md`, `h1-packet.md`, `drafts/<slug>.md` in `PLANS_DIR` | part A.6 row 3; D6 | producer; atomic writes (A.1) |
| `release-plan.md` step table: first column `step_id` `^[a-z0-9-]+$` unique, then step, owner `agent\|human`, `tag` | part A.6 (R4-J3) | minter of the ids; `release-track` keeps them |
| Ticket template with Gherkin AC; drafts local until `H1.ok` | part-04 §5.1; part A.2.1 | producer; no `jira-create` here |
| Rung and seats | part D2.2 row 4; D1.1 `RUNG:`, file `RUN_HOME/review-tailor-<slug>.md` | caller: mints `SLUG`, passes `ARTIFACTS`, `KIND=doc`, `STAKES`, `CONTENTION`, `NOVELTY`; reads the table, runs the named mechanism |
| H1 | part A.2.1 (`H1.ok\|.changes\|.reject`); part B8 (`GATE <run-id> H1 <verdict>`) | hands the packet only; verdicts are the desk's and the human's |
| Profile keys read (`e2e.harness`, `durations.*`, review profile) | part A.2.2; part-04 §5.8 | reader; link `@<sha>`, never copy (D22) |
| E2E harness statement | part-04 §5.2 item 8; D17; part-03 §3.6 step 1 | `nlta`: each user-visible story gets an e2e unit; `none`: name the gap, `test-plan.md` carries human hand-test rows post-merge |
| Cross-unit contracts | D63, D67 | one owning document each, cited by pin |
| `security_sensitive: yes\|no` header line of `architecture.md` | part A.2 `security_audit` row; D2.1 `security_audit`; AM-1 | producer; read by the conductor |
| Port guard | part A.5.2 (AM-1) | item 6 of section 8 |

## 5. Inherited module API
`review-tailor` (task 16) is invoked by name with the D2.2 row 4 inputs; `review-7-panel`, `doc-reviewer` (+ `references/delivery-doc-checks.md`), `panel-consultation`, `panel-review` run as that table names. `fix-verifier` runs after each fix. The fixer is never the author; reviewers never hunt lint (part-03 §3.4).

## 6. What you inherit
- Step order from card 3: find and update existing architecture docs (Rule 5); draft the tree spikes first; contracts for every shared value; name the e2e gap where no harness exists (D17); `review-tailor`; loop to 0B/0M or round 3 (D7); child-coverage and template-format checks; hand the packet.
- Rung rule: 1 for a story, 2b for an epic, 4 for a one-way door (card 3). Stop condition: the doc contradicts source, so measure (part-03 line 33).
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
7. Security (AM-1): `architecture.md` carries a header line `security_sensitive: yes` or `security_sensitive: no`, set by the Architect from `references/security-sensitive.md`. This skill passes `SECURITY_AUDIT=guidance` to `review-tailor` unless the conductor or operator says `full`. It does not run `security-audit` itself and writes no audit files. The rule for when the Architect writes `yes` is not given: SPEC-QUESTION 2.
8. No cost figures; no web.

## 9. Verification commands (W = `~/projects/agent-hq-worktrees/delivery-w0`)
```
S=$W/skills/delivery-architecture
test "$(grep -c '^## \(Trigger\|Steps\|Red flags\|Exit criteria\|Provenance\)$' $S/SKILL.md)" = 5
grep -q '^version: ' $S/SKILL.md && ! grep -q 'disable-model-invocation' $S/SKILL.md
[ "$(wc -w < $S/SKILL.md)" -le 3500 ] && [ "$(wc -l < $S/SKILL.md)" -le 500 ]
for t in 'ARCH: ready' 'DRAFTS:' 'review-tailor' 'H1' 'INPUT-ERROR' 'security-audit' 'port'; do grep -rq -- "$t" $S || echo MISSING $t; done
grep -rEo 'part [A-D][.0-9]*' $S | sort -u    # every anchor named must exist in INTERFACES (resolver, item 33)
! grep -rEi '/Users/[a-z]+|touri|runfrist|jetblue|notion' $S
bash $W/tools/check-doc-length.sh $W
```
Dry run on `references/fixtures/`: a reader follows the steps; outputs match `^ARCH: ready$` (line 1 of `review-architecture.md`) and `^DRAFTS: [0-9]+ drafts$` (line 1 of `drafts/index.md`); every `drafts/*.md` stem matches the slug regex; `release-plan.md` step ids are unique; an unset `RUN_HOME` gives `INPUT-ERROR RUN_HOME missing`. Heavy loop: `review-7-panel` per its SKILL.md with the pre-round check, up to 3 rounds, then the D7 stop.

## 10. Branch and worktree
Worktree W, branch `wt/delivery-w0`; write only section 3 paths; no git add, commit, branch, push or rebase; the loop's fixer edits only this directory. No symlinks, installs or web.

## 11. Decision Gate reminder
Write `.decisions/15-delivery-architecture.md` (fork, options, recommendation, `Outcome: Blocked`) instead of choosing when the card and INTERFACES leave a value open (for example the security-sensitive criterion), or when a fix would change a frozen grammar (that is an INTERFACES amendment with a consumer re-check list, M21).

## Open points
- SPEC-QUESTION 1: Placement of the template pack (item 27) against the directory-disjoint scope. This task creates no `references/templates/*` and cites `references/templates/{architecture,ticket,test-plan,release-plan}.md`.
- SPEC-QUESTION 2: AM-1 fixes the marker (`security_sensitive: yes` header, A.2) but no source says what makes an epic security-sensitive. Plan-checker or owner supplies the criterion; `references/security-sensitive.md` holds a placeholder until then.
- SPEC-QUESTION 3: `review-architecture.md` is both the review record and the `ARCH:` carrier (D1.1, A.6); whether its body must hold the `review-tailor` table is not stated. Default: link `RUN_HOME/review-tailor-<slug>.md`, do not copy.
- SPEC-QUESTION 4: At stage 2 the `SLUG` form is `run-doc-<n>` (A.1); who mints the per-run counter `n` is not stated. Default: this skill, next free integer under `RUN_HOME`.
