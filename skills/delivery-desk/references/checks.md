# delivery-desk: the 12 checks, the registry, inflight and markers

Depth for `SKILL.md` Steps 1 and 3-14. Authority: INTERFACES 1.10.0 (AM-6 to AM-10 applied) part B (B1, B2, B3, B5, B6,
B7, B9: `architecture/delivery-workflow/interfaces/part-b-desk.md:7-76`, `:108-151`, `:175-188`)
and part A (A.1, A.2.2, A.6, A.7, A.8: `.../interfaces/part-a-state.md:7-53`, `:109-161`,
`:293-354`, `:356-378`). Bare ids
(M29, R4-J20, ...) resolve in `references/source-keys.md`. This file restates them for the desk operator; where it
and part B differ, part B wins and this file is wrong.

## Sender registry (B1)

| Item | Rule |
|---|---|
| Where | In the desk session, mirrored after every change to `$DELIVERY_ROOT/desk-inbox/<run-id>.registry` (temp file plus `mv`, 0600). A desk restart reloads every mirror. `state.md` holds no registry the desk reads. |
| Content | Per run: the `run` sender id (the conductor that claimed the run) and one sender id per registered `st<N>` or `pm`. |
| First line of a run | Must be `REGISTER-SENDER <run-id> \| run \| <sender-id>` with `<sender-id>` equal to the transport sender; anything else for an unknown run is `refused`. |
| Later lines | Accepted only when the transport sender is the run's `run` id. A line for a registered `<subtask>` replaces its id (lead hand-over, C5.3). An identical repeat is `ok` (the conductor re-sends every line after its own resume). |
| Re-claim | A resumed conductor with a new sender id is `refused` until the human types `REBIND <run-id> <sender-id>`; the desk then sets `run` to that id and expects the conductor to re-send every line. |
| `claude -p` leads | Get no line (`<identity>` `-`). The conductor relays their `DESK` lines as the transport sender; the desk then needs the JSON `subtask` to equal the id's `<subtask>` (check 5). A line the conductor refuses to relay (wrong `<subtask>` or a conductor-only verb) never reaches the desk: the conductor writes `outbox/<id>.desk.refused` and the lead treats it as terminal `sender` (C5.1, `part-c-waves-control.md:117`, AM-4 W2-4); the desk writes nothing for it. |
| Non-lead requesters | `ticket-clerk`, `ci-fix-loop`, `delivery-cleanup`, `release-track` hold no entry; their host session sends the line, so the sender is that host's registered id. |
| Replies | `REGISTERED <run-id> \| <subtask\|run> \| ok\|refused`, one per line received. |

## The 12 checks (B3; first failure wins)

| # | Check | Code on failure | `.out` |
|---|---|---|---|
| 1 | Sender from the transport is in the run's registry; conductor-only verb needs `<subtask>` `run` and the registered conductor; any `run` id needs the registry's `run` sender | `sender` | **none** |
| 2 | `RUN_HOME/desk/<id>.out` exists: re-send its reply and stop (no hash compare) | (replay) | stored |
| 3 | Copy `RUN_HOME/desk/<id>.req` to `$DELIVERY_ROOT/desk-inbox/<id>.req` (desk-owned, 0700 dir; kept until the run is archived at CYCLE DONE) | a missing or unreadable `.req` is `schema`, `request_sha256` null (author default: the line names a file that does not exist) | yes |
| 4 | `shasum -a 256` of the copy equals `sha256=<hex>` | `hash` | yes |
| 5 | Copy validates: path equals `RUN_HOME/desk/<id>.req`; verb in B4 (a verb outside the 20, such as approve, trigger-prod or pipeline-edit, stops here as `schema`, never `policy`); JSON envelope `id`, `verb`, `subtask` equal the line; `fields` passes `schemas.json` `verbs.<verb>.request` (a `ref`, `base`, `merged_into`, `tag` or `package` starting with `-` fails here: raw flag, a contract rule, B9 26; an int written as `-0` or in exponent form fails here, read on the raw `.req` text, A.8 A.5; a non-Epic `jira-create` without `parent` fails here, B9 26); `pr-merge` `fields.subtask` equals the `record_path` `<subtask>` segment (the `method` check is in check 6, `repo`, INTERFACES 1.8.0 AM-8 V7). The branch regex is deliberately **not** part of this check (`schemas.json` `definitions.branch` carries no pattern) | `schema` | yes |
| 6 | Per-field roots and the branch regex (below); `pr-merge` `method` equals the resolved profile `merge_method` (else `repo`, AM-8 V7); redaction (B7); never-granted request (also a `test-report-push` first call with `dry_run: false`, B9 26); `tag-push` profile entry (N11) | `repo` or `policy` | yes |
| 7 | Session freshness (GitHub for `gh`/`git` verbs, Atlassian for `jira-*` and `test-report-push`) | `stale-session` | yes |
| 8 | Gate files (`H1.<run-id>.ok`; `H-prod.<step_id>.<run-id>.ok`; `tag-push` only under `approval: human`; names per A.2.1 AM-5 26); `pr-merge` `merge_reach` row; then predecessors; then markers | `gate-missing`, `order`, `marker` | yes |
| 9 | `mkdir desk/<id>.inflight`, write `target`, duplicate guard, act | `action-failed` | yes |
| 10 | Write `desk/<id>.out` atomically at 0600 | - | - |
| 11 | Append one masked (`[REDACTED]`, AM-8 V7) JSON line per request and per result to `$DELIVERY_ROOT/desk-log/<run-id>.jsonl` | - | - |
| 12 | Reply `DONE` or `REJECTED` | - | - |

Inside check 6 the order is: `repo` (the profile resolution and the registered clone, then the `pr-merge` `method` against `merge_method`), `branch`,
path roots, then redaction, then never-granted, then `release_tags`. Inside check 8: gate files,
then `order`, then markers in the B5 order (head, gate run, review record, H-pr, CI). The
`request_sha256` of a `.out` is the copy's hash; it is null only when the reject precedes check
4 (a check 3 failure).

### Per-field roots (check 6, B4 per-field rules)

| Field | Rule (realpath first, then compare) |
|---|---|
| `repo` | under a `clones[]` entry of the primary profile or of a `linked_profiles[]` profile; resolves to no profile: `repo` |
| `branch` | `^[A-Z][A-Z0-9]+-[0-9]+(-[a-z0-9-]+)?$` (`<JIRA-KEY>(-[a-z0-9-]+)?`); a branch that fails it (including one starting with `-`) is `repo` here, at check 6, per part B2.1 `repo` row and B3 step 6, so it is never checked at 5 |
| `body_path` | under `RUN_HOME/review/` or `RUN_HOME/bodies/` |
| `payload_path` | under `RUN_HOME/bodies/` (`test-report-push`) |
| `record_path` | under `RUN_HOME/review/<subtask>/`, file name `record-<expect_head>.md`; the `<subtask>` segment is the id's `<subtask>` for `pr-create` and `fields.subtask` for `pr-merge` (whose id subtask is `run`) |
| `pr-attach` `paths[]` | under `RUN_HOME/<subtask>/lanes/` (the id's `<subtask>`) |

Profile resolution (A.2.2): read `RUN_HOME/state.md` `repo_profile` (`<path>@<sha>`, the git blob
id); read the profile with `git cat-file blob <sha>` (or verify `git hash-object <path>` equals
`<sha>`). A linked profile that cannot be read at its sha is `policy` for `tag-push` and `repo`
for every other verb. Repo-less verbs (`jira-*`, `test-report-push`) use the primary profile
(`DEFAULT (author)`), so `secrets.pattern_file`, `jira.status_map` and `jira.archive_status` come
from it.

### Redaction (check 6, B7)

- Patterns: `secrets.pattern_file` of the resolved profile (primary profile for repo-less verbs), one ERE per line; scan with
  `grep -E -q -f <pattern_file> -- <file>` (or the field text on stdin).
- Fails closed (R1-6; code `policy` is an author default, part B names none): before any scan the
  pattern file must exist, be readable and hold at least one non-empty line; else `REJECTED
  policy`, `detail` `pattern-file <absent|unreadable|empty>` (the key, never content). Each scan's
  exit is read exactly: 1 is clean, 0 is a hit (`policy`), and any other exit (2 or more, a
  signal, a timeout) is `REJECTED policy` with `detail` `scan-error <field or file>`. A scan that
  did not run is never read as clean.
- Scanned: every string field of the request; every file named by `body_path`, `payload_path`,
  `record_path` and `pr-attach` `paths[]` except images; the `ci-logs` output before it is stored
  (a hit there is masked as `[REDACTED]` and the log is stored, B7 split, INTERFACES 1.8.0 AM-8 V7; a
  request body or attached file with a hit is still refused `policy`).
- `pr-attach` copy (ADR 0055 §3, `decisions/0055-desk-verb-permission-tiers-02.md:185-191`: the
  desk acts on what it copied; author default layout): after the root check, copy each `paths[]`
  file once, without following symlinks (`cp -P`), to `$DELIVERY_ROOT/desk-inbox/<id>.attach/<k>-<basename>`
  (`<k>` its index; desk-owned, 0700); a copy that is not a regular file is `repo`. Classify,
  scan and upload that copy only; the `lanes/` path is never read again after the copy, so a file
  swapped in after classification is never attached. `attached[].path` stays the request's path.
- Images in `pr-attach` are classified by content, not by name (R1-7; author default method), on
  the desk copy: a file is an image only when `file --brief --mime-type -- <copy>` prints `image/png`,
  `image/jpeg`, `image/gif` or `image/webp` **and** its extension (`.png`, `.jpg`, `.jpeg`,
  `.gif`, `.webp`) names the same type. Only such a file is attached unscanned (part B7,
  `part-b-desk.md:147`: "images are attached unscanned and labelled as such"); the requester's
  `pr-comment` labels it as an unscanned screenshot. Every other file, including a `.png` whose
  content is text or another type, is scanned like a trace; a hit is `policy`.
- A zip trace is scanned on its members (`unzip -p <file> | grep -E -q -f <pattern_file>`;
  author default, since a byte scan of a compressed file sees nothing); a non-zero `unzip` exit
  is `scan-error`, as above.
- A hit is `REJECTED policy`; `detail` names the field or file, never the matched text. Nothing
  is masked and sent.
- Scan the file once, and use the bytes that were scanned (read it into the desk's own memory or
  a desk-owned copy under `desk-inbox/`), so a file changed after the scan is never sent (same
  reasoning as M29 copy and hash; author default).
- Log lines (`desk-log/`), `ci-logs` output and a `.out` `detail` are masked before they are stored: each pattern-file hit is replaced by `[REDACTED]` and the line is kept (B7, INTERFACES 1.8.0 AM-8 V7; CI logs masked, not refused, INTERFACES 1.9.0 AM-9). Masking applies to logs only; a request body or attached file with a hit is refused `policy` (above), never masked and sent.

## Markers (check 8, B5)

The per-verb list is FROZEN: `push` head, gate run (plus the AM-4 first/later-push evidence, `verbs.md` §`push`); `pr-create` head, gate run, review record;
`pr-merge` head, gate run, review record, H-pr, CI, order, `merge_reach`; `branch-delete`
content-merged. The desk derives each one itself; a marker the request claims counts for
nothing. The only requester-host files read are the ones INTERFACES names, each compared to a
desk-derived value: the gate-run record and the review record (B5), `RUN_HOME/merge-<merge_sha>.md`
line 2 (B5 squash), and for `push` the B4 push-row evidence (`part-b-desk.md:83`): `PREPR: PASS`
as line 1 of `RUN_HOME/review/<subtask>/checklist-<subtask>.md` **and** `RUN_HOME/<subtask>/substate.md`
`prepr`/`head` (A.3; both must agree, B9 26) and `RUN_HOME/ci/<pr>.md`, read only for
the desk-derived `expect_head` and `<pr>`; they can only add refusals. Every `gh` call below carries
`--repo=<gh-repo>` and every `<remote>` is the clone's `origin` (ratified in B9 26, `verbs.md` §Repository binding).

| Marker | How the desk derives it | Fails as |
|---|---|---|
| head | `push`: `git -C <repo> rev-parse --verify --end-of-options refs/heads/<branch>` equals `expect_head`; `pr-create`: the same live branch head; `pr-merge`: `gh pr view <pr> --repo=<gh-repo> --json headRefOid` equals `expect_head` | `marker` |
| first/later push | `push` only (AM-4 24-Q2): exactly one open PR for the branch (`gh pr list --head=<branch>`) makes it a later push (B9 26), which needs `RUN_HOME/ci/<pr>.md` naming `expect_head` or `PREPR: PASS` for it; otherwise a first push, which needs `PREPR: PASS` for `expect_head`. `PREPR: PASS` = checklist line 1 and `substate.md` `prepr`/`head` agree (B9 26; disagreement is `marker`, `detail` `prepr`); `verbs.md` §`push` | `marker` |
| merge target | `pr-merge` only: PR `baseRefName` equals the profile `default_branch` (A.2.2, AM-4 20 Q6; `DEFAULT (author)` code) | `marker` |
| gate run | `RUN_HOME/<subtask>/gate-runs/<expect_head>.md` exists and line 1 matches `^GATE-PASS ([0-9a-f]{40}) (.+)$` with group 1 = `expect_head` (A.7; for `pr-merge` the `<subtask>` is `fields.subtask`) | `marker` |
| review record | at `record_path`: line 1 `^CODE-GATE-REVIEW: PASS head=([0-9a-f]{40}) blocking=0 medium=0$`, line 2 `^Reviewed-By: ([a-z0-9-]+) ([a-z0-9-]+) ([A-Za-z0-9_-]+)$`, line 3 `^Verified-By: ([a-z0-9-]+) head=([0-9a-f]{40})$`; both heads equal `expect_head`; line 3 seat differs from line 2 seat (A.6) | `marker` |
| H-pr | `gh pr view <pr> --repo=<gh-repo> --json reviewDecision,headRefOid,author,latestReviews` (or `gh api repos/<gh-repo>/pulls/<pr>/reviews` for `commit_id`): `reviewDecision == APPROVED` and at least one review `state == APPROVED` by a login that is not the PR author and does not end in `[bot]`, with `commit_id == headRefOid` | `marker` |
| CI | the B6 `ci-status` aggregate over the profile `ci.required_checks[]` is `success` on the landing head | `marker` |
| order | every `predecessors[]` PR is merged (`gh pr view <n> --repo=<gh-repo> --json state` is `MERGED`) | `order` |
| `merge_reach` | the profile row exists (checked first, at the gate step) | `gate-missing` |
| content-merged | first a desk-side fetch of both refs: `git -C <repo> fetch -- <remote> refs/heads/<merged_into>:refs/remotes/<remote>/<merged_into> refs/heads/<branch>:refs/remotes/<remote>/<branch>`. Let `M` = `refs/remotes/<remote>/<merged_into>` and `H` = `refs/remotes/<remote>/<branch>` as just fetched (part B5 "after a desk-side fetch", `part-b-desk.md:110`); a local `refs/heads/` name, which an agent can move, is never used, and there is no local fallback. Then `git merge-base --is-ancestor --end-of-options H M` (`ancestor`); else every branch commit has a patch-id match in `git cherry --end-of-options M H` with no `+` lines (`patch-id`); else (squash of 2+ commits) `git patch-id --stable` of `git diff --end-of-options <merge-base M H> H` equals that of `git diff --end-of-options S^ S` with `S` = `merge_sha`, which must be reachable from `M` and equal line 2 of `RUN_HOME/merge-<merge_sha>.md` (`squash`) | `marker` (never `DONE deleted=false`) |

CI bounds that are not leases (row R4-J20): `push` waits up to 5 minutes (default; source
`architecture/delivery-workflow/interfaces/part-b-desk.md:83`, marked `DEFAULT (integrator)`) for
`ci.min_push_spacing_s` since the last desk push to that repo to clear, else `REJECTED marker`
with `detail` `push-spacing`. The wait is never one blocking sleep: the desk re-checks in slices
of at most 60 seconds and between slices answers only `STATUS` lines (`SKILL.md` step 15;
every other line waits in the queue, §Inflight item 0) (author default slice; the 2-minute `BUSY` bound is
`architecture/permission-tiers-02.md:100-101`); `pr-create` counts the repo's open PRs with `gh` and at
`ci.max_open_pr_pipelines` answers `REJECTED marker` with `detail` `pipeline-bound`.

## Inflight and the duplicate-action guard (B2 idempotency, check 9)

0. One request at a time (ratified in B9 26, `part-b-desk.md:178`; part B's guard, `part-b-desk.md:47`, assumes the
   earlier attempt has stopped). While a request is in checks 1-12, including a wait or a slow
   act, the desk answers only `STATUS` (step 15); every other `DESK`, `REGISTER-SENDER` or human
   line is queued in arrival order and handled after the current id has its `.out` (or its
   `REJECTED sender` reply). So every `.inflight` the desk meets has no live handler: it is a
   stopped attempt of this session or one left by an earlier session.
1. Crash-resume, one place: B3 step 2 (`SKILL.md` step 5). A repeat `<id>` with
   `desk/<id>.inflight` and no `.out` is a stopped attempt (item 0). Why step 2: part B
   (`part-b-desk.md:47`) asks for the read-back "before acting again", and B3 settles a repeat id
   at step 2; checks 3-8 re-read state the stopped act may already have changed (a deleted remote
   branch fails content-merged as `marker`, a created PR moves the open-PR count), so placing it at
   the claim would answer `REJECTED` for an act that happened. Reconcile only when the desk copy
   `desk-inbox/<id>.req` exists (the earlier attempt passed checks 3-8 before its claim) and the
   `target` verb equals the line's verb; else go on at check 3. Read the target back (item 2
   form): PR, ref, issue, tag or registry entry present, `@<sha>` equal (item 3); for
   `branch-delete` present means `git ls-remote -- <remote> refs/heads/<branch>` prints nothing.
   Present: write the `.out` `DONE` with result fields from the read-back, `request_sha256` the
   hash of the existing desk copy, and values check 8 derived that a read-back cannot give
   (`branch-delete` `merged_check`) from `desk-inbox/<id>.derived`, which step 9 writes before
   acting (author default); then reply and stop. Absent: go on at check 3; step 9 reuses the
   `.inflight`. `mkdir RUN_HOME/desk/<id>.inflight` is the atomic claim at step 9.
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

## Reason codes (B2.1; first failing check wins; moved from `SKILL.md`)
| Code | Class | B3 step | Trigger (short) |
|---|---|---|---|
| `sender` | terminal | 1 | sender not registered; conductor-only or `run` id from a non-conductor |
| `schema` | terminal | 5 | copy fails the closed schema or the line cross-check; verb outside B4 (approve, trigger-prod, pipeline-edit); ref, base, merged_into, tag or package starting with `-`; non-Epic `jira-create` without `parent` (B9); int as `-0` or exponent |
| `hash` | terminal | 4 | copy sha256 differs |
| `repo` | terminal | 6 | repo not a registered clone; branch regex; path outside its root; `pr-merge` `method` differs from the profile `merge_method` (AM-8 V7) |
| `policy` | terminal | 6 | never-granted in-schema request; `test-report-push` first call with `dry_run: false` (B9); `tag-push` not allowed by profile; redaction hit; pattern file unusable or scan error |
| `stale-session` | curable | 7 | GitHub or Atlassian session not fresh |
| `gate-missing` | curable | 8 | `H1.<run-id>.ok`, `H-prod.<step_id>.<run-id>.ok` or `merge_reach` row absent |
| `order` | curable | 8 | a `pr-merge` predecessor not merged |
| `marker` | curable | 8 | a re-derived marker fails (also `push-spacing`, `pipeline-bound`; a `jira-create` parent missing at re-fetch, AM-8 V7) |
| `action-failed` | curable | 9 | valid request, the action failed |

Terminal: stop-the-line for that request; the requester reports it to the owner and never
resends it. Curable: "a curable code may be resent with a fresh id once its cause clears" (owner ruling
OP5 B, `architecture/delivery-workflow-sources/owner-decisions.md:67`); part B2.1: "the
requester may resend with a fresh id on the same channel once the cause clears"
(`architecture/delivery-workflow/interfaces/part-b-desk.md:54`). A fresh id is a new `<n>`;
the same id only replays the stored `REJECTED` (B3 step 2, `part-b-desk.md:47`). For the
conductor's own requests B9 (29-33) names the trigger per curable code: `marker` when `head` or
`review_record` changed; `order` when the predecessor has `merge_sha`; `action-failed`,
`stale-session` and `gate-missing` on the owner's word. `stale-session` here is the B2.1 desk
code; the A.3 `stop_reason: stale-session` (a second `pm` lead on a fresh `substate.lock`, A.8)
is a lead stop, not a desk reply.

## Requester-side rules the desk relies on (B1, for diagnosis only)

Sender side, for reference only (the desk never calls it): `tools/delivery/desk-req.sh <run-id>
<subtask|run> <verb> <fields-json-file>` writes `RUN_HOME/desk/<id>.req` (0600) and prints the
`DESK` line; exit 0 ok, 2 usage, 4 lock timeout (INTERFACES §Script interfaces, `INTERFACES.md:55-63`). (moved from `SKILL.md`)

- A `claude -p` lead polls `.out` (authoritative) up to 5 minutes, re-sends the same `<id>` once,
  then renames `<id>.req` to `<id>.req.noreply` and escalates (default; source
  `architecture/delivery-workflow/interfaces/part-b-desk.md:22`, marked `DEFAULT (integrator)`). The desk answers the re-send from
  the stored `.out` (check 2) or processes it if none exists.
- On resume each requester applies `DONE` results its own record does not show yet (applied-result
  scan, row R4-J9) before sending anything new; the conductor runs it before every send, its
  `REGISTER-SENDER` re-send included (B9 29-10).
- Conductor send gate (B9 29-16, 29-27): until the desk answers `REGISTERED <run-id> | run | ok`
  the conductor sends only the `run` claim and its one re-send, so the desk sees no lead line,
  relay or conductor request for that run before it; lead `REGISTER-SENDER` lines stay gated.
  Every conductor send (registration, its own `pr-approval-state`/`pr-merge`, each relayed
  `CONDUCTOR-REQUEST`) is re-sent once with the same line or id, then becomes a human step
  (`<id>.req.noreply`, terminal `sender`, B9 29-7); before minting an id it adopts its own `.req`
  with the same verb and fields and no `.out`, so the desk never sees one request under two ids.
  A relay or `CONDUCTOR-REQUEST` the conductor refuses (`.desk.refused`, `.refused`) never reaches
  the desk and is logged only in the conductor's turn output and status post (B9 29-4).
