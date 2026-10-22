#!/usr/bin/env bash
# session-end-push-check.sh — Claude Code SessionEnd nudge (ADR 0006/0007 addition, not in the ADR body).
# Local-only unpushed-backup reminder for hq. Never errors, never blocks session teardown.
# - Silent + exit 0 when hq HEAD is NOT ahead of origin/main.
# - If ahead by N, prints exactly one line naming N.
# - No network: uses only local refs (no git fetch). Degrades to silent success on any failure
#   (repo missing, origin/main absent/unreachable locally, non-numeric output).
# - SESSION_END_HQ_DIR overrides the repo checked (default $HOME/projects/agent-hq); the generic HQ_DIR is ignored.
# - The ref is spelled refs/remotes/origin/main (not origin/main) so a local tag named origin/main
#   cannot shadow the remote-tracking ref (git resolves refs/tags before refs/remotes).
HQ="${SESSION_END_HQ_DIR:-$HOME/projects/agent-hq}"
n="$(git -C "$HQ" rev-list --count refs/remotes/origin/main..HEAD 2>/dev/null)" || exit 0
case "$n" in
  ''|*[!0-9]*) exit 0 ;;
esac
if [ "$n" -gt 0 ] 2>/dev/null; then
  echo "hq has $n unpushed commit(s) — push is your only backup (ADR 0006/0007)"
fi
exit 0
