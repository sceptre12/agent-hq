# H1 packet: one-page layout

Sources: card 3 ("H1 packet (one page: decisions needed, risks, open findings if round 3 was reached, what you are accepting)"); INTERFACES 1.1.0 part A.2.1 (H1 files, `ref=` is the sha256 of `h1-packet.md`), part B8 (`GATE` line grammar), part A.6 (`h1-packet.md` in `PLANS_DIR`).

## Rules

- One page: at most 60 lines (a default of this skill), no section longer than its content needs.
- Link artifacts; never paste their content.
- The packet is the H1 reference: the desk computes `ref=` as its sha256, so any later change to the packet is a new H1 question.
- You write no verdict and no gate file. The human answers in the desk session; the desk writes `RUN_HOME/gates/H1.ok`, `H1.changes` or `H1.reject` (with `H1.notes.md`).
- `H1.ok` unlocks `jira-create` (through `ticket-clerk` and the desk); `H1.changes` re-enters stage 2 with the notes binding; `H1.reject` stops the run.

## Layout

```
# H1 packet: <epic summary> (<run-id>)
Date: YYYY-MM-DD. Review: rung <rung>, <rounds> rounds, final <B>/<M>/<L>. security_sensitive: <yes|no> (<reason item>).

## Decisions needed
1. <decision> - options: <a> | <b>; recommended: <a>, because <one line>; source: architecture.md item 4.
(none: "No open decisions.")

## Risks
- <risk> - stop-the-line signal: <signal>; mitigation: <one line> (architecture.md item 10).

## Open findings (only if round 3 was reached)
- <finding id> <severity> <one line> - record: <path>.

## What you are accepting
| Artifact | sha256 |
|---|---|
| architecture.md (and parts) | <sha256> |
| contracts/<file> | <sha256> |
| test-plan.md v0 | <sha256> |
| release-plan.md v0 | <sha256> |
| drafts/index.md (<n> drafts) | <sha256> |
| review-architecture.md | <sha256> |
Accepting means: the tree, the contracts and their owners, the e2e statement (harness or named gap with hand-test rows), the release steps marked human, and publication of the drafts to Jira after H1.

## How to answer (desk session)
GATE <run-id> H1 ok <text>
GATE <run-id> H1 changes <what to change>
GATE <run-id> H1 reject <why>
```

The "Open findings" section is omitted when the loop reached 0 Blocking / 0 Medium. On an `H1.changes` re-entry, add one line per note under "Decisions needed": `note <k>: <how it was handled>`.

The `review-architecture.md` hash is taken from its temp file in step 13 (same bytes after the `mv` in step 14).
