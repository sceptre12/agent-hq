# delivery-desk: human lines (B8) and gate files (A.2.1)

The human types one line in the desk session. These lines are not `SendMessage` verbs and not
B4 verbs; an agent never sends them and the desk never accepts them over the transport. The desk
is the only writer under `gates/` (M30). Authority: INTERFACES part B8 and part A.2.1.

## Grammar (POSIX ERE)

```
GATE   <run-id> <gate> <verdict> <text>     ^GATE ([a-z0-9-]+) (H0|H1|H-e2e\.(st[0-9]+|pm)|H-pr|H-prod\.[a-z0-9-]+) (ok|changes|reject)( .+)?$
ANSWER <run-id> <subtask> <unit> <text>     ^ANSWER ([a-z0-9-]+) (st[0-9]+|pm) ([ui][0-9]+) (.+)$
REBIND <run-id> <sender-id>                 ^REBIND ([a-z0-9-]+) ([^ ]+)$
```

A line that fails its regex, or names a `<run-id>` with no `$DELIVERY_ROOT/<run-id>/state.md`,
is answered in the session with what failed; nothing is written.

## Gate x verdict matrix

| Gate | Allowed verdicts | File written | Desk enforcement |
|---|---|---|---|
| `H0` | ok | `RUN_HOME/gates/H0.ok` | none (the conductor waits for the file) |
| `H1` | ok, changes, reject | `RUN_HOME/gates/H1.ok` / `H1.changes` / `H1.reject` | only `H1.ok` unlocks `jira-create` |
| `H-e2e.<subtask>` | ok | `RUN_HOME/<subtask>/gates/H-e2e.<subtask>.ok` | none at the desk; the lead refuses e2e generation without it |
| `H-prod.<step_id>` | ok | `RUN_HOME/gates/H-prod.<step_id>.ok` | `publish`; `tag-push` under `release_tags.approval: human` |
| `H-pr` | none | nothing: external evidence only (the approving review, B5) | `pr-merge` refuses without the read-back |

Any other gate-verdict pair is refused in the session and nothing is written.

## File content (A.2.1)

Key=value lines, written to a temp file in the same directory and `mv`d into place:

| Key | Value |
|---|---|
| `utc=` | ISO 8601 UTC `YYYY-MM-DDTHH:MM:SSZ` |
| `by=` | the OS login of the desk session, `id -un` |
| `ref=` | computed by the desk (below); a leading `ref=<value>` token in `<text>` overrides it (used for `jira:<KEY>@<comment-id>`) |
| `text=` | the typed text (after any leading `ref=` token) |
| `notes=` | `H1.changes` and `H1.reject` only: `RUN_HOME/gates/H1.notes.md` |

| Gate | Computed `ref=` |
|---|---|
| `H0` | sha256 of `plans_dir/brief.md` (`plans_dir` from `state.md`) |
| `H1` | sha256 of `h1-packet.md`, or the typed `jira:<KEY>@<comment-id>` |
| `H-e2e.<subtask>` | sha256 of the batched `.feature` list named in `test-plan.md` for that sub-task |
| `H-prod.<step_id>` | the release-plan `step_id` |

H1 history: before writing any `H1` file, rename every existing `H1.ok`, `H1.changes`,
`H1.reject` and `H1.notes.md` to `<name>.<yyyymmddThhmmssZ>`, so one live H1 file remains. For
`H1 changes` and `H1 reject` also write `<text>` to `RUN_HOME/gates/H1.notes.md`. A Jira-side
approval is recorded only as `GATE <run-id> H1 ok ref=jira:<KEY>@<comment-id> <text>`.

## ANSWER

Write one inbox file per part C5.1 (the desk is its `ANSWER` writer, so no agent can author a
human answer, M30): name `RUN_HOME/<subtask>/inbox/<seq>-<yyyymmddThhmmssZ>-answer.md`, where
`<seq>` (`^[0-9]{4}$`) is taken by an `O_EXCL` create (`set -C`) of the marker
`inbox/.seq/<seq>` for the next free number (a failed create tries the next number; the
conductor shares the counter). Line 1 is the typed `ANSWER` line verbatim. Write to a temp name
and `mv` into place, mode 0600. The lead processes it and renames it `<name>.consumed`.

## REBIND

Set the registry's `run` sender of `<run-id>` to `<sender-id>`, mirror the registry to
`desk-inbox/<run-id>.registry`, and say so in the session. The conductor then re-sends every
`REGISTER-SENDER` line of the run; until it does, its leads' lines are as registered before.
