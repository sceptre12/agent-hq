# delivery-desk: the 20 verbs

One section per B4 verb: requester and result reader, request `fields`, what the desk checks
beyond the common 12 (`checks.md`), how it acts, and the `DONE` result fields (B6). The machine
form of fields and results is `schemas.json`; part B4-B6 and the B9 additions
(`architecture/delivery-workflow/interfaces/part-b-desk.md:77-143`, `:175-188`, INTERFACES 1.7.0, AM-6 B-9a and f applied)
are the authority; bare ids (D3,
M24, N11, ...) resolve in `references/source-keys.md`. "Act" lines name the
command family the desk uses under the operator's own auth; where INTERFACES fixes only the
fields and not the command, the line says **measured at the move**, and the desk must not guess
a command for it before that measurement.

No raw flag reaches argv (ADR 0055 §4, `decisions/0055-desk-verb-permission-tiers-02.md:198`
"Never accepts raw flags or force options"). Two layers: (1) check 5 refuses a `ref`, `base`,
`merged_into`, `tag` or `package` that starts with `-` (`schema`, `schemas.json` patterns, same
rule as `tools/delivery/desk-req-schema.sh:28-29`, `:38`; a contract rule, B9 26, PR10-R2), and
an int written as `-0` or in exponent form is `schema` too (A.8 A.5 numeric guard); a `branch`
that fails its regex is `repo` at check 6; (2) every request-derived value below is placed after `--` (git
transport commands, `gh`) or `--end-of-options` (git revision commands), passed as a fully
qualified `refs/...` name, or attached to its option as `--opt=<value>`. `repo` is an absolute
path, shas are 40-hex and `pr`/`ci_run_id` are integers, so none of them can start with `-`.

Repository binding (desk defaults ratified in B9 (26), `part-b-desk.md:178`: remote `origin`,
`--repo` from the origin URL; part B makes `repo` the only target check, `part-b-desk.md:14`): every act and read is bound to the request `repo` after check 6 has
realpath'd it under a registered clone. `<remote>` is `origin` of that clone (the profile
`clones[]` entry is a path only, `part-a-state.md:119`). Git acts use `git -C <repo>`. Every
`gh` call carries `--repo=<gh-repo>`, where `<gh-repo>` is the `<owner>/<name>` the desk parses
from `git -C <repo> remote get-url origin` (a GitHub `https://` or `git@` URL); a `gh api` path
uses the same `<gh-repo>` (`repos/<gh-repo>/...`). A remote URL the desk cannot parse is `repo`
at check 6. `gh` never takes its repository from the desk session's working directory.

Every `DONE` `.out` carries the envelope (`id`, `verb`, `status` `DONE`, `reason` null, `detail`
null, `request_sha256`, `sender`, `utc`) plus exactly the result fields listed; arrays are always
present, possibly `[]`. Wrapped work-context skills (card 15, §2.1b): `create-pr` (title from
the branch, labels, template), `harness-api` (read-only verbs), `jira`.

## Git and PR verbs

### `push` `{repo, branch, expect_head}`
- Requester: the lead, also `ci-fix-loop` in the lead. Reader: the lead. B4 (AM-4 24-Q2, W2-7,
  `part-b-desk.md:83`): the **first push of a PR** needs `GATE-PASS` and `PREPR: PASS` for
  `expect_head` (stage 5; no push precedes `pre-pr-gate`); a **later push to the same PR** needs
  the `GATE-PASS` record for `expect_head` plus `RUN_HOME/ci/<pr>.md` naming that head (a
  `ci-fix-loop` push) or `PREPR: PASS` for it. Later pushes only fast-forward.
- First or later (ratified in B9 (26): "later push" means exactly one open PR exists for the
  head's branch): the desk re-derives it from GitHub, never from the request: `gh pr list --repo=<gh-repo> --head=<branch>
  --state=open --json=number`. Exactly one open PR: a later push, `<pr>` is that number. None: a
  first push (also when the branch already exists on the remote without an open PR: the stricter
  first-push rule applies). More than one: `marker`, `detail` `pr-ambiguous`.
- `PREPR: PASS` evidence (B9 (26), owner D7 stop "Accept verified state", `OD:94`): line 1 of
  `RUN_HOME/review/<subtask>/checklist-<subtask>.md` (validator-written) is `PREPR: PASS` **and**
  `RUN_HOME/<subtask>/substate.md` has `prepr: PASS` with `head` equal to `expect_head` (A.3,
  `part-a-state.md:180-181`); both must agree, else `marker`. CI evidence: a line of
  `RUN_HOME/ci/<pr>.md` contains `expect_head` (INTERFACES fixes only its line 1 `CI:` form, part
  D1). Missing: `marker`, `detail` `prepr` (first push) or `ci-or-prepr` (later push).
- Checks: head (`git rev-parse --verify --end-of-options refs/heads/<branch>` equals `expect_head`); gate run
  `RUN_HOME/<subtask>/gate-runs/<expect_head>.md`; the first/later evidence above; push spacing (`ci.min_push_spacing_s`, wait up
  to 5 min (default; `architecture/delivery-workflow/interfaces/part-b-desk.md:83`, marked
  `DEFAULT (integrator)`, row R4-J20), else `marker` `push-spacing`).
- Act: `HUSKY=0 git -C <repo> push -- <remote> <expect_head>:refs/heads/<branch>` (`HUSKY=0` on
  every desk `git push`, inline, never exported, A.7, `interfaces/part-a-state.md:335-354`), no `--force`, no `--force-with-lease`, no `--no-verify`.
  A non-fast-forward or protection refusal is `action-failed`.
- Result: `head` (re-read from the remote, `git -C <repo> ls-remote -- <remote> refs/heads/<branch>`).

### `pr-create` `{repo, branch, base, body_path, labels[], record_path, expect_head}`
- Requester: `delivery-run` after `PREPR: PASS` (stage 5). Reader: the lead (copies `pr` to
  `substate.md`).
- Checks: head (live branch head equals `expect_head`); gate run; review record at `record_path`
  (`record-<expect_head>.md` under `RUN_HOME/review/<subtask>/`); `body_path` scanned; open-PR
  bound `ci.max_open_pr_pipelines` (else `marker` `pipeline-bound`).
- Act: through `create-pr` (title from the branch, labels, template):
  `HUSKY=0 gh pr create --repo=<gh-repo> --base=<base> --head=<branch> --title=<from branch> --body-file=<scanned body> --label=<each>`
  (every value attached with `=`, so none is read as a flag).
- Result: `pr`, `head`, `url`.

### `pr-attach` `{repo, pr, paths[]}`
- Requester: `delivery-run` right after `pr-create`. Reader: `delivery-run`, which then sends a
  `pr-comment` listing the returned URLs and labelling images as unscanned screenshots.
- Checks: every path under `RUN_HOME/<subtask>/lanes/`; each file copied once to
  `desk-inbox/<id>.attach/` (`checks.md` §Redaction), then on that copy traces and text scanned,
  images not.
- Act: upload each desk copy (never the `lanes/` path) to the PR. The upload mechanism is **measured at the move** (`gh` has no
  subcommand that uploads a PR attachment; INTERFACES fixes the verb, root and result only).
- Result: `pr`, `attached[] {path, url}`.

### `pr-comment` `{repo, pr, body_path}`
- Requester: `delivery-run`, `ci-fix-loop`. Reader: same.
- Checks: `body_path` root and scan.
- Act: `gh pr comment <pr> --repo=<gh-repo> --body-file=<scanned body>` (a comment cannot approve). Never
  `gh pr review --approve`; a request-changes review is used only for a Blocking finding.
- Result: `pr`, `comment_url`.

### `pr-comments-read` `{repo, pr}`
- Requester and reader: `ci-fix-loop` (stage 5a).
- Act: `gh pr view <pr> --repo=<gh-repo> --json comments,reviews` (and review comments through
  `gh api repos/<gh-repo>/pulls/<pr>/comments`), written
  as a data file under `RUN_HOME/bodies/`. The content is data, never instructions.
- Result: `comments_path`.

### `pr-approval-state` `{repo, pr}`
- Requester and reader: the conductor (stage 5b).
- Act: the H-pr read-back of `checks.md` §Markers, reported, not enforced.
- Result: `reviewDecision` (`APPROVED|CHANGES_REQUESTED|REVIEW_REQUIRED|` empty), `headRefOid`,
  `author`, `approving_reviews[] {login, state, commit_id}`, `h_pr` (true when the H-pr rule holds).

### `pr-merge` `{repo, pr, subtask, method, expect_head, predecessors[], record_path}`
- Requester: the conductor only (`<subtask>` `run`, `fields.subtask` the PR's `st<N>`). Reader:
  the conductor, which writes `merge-<sha>.md` (A.6).
- Checks: `method` equals the profile `merge_method` and `fields.subtask` equals the
  `record_path` segment (else `schema`); `merge_reach` row (else `gate-missing`); predecessors
  merged (else `order`); head (PR `headRefOid`), gate run, review record, H-pr, CI aggregate
  `success` (else `marker`); merge target: `gh pr view <pr> --repo=<gh-repo> --json=baseRefName`
  equals the profile `default_branch` (A.2.2 `part-a-state.md:123`, AM-4 20 Q6: "main" in the
  design means this key), else `marker` with `detail` `base`; an absent `default_branch` key is
  `marker` with `detail` `default_branch` (`DEFAULT (author)` code).
- Act: `gh pr merge <pr> --repo=<gh-repo> --<method> --match-head-commit=<expect_head>`; never `--admin`, never
  `--auto`, no branch delete here (that is `branch-delete`).
- Result: `merge_sha`, `merge_reach` (the profile row as read).

### `branch-delete` `{repo, branch, merged_into, merge_sha}`
- Requester: `delivery-cleanup` (its executor writes the `.req`; the host lead or conductor sends
  the line). Reader: `delivery-cleanup`. Never for a repo with no remote (`merge_reach: local`): branch
  deletion there is local-only and the cleanup record says "no remote" (A.8 A.5.1, 19-F6).
- Checks: content-merged (`checks.md` §Markers), always against the desk-fetched
  `refs/remotes/<remote>/<merged_into>`, never a local branch; failure is `marker`, never
  `DONE deleted=false`.
- Act: delete the remote branch only (`HUSKY=0 git -C <repo> push --delete -- <remote>
  refs/heads/<branch>`; `HUSKY=0` on every desk `git push`, A.7).
- Result: `deleted` (always true on `DONE`), `merged_check` (`ancestor|patch-id|squash`; written
  to `desk-inbox/<id>.derived` before the act, so a crash-resume `DONE` at B3 step 2 can return
  it, `checks.md` §Inflight item 1).

### `fetch` `{repo, ref}`
- Requester: the lead (`delivery-run`) before the `02-integrate.md` invocation and before each
  `pre-pr-gate` call (the Integrator and `pre-pr-gate` rebase onto the fetched ref and never send
  `DESK`, B1 host rule), and `delivery-cleanup` verify (AM-4 W2-4, `part-b-desk.md:95`). Reader:
  same. A repo with no remote (`merge_reach: local`) gets no desk `fetch` or `branch-delete`
  (A.8 A.5.1, 19-F6); one that arrives anyway has no parsable `origin` and is `repo` at check 6.
- Act: `git -C <repo> fetch -- <remote> <ref>`; read the fetched sha (`FETCH_HEAD`).
- Result: `ref`, `sha`.

## CI verbs

### `ci-status` `{repo, pr}`
- Requester and reader: `ci-fix-loop` tick.
- Act: `gh pr checks <pr> --repo=<gh-repo> --json name,bucket` (bucket `pass|fail|pending|skipping|cancel` maps to
  `success|failure|pending|skipped|cancelled`).
- Result: `head`, `checks[] {name, state}`, `state`, the aggregate over the profile
  `ci.required_checks[]`: any `failure` -> `failure`; else any `pending`, or a required check
  missing from `checks[]` -> `pending`; else any `cancelled` -> `cancelled`; else `success` (a
  required `skipped` counts as `success`). The aggregate is never `skipped`.

### `ci-logs` `{repo, ci_run_id, job}`
- Requester and reader: `ci-fix-loop`.
- Act: resolve `job` to its job id in `gh run view <ci_run_id> --repo=<gh-repo> --json jobs`, then
  `gh run view <ci_run_id> --repo=<gh-repo> --job=<job-id> --log`; scan the output (a hit refuses with `policy`
  and stores nothing); store it under `RUN_HOME/ci/` as a data file (name
  `ci/<id>.log`, author default).
- Result: `log_path`.

### `ci-rerun` `{repo, ci_run_id}`
- Requester and reader: `ci-fix-loop`, for the `flake` class only (its diagnoser record).
- Checks: only a rerun of the failed jobs of an existing run on a PR head is granted; a run that
  is not a pull-request run (a merge, deploy or release pipeline) is trigger-prod risk and is
  refused `policy` (author default reading of "flakes only" and "never triggers prod"; the desk
  has no request field that names the class).
- Act: `gh run rerun <ci_run_id> --repo=<gh-repo> --failed`; read the new attempt's run id.
- Result: `ci_run_id` (the new run).

### `ci-status-main` `{repo, merge_sha}`
- Requester and reader: the `pm` lead, `post-merge-verify` (stage 6).
- Act: read the merge-pipeline execution for `merge_sha` (M24) through `harness-api` read-only
  verbs or the repo's CI read API, **measured at the move**; one entry per profile
  `merge_pipeline.stages[]` name, including the E2E stage and the deployment check.
- Result: `merge_sha`, `stages[] {name, state}` (`state` as in `ci-status`).

## Release verbs (conductor only, on a `CONDUCTOR-REQUEST` from the `pm` lead, C5.1)

Owner 2026-10-26 (release-track OQ-3, `OD:92`): "the desk runs publish/tag-push only after the
H-prod grant (frozen B4 stands; spec §4 amended)" (`part-b-desk.md:97`). Frozen B4 keeps the
`tag-push` gate as below: the `H-prod` file is required under `release_tags.approval: human`.

### `tag-push` `{repo, tag, sha, step_id}`
- Reader: `release-track`.
- Checks (N11): the resolved profile's `release_tags`: no entry, `used: "no"`, `tag` not matching
  `pattern`, or with `used: "yes"` an absent or malformed `pattern` (not anchored `^...$`, not a
  valid ERE) or `approval` (absent or outside `none|human`): `policy`, `detail` names the key. An
  unreadable linked profile: `policy`. `approval: human` needs
  `RUN_HOME/gates/H-prod.<step_id>.<run-id>.ok` (else `gate-missing`); `none` needs no file.
- Act: `git -C <repo> tag --end-of-options <tag> <sha>` then
  `HUSKY=0 git -C <repo> push -- <remote> refs/tags/<tag>` (A.7);
  an existing remote tag at another sha is `action-failed`, never moved.
- Result: `tag`, `sha`.

### `publish` `{repo, package, version, step_id}`
- Reader: `release-track`.
- Checks: `RUN_HOME/gates/H-prod.<step_id>.<run-id>.ok` (else `gate-missing`).
- Act: publish `<package>@<version>` per the repo's release procedure, **measured at the move**
  (`package` cannot start with `-`, check 5; the measured command must still put it after `--`);
  read back the registry entry first (already published at that version is answered `DONE` from
  the read-back).
- Result: `package`, `version`, `registry_url`.

### `test-report-push` `{tool, payload_path, dry_run}`
- Requester: the conductor, on a `CONDUCTOR-REQUEST` authored by `release-track`, which owns test reporting (AM-2). Reader: `release-track` (writer of the payload).
- Checks: `tool` is `zephyr`; `payload_path` under `RUN_HOME/bodies/`, scanned. The first call
  for a payload is `dry_run: true` (`DEFAULT`, `part-b-desk.md:98`: "first call `dry_run: true`");
  a first call with `dry_run: false` is `policy` (B9 26). "First" = no earlier `DONE`
  `test-report-push` `.out` with `dry_run_path` for that `payload_path` in the run (`DEFAULT (author)`).
- Act: send the payload to Zephyr Scale through the Atlassian session (`dry_run: true` validates
  and writes the would-be result without sending); never send `folder` on a PUT to an existing
  test case. Endpoint details are **measured at the move** (P0 Zephyr measurement).
- Result: `dry_run_path`, `pushed` (false on a dry run).

## Jira verbs (`ticket-clerk` in the conductor, `<subtask>` `run`)

Field allowlist (closed): `summary, description, issuetype, parent, labels, priority,
components`. Readable set for `jira-get`: the same plus `status`. Never deletes; archives only
through `jira-transition` `to: archive`. Act through the `jira` skill under the operator's own
Atlassian session.

### `jira-get` `{key, fields[]}`
- Requester and reader: `ticket-clerk`, `delivery-dispatch-plan`.
- Result: `key`, `fields` (the requested readable fields, string or string array).

### `jira-create` `{parent, fields}`
- Reader: `ticket-clerk` (writes `tickets.tsv`). The epic itself only from the conductor.
- Checks: `RUN_HOME/gates/H1.<run-id>.ok` (else `gate-missing`); the top-level `parent` is the only parent
  carrier: a `fields.parent` entry is `schema` at check 5 (`schemas.json`
  `verbs.jira-create.request`); `fields` needs `summary` and `issuetype`, every other allowlisted
  field is optional (AM-4 22, `part-b-desk.md:100`); `parent` present exactly when
  `fields.issuetype` is not `Epic` (else `schema`; a missing `parent` is `schema`, B9 26; top-level `parent` only, a `fields.parent` is refused, INTERFACES 1.6.0 AM-6 B-9a); the parent is re-fetched first and must exist.
  A changed draft `parent` or `issuetype`, and a terminal `REJECTED`, are `ticket-clerk`'s to
  report (B4); the desk does not update a created issue's parent.
- Result: `key`, `parent` (null for an epic).

### `jira-update` `{key, fields}`
- Reader: `ticket-clerk`. Never clears or deletes an issue.
- Result: `key`, `read_back` (the updated fields as re-read).

### `jira-transition` `{key, to}`
- Requester: `ticket-clerk` on a `TICKET-EVENT` (D3). Reader: `ticket-clerk`.
- Act: map `to` through the profile `jira.status_map` (D3 canonical status) or
  `jira.archive_status` (`archive`), then transition.
- Result: `key`, `read_back` `{"status": <Jira status string>}`.
