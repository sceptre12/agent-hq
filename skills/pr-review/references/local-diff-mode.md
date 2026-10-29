# PR Review — Local-diff mode (`PR_REVIEW_MODE=local-diff`)

Review a local `git diff` with no GitHub PR; the review record goes to a file instead of a PR comment.
Authority: INTERFACES 1.5.0 D2.3 `PR_REVIEW_MODE`; every other choice here is a brain default under R-q
(owner may veto). Differences from pr mode, all in one place:

- **Inputs** (replace `REPO`/`PR_NUMBER`): `REPO_DIR` (git checkout holding both refs; read-only for the
  whole run), `BASE_REF`, `HEAD_REF` (ref or sha), `RECORD_PATH` (absolute, outside the reviewed tree).
  Stacked PR: `STACK_BASE` + `STACK_HEAD` (both 40-hex) replace the ref pair; `HEAD_SHA` is `STACK_HEAD`.
- **Step 2:** `git -C "$REPO_DIR" diff "$BASE_REF...$HEAD_REF"` replaces `gh pr diff` (stacked:
  `git diff "$STACK_BASE..$STACK_HEAD"`, two dots, never the three-dot form); capture `HEAD_SHA`.
- **Steps 4/6/8:** prompt fields `repo_dir`/`base_ref`/`head_ref`/`head_sha` replace `repo`/`pr_number`;
  agents read files only via `git -C "$REPO_DIR" show "$HEAD_SHA:<path>"`, never the working tree, never a write.
  Never read `.env*`, `*hermesAuth*`, or any credential/token/key file this way even if the path exists
  at `HEAD_SHA` — `git show` has no scope restriction to diffed files, so this is a general-repo-read
  rule, not an edge case. If such a path is genuinely needed for context, PASS the check and note the
  gap instead of reading the file.
- **Step 8:** the orchestrator writes `RECORD_PATH` (`references/review-record.md`).
- **No `gh` call, no network, no network-check.** Phase C: approved fixes go in the author's `wt/` worktree, never `REPO_DIR`.

