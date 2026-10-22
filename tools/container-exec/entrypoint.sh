#!/usr/bin/env bash
# hqx entrypoint (ADR 0008). Bare Claude Code, full-auto, results to /out.
set -uo pipefail
MODE="${HQX_MODE:-clone}"        # clone (default) | rw
MODEL="${HQX_MODEL:-opus}"
SLUG="${HQX_TASK_SLUG:-work}"

if [ "$MODE" = clone ]; then
  git clone --no-hardlinks /src-ro /work
fi
cd /work
BASE="$(git rev-parse HEAD)"
git switch -c "hqx/${SLUG}-$(date +%s)"

# Headless, full-auto. NOT --bare (bare ignores CLAUDE_CODE_OAUTH_TOKEN).
set +e
claude -p "$(cat /task/spec.md)" \
  --dangerously-skip-permissions \
  --model "$MODEL" \
  --output-format stream-json --verbose \
  2>&1 | tee /out/session.stream.jsonl
rc="${PIPESTATUS[0]}"
set -e

# Results-out: inert bundle + diff (no push authority).
git add -A
git -c commit.gpgsign=false commit -m "hqx: ${SLUG} result" || true
if git rev-parse "${BASE}..HEAD" >/dev/null 2>&1 && \
   [ -n "$(git rev-list "${BASE}..HEAD")" ]; then
  git bundle create /out/result.bundle "${BASE}..HEAD"
  git diff "${BASE}..HEAD" > /out/result.diff
else
  : > /out/result.diff   # no commits produced
fi

# Usage-measurement copy-out (D8 blind-spot mitigation).
mkdir -p /out/usage
cp -r "${HOME}/.claude/projects" /out/usage/ 2>/dev/null || true

exit "$rc"
