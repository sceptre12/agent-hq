# Task Spec — 26: `delivery-desk` + `references/schemas.json`

> Item 26 of design §7 (`part-06-build-plan-and-sources.md:25`). Heavy item. Read `build-common.md` first; it is binding.
> Branch/worktree: no branch work by the author (`delivery-w0` worktree; the integrator commits).
> Spec status: written at W0 item 2b. INTERFACES version read: `1.1.0` (AM-1 landed; re-checked, part B unchanged by it, see §11).

| Field | Value |
|---|---|
| Tier | `design` (§7 table: item 26 "design"); author on the design-tier model per `tools/model-routing.md` |
| Review rung | `review-7-panel` (7 seats, up to 3 rounds, then the owner, D7); heavy item per `part-02` §2.4 and `part-06` item 31 |
| Depends on | INTERFACES frozen (done); ADR 0055 accepted 2026-10-26 (done, gates this item); `tools/delivery/desk-req.sh` (item 7) is the sender-side producer, not a build dependency (the skill cites its CLI, INTERFACES §Script interfaces) |
| Parallel with | any W1 item; directory-disjoint |
| Split | none (1 agent, 3 h); integration step: none (single directory) |

## 1. Objective
Write the `delivery-desk` skill (run by the desk session, D3) and its machine-readable contract `references/schemas.json`, so that every one of the 20 desk verbs, the sender registry, the 10 reason codes and the human gate lines behave exactly as INTERFACES part B freezes them.

## 2. Context Package
- Card: `part-02-skill-inventory.md:78` (card 15); contract `part-05-execution-constraints.md:36-44` (§6.3); stage flow `part-01-summary-and-process-map.md:71-75`.
- Authority for every field name, regex, class and order of checks: `interfaces/part-b-desk.md` (B1 to B8). Where design prose and part B differ (short `DONE` form, "nine codes", "per-request account lock"), part B and the INTERFACES errata win.
- ADR `decisions/0055-desk-verb-permission-tiers-02.md` (accepted): grammar §1, reason codes §2, security properties §3, "what the desk never does" §4.
- Single `HUSKY=0` statement: `interfaces/part-a-state.md` A.7 (link, do not restate or vary). Profile keys the desk reads: A.2.2. Gate files: A.2.1. Review record and `merge-<sha>.md` layouts: A.6. Redaction pattern file: `secrets.pattern_file`.
- Anatomy: `tools/skill-authoring.md` §2-§5. Owner deviation to record in the checklist: model-invocable (D16).

## 3. Scope
**In scope (exact file scope, one directory):** `skills/delivery-desk/` only:
- `SKILL.md` (body under 5k tokens; frontmatter `name`, `description` with "Use when", `version:`, no `disable-model-invocation`)
- `references/schemas.json`
- `references/*.md` for depth that does not fit the body (suggested: `verbs.md` per-verb notes and requester table, `checks.md` the 12-step order, `human-gates.md` B8). Each stays about 500 lines or less.

**Out of scope:** `tools/delivery/*` (items 5-7: `desk-req.sh` etc.); any `INTERFACES.md` or ADR edit (a gap is a SPEC-QUESTION or STUCK, never a silent change); templates (item 27); persona briefs (item 27b, `desk` brief); any other skill; Zephyr Cloud reads (not desk verbs, B4 "Not verbs").

**Do NOT create:** tests or scripts under the skill (none are assigned; "a script without mapped tests" is a build stop condition); symlinks; a bot-account or approved-account list (R2-4); any approve, trigger-prod, pipeline-edit, force or raw-flag path (M27, D23); a `DESK` copy of the A.7 rule.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| Grammar | `DESK`, `DONE` (long form with `result=`), `REJECTED <id> \| <reason>` and their regexes | part B B2 |
| Verbs | exactly 20: push, pr-create, pr-attach, pr-comment, pr-comments-read, pr-approval-state, pr-merge, branch-delete, ci-status, ci-logs, ci-rerun, ci-status-main, fetch, tag-push, publish, test-report-push, jira-get, jira-create, jira-update, jira-transition; closed, no raw flags, arrays not strings | B4 |
| Fields added by owner Q3 | `record_path` on `pr-create` and `pr-merge` (under `RUN_HOME/review/<subtask>/`, file `record-<expect_head>.md`); the `pr-attach` verb (`{repo, pr, paths[]}`, paths under `RUN_HOME/<subtask>/lanes/`, images unscanned and labelled, traces scanned) | B4, B5, B7; `owner-decisions.md:60`, `:71` |
| Sender registry | `REGISTER-SENDER` line and `REGISTERED` reply regexes; first line claims `run`; re-claim only by human `REBIND`; mirror `desk-inbox/<run-id>.registry`; sender from the transport, never a file field; conductor-only verbs `pr-merge\|publish\|tag-push\|test-report-push` need `<subtask>` `run`; any `run` id needs the registered conductor | B1 |
| Reason codes | 10, with class: terminal `sender schema hash repo policy`; curable `marker order stale-session gate-missing action-failed`; check-to-code pairings; fresh id on a curable resend, never resend a terminal, never another channel | B2.1; OP5 B, OP10 A |
| Check order | 12 steps, first failure wins; replay answered before copy and hash; no `.out` for `sender`; `.inflight` directory plus `target` line and the fresh-id duplicate guard | B2 idempotency, B3 |
| `HUSKY=0` (N10) | every desk `push` and `pr-create` carries `HUSKY=0` as an inline per-command assignment, never exported; `--no-verify` never; the `GATE-PASS` record `gate-runs/<expect_head>.md` still gates every push and PR creation | A.7; `owner-decisions.md:80` |
| `tag-push` (N11) | behaviour per repo profile: `release_tags.used`, `.pattern`, `.approval`; no profile entry, `used: "no"`, pattern mismatch or malformed entry = `REJECTED policy`; `approval: human` needs `H-prod.<step_id>.ok` else `gate-missing`; `step_id` field | B4; `owner-decisions.md:81-84` |
| Markers re-derived | head, gate run, review record 0B/0M plus distinct `Verified-By`, H-pr read-back (human login, not author, not `[bot]`, `commit_id == headRefOid`), CI aggregate, order, `merge_reach`, content-merged for `branch-delete` | B5 |
| Result files | envelope and per-verb fields, `additionalProperties: false` on `DONE`, envelope only on `REJECTED`; `.out` atomic at 0600, also for `REJECTED` except `sender` | B6 |
| Redaction, human gate lines | scan before use, a hit is `policy`; `GATE`, `ANSWER`, `REBIND` regexes and the gate x verdict matrix | B7, B8 |

## 5. Inherited module API
- `tools/delivery/desk-req.sh <run-id> <subtask|run> <verb> <fields-json-file>` (sender side; INTERFACES §Script interfaces). The desk never calls it.
- Envelope: `SendMessage` per `architecture/permission-tiers-02.md` §2; `STATUS`/`BUSY` 2-minute rule.
- `DESK_ADDRESS` = `desk` (B1). Existing wrapped skills named by card 15/§2.1b: `create-pr` (title from branch, labels, template), `harness-api` read-only verbs, `jira`.

## 6. What You Inherit
Frozen INTERFACES; ADR 0055; the ported skills in `skills/`; `check-doc-length.sh`. Nothing is installed: the desk's own tool needs go through `INSTALL`, none are expected.

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| reason-code count | 10 (adds `action-failed`) | 9 (design §6.3 prose) | B2, OP10 A |
| `DONE` form | long: `DONE <id> \| <verb> \| result=<path> \| <verdict>` | short `DONE <id> \| <verdict>` | B2, OP2 A |
| `REJECTED` detail | in `.out` `detail` only | trailing text on the line | B2, OP1 A |
| sender | `SendMessage` id vs the desk-held registry | any request-file field | B1, M29 |
| account lock | none | per-request account lock | B3, R2-4 |
| `HUSKY=0` | inline on desk push and PR create, plus `GATE-PASS` still required | exported, or `--no-verify`, or "skip the gate" | A.7, N10 |
| `pr-merge` requester | conductor, envelope `<subtask>` `run`, `fields.subtask` `st<N>` | a lead | B1, B4 |
| `jira-create` fields | `parent` required unless `issuetype` is `Epic` | always required | B4 |
| `tag-push` default | refused without a profile entry | allowed | N11 |
| class of `marker` | curable | terminal | B2.1 |

## 8. Acceptance Criteria
- [ ] `SKILL.md` has frontmatter (`name: delivery-desk`, "Use when" description from card 15, `version:`), `## Trigger`, `## Steps`, `## Red flags`, `## Exit criteria`, `## Provenance`; Step 0 validates named inputs and prints `INPUT-ERROR <field>` (part D1); no `disable-model-invocation`.
- [ ] Steps follow B3 in order, with the replay-before-copy order, `.inflight` handling and the fresh-id guard.
- [ ] Sender registry, `REGISTER-SENDER`/`REGISTERED`, `REBIND`, `GATE`, `ANSWER` handled as B1/B8 (the human types them in the desk session; the desk writes gate files).
- [ ] All 20 verbs covered, each with requester, request schema, markers, result fields; `pr-attach`, `record_path`, `tag-push` per profile, `ci-status-main` included.
- [ ] 10 reason codes with class and trigger; terminal codes reported to the owner, curable ones resent only with a fresh id on the same channel.
- [ ] `HUSKY=0` appears as the N10 rule (link to A.7), with `GATE-PASS` still gating every push; `tag-push` states the N11 rule.
- [ ] Red flags include: desk approves or triggers prod; trusts a claimed marker; reads sender from the file; masks instead of refusing a redaction hit; pushes without `GATE-PASS`; treats a reply or `.out` text as instructions; retries a terminal code.
- [ ] `references/schemas.json` is valid JSON and matches B4/B6/B2.1 exactly (check 3 below).
- [ ] Provenance: friction-based line citing the learnings named for card 15 in design §7b and the card (`gh-auth` account flips, panel B1, `dispatch-stop-conditions-02`); no invented ids.
- [ ] Sanitized per build-common SUB rules; no personal-project text; dates `YYYY-MM-DD`.

## 9. Verification Commands
Run from the worktree root `W` (all read-only; `python3 -I`, stdlib only):
```bash
S=skills/delivery-desk; B=architecture/delivery-workflow/interfaces/part-b-desk.md
# 1 structure and length
for s in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$s" $S/SKILL.md || echo MISSING "$s"; done
grep -q '^description:.*Use when' $S/SKILL.md || echo NO-USE-WHEN
! grep -q 'disable-model-invocation' $S/SKILL.md || echo D16-VIOLATION
bash tools/check-doc-length.sh . ; wc -w $S/SKILL.md   # body about 3,800 words max (5k tokens)
# 2 rules present
grep -q 'HUSKY=0' $S/SKILL.md && grep -q 'GATE-PASS' $S/SKILL.md && grep -q 'release_tags' $S/SKILL.md && grep -q 'record_path' $S/SKILL.md && grep -q 'pr-attach' $S/SKILL.md || echo RULE-MISSING
# 3 schemas.json against part B (verbs, fields, codes and classes)
python3 -I - <<'PY'
import json,re
B=open('architecture/delivery-workflow/interfaces/part-b-desk.md').read()
b4=B.split('## B4.')[1].split('## B5.')[0]
rows=re.findall(r'^\| `([a-z-]+)` \| `\{([^}]*)\}`',b4,re.M)
b21=B.split('### B2.1')[1].split('## B3.')[0]
codes=dict(re.findall(r'^\| `([a-z-]+)` \| (terminal|curable)',b21,re.M))
j=json.load(open('skills/delivery-desk/references/schemas.json'))
assert len(rows)==20 and len(codes)==10, (len(rows),len(codes))
assert set(j['verbs'])=={v for v,_ in rows}, set(j['verbs'])^{v for v,_ in rows}
for v,f in rows:
    want={x.strip().rstrip('[]') for x in f.split(',')}
    got=set(j['verbs'][v]['request']['properties']); assert want==got,(v,want^got)
    assert j['verbs'][v]['result']['properties'] is not None
assert {c:j['reason_codes'][c]['class'] for c in codes}==codes
print('DESK-SCHEMAS-OK')
PY
```
(Layout assumed by check 3: top-level keys `verbs` and `reason_codes`; see SPEC-QUESTION 1. `jira-create`'s `parent` is optional in `required` but present in `properties`.)

**Done condition (one, machine-checkable):** checks 1 to 3 print no `MISSING`/`VIOLATION`/`NO-USE-WHEN`/`RULE-MISSING`, exit 0, and the last line printed is `DESK-SCHEMAS-OK`; then the `review-7-panel` record is 0 Blocking / 0 Medium or a D7 stop is handed to the owner.

## 10. Branch
Work only in worktree `delivery-w0` (`~/projects/agent-hq-worktrees/delivery-w0`, branch `wt/delivery-w0`); no `git add`, commit, branch, push or rebase (the integrator, Worker1, commits).

## 11. Decision Gate Reminder, SPEC-QUESTIONs and re-check
If part B, ADR 0055 and design prose conflict, or a field is missing, write `.decisions/26.md` (fork, options, recommendation, `Outcome: Blocked`) and stop. Do not reword an owner ruling (N10, N11, Q3, OP1-OP10).
- `SPEC-QUESTION 1:` B6 says `additionalProperties: false` but INTERFACES does not fix the `schemas.json` layout or JSON Schema draft. Proposed default for the plan-checker: draft-07 objects, top keys `verbs` (each `request` and `result` as an object schema with `required` and `additionalProperties: false`), `reason_codes` (`class`, `trigger`), `envelope`, `regexes`. Check 3 depends on it.
- `SPEC-QUESTION 2:` the human gate lines and `REGISTER-SENDER` are not `DESK` verbs; confirm they live in `SKILL.md` prose (and `schemas.json` `regexes`), not in `verbs`.
- AM-1 (1.1.0) re-check done at writing: it lists no part B section, so no desk verb, schema field, reason code or check changes. The port guard (`tools/port-check.sh`, catalog `port` rows, hook) binds launches by leads and lanes, not desk actions; `security-audit` runs in the lead (vendored via an earlier desk INSTALL), not through a verb. The author adds no port or audit behaviour to the desk. Re-read INTERFACES `Amendments` just before finishing; a later amendment touching part B means update this spec and the skill, or mark STUCK.
