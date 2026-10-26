# PR Review — Step 2 diff fetch scripts

Dispatch a `mechanical`-tier sub-agent (tier resolved by `tools/model-routing.md`) to run the script for the mode. `DIFF_PATH` is an input, set by Step 1:
standalone `/tmp/pr-review-${SESSION_SUFFIX}.diff` (`bus-start-standalone.md`), inside a run
`$RUN_HOME/review/$SUBTASK/pr-review-$SESSION_SUFFIX/diff.diff` (`bus-start-run.md`). Step 0 has already
validated the inputs; the checks below repeat them before any shell interpolation.

## pr mode

```bash
: "${DIFF_PATH:?DIFF_PATH from Step 1}"
# Validate inputs before shell interpolation
echo "$REPO" | grep -qE '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' || { echo "ERROR: invalid REPO format — expected owner/repo"; exit 1; }
echo "$PR_NUMBER" | grep -qE '^[0-9]+$' || { echo "ERROR: invalid PR_NUMBER — must be an integer"; exit 1; }
gh pr diff --repo "$REPO" "$PR_NUMBER" > "$DIFF_PATH" || { echo "ERROR: gh pr diff failed — check repo and PR number"; exit 1; }
chmod 600 "$DIFF_PATH"
[ -s "$DIFF_PATH" ] || { echo "ERROR: diff is empty — PR may have no changes or gh failed silently"; exit 1; }
wc -c "${DIFF_PATH}"
```

Capture `DIFF_PATH`. Halt if the file is empty or `gh` fails.

## local-diff mode (no `gh`, no network)

Unstacked: `BASE_REF`/`HEAD_REF`, three-dot diff. Stacked (`STACK_BASE` and `STACK_HEAD` set): the
ref pair is not required; both shas must resolve as commits; two-dot diff, never the three-dot form.

```bash
: "${DIFF_PATH:?DIFF_PATH from Step 1}"
# Validate inputs; REPO_DIR is only ever read
git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: REPO_DIR is not a git checkout"; exit 1; }
case "$RECORD_PATH" in /*) ;; *) echo "ERROR: RECORD_PATH must be absolute"; exit 1;; esac; case "$RECORD_PATH" in "$(cd "$REPO_DIR" && pwd -P)"/*) echo "ERROR: RECORD_PATH is inside REPO_DIR"; exit 1;; esac
if [ -n "${STACK_BASE:-}" ]; then   # stacked PR (Step 0 checked both are 40-hex)
  git -C "$REPO_DIR" rev-parse --verify "$STACK_BASE^{commit}" >/dev/null 2>&1 || { echo "ERROR: STACK_BASE does not resolve"; exit 1; }
  git -C "$REPO_DIR" rev-parse --verify "$STACK_HEAD^{commit}" >/dev/null 2>&1 || { echo "ERROR: STACK_HEAD does not resolve"; exit 1; }
  HEAD_SHA=$(git -C "$REPO_DIR" rev-parse "$STACK_HEAD^{commit}")
  git -C "$REPO_DIR" diff "$STACK_BASE..$STACK_HEAD" > "$DIFF_PATH" || { echo "ERROR: git diff failed"; exit 1; }
else
  git -C "$REPO_DIR" rev-parse --verify "$BASE_REF^{commit}" >/dev/null 2>&1 || { echo "ERROR: BASE_REF does not resolve"; exit 1; }
  git -C "$REPO_DIR" rev-parse --verify "$HEAD_REF^{commit}" >/dev/null 2>&1 || { echo "ERROR: HEAD_REF does not resolve"; exit 1; }
  HEAD_SHA=$(git -C "$REPO_DIR" rev-parse "$HEAD_REF^{commit}")
  git -C "$REPO_DIR" diff "$BASE_REF...$HEAD_REF" > "$DIFF_PATH" || { echo "ERROR: git diff failed"; exit 1; }
fi
chmod 600 "$DIFF_PATH"
[ -s "$DIFF_PATH" ] || { echo "ERROR: diff is empty — nothing to review"; exit 1; }
wc -c "${DIFF_PATH}"
echo "HEAD_SHA=${HEAD_SHA}"
```

Capture `DIFF_PATH` and `HEAD_SHA`. Halt if the file is empty or a ref fails to resolve. On any halt
after Step 1 started the bus, run Step 9 cleanup before reporting.

## Network unavailable (pr mode)

In pr mode this skill makes outbound network calls: `gh pr diff` (fetches the PR diff) and
`gh pr comment` (posts the review comment). Local-diff mode has none; this section does not apply.

If network connectivity is unavailable (pr mode): make no `gh` calls; log
`[SKIPPED] network unavailable — pr-review skipped`; exit 0 in script/automated contexts (a non-zero
exit would flip a launchd-tracked service unhealthy for an intentional skip); interactively, tell the
user the review could not be completed and suggest retrying later. Before any `gh` call (pr mode), run
`~/.claude/skills/network-check/scripts/check-network.sh` (exit 0 = reachable, exit 1 = unreachable).
