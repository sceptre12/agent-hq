# Event handling and tickets.tsv

## Event to request

| Event | `jira-transition` `to` | Row `status` |
|---|---|---|
| `published` | `Backlog` | `Backlog` |
| `dispatched` | `In Progress` | `In Progress` |
| `prepr-pass` | `In Review` | `In Review` |
| `blocked` | `Blocked` | `Blocked` |
| `unblocked` | latest non-`Blocked` row status for the slug in `tickets.tsv` | that status |
| `verified` | `Verified` | `Verified` |
| `done` | `Done` | `Done` |
| `archive` | `archive` (the desk maps it to the profile's `jira.archive_status`) | the last row's status stays; the read-back status is not a canonical value |

The profile key `jira.status_map` is applied by the desk, not the clerk. The request file is `{"key": "<KEY>", "to": "<value>"}`; the clerk never writes `fields.status`.

## Resolving the ticket

1. An event subject matching the key shape is a key; find the latest row by `key`.
2. Otherwise it is a slug; take the latest row for the slug. If its key is `-` (not yet created), the event cannot be applied yet: stop the batch at that line, leave the cursor before it, and report. Exception: `published` for a slug whose create is in this batch is satisfied by the create.
3. Unknown subject (no row, no draft): skip with one report line and pass the cursor.

## Published after create

A successful `jira-create` writes a row with status `Backlog` (publish after H1 enters the ticket at Backlog, D3). A later `published` event for a slug whose latest row already says `Backlog` with a key sends no request and only advances the cursor.

## Unblocked

Scan `tickets.tsv` for the slug from the bottom; the first row whose status is not `Blocked` gives the target. If every row is `Blocked`, stop and report; never assume a status.

## Row format

`slug<TAB>key<TAB>parent<TAB>status<TAB>utc`. `key` is `-` before creation; `parent` is the parent's key (`-` for an epic); `status` is a canonical D3 status; `utc` is `yyyymmddThhmmssZ`. Latest row per slug governs. Append with a single-line `>>`; one writer.

For a create, `key` and `parent` come from the `.out`. For a transition, the new status comes from the `.out` `read_back.status` mapped back by the clerk's own table above (the row records the canonical name, not the Jira string).

## Cursor

`ticket-events.cursor` holds one line `^[0-9]+$`: the number of the last fully processed log line. Write the new value to a temp file in `RUN_HOME`, then `mv` it over the cursor, after the row for that event. On start resume from the next line. A line whose request was terminally rejected is not passed.

## Draft updates

A created draft whose file modification time is later than its latest row's `utc` is a candidate for `jira-update`. Read the current ticket with `jira-get` (`fields` from `summary, description, issuetype, parent, labels, priority, components, status`), diff against the freshly composed body, and send `jira-update` with only the changed allowlist fields. No difference: no request.

## Cadence

Flush at loop hand-back or about every 30 minutes since the last flush (D62), whichever first. A flush handles creates, then events in log order, then updates. Between flushes the skill does nothing.
