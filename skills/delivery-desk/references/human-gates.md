# delivery-desk: human lines (B8) and gate files (A.2.1)

The human types one line in the desk session. These lines are not `SendMessage` verbs and not
B4 verbs; an agent never sends them and the desk never accepts them over the transport. The desk
is the only writer under `gates/` (M30). Authority: INTERFACES 1.5.0 part B8 and B9
(`architecture/delivery-workflow/interfaces/part-b-desk.md:152-185`) and part A.2.1
(`.../interfaces/part-a-state.md:92-108`); M30 resolves in `references/source-keys.md`.

## Grammar (POSIX ERE)

```
GATE   <run-id> <gate> <verdict> <text>     ^GATE ([a-z0-9-]+) (H0|H1|H-e2e\.(st[0-9]+|pm)|H-pr|H-prod\.[a-z0-9-]+|grant\.(st[0-9]+|pm)\.[0-9]+|H-destructive\.[A-Za-z0-9.-]+|RESUME\.(st[0-9]+|pm)) (ok|changes|reject)( .+)?$
ANSWER <run-id> <subtask> <unit> <text>     ^ANSWER ([a-z0-9-]+) (st[0-9]+|pm) ([ui][0-9]+) (.+)$
REBIND <run-id> <sender-id>                 ^REBIND ([a-z0-9-]+) ([^ ]+)$
```

B9 (AM-5 26, 21, queue row 29; `part-b-desk.md:179`, `:184`) adds three gates to B8:
`grant.<subtask>.<n>` (A.2.1 grant row, AM-4 20 Q1), `H-destructive.<row-id>` (a human grant for
a destructive post-merge test row; `<row-id>` as D2.2 row 12, `[A-Za-z0-9.-]+`) and
`RESUME.<subtask>` (the only exit from `stopped`, A.8 O-4). B9 writes them as
`GATE <gate> ok <text>`; the desk accepts them in the B8 form with `<run-id>` (the run must
resolve; a line without it fails the regex).

Every gate-file name carries the run id (A.2.1 AM-5 26): `<gate>.<run-id>.<verdict>`, so one
desk session serving several runs cannot confuse them. Below, `<rid>` is the line's `<run-id>`.

A line that fails its regex, or names a `<run-id>` with no `$DELIVERY_ROOT/<run-id>/state.md`,
is answered in the session with what failed; nothing is written.

## Gate x verdict matrix

| Gate | Allowed verdicts | File written | Desk enforcement |
|---|---|---|---|
| `H0` | ok | `RUN_HOME/gates/H0.<rid>.ok` | none (the conductor waits for the file) |
| `H1` | ok, changes, reject | `RUN_HOME/gates/H1.<rid>.ok` / `.changes` / `.reject` | only `H1.<rid>.ok` unlocks `jira-create` |
| `H-e2e.<subtask>` | ok | `RUN_HOME/<subtask>/gates/H-e2e.<subtask>.<rid>.ok` | none at the desk; the lead refuses e2e generation without it |
| `H-prod.<step_id>` | ok | `RUN_HOME/gates/H-prod.<step_id>.<rid>.ok` | `publish`; `tag-push` under `release_tags.approval: human` |
| `H-pr` | none | nothing: external evidence only (the approving review, B5) | `pr-merge` refuses without the read-back |
| `grant.<subtask>.<n>` | ok | `RUN_HOME/gates/grant.<subtask>.<n>.<rid>.ok` (A.2.1, AM-4 20 Q1; B9) | none at the desk; a `pre-pr-gate` sensitive-path hit passes only with a desk `INSTALLED` row for that path or this file |
| `H-destructive.<row-id>` | ok | `RUN_HOME/gates/H-destructive.<row-id>.<rid>.ok` (A.2.1 AM-5 21; B9) | the desk honours the line and writes the file; `post-merge-verify` refuses the row without it (`POSTMERGE: STOP`, D1.1) |
| `RESUME.<subtask>` | ok | `RUN_HOME/gates/RESUME.<subtask>.<rid>.ok` (A.8, O-4; B9) | none at the desk; the conductor moves a `stopped` sub-task on only with this file (owner action) |

Any other gate-verdict pair is refused in the session and nothing is written.

## File content (A.2.1)

Key=value lines, written to a temp file in the same directory and `mv`d into place:

| Key | Value |
|---|---|
| `utc=` | ISO 8601 UTC `YYYY-MM-DDTHH:MM:SSZ` |
| `by=` | the OS login of the desk session, `id -un` |
| `ref=` | computed by the desk (below); a leading `ref=<value>` token in `<text>` overrides it (used for `jira:<KEY>@<comment-id>`) |
| `text=` | the typed text (after any leading `ref=` token) |
| `notes=` | `H1.<rid>.changes` and `H1.<rid>.reject` only: `RUN_HOME/gates/H1.notes.md` |

| Gate | Computed `ref=` |
|---|---|
| `H0` | sha256 of `plans_dir/brief.md` (`plans_dir` from `state.md`) |
| `H1` | sha256 of `h1-packet.md`, or the typed `jira:<KEY>@<comment-id>` |
| `H-e2e.<subtask>` | sha256 of the batched `.feature` list named in `test-plan.md` for that sub-task |
| `H-prod.<step_id>` | the release-plan `step_id` |
| `H-destructive.<row-id>` | the `<row-id>` (H-prod form; `DEFAULT (author)`, A.2.1 names no `ref=`) |
| `RESUME.<subtask>` | the `<subtask>` (`DEFAULT (author)`, A.2.1 names no `ref=`) |
| `grant.<subtask>.<n>` | the sensitive path (A.2.1 "`ref=` names the sensitive path"); the desk cannot compute it, so the typed `<text>` must start with `ref=<path>`, else the line is refused in the session and nothing is written (`DEFAULT (author)`) |

H1 history: before writing any `H1` file, rename every existing `H1.<rid>.ok`, `.changes`,
`.reject` and `H1.notes.md` to `<name>.<yyyymmddThhmmssZ>`, so one live H1 file remains. For
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
