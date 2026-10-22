# Subagent role contract — role banner, role-conditioned Rule 2, nesting notice (design record)

- **Status:** RATIFIED-WITH-AMENDMENTS — Fable, 2026-10-02 (ADR 0014 T5 + T6); record
  `architecture/subagent-role-contract-ratification.md`. Build (S1) may proceed; S4b and
  S5 remain owner steps.
- **Date:** 2026-10-02
- **Decision this implements:** `decisions/0043-subagent-role-contract.md` (L1–L3), shaped by
  the owner's 2026-10-02 ruling quoted there: awareness only, nothing restricts a spawn.
- **Dispatch plan:** `plans/subagent-role-contract.md`
- **Ground truth used:** hooks docs <https://code.claude.com/docs/en/hooks.md> (fetched
  2026-10-02); spike S0 `FINDINGS.md` (claude 2.1.287) at
  `<session-scratchpad>/spike-hooks/`
  (session scratchpad — ephemeral; the facts it established are copied into ADR 0043
  Context item 4).

## Purpose

Make every subagent know it is a subagent — the worker, not the orchestrator — so it does its
brief's work instead of treating global Rule 2's delegation duty as its own. Nesting stays
fully available; each nested spawn is made visible (context notice + capped log line).

## Components

| # | Component | Path (canonical, hq) | Layer |
|---|---|---|---|
| C1 | Role banner hook | `tools/hooks/subagent-role-banner.sh` | L1 |
| C2 | Nesting notice hook | `tools/hooks/agent-spawn-notice.sh` | L3 Nesting notice (awareness, never a restriction) |
| C3 | Hook wiring | `config/settings.json` (live via `~/.claude/settings.json` symlink) | L1, L3 |
| C4 | Rule 2 text | `config/CLAUDE.md` (live via `~/.claude/CLAUDE.md` symlink) | L2 |
| C5 | Spawn log | `~/.claude/logs/agent-spawn/<session_id>.jsonl` (outside hq, not in VCS) | L3 |

C4's exact text is ADR 0043 §"PROPOSED — requires owner approval per Rule 9"; it is applied
only after owner approval (plan S5).

## Interfaces

### Hook input consumed (stdin JSON; measured in S0)

| Field | C1 SubagentStart | C2 PreToolUse(Agent) | Use |
|---|---|---|---|
| `agent_id` | present | present only inside a subagent (caller's id) | role test; banner/log |
| `agent_type` | present | present only inside a subagent | banner/log |
| `session_id` | present | present | log file name |
| `transcript_path` | present (main session jsonl) | present | locate `meta.json` for depth |
| `tool_input.description` | — | present | log `child_description` |
| `tool_input.subagent_type` | — | **optional** (absent when omitted) | log, `null` if absent |
| `tool_input.prompt` | — | present | optional `reason` scan for the log only |

Nothing else is read. `hook_event_name` may be checked defensively.

### Depth lookup (best-effort, both hooks)

`meta = "${transcript_path%.jsonl}/subagents/agent-${agent_id}.meta.json"`; if readable and
`.spawnDepth` is an integer, use it; otherwise depth is unknown and is omitted (text) or
`null` (log). Never inferred. For C2 the file is the **caller's**, so the value is the
caller's depth. Open S1 check: does C1's own `meta.json` exist when SubagentStart fires?
Ratification measurement (S0 transcript dir, `stat -f %SB`): depth-1 `meta.json` born
05:57:33Z; its SubagentStart `hook_success` is timestamped 05:57:32.841Z — the file did
**not** exist when C1 ran. Depth-2 is inconclusive at one-second resolution (hook .490Z,
birth second 36). Design assumption for S1: L1 omits depth; C2 (caller's file) carries it.
The path needs no cwd encoding: `transcript_path` is given verbatim in every payload
(checked on this session: `${transcript_path%.jsonl}/subagents/agent-<id>.meta.json` →
`spawnDepth: 1`).

### C1 output (always, exit 0)

```json
{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"<BANNER>"}}
```

`<BANNER>` (one paragraph; `[, depth N]` only when known):

> SUBAGENT ROLE (hq ADR 0043): You are a subagent — type `<agent_type>`, id `<agent_id>`[,
> depth N]. You are the worker, not the orchestrator (main chat). Global Rule 2's "delegate
> all work" binds the orchestrator, not you: do your brief's work yourself with your own
> tools. You may dispatch further subagents whenever that genuinely helps; say why in the
> dispatch prompt (a convention for auditability, not an enforced requirement). Rules 1, 3
> and 4 still apply to you.

Missing `agent_id`/`agent_type` → the literal `unknown` in their place; the banner is still
emitted.

**S1: as built,** a payload with no `agent_id` emits nothing (orchestrator brief, 2026-10-02; SubagentStart
always carries one); a missing `agent_type` becomes `unknown`. Fixtures live in
`tools/hooks/tests/subagent-role-contract/` (`run-fixtures.sh`); F8 checks depth on C2 only, since C1 omits it (A7).

### C2 behaviour (always allows, always exit 0)

| Condition | stdout | Log |
|---|---|---|
| `agent_id` absent/empty (main thread, incl. `claude --agent` sessions) | nothing | none |
| inside a subagent | notice JSON (below) | one line appended (if under cap) |
| any parse/IO failure | nothing (fail-open) | none |

There is no other branch: C2 never emits `deny` or `ask`, never sets
`permissionDecisionReason`, never rewrites input. Notice:

```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"agent-spawn-notice (hq ADR 0043): you are a subagent (type <t>, id <id>[, depth N]) spawning a nested child; the child will receive its own SUBAGENT ROLE banner."}}
```

`permissionDecision` is omitted so the normal permission flow is unchanged. S0 proved
delivery only with `"permissionDecision":"allow"` present; if S2 shows context-only output is
not delivered, S1 switches to adding `"permissionDecision":"allow"` (orchestrator-permitted
fallback, 2026-10-02). Either way the call proceeds. Delivery timing (docs): PreToolUse
`additionalContext` is added "next to the tool result", so the caller sees the notice once
the spawn is issued — it informs the caller's next decision and the log, not that call.

### C5 log line schema (one compact JSON object per line; observability only)

```json
{"ts":"2026-10-02T09:15:00Z","session_id":"<id>","parent_agent_id":"<caller agent_id>",
 "parent_agent_type":"<caller agent_type>","parent_spawn_depth":"<int>|null",
 "child_subagent_type":"<string>|null","child_description":"<≤240 chars>|null",
 "reason":"<≤240 chars>|null"}
```

- `ts` from `date -u +%Y-%m-%dT%H:%M:%SZ`.
- `child_subagent_type` / `child_description`: from `tool_input`, `null` when absent.
- `parent_spawn_depth`: from the caller's `meta.json` (above); an addition to the
  orchestrator's field list made possible by S0; nullable.
- `reason` (**optional**): the first prompt line that begins with the exact, case-sensitive
  bytes `NESTING-REASON:`, prefix stripped and trimmed; `null` when no such line exists.
  Its presence or absence changes nothing but this field. jq form: `(.tool_input.prompt //
  "") | split("\n") | map(select(startswith("NESTING-REASON:"))) | first // null |
  if . == null then null else (ltrimstr("NESTING-REASON:") | gsub("^\\s+|\\s+$"; "")) end`.

**Location and bounds.** `${AGENT_SPAWN_NOTICE_LOG_DIR:-$HOME/.claude/logs/agent-spawn}/
<session_id>.jsonl`, `session_id` filtered to `[A-Za-z0-9-]` (empty → `unknown-session`).
Not the scratchpad: it is under `/private/tmp` (lost on reboot, so no audit for a later
retro), and it is shared mutable state across concurrent agents (memory
`scratchpad-shared-between-agents`). Bounded per memory `no-large-state-log-files`: at most
**100 lines per session file** (at cap: no append; the notice is still emitted), string
fields truncated to 240 chars (≈≤80 KB per file worst case), and files older than **14 days**
pruned (`find "$dir" -name '*.jsonl' -mtime +14 -delete`) when a line is appended. Read it
with `wc -l`/`tail`/`jq`, never whole into an agent's context. Both numbers are tunables at
the top of C2, open to change at ratification or by the owner. `AGENT_SPAWN_NOTICE_LOG_DIR`
exists for test isolation only.

**S1: default off pending N4.** As built, C2 writes the C5 line only when `AGENT_SPAWN_NOTICE_LOG_DIR`
is set and non-empty (the owner has not agreed to the state file, ratification item N4). The
schema and caps above apply unchanged when it is set; flipping the default later is a one-line
change in `agent-spawn-notice.sh`. The variable is no longer "test isolation only".

### C3 wiring (additions only; no existing entry changes)

- `hooks.SubagentStart` gains a second element: `{"hooks":[{"type":"command","command":
  "$HOME/projects/agent-hq/tools/hooks/subagent-role-banner.sh","timeout":5}]}` (no
  matcher: every agent type). The agentmemory element stays; docs say every hook's
  `additionalContext` is delivered.
- `hooks.PreToolUse` gains `{"matcher":"Agent","hooks":[{"type":"command","command":
  "$HOME/projects/agent-hq/tools/hooks/agent-spawn-notice.sh","timeout":5}]}`.

## Constraints

- **Never blocks.** No hook in this design emits `deny`/`ask` or exits non-zero. A non-zero
  PreToolUse exit blocks unconditionally (precedent: `tools/hooks/port-precheck.sh` header),
  so both scripts exit 0 on every path and never use `set -e`.
- **Fast:** each hook under 1 s wall clock (S2 measures it); settings `timeout: 5` is a
  backstop only.
- **Tools present on this Mac (measured 2026-10-02):** `/usr/bin/jq` (`jq-1.7.1-apple`,
  ~0.00 s startup); `/bin/bash` is **GNU bash 3.2.57** — no associative arrays or bash-4
  expansions. `python3` resolves to a pyenv shim (`~/.pyenv/shims/python3`, 0.07 s startup)
  and is **not** used. `shellcheck` is not installed. Scripts call jq as
  `${JQ:-/usr/bin/jq}` (the override exists for the fail-open test) and use `command grep`.
- **Side effects:** C1 none. C2 writes only under the log dir. Neither touches the network.
- **Output is built by jq, never printf.** The banner contains quotes and backticks; stdout
  must be one valid JSON object or the harness ignores it. Build every output and log line
  with `jq -nc --arg …` so encoding is never hand-rolled. Measured hook cost in S0 for a
  jq-based hook: 12–141 ms (`durationMs` in the transcripts).
- **Cap race, accepted:** the 100-line check (`wc -l`) then append is not atomic; concurrent
  spawns can overshoot the cap by a few lines. Harmless at this size; not worth a lock.
- **Source length:** each script stays under ADR 0016's ~300-line default.

## Verification protocol (S2 — independent verifier, never the S1 author)

Live config stays untouched: everything below runs from the worktree's scripts, with
`AGENT_SPAWN_NOTICE_LOG_DIR` and all files in a verifier-unique scratch subdirectory.

**V0 static.** `bash -n` both scripts; `jq . config/settings.json` parses; `git diff
main -- config/settings.json` is additions-only and limited to the two C3 elements; a
grep shows no `set -e`, no `"deny"`, no `"ask"` and no `permissionDecisionReason` in
either script.

**V1 fixtures (stdin piped into the scripts).** F1 main-thread PreToolUse (no `agent_id`) →
empty stdout, exit 0, log dir unchanged. F2 subagent, prompt without a `NESTING-REASON:`
line → notice JSON, no `deny`, log +1 line with `reason: null`. F3 subagent with an indented
or lower-case marker → same as F2 (`reason: null`). F4 subagent with a valid marker line →
notice JSON, log +1 line with the trimmed `reason`; `child_subagent_type` `null` when absent.
F5 empty or malformed stdin → exit 0, empty stdout. F6 `JQ=/nonexistent` → exit 0, empty
stdout. F7 seeded 100-line log → no append, notice still emitted. F8 banner with a fixture
`meta.json` → contains `depth`; without → no `depth`, banner still present. F9 every fixture
under 1 s by `/usr/bin/time -p`. F10 across F1–F9, no stdout ever contains
`permissionDecision` other than (fallback only) `"allow"`. Each fixture's before/after
evidence is recorded; a check that observed nothing (e.g. an empty log dir) is a FAIL.

**V2 live harness.** A settings file holding only the two C3 elements, pointed at the
worktree script paths. Run from the verifier's scratch subdir (S0 lessons: prompt *before*
the variadic `--allowedTools`; stdin from `/dev/null`; macOS has no `timeout`):

```bash
perl -e 'alarm 300; exec @ARGV' claude -p "$(cat prompt.txt)" \
  --settings ./s2-settings.json --model haiku --allowedTools "Agent,Read" \
  < /dev/null > stdout.txt 2> stderr.txt
```

Headless subagents run in the background and `claude -p` exits before they finish (S0), so
stdout is **not** evidence. Evidence is the transcripts under
`~/.claude/projects/<encoded scratch cwd>/<session_id>.jsonl` and
`<session_id>/subagents/agent-*.{jsonl,meta.json}`, polled until they stop changing.

One run: main spawns a depth-1 subagent whose brief asks it to spawn one depth-2 child.
Check: (a) the depth-1 and depth-2 jsonl each have a `hook_additional_context` attachment
beginning `SUBAGENT ROLE (hq ADR 0043)` naming that agent's own `agent_id`; (b) the depth-1
jsonl has a `PreToolUse:Agent` `hook_success` whose stdout is the notice and carries no
`deny`; (c) a depth-2 `meta.json` exists with `parentAgentId` = depth-1 id (the spawn went
through); (d) the log has exactly one line, with `parent_agent_id` = depth-1 id — the main
thread's own spawn added none; (e) the depth-2 banner shows `depth 2` only if the S1 timing
check found `meta.json` readable at SubagentStart.

Verdict: PASS only if every V0–V2 check was observed; any unobservable check is FAIL.

**Open checks (named at ratification, not gating S2).** (i) Forks: 38 on-disk `meta.json`
files carry `"agentType":"fork","isFork":true`; whether SubagentStart fires for a fork, and
with what `agent_type`, is unmeasured. A fork inherits the orchestrator's full history, so
it is the case most likely to still self-identify as the main chat. (ii) Agents started by
the Workflow tool: no hook-docs statement either way. Either can be settled later with one
`claude -p --settings` probe; neither changes an interface.

## Non-goals

- No mechanism in this design may block or deny a spawn.
- No change to `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (default three layers stays); no change
  to `agents/topology-worker*.md` (they stay leaf workers via `disallowedTools`).
