#!/usr/bin/env bash
# tools/hooks/subagent-role-banner.sh — SubagentStart role banner (hq ADR 0043, layer L1).
#
# WHY THIS EXISTS: global Rule 2 ("delegate all work to subagents") binds the orchestrator, but a
# subagent reads the same rule and can wrongly treat the duty as its own. This hook injects a short
# SUBAGENT ROLE banner into every subagent's context at start, so it knows it is the worker.
# Design record: architecture/subagent-role-contract.md (component C1). Awareness only: this hook
# restricts nothing and can restrict nothing (SubagentStart cannot block; this script also never
# exits non-zero).
#
# BEHAVIOUR: reads the hook's stdin JSON. No `agent_id` (or unparseable stdin, or any jq failure)
# -> prints nothing, exits 0. Otherwise prints one hookSpecificOutput JSON object whose
# additionalContext is the banner naming this agent's type and id. Depth is deliberately omitted:
# the agent's own meta.json is not yet written when SubagentStart fires (ratification finding A7).
#
# FAIL-OPEN, ALWAYS `exit 0`, NEVER errexit mode: every path below ends in exit 0, same discipline
# as tools/hooks/port-precheck.sh. This runs on every subagent start on this machine.
#
# OUTPUT IS BUILT BY jq, NEVER printf: the banner contains quotes and backticks, and stdout must be
# exactly one valid JSON object or the harness ignores it.
#
# ENV (test injection only)
#   JQ   default: /usr/bin/jq   (the fixture runner points it at a nonexistent path to prove fail-open)

JQ="${JQ:-/usr/bin/jq}"

main() {
  local payload agent_id agent_type
  payload="$(cat)" || return 0
  [ -n "${payload}" ] || return 0

  agent_id="$(printf '%s' "${payload}" | "${JQ}" -r '.agent_id // empty | tostring' 2>/dev/null)" || return 0
  [ -n "${agent_id}" ] || return 0
  agent_type="$(printf '%s' "${payload}" | "${JQ}" -r '.agent_type // empty | tostring' 2>/dev/null)" || agent_type=""
  [ -n "${agent_type}" ] || agent_type="unknown"

  "${JQ}" -nc --arg t "${agent_type}" --arg i "${agent_id}" '
    {hookSpecificOutput: {
      hookEventName: "SubagentStart",
      additionalContext: ("SUBAGENT ROLE (hq ADR 0043): You are a subagent — type `" + $t + "`, id `" + $i + "`. You are the worker, not the orchestrator (main chat). Global Rule 2'"'"'s \"delegate all work\" binds the orchestrator, not you: do your brief'"'"'s work yourself with your own tools. You may dispatch further subagents whenever that genuinely helps; say why in the dispatch prompt (a convention for auditability, not an enforced requirement). Rules 1, 3 and 4 still apply to you.")
    }}' 2>/dev/null
  return 0
}

main
exit 0
