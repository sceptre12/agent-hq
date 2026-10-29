---
name: create-pr
description: Opens a pull request for the current branch against main, following the repo PR template, conventional commits, label rules, and HUSKY=0 for multi-agent safety.
model: haiku
context: fork
agent: general-purpose
background: false
metadata:
  type: skill
  status: active
---

## Task

Working directory / branch context: $ARGUMENTS

This skill runs in a forked subagent with no inherited cwd, shell state, or
conversation history — it does not start inside the repo/worktree whose branch needs
a PR, and cannot infer one. The line above must supply the absolute path to that
repo/worktree (e.g. `/Users/Xavier.Thomas/projects/context-docs-worktrees/my-fix`); the
target branch is whatever is already checked out there, so it does not need to be
named separately unless there's ambiguity. `cd` into the given path before running
Pre-flight Step 1 below — every other step assumes cwd is already that repo. If no
working directory is provided, stop and report what's missing rather than guessing a
repo or branch.

---

# Create PR

Opens a pull request for the current branch against `main`, following the repo's PR
template, conventional commit standards, and label rules. Safe for multi-agent use.

## Trigger

- After all commits on a feature/fix branch are ready and pushed
- When a subagent needs to open a PR without triggering Husky hooks
- Any time a PR must conform to the repo's template and label requirements

---

## Subagent Detection

A single condition — "this run was dispatched as a subagent" — is signaled through two
channels. Check them in order and resolve to one value:

1. **`IS_SUBAGENT` environment variable** (primary) — injected by the SessionStart hook,
   or by a dispatcher's `IS_SUBAGENT=true claude -p ...` prefix:
   ```bash
   IS_SUBAGENT="${IS_SUBAGENT:-false}"
   ```
2. **`is_subagent: true` in your context** (fallback) — the prompt-text marker
   dispatchers append for environments that strip env vars. If the env var resolved
   `false` but this marker is present in your context, treat the run as a subagent
   run: set `IS_SUBAGENT=true` when executing the steps below.

The resolved value drives one remaining subagent behavior in this skill:

- **Interactivity** — when `IS_SUBAGENT=true`, the skill runs non-interactively:
  prompts are skipped and defaults are applied. When `IS_SUBAGENT=false`, the skill
  prompts the user at each interactive step.

(Model routing used to be a second behavior driven by this flag — a manual
`claude --model ... -p` re-exec, checked above. That's now handled natively by this
skill's own frontmatter (`context: fork` + `model: haiku` pins the forked subagent to
Haiku directly), so `IS_SUBAGENT` no longer needs to gate model selection. Note that
`context: fork` means every invocation of this skill now runs as an isolated subagent
by construction — `IS_SUBAGENT` here still answers a different question, namely whether
a human is attending this specific run (foreground, someone might answer a prompt) vs.
it being invoked deep inside an unattended automated pipeline.)

---

## Steps

Run all checks before proceeding. Fail fast on any error.

0. `cd` into the working directory supplied in `## Task` above. This is required —
   the forked subagent's default cwd is not the target repo, so every `git`/`gh`
   command below silently operates on (or errors against) the wrong directory
   otherwise. EXIT_ERROR: no working directory provided, if `## Task` was empty.

1. Confirm not on main:
   `git rev-parse --abbrev-ref HEAD` — EXIT_ERROR if result is `main`

2. Confirm commits exist ahead of main:
   `git log main..HEAD --oneline` — EXIT_ERROR: no commits ahead of main, if output is empty

3. Confirm the branch is pushed with an upstream:
   `git rev-parse --abbrev-ref @{u}` — EXIT_ERROR: branch has no upstream — push it
   first (`HUSKY=0 git push -u origin HEAD`), if the command fails

4. Confirm GitHub CLI is authenticated:
   `gh auth status` — EXIT_ERROR if not authenticated

5. Template path resolution is performed in Step 3. If no template is found and
   `IS_SUBAGENT=false`, the user is prompted to supply a path. If `IS_SUBAGENT=true`,
   a warning is logged and the PR opens with an empty body.

6. Read commit style:
   `git log --oneline -10` — scan for conventional commit format in use
   Also check for `.commitlintrc*` or `commitlint.config.*` for the exact ruleset.

**Execution note:** shell state does not persist across separate Bash tool
invocations. Variables set in Steps 1–5 (`PR_TITLE`, `LABELS`/`LABEL_ARGS`,
`TEMPLATE_PATH`) are consumed in Step 6 — run the variable-sharing steps in a single shell invocation
(one combined script), or re-derive each variable in the invocation that uses it.

---

### Step 1 — Derive PR Title

Extract the descriptive part of the branch name and format it as the PR title:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Extract ticket prefix if present (e.g. FOUND-1234)
TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
# Strip type prefix (feat/, fix/, chore/, etc.)
BRANCH_DESC=$(echo "$BRANCH" | sed 's|^[a-z]*/||')
# Remove ticket prefix from desc (only when a ticket was found — an empty ${TICKET}
# would corrupt the sed into "s/-//; s///", silently eating hyphens), then replace
# remaining hyphens/underscores with spaces
if [ -n "$TICKET" ]; then
  BRANCH_WORDS=$(echo "$BRANCH_DESC" | sed "s/${TICKET}-//; s/${TICKET}//; s/[-_]/ /g" | xargs)
  PR_TITLE="${TICKET} ${BRANCH_WORDS}"
else
  BRANCH_WORDS=$(echo "$BRANCH_DESC" | sed 's/[-_]/ /g' | xargs)
  PR_TITLE="$BRANCH_WORDS"
fi
```

Example: `feat/FOUND-1234-add-new-thing` → `FOUND-1234 add new thing`

If the branch contains a Jira ticket prefix (e.g. `FOUND-1234`), preserve it at the
front of the title.

---

### Step 2 — Detect Migration Changes

Check both file paths and commit messages for migration signals:

```bash
LABELS=()
IS_MIGRATION=false
git diff main..HEAD --name-only | grep -qiE '(migration|migrate)' && IS_MIGRATION=true
git log main..HEAD --oneline | grep -qiE '(migration|migrate)' && IS_MIGRATION=true
[ "$IS_MIGRATION" = true ] && LABELS+=("COUPLED_DEPENDENCY_UPDATE")
```

If `IS_MIGRATION=true`, `COUPLED_DEPENDENCY_UPDATE` is added to `LABELS` automatically.

---

### Step 3 — Read PR Template

```bash
TEMPLATE_PATH=""
if [ -f ".github/pull_request_template.md" ]; then
  TEMPLATE_PATH=".github/pull_request_template.md"
else
  TEMPLATE_PATH=$(ls .github/PULL_REQUEST_TEMPLATE/*.md 2>/dev/null | head -1)
fi
```

If `TEMPLATE_PATH` is empty and `IS_SUBAGENT=false`:
> "No PR template found in .github/. Provide path to template, or press Enter to skip:"

If `TEMPLATE_PATH` is empty and `IS_SUBAGENT=true`: proceed with empty body, log warning.

---

### Step 4 — Validate Conventional Commits

Read commits on the branch:
```bash
git log main..HEAD --format="%s"
```

Each subject must match: `type(scope): description` or `type: description`
(a `!` before the colon — `type(scope)!: description` — marks a breaking change and is valid)

Valid types: `feat` `fix` `chore` `refactor` `docs` `test` `build` `ci` `perf` `revert`
(if a `.commitlintrc*` / `commitlint.config.*` was found in Pre-flight, its ruleset wins)

If any commit does not match:
- `IS_SUBAGENT=false`: warn the user, ask whether to proceed
- `IS_SUBAGENT=true`: log WARNING: non-conventional commit detected — proceeding

---

### Step 5 — Labels

Auto-detected labels are always applied (e.g. `COUPLED_DEPENDENCY_UPDATE` for migration PRs).

```bash
if [ "$IS_SUBAGENT" = "false" ]; then
  echo "Labels to apply: ${LABELS[*]}. Add more? (comma-separated, or Enter to skip):"
  read -r EXTRA_LABELS
  if [ -n "$EXTRA_LABELS" ]; then
    IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_LABELS"
    for label in "${EXTRA_ARRAY[@]}"; do
      LABELS+=("$(echo "$label" | xargs)")
    done
  fi
fi

# Build label args as an array — a flat string of embedded quotes would be
# word-split into broken arguments when expanded unquoted in Step 6
LABEL_ARGS=()
for label in "${LABELS[@]}"; do
  LABEL_ARGS+=(--label "$label")
done
```

If `IS_SUBAGENT=true`: auto-detected labels only, prompt skipped.

---

### Step 6 — Open the PR

```bash
# Use --body-file for the template (avoids quoting/splitting bugs entirely)
BODY_ARGS=()
if [ -n "$TEMPLATE_PATH" ]; then
  BODY_ARGS=(--body-file "$TEMPLATE_PATH")
else
  BODY_ARGS=(--body "")
fi

HUSKY=0 gh pr create \
  --base main \
  --title "$PR_TITLE" \
  "${BODY_ARGS[@]}" \
  "${LABEL_ARGS[@]}"
```

GitHub CODEOWNERS handles reviewer assignment automatically — do not pass `--reviewer`.

---

### Step 7 — Report

After the PR is created, output:
- PR URL
- PR number
- Labels applied
- Template used (path or "none")
- Any commit format warnings that were bypassed

---

## HUSKY=0 Rule

`HUSKY=0` is applied to the `gh pr create` call in Step 6. Read-only `git` commands
(`log`, `diff`, `rev-parse`) do not trigger Husky hooks and do not need the prefix.

---

## Label Reference

| Condition | Auto-applied label |
|-----------|-------------------|
| Migration files changed or migration-related commits detected | `COUPLED_DEPENDENCY_UPDATE` |

---

## Cross-References

- `pr-review` — run after the PR is open to code-review it
- `pr-check-migration-needed` — call before this skill to determine if a migration script
  is required; its output informs the `COUPLED_DEPENDENCY_UPDATE` label decision

## Network Unavailable

This skill makes outbound network calls: `gh auth status` (GitHub auth check) and `gh pr create` (GitHub API).

If network connectivity is unavailable when this skill is invoked:
- Do not attempt the `gh` calls
- Log or echo: `[SKIPPED] network unavailable — create-pr skipped`
- Exit 0 in script/automated contexts (do not error — launchd tracks LastExitStatus)
- If running interactively: inform the user the PR could not be created and suggest retrying when connectivity is restored

To verify connectivity before running: `use the `network-check` skill.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll just run `gh pr create` without `HUSKY=0`." | Always prefix the create call with `HUSKY=0` — it's the one command in this skill that triggers hooks. |
| "No upstream is set, I'll just create the PR anyway." | Push first (`HUSKY=0 git push -u origin HEAD`) — `gh pr create` needs a pushed branch. |
| "I'll pass `--reviewer` to be helpful." | GitHub CODEOWNERS handles reviewer assignment automatically — do not pass `--reviewer`. |
| "A commit doesn't match conventional-commit format, I'll just block." | In a subagent run, log the warning and proceed; only block interactively if the user chooses not to proceed. |
| "I'll build the PR body as an inline `--body` string with the template text." | Use `--body-file` for the template — inline `--body` risks quoting/splitting bugs with embedded content. |

## Exit criteria

- [ ] Pre-flight checks 1-4 all passed (not on main, commits ahead, branch pushed with
  upstream, `gh` authenticated) before any write call was attempted.
- [ ] The `gh pr create` call used `HUSKY=0` and `--body-file` (when a template was found).
- [ ] The report includes PR URL, PR number, labels applied, template used, and any
  bypassed commit-format warnings.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/create-pr@9d7143e (trimmed: pointed the
connectivity-check cross-reference at the `network-check` skill instead of a
work-machine-only absolute script path)
