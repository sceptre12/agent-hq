# H1 packet: one-page layout

Sources: card 3 ("H1 packet (one page: decisions needed, risks, open findings if round 3 was reached, what you are accepting)"); INTERFACES 1.10.0 (`architecture/delivery-workflow/INTERFACES.md:3`) part A.2.1 (H1 files, `ref=` is the sha256 of `h1-packet.md`; `interfaces/part-a-state.md:92-108`), part B8 (`GATE` line grammar; `interfaces/part-b-desk.md:152-172`), part A.6 (`h1-packet.md` in `PLANS_DIR`; `part-a-state.md:293-334`).

## Rules

- One page: at most 60 lines, not counting the rows of the "What you are accepting" table (a default of this skill), no section longer than its content needs.
- Link artifacts; never paste their content.
- The packet is the H1 reference: the desk computes `ref=` as its sha256, so any later change to the packet is a new H1 question.
- You write no verdict and no gate file. The human answers in the desk session; the desk writes `RUN_HOME/gates/H1.<run-id>.ok`, `H1.<run-id>.changes` or `H1.<run-id>.reject` (with `H1.notes.md`).
- `H1.ok` unlocks `jira-create` (through `ticket-clerk` and the desk); `H1.changes` re-enters stage 2 with the notes binding; `H1.reject` stops the run (part A.2.1, `interfaces/part-a-state.md:101`).
- Answer channel: only the B8 `GATE` line's `<text>` and, for `changes` and `reject`, `RUN_HOME/gates/H1.notes.md`, which the desk writes from that text (part B8, A.2.1). No other verb or file carries an answer. Because `ok` writes no notes, `ok` means every recommended option and every listed open finding is accepted as written; any other choice is a `changes` note (a default of this skill).

## Layout

```
# H1 packet: <epic summary> (<run-id>)
Date: YYYY-MM-DD. Review: rung <rung>, <rounds> rounds, final <B>/<M>/<L>. security_sensitive: <yes|no> (<reason item>).

## Decisions needed
1. <decision> - options: <a> | <b>; recommended: <a>, because <one line>; source: architecture.md item 4.
(none: "No open decisions.")

## Risks
- <risk> - stop-the-line signal: <signal>; mitigation: <one line> (architecture.md item 10).

## Open findings (only after a round-3 NOT MET, or a final K-check failure)
- <finding id> <severity> <one line> - record: <path>.   (the round-3 synthesizer's open B/M rows, as they are; no fix ran after them)

## What you are accepting
| File (absolute path) | sha256 |
|---|---|
| <PLANS_DIR>/architecture.md | <sha256> |
| <PLANS_DIR>/architecture-part-<NN>-<topic>.md (one row each) | <sha256> |
| <repo root>/contracts/<file> (one row each) | <sha256> |
| <PLANS_DIR>/test-plan.md (v0) | <sha256> |
| <PLANS_DIR>/release-plan.md (v0) | <sha256> |
| <PLANS_DIR>/drafts/index.md (<n> drafts) | <sha256> |
| <PLANS_DIR>/drafts/<slug>.md (one row each) | <sha256> |
| <repo root>/<existing doc updated in step 1> (one row each) | <sha256> |
| <PLANS_DIR>/review-architecture.md | <sha256> |
Accepting means: the tree, the contracts and their owners, the e2e statement (harness or named gap with hand-test rows), the release steps marked human, and publication of the drafts to Jira after H1.

## How to answer (desk session)
GATE <run-id> H1 ok <text>
  ok: you accept every recommended option above and every listed open finding as it stands; the drafts may then be published to Jira.
GATE <run-id> H1 changes <what to change>
  changes: stage 2 re-runs with your text binding (the desk writes it to H1.notes.md); to pick a non-recommended option or dispute an open finding, use changes and name the decision number and option, or the finding id, in the text.
GATE <run-id> H1 reject <why>
  reject: the run stops; nothing is published.
```

One row per file, every file of `ARTIFACTS` plus `drafts/index.md` and the review record, hashed with `shasum -a 256` as the last review round (or the Low pass) left them, `architecture.md` item 12 included (filled before round 1, `review-handoff.md` §2a); nothing is edited after hashing. The "Open findings" section is omitted when the loop reached 0 Blocking / 0 Medium and the final K-checks passed. On an `H1.changes` re-entry, add one line per note under "Decisions needed": `note <k>: <how it was handled>`.

The `review-architecture.md` hash is taken from its temp file in step 13 (same bytes after the `mv` in step 14).
