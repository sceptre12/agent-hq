# Event handling and tickets.tsv

## Event to request

| Event | `jira-transition` `to` | Row `status` on `DONE` |
|---|---|---|
| `published` | `Backlog` | `Backlog` |
| `dispatched` | `In Progress` | `In Progress` |
| `prepr-pass` | `In Review` | `In Review` |
| `blocked` | `Blocked` | `Blocked` |
| `unblocked` | latest non-`Blocked` row status for the slug in `tickets.tsv` | that status |
| `verified` | `Verified` | `Verified` |
| `done` | `Done` | `Done` |
| `archive` | `archive` (the desk maps it to the profile's `jira.archive_status`) | the latest row's status (archive is not a canonical status, part D3) |

The mapping is part D3. The desk applies the profile key `jira.status_map` on `jira-transition` (part A.2.2); the clerk sends the canonical `to` and needs no reverse mapping, because the row records the `to` it sent, never the Jira string. The request file is the B4 object `{"key": "<KEY>", "to": "<value>"}`; the clerk never writes `fields.status`.

A transition event other than `published` and `archive` whose `to` equals the status of the slug's latest row sends no request and appends no row; only the cursor passes it (this is also how a re-read line after a resumed `.out` is absorbed). For `archive`, a `DONE` `jira-transition` `.out` in `RUN_HOME/desk/` for the same key whose `.req` has `to: archive` means it is already archived: no request. `published` is absorbed the same way by a `DONE` `jira-transition` `.out` for the key whose `.req` has `to: Backlog` (§Published).

## Resolving the ticket

1. An event subject matching the key shape `^[A-Z][A-Z0-9]+-[0-9]+$` is a key; take the latest row with that `key`. No such row: skip with one report line and pass the cursor.
2. Otherwise it is a slug. A row for the slug: take the latest one and its `key`.
3. A slug with a draft but no row is not yet created (creates run before events in a flush, so this means the create is held, rejected or still gated by `H1.ok`): the event cannot be applied yet. Stop applying events at that line, leave the cursor before it, report one line; it is retried at the next flush.
4. A slug with no row and no draft: skip with one report line and pass the cursor.

Every row this skill writes comes from a read-back that carries a key, so it writes no row whose `key` is `-`. Part A.6 keeps `-` as the absence token for `key`; a `-` key row, if one is met, is read as no row (rule 3).

## Published

`published` maps to `Backlog` (part D3: "`published` -> `Backlog` (publish after H1)"), and like the other six events it is sent as one `jira-transition` (part D3; spec 22 §8 "apply the seven events plus `archive` as `jira-transition`"). The create's row already carries status `Backlog` (SKILL.md step 10) because `jira-create` returns only `key` and `parent` (part B6); the `published` transition is what confirms it through its `read_back`. So:

- latest row `Backlog` and no `DONE` `jira-transition` `.out` for the key with `.req` `.fields.to` `Backlog`: send `{"key": "<KEY>", "to": "Backlog"}`; on `DONE` append the row (status `Backlog`, fresh `utc`);
- such a `.out` exists: already applied, no request, the cursor passes;
- latest row not `Backlog` (the ticket has moved on): report one line, send nothing, the cursor passes; the clerk never moves a ticket back to `Backlog` on a late `published`.

## Event batches

Step 7 takes unprocessed lines in log order into a batch until the next line names a slug (or key) already in the batch, or a line cannot be applied yet (§Resolving the ticket rule 3). Each line of the batch is resolved and tested (equal status, §Published, §Unblocked) against the latest rows, then its request is sent; the batch's requests are in flight together (distinct slugs only), each is read back and recorded at once (SKILL.md steps 9-10), and only then is the next batch formed. So a second event for one ticket (for example `blocked` then `unblocked`) is always tested against the row its first event wrote. A line in the batch that ends `REJECTED` or with no reply ends step 7 after this batch: no later batch is formed in this flush.

## Unblocked

Scan `tickets.tsv` for the slug from the bottom; the first row whose status is not `Blocked` gives the target. If every row is `Blocked`, stop and report; never assume a status.

## Row format

`slug<TAB>key<TAB>parent<TAB>status<TAB>utc`, one row per ticket event (part A.6). `key` is the Jira key; `parent` is `-` for an epic; `status` is a canonical D3 status; `utc` is ISO 8601 UTC `YYYY-MM-DDTHH:MM:SSZ` (part A.1 timestamps: the file-body form; the compact `yyyymmddThhmmssZ` is only for desk `<id>`s and file names), the same form as the `.out` `utc` (part B6), so rows and `.out`s compare directly. Latest row per slug governs. Append with a single-line `>>`; one writer.

Open (owner question OQ-22-1, defined in the loop record `architecture/delivery-workflow/reviews/22-ticket-clerk-rung1.md`): part A.6 does not say whether the `parent` column holds the parent's Jira key or its slug. This skill writes the key, as returned in the `jira-create` `.out` `parent` (part B6 types it `JIRA-KEY` or null), and copies it from the latest row for later rows.

Values per `DONE` (SKILL.md step 10): create: `key` and `parent` from the `.out` (`-` when `parent` is null), status `Backlog`; transition: `key` and `parent` from the latest row, status the `to` sent (for `archive`, the latest row's status); update: `key`, `parent` and status from the latest row. Each row gets a fresh `utc`.

## Resume scan

On start, before any send (part B1 "Applied-result scan"):

1. List `RUN_HOME/desk/*.out` with `verb` `jira-create`, `jira-update` or `jira-transition` and `status` `DONE`. Steps 2-5 below apply them.
2. An `.out` is unrecorded when no row with its `key` has a `utc` at or after the `.out` `utc` (both ISO 8601 UTC; compare them as written) and, for a transition other than `archive`, also a `status` equal to the `.req` `.fields.to`. The status test keeps a later row for the same key from hiding an earlier unrecorded transition.
3. Unrecorded create: no row has its `key`. Find its draft through the `.req` (`RUN_HOME/desk/<id>.req`; the B3 envelope `fields` holds the B4 object, so the summary is at `.fields.fields.summary` and the parent at `.fields.parent`, absent for an epic): the draft whose summary equals it and whose parent's key equals it. Exactly one draft: append its row. None or several: stop and report.
4. Unrecorded transition or update: append the row for that `key` with the values above (the `to` is read from the `.req` `.fields.to`).
5. Apply in `utc` order. Then read events from the cursor; a re-read event already applied is absorbed by the equal-status rule above (or, for `published` and `archive`, by their stored `.out`).
6. Re-attach (part B1: "a resumed requester scans `RUN_HOME/desk/*.req` (never `.req.noreply`) without `.out` and re-attaches"): every `RUN_HOME/desk/*.req` whose `verb` is `jira-get`, `jira-create`, `jira-update` or `jira-transition` and which has no `<id>.out` is read back under its own id by SKILL.md step 9 (re-send the same `DESK` line, `sha256=` of that `.req`, once) and recorded by step 10. Its slug (through `.fields.key` and the latest row, or, for a create, the draft match of item 3) counts as in flight, so no new request for that slug is composed until it resolves. Never a fresh id for it: the desk answers a repeated id from its stored `.out` (part B2 idempotency).
7. Standing stops: list `RUN_HOME/desk/*.out` for the four `jira-*` verbs with `status` `REJECTED` and a terminal `reason` (part B2.1: `sender, schema, hash, repo, policy`), and every `RUN_HOME/desk/*.req.noreply` (terminal `sender`, part B1). Each names one request (slug through its `.req` as in item 6). That request is never resent (part B2: "a terminal code is never resent"); a corrected request is a new request (part B2.1), so:
   - a create or update: the slug (for a create, also every draft under it: parent unresolved) is held and reported at each flush until the draft's modification time is later than the reject (the `.out` `utc`; for a `.req.noreply`, the `<utc>` of its `<id>`); a later change is a corrected draft and is composed afresh;
   - a transition: the event line stays before the cursor (§Cursor) and is reported at each flush; no request is rebuilt for it.
   A `REJECTED` `.out` with a curable `reason` is no stop: its line or draft is simply still unapplied and goes again with a fresh id once the cause clears.

## Cursor

`ticket-events.cursor` holds one line `^[0-9]+$`: the number of the last fully processed log line (part A.6). Write the new value to a temp file in `RUN_HOME`, then `mv` it over the cursor, after the row for that event. On start resume from the next line. One rule, by outcome of each line, in log order:

| Outcome of the line | Fully processed? | Cursor |
|---|---|---|
| `DONE`, row appended | yes | may pass it |
| no request needed (equal status, already applied, skipped malformed or unknown line, late `published`) | yes | may pass it |
| not applicable yet (rule 3), or curable `REJECTED` (part B2.1) | no | stays before it; the line is retried at the next flush with a fresh id once the cause clears |
| terminal `REJECTED`, or no reply (`.req.noreply`, terminal `sender`) | no | stays before it; standing stop (§Resume scan item 7) |

The cursor moves to the last line of the longest run of fully processed lines that starts right after it; it never passes a line that is not fully processed. Lines after such a line that were already applied in the same batch are re-read at the next flush and absorbed (equal status, or the stored `.out` for `published` and `archive`), because no later batch is formed after a non-`DONE` line (§Event batches), so their row is still the slug's latest.

Open (owner question OQ-22-4): part B2.1 makes a terminal code "stop-the-line for that request: reported to the owner, never resent", and part A.6 lets the cursor pass only a fully processed line, but neither says how a terminally rejected or no-reply event line is released, so every later event stays behind it. Until answered, the interim is: the line holds the cursor, the clerk reports it at every flush and sends nothing for it.

## Draft updates

A created draft (its slug has a row) whose file modification time is later than the `utc` of the latest `DONE` `jira-create`, `jira-update` or `jira-get` `.out` for its key in `RUN_HOME/desk/` is a candidate for `jira-update` (the `.out` `utc` is ISO 8601 UTC, part B6; compare it with the modification time as UTC instants). A `jira-get` that found no difference therefore ends the candidacy until the draft changes again, so an unchanged draft is not re-read and re-scored every flush. Read the current ticket with `jira-get` (`{key, fields[]}`, `fields[]` from the readable set `summary, description, issuetype, parent, labels, priority, components, status`, part B4), compose and score the body again (`references/ticket-body.md`), diff against the read, and send `jira-update` `{key, fields}` with only the changed allowlist fields. No difference: no request. On `DONE`, append the row (status unchanged, fresh `utc`).

A change of the draft's front matter `parent` or `issuetype` after the create is reported and not sent (Open, owner question OQ-22-3, defined in the loop record `architecture/delivery-workflow/reviews/22-ticket-clerk-rung1.md`: whether a re-parent goes as `jira-update` `fields.parent`, and whether an `issuetype` change goes as `jira-update` `fields.issuetype`; both are allowlist keys in part B4, which does not say). Until answered, both are the interim report-and-hold form.

## Cadence

Flush at loop hand-back or about every 30 minutes since the last flush (D62), whichever first. A flush handles creates, then events in log order, then updates. Between flushes the skill does nothing.
