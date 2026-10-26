# delivery-desk: the 12 checks, the registry, inflight and markers

Depth for `SKILL.md` Steps 1 and 3-14. Authority: INTERFACES 1.2.0 part B (B1, B2, B3, B5, B6,
B7) and part A (A.1, A.2.2, A.6, A.7). This file restates them for the desk operator; where it
and part B differ, part B wins and this file is wrong.

## Sender registry (B1)

| Item | Rule |
|---|---|
| Where | In the desk session, mirrored after every change to `$DELIVERY_ROOT/desk-inbox/<run-id>.registry` (temp file plus `mv`, 0600). A desk restart reloads every mirror. `state.md` holds no registry the desk reads. |
| Content | Per run: the `run` sender id (the conductor that claimed the run) and one sender id per registered `st<N>` or `pm`. |
| First line of a run | Must be `REGISTER-SENDER <run-id> \| run \| <sender-id>` with `<sender-id>` equal to the transport sender; anything else for an unknown run is `refused`. |
| Later lines | Accepted only when the transport sender is the run's `run` id. A line for a registered `<subtask>` replaces its id (lead hand-over, C5.3). An identical repeat is `ok` (the conductor re-sends every line after its own resume). |
| Re-claim | A resumed conductor with a new sender id is `refused` until the human types `REBIND <run-id> <sender-id>`; the desk then sets `run` to that id and expects the conductor to re-send every line. |
| `claude -p` leads | Get no line (`<identity>` `-`). The conductor relays their `DESK` lines as the transport sender; the desk then needs the JSON `subtask` to equal the id's `<subtask>` (check 5). |
| Non-lead requesters | `ticket-clerk`, `ci-fix-loop`, `delivery-cleanup`, `release-track` hold no entry; their host session sends the line, so the sender is that host's registered id. |
| Replies | `REGISTERED <run-id> \| <subtask\|run> \| ok\|refused`, one per line received. |

## The 12 checks (B3; first failure wins)

| # | Check | Code on failure | `.out` |
|---|---|---|---|
| 1 | Sender from the transport is in the run's registry; conductor-only verb needs `<subtask>` `run` and the registered conductor; any `run` id needs the registry's `run` sender | `sender` | **none** |
| 2 | `RUN_HOME/desk/<id>.out` exists: re-send its reply and stop (no hash compare) | (replay) | stored |
| 3 | Copy `RUN_HOME/desk/<id>.req` to `$DELIVERY_ROOT/desk-inbox/<id>.req` (desk-owned, 0700 dir; kept until the run is archived at CYCLE DONE) | a missing or unreadable `.req` is `schema` (author default: the line names a file that does not exist) | yes |
| 4 | `shasum -a 256` of the copy equals `sha256=<hex>` | `hash` | yes |
| 5 | Copy validates: path equals `RUN_HOME/desk/<id>.req`; verb in B4; JSON envelope `id`, `verb`, `subtask` equal the line; `fields` passes `schemas.json` `verbs.<verb>.request`; `pr-merge` `method` equals profile `merge_method`, `fields.subtask` equals the `record_path` `<subtask>` segment | `schema` | yes |
| 6 | Per-field roots (below); redaction (B7); never-granted request; `tag-push` profile entry (N11) | `repo` or `policy` | yes |
| 7 | Session freshness (GitHub for `gh`/`git` verbs, Atlassian for `jira-*` and `test-report-push`) | `stale-session` | yes |
| 8 | Gate files (`H1.ok`; `H-prod.<step_id>.ok`; `tag-push` only under `approval: human`); `pr-merge` `merge_reach` row; then predecessors; then markers | `gate-missing`, `order`, `marker` | yes |
| 9 | `mkdir desk/<id>.inflight`, write `target`, duplicate guard, act | `action-failed` | yes |
| 10 | Write `desk/<id>.out` atomically at 0600 | - | - |
| 11 | Append one redacted JSON line per request and per result to `$DELIVERY_ROOT/desk-log/<run-id>.jsonl` | - | - |
| 12 | Reply `DONE` or `REJECTED` | - | - |

Inside check 6 the order is: `repo` (the profile resolution and the registered clone), `branch`,
path roots, then redaction, then never-granted, then `release_tags`. Inside check 8: gate files,
then `order`, then markers in the B5 order (head, gate run, review record, H-pr, CI). The
`request_sha256` of a `.out` is the copy's hash; it is null only when the reject precedes check
4 (a check 3 failure).

### Per-field roots (check 6, B4 per-field rules)

| Field | Rule (realpath first, then compare) |
|---|---|
| `repo` | under a `clones[]` entry of the primary profile or of a `linked_profiles[]` profile; resolves to no profile: `repo` |
| `branch` | `^[A-Z][A-Z0-9]+-[0-9]+(-[a-z0-9-]+)?$` (`<JIRA-KEY>(-[a-z0-9-]+)?`) |
| `body_path` | under `RUN_HOME/review/` or `RUN_HOME/bodies/` |
| `payload_path` | under `RUN_HOME/bodies/` (`test-report-push`) |
| `record_path` | under `RUN_HOME/review/<subtask>/`, file name `record-<expect_head>.md` |
| `pr-attach` `paths[]` | under `RUN_HOME/<subtask>/lanes/` (the id's `<subtask>`) |

Profile resolution (A.2.2): read `RUN_HOME/state.md` `repo_profile` (`<path>@<sha>`, the git blob
id); read the profile with `git cat-file blob <sha>` (or verify `git hash-object <path>` equals
`<sha>`). A linked profile that cannot be read at its sha is `policy` for `tag-push` and `repo`
for every other verb.

### Redaction (check 6, B7)

- Patterns: `secrets.pattern_file` of the resolved profile, one ERE per line; scan with
  `grep -E -q -f <pattern_file>`.
- Scanned: every string field of the request; every file named by `body_path`, `payload_path`,
  `record_path` and `pr-attach` `paths[]` except images; the `ci-logs` output before it is stored
  (a hit there refuses the request; nothing is stored).
- Images in `pr-attach` (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`; author default extension set)
  are attached unscanned; the requester's `pr-comment` labels them as unscanned screenshots.
- A zip trace is scanned on its members (`unzip -p <file> | grep -E -q -f <pattern_file>`;
  author default, since a byte scan of a compressed file sees nothing).
- A hit is `REJECTED policy`; `detail` names the field or file, never the matched text. Nothing
  is masked and sent.
- Scan the file once, and use the bytes that were scanned (read it into the desk's own memory or
  a desk-owned copy under `desk-inbox/`), so a file changed after the scan is never sent (same
  reasoning as M29 copy and hash; author default).
- Log lines (`desk-log/`) are redacted before append.

## Markers (check 8, B5)

The per-verb list is FROZEN: `push` head, gate run; `pr-create` head, gate run, review record;
`pr-merge` head, gate run, review record, H-pr, CI, order, `merge_reach`; `branch-delete`
content-merged. The desk derives each one itself; nothing the requester wrote counts.

| Marker | How the desk derives it | Fails as |
|---|---|---|
| head | `push`: `git -C <repo> rev-parse refs/heads/<branch>` equals `expect_head`; `pr-create`: the same live branch head; `pr-merge`: `gh pr view <pr> --json headRefOid` equals `expect_head` | `marker` |
| gate run | `RUN_HOME/<subtask>/gate-runs/<expect_head>.md` exists and line 1 matches `^GATE-PASS ([0-9a-f]{40}) (.+)$` with group 1 = `expect_head` (A.7; for `pr-merge` the `<subtask>` is `fields.subtask`) | `marker` |
| review record | at `record_path`: line 1 `^CODE-GATE-REVIEW: PASS head=([0-9a-f]{40}) blocking=0 medium=0$`, line 2 `^Reviewed-By: ([a-z0-9-]+) ([a-z0-9-]+) ([A-Za-z0-9_-]+)$`, line 3 `^Verified-By: ([a-z0-9-]+) head=([0-9a-f]{40})$`; both heads equal `expect_head`; line 3 seat differs from line 2 seat (A.6) | `marker` |
| H-pr | `gh pr view <pr> --json reviewDecision,headRefOid,author,latestReviews` (or `gh api repos/<o>/<r>/pulls/<pr>/reviews` for `commit_id`): `reviewDecision == APPROVED` and at least one review `state == APPROVED` by a login that is not the PR author and does not end in `[bot]`, with `commit_id == headRefOid` | `marker` |
| CI | the B6 `ci-status` aggregate over the profile `ci.required_checks[]` is `success` on the landing head | `marker` |
| order | every `predecessors[]` PR is merged (`gh pr view <n> --json state` is `MERGED`) | `order` |
| `merge_reach` | the profile row exists (checked first, at the gate step) | `gate-missing` |
| content-merged | after a desk-side `git fetch`: `git merge-base --is-ancestor <branch-head> <merged_into>` (`ancestor`); else every branch commit has a patch-id match in `git cherry <merged_into> <branch>` with no `+` lines (`patch-id`); else (squash of 2+ commits) `git patch-id --stable` of `git diff <merge-base> <branch-head>` equals that of `git diff S^ S` with `S` = `merge_sha`, which must equal line 2 of `RUN_HOME/merge-<merge_sha>.md` (`squash`) | `marker` (never `DONE deleted=false`) |

CI bounds that are not leases (row R4-J20): `push` waits up to 5 minutes for
`ci.min_push_spacing_s` since the last desk push to that repo to clear, else `REJECTED marker`
with `detail` `push-spacing`; `pr-create` counts the repo's open PRs with `gh` and at
`ci.max_open_pr_pipelines` answers `REJECTED marker` with `detail` `pipeline-bound`.

## Inflight and the duplicate-action guard (B2 idempotency, check 9)

1. `mkdir RUN_HOME/desk/<id>.inflight` is the atomic claim; if it already exists for this id and
   no `.out` exists, a previous attempt stopped mid-action: read the target back (PR, ref, issue
   or tag present?) and answer `DONE` from the read-back if present, else act.
2. Write `desk/<id>.inflight/target`, one line `<verb> <target>`:

| Verb | `<target>` |
|---|---|
| `push`, `pr-create` | `repo#branch@expect_head` |
| `branch-delete` | `repo#branch` |
| `pr-merge`, `pr-attach` | `repo#pr` |
| `tag-push` | `repo#tag@sha` |
| `jira-create` | parent key (or `-` for an epic) plus the summary |
| `jira-update`, `jira-transition` | the issue key |
| `publish` | `package@version` |
| `test-report-push` | `payload_path` |

   Read-only verbs (`pr-comments-read`, `pr-approval-state`, `ci-status`, `ci-logs`,
   `ci-status-main`, `fetch`, `jira-get`) and `pr-comment`, `ci-rerun` have no target form in
   B2; write `<verb> <id>` for them (author default), so the guard never matches across ids.
3. Before acting, scan `desk/*.inflight/target` for the same line under another id whose `.out`
   is missing or not `DONE`. If one exists, read the target back first; when the action is
   already present answer `DONE` from the read-back without acting. For `push`, `pr-create` and
   `tag-push`, "present" means the remote ref or the PR head equals the target's `@<sha>`, so a
   new head is never answered from an older inflight.
4. On `action-failed` the `.inflight` directory stays; a later fresh-id resend of the same
   `<verb> <target>` reconciles by read-back.

## Requester-side rules the desk relies on (B1, for diagnosis only)

- A `claude -p` lead polls `.out` (authoritative) up to 5 minutes, re-sends the same `<id>` once,
  then renames `<id>.req` to `<id>.req.noreply` and escalates. The desk answers the re-send from
  the stored `.out` (check 2) or processes it if none exists.
- On resume each requester applies `DONE` results its own record does not show yet (applied-result
  scan, row R4-J9) before sending anything new.
