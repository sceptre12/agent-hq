# 22-ticket-clerk — Rung 1 loop record

- **Artifact:** `skills/ticket-clerk/` (`SKILL.md`, `references/event-handling.md`, `references/ticket-body.md`). Spec: `architecture/delivery-workflow/tasks/22-ticket-clerk.md`.
- **Loop:** one orchestrator for the loop (D35), and a separate agent for every role, never reused across roles:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed `doc-reviewer` skill (M29).
  - Fix: Opus.
  - Fix-verify: Sonnet, running the installed `fix-verifier` skill.
- **Round cap:** 3 rounds (D7). The G48 screen ran before round 1 and after each fix. Its findings went to the fixer first.
- **Date:** 2026-10-26.
- **Sources given to reviewers:**
  - the spec (its RESOLVED lines are binding)
  - INTERFACES (`INTERFACES.md` and `interfaces/part-a..d`)
  - `architecture/delivery-workflow-sources/owner-decisions.md`
  - `tools/skill-authoring.md`
  - part-04 §5.1
- **INTERFACES version:**
  - The author wrote against 1.1.0 and did not re-read the document after AM-2 (1.2.0).
  - The round 1 review was told to check parts B and D3 at 1.2.0 in full, with the draft-to-request linkage and the `parent` field rule as mandatory focus.
  - During the loop INTERFACES moved to 1.3.0 (AM-3). AM-3 touches none of B1-B6, A.1, A.6, D1, D2.1 (ticket issue type), D2.2 row 14 or D3.
  - The item now cites "1.2.0 or later (checked against 1.3.0)".

## Rounds

| Round | Screen | Review | Fix | Fix-verify | Open after round |
|---|---|---|---|---|---|
| 1 | PC-1..9: 2 M, 7 L | R1-1..16: B=0 M=9 L=7 | all M and L fixed; OQ-22-1..3 opened | B=0 M=0 L=3 (N1-N3) | 0 B / 0 M |
| 2 | post-fix PC2: 1 valid M (`tickets.tsv` `utc` in compact form, against part-a A.1 timestamps row), 1 L (OQ ids pointed nowhere; screen rated it M, orchestrator downgraded) | fresh reviewer R2-1..8 (run after the fix): B=0 M=5 L=3 | utc M, OQ pointer, N1-N3 fixed | B=0 M=0 L=1 (this record missing) | 0 B / 5 M (R2-1..5) |
| 3 | post-fix PC3: PC3-3 rated M, downgraded to L by the orchestrator (the Provenance source is the one spec §6 names; part-06:98 records `NLTA/shared/learnings.md` as a source; same form as the sibling skills) | none (round cap) | R2-1..5, R2-7, R2-8, PC3-1 fixed; OQ-22-4 opened | B=0 M=0 L=2; post-fix screen PC4: 3 L | **0 B / 0 M** |

### Round 1 Medium findings, with how each was closed

- **R1-1:** the parent key was resolved after the request was written.
  - Closed: step 6 resolves the parent KEY from `tickets.tsv` first, then writes the B4 `{parent, fields}` object. Example `.req` files pass the shipped `dr_validate`.
- **R1-2:** the epic (`parent: -`) hit the no-draft stop, and `issuetype` and `parent` were never cross-checked.
  - Closed: step 4 validates the front matter before any send. It checks for exactly three keys, the slug against the file stem and the A.1 regex, `issuetype` against D2.1, that `parent` is `-` exactly for `Epic`, that the parent draft exists, and that there is no cycle.
- **R1-3:** the parent-pending and stop rules contradicted each other.
  - Closed: each parent state is defined (has a key row, in flight, curable reject, terminal reject).
- **R1-4:** the item mapped Jira statuses back through its own table, which holds no Jira strings.
  - Closed: the row records the canonical `to` that was sent. `jira.status_map` stays with the desk (A.2.2).
- **R1-5:** a failed create was re-checked with `jira-get`, which needs a key.
  - Closed: the clerk resends with a fresh id, and the desk reconciles through the B2 duplicate-action guard.
- **R1-6:** the resume scan covered creates only, and the `.req` path was wrong.
  - Closed: the scan covers all three verbs, and the path is `.fields.fields.summary`.
- **R1-7 / PC-1:** `INPUT-ERROR` lines failed the D1 regex.
  - Closed: all 8 lines now match.
- **R1-8:** the item cited the wrong INTERFACES version.
  - Closed: it now cites "1.2.0 or later (checked against 1.3.0)".
- **R1-9:** the `-` key branch was dead code, and a slug with a draft but no row was undefined.
  - Closed: the resolution rules are rewritten.
- **PC-2:** `$RUN` was undefined.
  - Closed: replaced by `RUN_ID`, the last segment of `RUN_HOME`.

### Round 2 Medium findings, with how each was closed

- **utc format:** `tickets.tsv` `utc` was in compact form.
  - Closed: it is now ISO 8601 `YYYY-MM-DDTHH:MM:SSZ` in every file body. The compact form appears only in desk `<id>`s and file names.
- **R2-1:** the step order was circular.
  - Closed: the clerk reads back and records after each request. Creates go in waves (epic first, then each level once its parent has a row).
- **R2-2:** two events for one ticket in a single flush were judged against rows not yet written.
  - Closed: one request per ticket is in flight, and events go in batches of distinct tickets.
- **R2-3:** `published` sent no transition.
  - Closed: it now sends `jira-transition to: Backlog`, per D3 and spec §8.
- **R2-4:** the resume scan skipped the B1 re-attach rule and stored terminal rejections.
  - Closed: the scan re-attaches a `.req` that has no `.out` under its original id. Stored terminal `.out`s and `.req.noreply` files are standing stops and are never resent.
- **R2-5:** the cursor rule for curable rejects was undefined.
  - Closed: one cursor table covers DONE, no-request, not-yet-applicable, curable, terminal and no-reply.

## parent-field analysis (reviewer round 1, confirmed by both verifiers)

1. **Draft front-matter `parent`** (A.6 part-a:291, AM-2 row 10): the parent's slug, `-` for the epic. This is unambiguous, and the item reads it as a slug.
2. **`tickets.tsv` column `parent`** (A.6 part-a:323): INTERFACES does not say whether it holds a slug or a key. The item writes the key from the `jira-create` `.out` (B6 types `parent` as `JIRA-KEY` or null). This is OQ-22-1.
3. **`jira-create` request:**
   - B4 (part-b:79) carries a top-level `parent` (a KEY), present exactly when `issuetype` is not `Epic`.
   - The nested allowlist (part-b:104) also lists `parent`.
   - B4 also says "Every listed field is required".
   - The item sends the top-level `parent` only, with no nested `fields.parent`, which is the form the shipped `desk-req-schema.sh` accepts. This is OQ-22-2.

The end-to-end chain matches INTERFACES: draft slug, then key via `tickets.tsv` column `key`, then the top-level `parent` KEY, then `.out` `parent`, then the row.

## Owner questions (the item marks each "Open"; each has a safe interim)

- **OQ-22-1 (part-a A.6:323):** in `tickets.tsv`, does the `parent` column hold the parent's Jira KEY or its slug?
  - Recommended: the KEY. Amend A.6 to read "`parent` (a Jira key; `-` for an epic)".
  - Interim in the item: writes the key.
- **OQ-22-2 (part-b B4:79, :104):** for `jira-create`, is the top-level `parent` the only carrier of the parent KEY, with a nested `fields.parent` refused (`schema`) on create? And are the nested allowlist keys optional except `summary` and `issuetype`?
  - Recommended: yes to both, and add one example `.req` per Jira verb to B4.
  - Interim in the item: sends the top-level `parent` only.
- **OQ-22-3 (part-b B4:101, :104):** after a ticket is created, does a change to the draft's front-matter `parent` or `issuetype` go to Jira as `jira-update`, or is it a draft defect to report?
  - Recommended: report it as a draft defect; the clerk does no re-parenting or re-typing.
  - Interim in the item: reports it and sends nothing.
- **OQ-22-4 (part-b B2.1, part-a A.6):** after a terminal `REJECTED` or a no-reply (`.req.noreply`) on an event line, how is the line released? Until it is, every later event waits behind it.
  - Recommended: after the clerk has reported the stored `.out` once, the cursor passes the line without sending anything. The `.out` stays as the record, and the owner corrects by hand or with a new event line.
  - Interim in the item: the line holds the cursor and is reported at every flush.

## Open Lows (not fixed; the loop is at the round cap)

- **verify-r3 L-1:** batch distinctness compares the subject as written, so a slug and a key for the same ticket could both be in flight. It should compare the resolved ticket.
- **verify-r3 L-2:** for a standing-stop transition line, the text does not say how a stored request maps back to its log line. The stop-conditions wording ("the rest of the flush runs") can be read against the cursor hold.
- **PC4-1:** step 9 and the `sender` row apply B1's 5+5 minute no-reply rename, which B1 states for leads, to the conductor by analogy.
- **PC4-2:** `SKILL.md` has more H2 sections than the "Five sections" in spec §8. Extra sections are not forbidden.
- **PC4-3 / PC3-3:** the Provenance line cites `NLTA/shared/learnings.md` 7, which is outside agent-hq. This is the source spec §6 names. A §5-compliant in-repo link needs a `learnings/` or `retros/` entry, which is an integrator or owner call.
- **PC3-2:** `jira-ticket-quality` is not installed on the build machine, so its contract is unverified. Spec RESOLVED 1 covers the case where it is missing at run time.
- **Residual (fixlog-r3):** part C2 places escalation files at `RUN_HOME/<subtask>/escalations/<unit>.md`, which has no slot for run-level (`run`) work. The clerk's `ESCALATE human-step` therefore goes in its report line only, and no path was invented. The integrator should confirm.
- **Spec drift (outside the item):** `tasks/22-ticket-clerk.md:3` and `:88` still say INTERFACES 1.1.0. The integrator should fix them.
- **Pilot check (advisory):** `published` sends a Backlog-to-Backlog transition, which D3 mandates but Jira may refuse. A refusal would hold the cursor on every flush.

## Spec §9 done condition

- Run as the non-author dry run by the round 3 fix-verifier, and again by the round 3 post-fix screen: stdout last line `SKILL-22-OK`, exit 0.
- `SKILL.md` is 2684 words (the cap is 3500).
- The other half of the done condition is that the review trio returns CLEAN. The final verifier verdict is `ISSUES_FOUND B=0 M=0 L=2`: no Blocking and no Medium, with the Lows listed above.

## Working files

The per-round screens, reviews, fix logs and verifications, plus the snapshots before round 1 and before round 3, are in the build scratchpad under `r1-22/`. They are not committed.
