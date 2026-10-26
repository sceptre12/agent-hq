# Task Spec — 27: template pack (12 files, design §5.0 to §5.11), split 4 ways

> Item 27 of design §7 (`part-06-build-plan-and-sources.md:26`). Read `build-common.md` first; it is binding. Templates are documents, not skills: no SKILL.md here.
> Spec status: written at W0 item 2b. INTERFACES version read: `1.1.0` (AM-1 port guard and security-audit applied below).

| Field | Value |
|---|---|
| Tier | `execute` (§7 table) for the four authors |
| Review rung | Rung 1 trio (`doc-reviewer`, fix agent, `fix-verifier`; at most 3 rounds then the owner, D7), one trio per split piece; the integration check is mechanical |
| Depends on | INTERFACES frozen (done). No dependency on another W1 item to author. Soft: the owning skills' `SKILL.md` items (14-22, 28-29) name these files; they must not write `references/templates/` |
| Split | 4 agents, directory-disjoint (§3); one integration step |

## 1. Objective
Produce the 12 reusable templates of design §5.0-§5.11 as files under `references/templates/` of the skill that owns each artifact, each a fill-in skeleton whose field names, enums and regexes are exactly those of INTERFACES, so no consumer skill re-derives a grammar.

## 2. Context Package
- Design source per file: `part-04-templates.md` (§5.0 to §5.11, §5.3b, §5.8b); writers and exact artifact names: `interfaces/part-a-state.md` A.6; paths/planes: A.1 and part D6 (design §5.11 is itself one of the 12).
- Frozen grammars the templates must reproduce, not paraphrase: `state.md`, `substate.md`, slot row, machine row, gate files (A.2, A.2.1, A.3, A.4); `catalog.tsv` 12 columns, kind set and per-kind table (A.5, A.5.1; note "no executable column"); `GATE-PASS` and `HUSKY=0` (A.7, link only); review record, `merge-<sha>.md`, `cleanup-*.md`, `tickets.tsv` (A.6); profile keys with YAML serialization (A.2.2); `UNIT-VERDICT`, `NEXT:` (part C); enums (part D).
- Design limits: generated docs stay about 500 lines; templates carry `FILL_IN_BEFORE_DISPATCH` sentinels where a value is unmeasured (§5.8 sentinel list), never invented values.

## 3. Scope: the split (4 agents, 12 files, directory-disjoint)
Each file is a Markdown skeleton with: purpose line, field table or fenced skeleton, enum/regex references by INTERFACES anchor, "Writer / Reader" line, and sentinels. One file per design section; sub-sections fold in (5.3b into the 5.3 file as Part B; 5.8b into the 5.8 file as a labelled seed appendix; `substate.md` into the 5.0 file).

| Piece | Agent | Directory (exclusive) | Files (design section) |
|---|---|---|---|
| T-A | 1 | `skills/delivery-pipeline/references/templates/` | `state-and-substate.md` (5.0), `retro-and-execution-log.md` (5.9), `artifact-to-plane.md` (5.11) |
| T-B | 2 | `skills/delivery-architecture/references/templates/` | `ticket.md` (5.1), `architecture.md` (5.2), `test-plan.md` (5.4), `release-plan.md` (5.5, with the `step_id` table, A.6) |
| T-C | 3 | `skills/delivery-dispatch-plan/references/templates/`, `skills/delivery-run/references/templates/`, `skills/resource-catalog/references/templates/` | `dispatch-plan.md` (5.3 plus 5.3b unit task spec, additions in A.6), `decisions-fork.md` (5.10), `catalog.tsv.md` (5.6) |
| T-D | 4 | `skills/delivery-intake/references/templates/`, `skills/pre-pr-gate/references/templates/` | `repo-profile.md` (5.8 plus 5.8b seed), `step-completeness-checklist.md` (5.7) |

Ownership rationale: the writer column of A.6 (conductor writes `state.md`, retro; `delivery-architecture` writes architecture, test-plan v0, release-plan v0, drafts; `delivery-dispatch-plan` writes the plan and `.tasks`; `delivery-run` owns `.decisions` fork flow; `resource-catalog` owns `catalog.tsv`; `pre-pr-gate` writes the checklist; `delivery-intake` writes the profile). The directory name `references/templates/` is design §5 line 3.

**Out of scope:** every `SKILL.md` and other `references/` content in those skills (items 14-22, 28-29 and 27b own them); `tools/delivery/*`; INTERFACES edits; briefs (`references/briefs/` in `delivery-run` is item 27b's).
**Do NOT create:** a `templates/` file outside the table; executable columns or commands in `catalog.tsv.md` (M26); a restatement of the `HUSKY=0` rule (link A.7); invented profile values; symlinks.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| `state.md` | one YAML doc; `interfaces_version`, `skill_versions: name: <version>@<sha256>`, gates as pointers only (a verdict is never an agent-written field, M30) | A.2, §5.0 |
| `substate.md` | header fields, `live: <n>/30 (derived)`, slot row 9 fields in §5.0 order, machine row `session= pid= live_count= build= utc=` | A.3, A.4 |
| `catalog.tsv` | 12 columns, 18 kinds, states `planned\|live\|released\|failed\|kept`, 400-byte row, no executable column | A.5, A.5.1 |
| `repo-profile.md` | YAML, dotted keys nested, `"yes"`/`"no"` quoted, sole authority (D22), `release_tags.*`, `e2e.*`, sensitive-path deny list, lane profile | A.2.2, §5.8 |
| Tickets and `.tasks` | 11-section unit spec (§5.3b); scope globs live in `## 3` as `- <glob>` lines (scope-check reads them) | part C1.2 |
| Release plan | step table, first column `step_id` `^[a-z0-9-]+$`, owner `agent\|human` | A.6 |
| Checklist | every §5.7 row plus a `GATE-PASS` row; `PASS` only if each row has evidence | §5.7, A.7 |
| Planes | exact §5.11 table; RUN vs repo `plans/<epic>/`; adds the AM-1 rows `security-audit/run-<N>/` (RUN `<subtask>/`) and `skills/security-audit/` (vendored) | A.1, D6 |
| AM-1 `state.md` | field `security_audit: guidance\|full`, default `guidance` | A.2 |
| AM-1 `architecture.md` | optional header line `security_sensitive: yes` (sets `security_audit: full`) | A.2, A.6 |
| AM-1 `substate.md` slot rows | persona `security-auditor`, unit `-`, tier `verify`, counted in the ledger | A.4 |
| AM-1 catalog | `port` kind: handle `<port>`, planned before launch, released only by cleanup via a `released` registry row; claim order in A.5.2 | A.5.1, A.5.2 |
| AM-1 checklist | a gate row: under `full`, `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json` exits 0 | A.5.3 |
| AM-1 dispatch plan lane table | each lane/dev-server/bus port is claimed (never auto-picked) | A.5.2, C1.1 |

## 5. Inherited module API
`doc-reviewer`, `fix-verifier`; `tools/check-doc-length.sh`; the XC template sources (read only): `~/projects/x-context-docs/_templates/task-spec.md`, `retrospective.md`, `execution-log.md`, and the Jira ticket template for §5.1, sanitized per build-common SUB rules (employer/client/personal-project text removed as whole blocks).

## 6. What You Inherit
Frozen INTERFACES parts A to D. Nothing to install.

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| `catalog.tsv` columns | 12, no `verify_cmd` | 13 with a command column | A.5 |
| Task spec sections | 11, six pre-flight checks | 10 or an added section | §5.3b |
| Gate file names | `H0.ok`, `H1.ok\|.changes\|.reject`, `H-e2e.<subtask>.ok`, `H-prod.<step_id>.ok` | `H-pr` as a file | A.2.1 |
| Review record | 3 lines, `CODE-GATE-REVIEW: PASS head=<sha> blocking=0 medium=0` | 2 lines | A.6 |
| sha | 40-hex everywhere | abbreviated | A.1 |
| Plane for `release-plan.md` v1, `retro.md` | RUN | `plans/<epic>/` | A.6 |
| Dates | `YYYY-MM-DD` | other formats | build-common |

## 8. Acceptance Criteria
- [ ] Exactly the 12 files of §3 exist; no other file under those `templates/` directories.
- [ ] Each file under about 500 lines (`check-doc-length.sh`), has a Writer/Reader line and cites INTERFACES anchors for every grammar.
- [ ] Every regex/enum value copied from INTERFACES equals the source (grep check below).
- [ ] 5.8 contains the `FILL_IN_BEFORE_DISPATCH` sentinel convention and lists each unmeasured field; 5.8b rows carry their source and "re-verify at move".
- [ ] 5.5 carries `agent`/`human` per step with the exact prepared command slot, and the `step_id` table.
- [ ] 5.11 table equals design §5.11 (7 rows) with A.6 planes.
- [ ] AM-1 carried: `security_audit` in the `state` template, `security_sensitive` in the `architecture` template, the `port` claim order in the `catalog` and `dispatch-plan` templates, the `validate-findings.cjs` row in the checklist (grep below).
- [ ] No `/Users/xavier`, no personal-project names, no Notion path (sanitization grep).

## 9. Verification Commands (the verifier re-runs these)
```bash
cd ~/projects/agent-hq-worktrees/delivery-w0
T="skills/delivery-pipeline/references/templates/state-and-substate.md skills/delivery-pipeline/references/templates/retro-and-execution-log.md skills/delivery-pipeline/references/templates/artifact-to-plane.md skills/delivery-architecture/references/templates/ticket.md skills/delivery-architecture/references/templates/architecture.md skills/delivery-architecture/references/templates/test-plan.md skills/delivery-architecture/references/templates/release-plan.md skills/delivery-dispatch-plan/references/templates/dispatch-plan.md skills/delivery-run/references/templates/decisions-fork.md skills/resource-catalog/references/templates/catalog.tsv.md skills/delivery-intake/references/templates/repo-profile.md skills/pre-pr-gate/references/templates/step-completeness-checklist.md"
n=0; for f in $T; do [ -s "$f" ] && n=$((n+1)) || echo MISSING $f; done; echo files=$n   # expect 12
find skills/{delivery-pipeline,delivery-architecture,delivery-dispatch-plan,delivery-run,resource-catalog,delivery-intake,pre-pr-gate}/references/templates -type f | grep -v -x -F "$(printf '%s\n' $T)" && echo EXTRA-FILE
bash tools/check-doc-length.sh .
grep -L -E 'Writer' $T                               # expect no output
grep -l -E '/Users/xavier|touri|ofw|runfrist|jetblue|[Nn]otion' $T   # expect no output
grep -c 'FILL_IN_BEFORE_DISPATCH' skills/delivery-intake/references/templates/repo-profile.md   # >= 1
grep -q 'verify_cmd' skills/resource-catalog/references/templates/catalog.tsv.md && echo EXEC-COLUMN   # only allowed in a "dropped" note; reviewer reads context
# grammar copy check: the review-record regex and kind list appear verbatim
grep -q 'CODE-GATE-REVIEW: PASS head=' skills/pre-pr-gate/references/templates/step-completeness-checklist.md || echo RECORD-MISSING
grep -q 'validate-findings' skills/pre-pr-gate/references/templates/step-completeness-checklist.md || echo AM1-CHECKLIST
grep -q 'security_audit' skills/delivery-pipeline/references/templates/state-and-substate.md || echo AM1-STATE
grep -q 'security_sensitive' skills/delivery-architecture/references/templates/architecture.md || echo AM1-ARCH
grep -q 'port-check' skills/resource-catalog/references/templates/catalog.tsv.md || echo AM1-PORT
grep -q 'security-auditor' skills/delivery-pipeline/references/templates/state-and-substate.md || echo AM1-PERSONA
for k in worktree branch tag process pm2-app port bus tmpdir container image lane-lease db clone cron bgtask file workspace; do grep -q -- "$k" skills/resource-catalog/references/templates/catalog.tsv.md || echo KIND-MISSING $k; done
```
**Done condition:** `files=12`, no `MISSING`, `EXTRA-FILE`, `RECORD-MISSING`, `AM1-*`, `KIND-MISSING`, no output from the `grep -L`/`grep -l` lines, `check-doc-length.sh` exit 0, integration record written (below), and each piece's Rung 1 trio at 0 Blocking / 0 Medium (or a D7 owner stop).

**Integration step (one, serial, after T-A to T-D, by the integrator):** run the block above; diff each template's quoted enum/regex against INTERFACES (`grep -F` of each regex string in the matching part); check that every template filename the W1 `SKILL.md` items cite exists (`grep -rho 'references/templates/[A-Za-z0-9._-]*' skills | sort -u` against the 12); write a pass line in the item-33 consistency log. Failure of any row returns the piece to its author, not to another piece.

## 10. Branch
Worktree `delivery-w0` (`wt/delivery-w0`); no git add, commit, branch, push or rebase by authors; the integrator commits.

## 11. Decision Gate Reminder, SPEC-QUESTIONs
Stop and write `.decisions/27-<piece>.md` if INTERFACES contradicts the design section or a value is unmeasured; use a sentinel, never a guess.
- `SPEC-QUESTION 1:` design §5 says only "owning skill"; the file-to-skill mapping and filenames in §3 are this spec's derivation from A.6 writers. Plan-checker to confirm (notably `retro` and `artifact-to-plane` in `delivery-pipeline`, `decisions-fork` in `delivery-run`).
- `SPEC-QUESTION 2:` "12 files" is taken as one per section §5.0 to §5.11, folding 5.3b, 5.8b and `substate.md` in. If the owner meant 15 (sub-sections separate), T-C and T-D grow by file, not by directory.
- `SPEC-QUESTION 3:` items 28 (`delivery-run`) and 14, 15, 17, 21 write `references/` in the same skill directories; their scopes must exclude `templates/` (and, in `delivery-run`, `briefs/`).
- AM-1 (1.1.0) is applied above: T-A (`state`, slot row persona), T-B (`architecture` header), T-C (`catalog`, `dispatch-plan` lane ports), T-D (`checklist` gate row). AM-1's re-check list names "the `state.md` and `dispatch-plan.md` templates" as consumers; this item is that re-check, so the integration record states the result. Re-read INTERFACES `Amendments` just before finishing; a newer amendment is applied the same way or marked STUCK.
