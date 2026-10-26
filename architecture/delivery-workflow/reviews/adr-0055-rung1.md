# ADR 0055 — Rung 1 loop record

- **Artifact:** `decisions/0055-desk-verb-permission-tiers-02.md` (the `DESK` verb amendment to
  `architecture/permission-tiers-02.md` §2). Its status stays "proposed — awaiting owner
  ratification".
- **Loop:** one orchestrator for the loop (D35), and a separate agent for every role, never
  reused across roles:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the `doc-reviewer` skill.
  - Fix: Opus.
  - Fix-verify: Sonnet, running the `fix-verifier` skill.
- **Round cap:** 3 rounds (D7). The pre-round screen ran before round 1 and after each fix. Its
  findings went to the fixer first.
- **Date:** 2026-10-26.
- **Sources given to reviewers:**
  - `architecture/delivery-workflow/part-01..06-*.md`
  - `architecture/permission-tiers-02.md`
  - `decisions/0053-permission-tiers.md`
  - `architecture/delivery-workflow/interfaces/*.md`
  - owner rulings (`architecture/delivery-workflow-sources/owner-decisions.md`)
  - the design v2 changelog
- **Lint and typo nits:** reviewers skipped them.

## Round 1

**Pre-round screen (G48): 0 Blocking, 8 Medium, 10 Advisory.**
- Finding codes were ambiguous across the two panel rounds.
- The reason table paired checks with codes that design §6.3 does not state.
- The ADR claimed "no -02 rule changes", but the `DESK` id is an exception to the -02 id rule.
- Two id formats were undefined: the conductor `<subtask>` slot and `<utc>`.
- The sender registry was undefined, and `claude -p` leads have no `SendMessage` identity.
- The `publish` gate file was unnamed.
- R2-7 was cited as an owner ruling, but it is a coordinator default.

**Review (doc-reviewer): 0 Blocking, 7 Medium, 6 Advisory. Verdict: READY WITH CONDITIONS.**
- Sender binding cannot be met by `claude -p` leads.
- The ADR contradicted itself on reason-code mapping.
- The stop-the-line rule was applied to transient reasons, and no retry model was given.
- The runtime-only scope sat outside the text bound for -02.
- The text bound for -02 depended on external references.
- The desk tier conflicted with the -02 rule "never source" and with ADR 0053 item 2.
- The marker "record path" was carried by no schema.

**Fix (Opus): all 15 Medium findings fixed.**
- R6 was partly accepted: design part-03 "execute" is a model-tier column, but the conflict with
  -02 and ADR 0053 is real.
- Finding codes are now qualified by round.
- Unresolved points are marked `[OP n]`, and six owner questions were added (OP3-OP8).
- The text bound for -02 was made self-contained.

**Fix-verify: ISSUES_FOUND, 0 Blocking, 4 Medium, 3 Advisory.**
- While the round ran, `interfaces/part-b-desk.md` resolved its OPEN items into
  `DEFAULT (integrator)` drafts. That left the ADR's "OPEN in part-b" citations stale.
- `pr-attach` was missing from the verb list.
- The grammar block assumed the answers to OP1 and OP2 with no marker.
- The header's claim about markers was false.

## Round 2

**Owner input received mid-loop.** The coordinator relayed it, and it matches
`owner-decisions.md` l.57-60, "INTERFACES owner questions (2026-10-26)". Both are now settled:
- **Q1 YES:** the conductor relays `DESK` lines for `claude -p` leads, and the desk cross-checks
  the id and the subtask.
- **Q3 YES:** a `pr-attach` verb, plus a `record_path` field on `pr-create` and `pr-merge`
  (ratify with 0055).

**Pre-round screen (G48): 1 Blocking, 9 Medium, 7 Advisory.**
- Blocking: the grammar block fixed OP2 = A and OP1 = A in text that is applied as written.
- Stale "OPEN in part-b" citations.
- OP2 misquoted card 15.
- Open items in the body were not listed as open points (the `publish` gate, hash-mismatch
  replay, `REJECTED` stored as `.out`).
- The conductor registration had no source.
- D3 was narrowed on the strength of R2-7.
- Executor R-7 versus `DESK` pushes under the operator's auth.

**Review (doc-reviewer): 0 Blocking, 6 Medium, 4 Advisory. Verdict: READY WITH CONDITIONS.**
- Stale part-b citations.
- `pr-attach` missing.
- Missing `[OP 2]` and `[OP 8]` markers.
- Open-point premises were stale, and draft defaults were not stated.
- Consequences omitted the profile templates that copy the -02 §2 grammar.
- The reason-code triggers had two homes that disagreed.

**Fix (Opus): all Blocking and Medium findings fixed.**
- Q1 and Q3 are recorded as settled, with the owner citation; there are now 20 verbs.
- OP8 (record carrier) was removed as settled by Q3.
- Every draft is cited as `DEFAULT (integrator)`, never as an owner ruling.
- `part-b-desk` §B2.1 is now the single home for the reason-code triggers.
- Consequences now names `tools/claude-profile/templates/executor-CLAUDE.md:39` and
  `desk-CLAUDE.md:10`, and adds the ADR 0053 item 3 pointer.
- Two owner questions were added: the executor R-7 push rule, and unscanned images on
  `pr-attach`.

**Fix-verify: CLEAN, 0 Blocking, 0 Medium, 4 Advisory.**
- Q1 and Q3 are accurate.
- No open point is decided.
- The markers are in sync.
- No draft default is presented as an owner ruling.

## Round 3 (final, D7)

**Pre-round screen (G48): 0 Blocking, 5 Medium, 3 Advisory.**
- §3 conflicted between "a swapped file fails `hash`" and "a replay returns the stored result".
- Integrator-freeze items (the `publish` gate path, replay ordering, the `record_path` root)
  carried no marker, which made the header's claim false.
- OP9's framing was out of step with Q3.
- §5 said ADR 0053 item 6 is unchanged, while the ADR also says "R2-4 drops the account list".
- The interface drafts present OP1 and OP2 as decided. This is outside the ADR, so it goes to the
  integrator.

**Review (doc-reviewer): 0 Blocking, 5 Medium, 5 Advisory. Verdict: READY WITH CONDITIONS.**
- `pr-merge` "conductor only" cannot be enforced for relayed lines unless the reserved `run`
  token (OP7) is used.
- The sender registry and gate files are plain same-user files. This forgery exposure was absent
  from the accepted residual and from OP3.
- The ADR attributed the "redacted screenshots and traces" wording to the owner. Q3 does not say
  it; only the part-b draft does.
- There is no reply form for a validated request whose action then fails.
- OP4 options B and C name no desk address, and the requester-tier part had no option labels.

**Fix (Opus): all 9 Medium findings closed.**
- The header now scopes `[OP n]` to owner questions and adds a `[freeze]` label for items the
  integrator settles at the INTERFACES freeze. Eight places carry it, among them the replay
  order, the review root, the `publish` gate and the id-collision check.
- §3 now gives the part-b draft order: bind the sender, then replay, then copy and hash, labelled
  `[freeze]`.
- Q3 is quoted verbatim. The "redacted screenshots and traces" wording is attributed to the
  part-b draft.
- Additions to open points:
  - OP3: the forgery exposure.
  - OP4: a desk name under each option, and tiers per requester class.
  - OP7: its effect on the "conductor only" rule for `pr-merge`.
  - OP8: part (a), R2-4 against ADR 0053 item 6 for executors.
- New OP10 asks for the reply form when a validated action fails.
- The ADR is 308 lines. The doc-length check flags no blocking files.

**Fix-verify: ISSUES_FOUND, 0 Blocking, 1 Medium, 1 Advisory.**
- All nine round 3 Medium findings landed.
- Q1 and Q3 are settled, with Q3 quoted verbatim.
- OP1-OP10 are all undecided questions with options.
- No draft default is presented as a ruling.
- **Open Medium (new):** `[OP 10]` is missing from the reason-code set. OP10 option A would add
  a tenth `REJECTED` code, but four places mark only `[OP 1]` or nothing:
  - the grammar `REJECTED` line (l.54)
  - the note on that line (l.57-58)
  - the §1 "Reasons" bullet (l.94-97)
  - §2 "This ADR fixes only the code set: the nine codes" (l.114-117)

  This makes the header's claim about markers untrue at those lines. The fix is mechanical: add
  the marker. It decides nothing.
- **Advisory:** OP8 cites only R2-4 for "no approved-account list in the work runtime". R2-7 says
  the same.

## Final status

**Loop closed at the D7 cap (3 rounds), with 0 Blocking, 1 Medium and 1 Advisory open.**
- The open Medium is the missing `[OP 10]` marker on the reason-code set; it goes to the owner
  under D7.
- The ADR remains "proposed — awaiting owner ratification".
- Owner rulings settled during the loop: Q1 and Q3 (`owner-decisions.md` l.57-60).

**Owner questions in the ADR (OP1-OP10):**
1. Should a `DESK` `REJECTED` line carry an optional `[| <detail>]`?
2. Which `DONE` form: long (`<verb>`, `result=`) or a short form?
3. Where does sender registration live (`state.md` read or a registration message), given the
   forgery exposure of each?
4. Which desk runs `DESK`, and under what name and tier? It could be the existing desk tier with
   "never source" scoped to `INSTALL`, a new tier, or a distinct session. The question also asks
   which tier each requester class runs in.
5. Retry model: do all rejections stop the line, or are they split into terminal and curable,
   with a curable one resent under a fresh id?
6. Is the R2-7 runtime-only scope (build-time git stays on `RESEARCH`, `INSTALL` and `STATUS`)
   confirmed, given the rule "Single environment = work"?
7. Id slots: what token does a conductor request use for `<subtask>`, and does it enforce
   "`pr-merge` conductor only"? And what is the `<utc>` format?
8. (a) R2-4 against ADR 0053 item 6 for executors; (b) a push-target rule for `DESK` pushes and
   merges.
9. `pr-attach` images: Q3 says nothing on scanning. Attach them unscanned, or require a scan or
   redaction?
10. What is the reply when a validated action then fails: a new code, `DONE` with a failure
    verdict, or left to `INTERFACES.md`?

**For the integrator (drift in other files, not edited by this loop):**
- `INTERFACES.md` (l.29, rows B2/B2.1) and `interfaces/part-b-desk.md` (l.3, l.30, l.32) present
  the `DONE` form, the `REJECTED` detail and the code mapping as decided. The ADR holds OP1 and
  OP2 open.
- `part-b-desk` B1 and B4 still mark Q1 and Q3 as pending.
- `INTERFACES.md` E5 misquotes card 15.
- `part-b-desk` l.66 says "redacted", but l.123 attaches images unscanned.
- `tools/claude-profile/templates/executor-CLAUDE.md` lacks `[| <detail>]` on its `INSTALL`
  `REJECTED` line.
- `part-b-desk` l.67 requires `branch-delete` only when the branch is content-merged (D8). The
  ADR's re-derivation list does not mention this.

**Discrepancy to note.** The brief described the ADR as having 3 open points. The version that
entered round 1 had 2 listed open points: the `REJECTED` detail field and the `DONE` form. A
third was only implied in the body: `stale-session` was "inferred", and the run-id non-collision
was "to be confirmed". The loop kept the first two in place, and that third item is now covered
by OP7 and by the `[freeze]` items.

## Owner answers applied and ratification (2026-10-26)

- **Owner answers** (`owner-decisions.md`, "ADR 0055 open points", "Accept all"): OP1 A, OP2 A,
  OP3 B, OP4 A (plus requester tiers), OP5 B, OP6 A, OP7 A, OP8 (a) B and (b) A, OP9 A, OP10 A.
  Every `[OP n]` marker is now decided text citing "owner 2026-10-26"; "Open points for the
  owner" is now "Owner decisions".
- **Leftover Medium closed:** `action-failed` is the tenth code on the grammar line, the Reasons
  and Result bullets, §2, §5 and Consequences; it is curable under OP5.
- **Fix-verify 1 (Sonnet, `fix-verifier`): ISSUES_FOUND**, 0 Blocking, 0 Medium, 5 Advisory
  (derived text sitting inside owner citations: desk naming under OP4, OP5 report/same-channel,
  OP8 (a) executor scope, the epic `jira-create` example under OP7; subtask shape omitted `pm`).
  Fixed by moving derived text outside the citations and pointing the shape at part-b-desk §B2.
- **Fix-verify 2: CLEAN**, all 5 advisories closed, nothing new.
- **Status set to** "accepted 2026-10-26 (owner ratified conditional on fix-verify)".

## INTERFACES lines that now need updating (owned by the INTERFACES loop; not edited here)

1. `INTERFACES.md:29` — `DONE` form "DEFAULT pending ADR 0055 OP 2"; OP2 A decided.
2. `INTERFACES.md:39-43` (N3-N7) — "owner to decide" for OP9, OP1/OP2, OP3, OP7, OP4; all decided.
3. `INTERFACES.md:82` (B1 row) — desk reads `state.md` `conductor_id`/`lead_id`; OP3 B: a
   desk-held registry the conductor fills over the transport.
4. `INTERFACES.md:83-84` (B2, B2.1 rows) — nine-code pairing; add `action-failed` and the
   terminal/curable class per code (OP5 B, OP10 A).
5. `INTERFACES.md:117` (B1 decisions row) — `DESK_ADDRESS` default; OP4 A: a desk-tier session
   named per R-1.
6. `interfaces/part-b-desk.md:5` — Scope cites R2-7 as default; OP6 A confirmed it.
7. `interfaces/part-b-desk.md:11` — desk "execute tier"; OP4 A: existing desk tier
   (`config/tiers/desk.json`), "never source" scoped to `INSTALL`; conductor and Agent-tool
   leads executor tier, `claude -p` leads no tier.
8. `interfaces/part-b-desk.md:12` — desk address "owner to decide (OP 4)".
9. `interfaces/part-b-desk.md:14-15` — sender identity and registered ids from `state.md`;
   needs the conductor's registration line (form set at the freeze, OP3 B).
10. `interfaces/part-b-desk.md:16, 32` — "owner to decide (OP 7)"; OP7 A: token `run`,
    `yyyymmddThhmmssZ`.
11. `interfaces/part-b-desk.md:28` — `REJECTED` line lacks `action-failed`.
12. `interfaces/part-b-desk.md:41` — `sender` code text names `conductor_id`/`lead_id` from
    `state.md`; now the desk-held registry.
13. `interfaces/part-b-desk.md:49, 55` — B2.1 table and B3 check order: add `action-failed`
    (after step 9, act) and a terminal/curable column.
14. `interfaces/part-b-desk.md:61` — `subtask` regex `^(st[0-9]+|pm)$` excludes `run` while the
    id regex (l.32) allows it; reconcile.
15. `interfaces/part-b-desk.md:98` — `.out` envelope `status` `DONE|REJECTED`: note
    `reason: action-failed` for a failed action.
16. `interfaces/part-b-desk.md:127` — "owner to decide, OP 9"; OP9 A decided.
17. `interfaces/part-a-state.md:62, 78` — `conductor_id` and `lead_id` as the desk's sender
    registry; OP3 B moves the registry into the desk (the state fields may stay for the
    conductor's own use).
18. Design `part-05` lines 41 and 43 (§6.3) and card 15 — nine codes and short `DONE` forms;
    errata E5 plus a new erratum for `action-failed`.
