# Fix r2: delivery-architecture (W1 item 15, 2b), 2026-10-26

Fixer: Opus fixer of skills/review-7-panel (not the author). Input: panel7-delivery-architecture-r2-2026-10-26.md, M rows R2-1..R2-6 and PR4-C2. L rows, PR4-C1 (refuted) and the OWNER-NOTE s3-2 (card-3 floor vs review-tailor) are untouched. templates/ not edited; spec 15 not edited. Paths are under skills/delivery-architecture/.

| finding id | file:line changed | change (one clause) | status |
|---|---|---|---|
| R2-1 | SKILL.md:22; references/tree-rules.md:72 (K13) | a split Story's A3 row uses the `st<N>` of the Subtask that builds the user-visible behaviour (unit slug stays the Story's); K13 requires every A3 sub-task cell and batched-list `st<N>:` label to be an item 5 `st<N>` id | fixed |
| R2-2 | SKILL.md:20, :26, :28; references/review-handoff.md:27-36 (new §2a), :70 (§8); references/h1-packet.md:53 | item 12 is filled at step 10, before round 1, with known values and pointer-only text (rung; seats, rounds, open findings as links to the tailor record and review-architecture.md), never changed after; step 12 no longer fills it; packet and §8 say the hashed bytes include item 12 as reviewed | fixed. Choice: fill before round 1 (not hash exclusion), because it needs no owner decision and keeps the template's item 12 lines (`templates/architecture.md` item 12, frozen) with pointer values; the final counts live in review-architecture.md, which is hashed |
| R2-3 | SKILL.md:23 (step 7); references/tree-rules.md:71 (K12) | `approval: human` makes the tag step owner `human` (gate `H-prod.<step_id>.ok`, part-a-state.md:100); with `used: "yes"` and a malformed or absent `pattern`/`approval`, no tag step is planned (part-a-state.md:136); K12 checks both | fixed |
| R2-4 | references/review-handoff.md:45 (§3 brief list); SKILL.md:29 (step 13) | the brief now sets records directory `RUN_HOME/review/<SLUG>/` and ledger `RUN_HOME/review/<SLUG>/ledger.md` (defaults of this skill; review-7-panel says the brief sets the ledger), round numbering restarts at 1 only in a new directory (each call mints a new SLUG, so a re-entry never reuses a name); the review record lists the directory, ledger and every round record path | fixed |
| R2-5 | references/h1-packet.md:12 (Rules), :45-50 (How to answer) | answer channel is the B8 `GATE` line `<text>` and, for changes/reject, `H1.notes.md` (A.2.1); `ok` accepts every recommended option and listed open finding; another option or a disputed finding is `changes` naming the decision or finding id; one consequence line per verdict; no new verb. SKILL.md:30 points to it | fixed |
| R2-6 | SKILL.md:16 (step 1); references/tree-rules.md:17 (item 5 st0) | step 1 edits each updated existing doc in place before step 10 (so a round reads it) and adds its repo path to the st0 scope in item 5, so the dispatch plan's st0 commits it | fixed |
| PR4-C2 | SKILL.md:21 (step 5a) | added `architecture/delivery-workflow-sources/owner-decisions.md:88-89` and `architecture/delivery-workflow/INTERFACES.md:25` | fixed |

## Checks
- `wc -w SKILL.md` = 2906 (<=3500); `wc -l SKILL.md` = 68; reference files 15-85 lines (all <500).
- Spec §9 tokens (ARCH: ready, DRAFTS:, review-tailor, H1, INPUT-ERROR, security-audit, security_sensitive, port, run-doc-, issuetype, parent): all present; `plan-check default` in references/security-sensitive.md: 2 hits (unchanged).
- Forbidden grep `/Users/[a-z]+|touri|ofw|runfrist|jetblue|notion|\$[0-9]+|cost` (case-insensitive, outside templates/): 0 hits.
- `bash tools/check-doc-length.sh <W>`: 0 blocking files over 500 lines (4 informational over 40000 bytes, all in architecture/delivery-workflow/, not this skill).
