# Fix record: delivery-desk, review-7-panel round 2 (2026-10-26)

Fixer: Opus subagent (not the author, not a seat or verifier). Input:
`panel7-delivery-desk-r2-2026-10-26.md` (0/3/19). Scope: `skills/delivery-desk/*` only.
Paths below are relative to `skills/delivery-desk/`.

## Findings

| id | status | file:line after | change |
|---|---|---|---|
| r2-1 | FIXED | references/verbs.md:21-28, 57, 72, 78-79, 96, 119, 128-129, 140; references/checks.md:97-98, 99, 102, 104; SKILL.md:113-114 | New "Repository binding" paragraph: every `gh` call carries `--repo=<gh-repo>`, `<gh-repo>` = `<owner>/<name>` parsed from `git -C <repo> remote get-url origin` of the realpath'd registered clone; `gh api` uses `repos/<gh-repo>/...`; unparsable URL is `repo` at check 6; `gh` never uses the session cwd. Chosen: `--repo`, not cwd. Every `gh` command in verbs.md and checks.md now carries it. Author default. |
| r2-2 | FIXED | SKILL.md:65-67, 108, 131-134; references/checks.md:115-116, 122-128 | One request at a time: during a wait or act only `STATUS` is answered; every other `DESK`, `REGISTER-SENDER` or human line is queued until the current id has its `.out` (or its `REJECTED sender` reply). checks.md "takes other lines" removed. New §Inflight item 0: any `.inflight` met has no live handler; read-back reconcile applies only to such. Author default. |
| r2-3 | FIXED | references/schemas.json:83-87 | `envelope.verb` is now `{"type":"string","pattern":"^[a-z-]+$"}` (DESK-regex verb shape) with a `$comment` citing part-b-desk.md:116 (no enum). `verbs.<verb>.result` keeps `verb` const for `DONE`. |
| r2-5 | FIXED | references/verbs.md:23-24; checks.md:98; SKILL.md:114 | `<remote>` = `origin` of the registered clone (profile `clones[]` is a path only, part-a-state.md:115). Author default. |
| r2-7 | FIXED | SKILL.md:88; references/checks.md:53 | `record_path` segment: id `<subtask>` for `pr-create`, `fields.subtask` for `pr-merge`. |
| r2-11 | FIXED | SKILL.md:154-156, 205-206; references/verbs.md:45-46, 107, 160 | Scope stated as "every desk `git push`" (`push`, `branch-delete`, `tag-push`) and PR creation, by link to part-a-state.md:325-342 (A.7); form no longer restated in SKILL.md ("inline per-command, never exported" removed); N10 cite kept. |
| r2-12 | FIXED | SKILL.md:84-85; references/checks.md:59-61, 65 | Repo-less verbs (`jira-*`, `test-report-push`) use the primary profile, marked `DEFAULT (author)`. |
| r2-17 | FIXED | SKILL.md:69-70; references/checks.md:28 | Missing or unreadable `.req`: `REJECTED schema`, `request_sha256` null. |
| r2-19 | FIXED (partial) | SKILL.md (whole) | 22,509 -> 19,342 bytes (2,792 words). Moved: reason-code table and resend paragraph to checks.md §Reason codes (:155); sender-side paragraph to checks.md §Requester-side rules (:178); verbs table replaced by the closed list of 20 plus conductor-only set, detail in verbs.md (already held every column); `record_path`/`pr-attach` fixed-rule bullets folded to one line linking step 9 and checks.md §Markers; branch-regex and image prose shortened with links. No rule dropped. Just above the ~19,000 target. |
| r2-21 | FIXED | references/checks.md:30; schemas.json:869 | Leading-dash list is `ref`, `base`, `merged_into`, `tag`, `package` everywhere. |
| r2-22 | FIXED | SKILL.md:122 | "except reason `sender` (step 4)". |
| r2-4, r2-6, r2-9, r2-10, r2-13, r2-15, r2-16, r2-18, r2-20 | OPEN (not in this fixer's brief) | - | Untouched. |
| r2-8, r2-14 | OWNER | - | Untouched; see owner notes. |

## Hunk map

- schemas.json `envelope.verb` -> r2-3; `reason_codes.schema` trigger -> r2-21.
- verbs.md Repository binding paragraph -> r2-1, r2-5; each `gh ... --repo=<gh-repo>` hunk (pr-create, pr-comment, pr-comments-read, pr-merge, ci-status, ci-logs, ci-rerun) -> r2-1; push, branch-delete, tag-push HUSKY annotations -> r2-11.
- checks.md row 3 -> r2-17; row 5 -> r2-21; `record_path` row -> r2-7; profile-resolution and Patterns lines -> r2-12; Markers intro and four `gh` cells -> r2-1, r2-5; push-spacing wait sentence and §Inflight item 0/1 -> r2-2; §Reason codes and sender-side paragraph (moved) -> r2-19.
- SKILL.md step 5, 11, 15 -> r2-2; step 6 -> r2-17; step 9 -> r2-12, r2-7, r2-19 (image prose); step 8 tail -> r2-19; step 12 -> r2-1, r2-5, r2-19; step 13 -> r2-22; Verbs section, Reason codes section, Inputs references bullet, Credentials and record_path/pr-attach bullets, step 4 Q1 sentence -> r2-19; HUSKY bullet and exit criterion -> r2-11.

## Owner notes (open)

- r2-8: reason code (and the definition of "first call") for `test-report-push` with `dry_run: false` first, and for a `jira-create` whose parent is missing; part B gives none.
- r2-14: `tools/delivery/desk-req-schema.sh:21` control-char rejection on the sender side (outside `skills/delivery-desk/`).
- Hardening (from s3-2): whether the desk ignores repo-local url/pushurl/sshCommand/credential config and hooks of agent-writable clones; needs an INTERFACES decision.
- New author defaults introduced here for owner awareness: `<remote>` = `origin`; `--repo=<gh-repo>` from the origin URL (unparsable = `repo`); one-request-at-a-time queueing.

## Checks (run from W)

- `bash SCRATCH/s9-26.sh`: DESK-SCHEMAS-OK; no MISSING, VIOLATION, NO-USE-WHEN or RULE-MISSING; check-doc-length 0 blocking; SKILL.md 2,792 words.
- `json.load` on schemas.json: OK, 898 lines.
- `python3 -I` jsonschema 4.25.1 Draft7 probe: envelope accepts a `REJECTED schema` `.out` with verb `approve` (True); rejects an unknown envelope key (True); rejects verb `Approve!` (True); `verbs.push.result` rejects a `DONE` with verb `approve` (True).
- Reference files: checks.md 183, verbs.md 207, human-gates.md 69, source-keys.md 35 lines.
