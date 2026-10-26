# 0043. Subagent role contract — a role banner, a role-conditioned Rule 2, and a nesting notice

- **Status:** proposed — Fable T5+T6 ratified 2026-10-02, RATIFIED-WITH-AMENDMENTS
  (`architecture/subagent-role-contract-ratification.md`); Rule 2 wording still awaits owner
  approval per global Rule 9; banner/notice wording and the C5 log await owner confirmation
  at plan S4b (see Consequences)
- **Date:** 2026-10-02
- **Context of:** workspace-wide (every Claude Code session on this Mac: global
  `~/.claude/CLAUDE.md` → `config/CLAUDE.md`, live `~/.claude/settings.json` →
  `config/settings.json`)

## Context

The owner, 2026-10-02: "sub agents think they are the main chat and they keep delegating
tasks to further sub agents till the nested limit is hit." The owner also said "i want sub
agents to be able to spawn sub agents".

**Owner ruling that shapes this ADR (provenance).** Date: 2026-10-02. Mechanism: typed by
the owner in the main chat of session `84f8c8d6-466e-49e6-8c58-7a6fd0341618`, relayed
verbatim to this ADR's author by the orchestrator in a mid-task message (the author did not
witness the owner turn first-hand). Verbatim:

> "do not restrict agents from have nest sub agents. We just need agents to be aware of if
> they are a sub agent."

This ruling replaced an earlier orchestrator design whose third layer refused a nested
spawn that lacked a stated-reason marker line (see Alternatives). The fix is therefore
**awareness only**: a subagent learns its role; nothing blocks it from nesting.

**Root cause.** Facts marked (O) were supplied by the orchestrator as verified 2026-10-02
with the source shown; facts marked (A) were re-checked by this ADR's author.

1. (O, <https://code.claude.com/docs/en/sub-agents.md>) Subagents load `~/.claude/CLAUDE.md`
   by default; built-in Explore and Plan skip it; `omitClaudeMd: true` opts a custom agent
   out. Nesting is on by default, three layers deep; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`
   changes it. `general-purpose` and `claude` agent types carry the Agent tool.
2. (A) `~/.claude/CLAUDE.md` is a symlink to `hq/config/CLAUDE.md` (`ls -la`). Its H1 says the
   rules "apply to every session and task"; Rule 2 says "All work is delegated to subagents
   (the Agent tool)". A subagent that reads this file reads an unconditional order to
   delegate — and obeys it, spawning another subagent that reads the same order.
3. (A, <https://code.claude.com/docs/en/hooks.md>, fetched 2026-10-02) Hook input carries
   `agent_id` "only when the hook fires inside a subagent call" and `agent_type` for
   subagents and `--agent` sessions; `SubagentStart` returns
   `hookSpecificOutput.additionalContext` and "cannot block"; PreToolUse output supports
   `permissionDecision` (`allow|deny|ask|defer`), `permissionDecisionReason`,
   `updatedInput`, `additionalContext`; several hooks' `additionalContext` for one event are
   all delivered. No parent-agent id and no depth field are documented.
4. (S0 spike by another agent; its `FINDINGS.md` read by this author 2026-10-02; claude 2.1.287)
   Measured payloads. `SubagentStart` stdin keys: `session_id, transcript_path, cwd,
   prompt_id, agent_id, agent_type, hook_event_name`. `PreToolUse` with matcher `Agent`
   (observed `tool_name` = `"Agent"`) inside a subagent adds `permission_mode, tool_name,
   tool_input, tool_use_id` and carries the **caller's** `agent_id`/`agent_type`; in the main
   thread both are absent. `tool_input` keys seen: `description, prompt, model` —
   `subagent_type` is absent when the model omits it. No parent or depth key in any payload.
   Returned `additionalContext` reached the subagent at depth 1 and depth 2 (SubagentStart)
   and the caller (PreToolUse, returned with `permissionDecision: "allow"`). Depth **is** on
   disk: `<transcript dir>/<session_id>/subagents/agent-<agent_id>.meta.json` holds
   `spawnDepth` and `parentAgentId` (absent at depth 1); `transcript_path` in subagent
   payloads points at the main session jsonl.
5. (A) `config/settings.json` hooks today: `PreToolUse` matchers are only
   `Edit|Write|Read|Glob|Grep` (agentmemory) and `Bash` (`port-precheck.sh`) — **no `Agent`
   matcher**. One `SubagentStart` hook exists (agentmemory `subagent-start.mjs`).
6. (A) hq already makes three agents structural leaves: `agents/topology-worker{,-light,
   -strong}.md` each carry `disallowedTools: ["Agent"]` (ADR 0037). That fits a worker that
   must never nest, but applied workspace-wide it would restrict nesting, which the owner
   ruled out.

## Decision

We will add a three-layer **subagent role contract** whose every layer informs and none
restricts. Interfaces: `architecture/subagent-role-contract.md`; execution:
`plans/subagent-role-contract.md`.

- **L1 — Role banner.** A `SubagentStart` hook, `tools/hooks/subagent-role-banner.sh`, wired
  in `config/settings.json`, returns `additionalContext` for every subagent: it is a
  subagent of type `<agent_type>` with id `<agent_id>`; it is the worker, not the
  orchestrator; global Rule 2's delegation duty binds the orchestrator, not it; it does its
  brief's work itself and may dispatch further subagents when that genuinely helps, stating
  why in the dispatch by convention (auditability only; nothing checks it). It adds "depth N"
  when the agent's `meta.json` is readable (best-effort; whether the file exists when
  SubagentStart fires is unverified — an S1 check item) and omits depth otherwise.
- **L2 — Role-conditioned Rule 2.** Rule 2 in `config/CLAUDE.md` is rewritten so the
  orchestrator obligation is unchanged, a subagent clause is added, and nesting stays
  explicitly permitted. Proposed text below; it is **not** applied by this ADR.
- **L3 — Nesting notice (awareness, never a restriction).** A `PreToolUse` hook (matcher
  `Agent`, the `tool_name` S0 observed), `tools/hooks/agent-spawn-notice.sh`, **always
  allows** and always exits 0:
  - no `agent_id` (main thread, including `claude --agent` sessions) → no output;
  - inside a subagent → one-line `additionalContext`: the caller is a subagent of type X
    (at depth N if known) spawning a nested child, and the child will receive its own role
    banner; plus one JSON line appended to a capped per-session log, for observability only.
    The log's `reason` field is optional: taken from a line starting `NESTING-REASON:` in the
    dispatch prompt if one is present, `null` otherwise — absence changes nothing else.
- Nesting stays allowed; the default three-layer cap stays. **No mechanism in this ADR may
  block or deny a spawn.**

### PROPOSED — requires owner approval per Rule 9

Replacement for the whole `## Rule 2` section of `config/CLAUDE.md` (H1 and other rules
unchanged):

```markdown
## Rule 2 — The Orchestrator Delegates; a Subagent Does Its Brief's Work
- **Know your role.** You are a subagent if your context opens with a `SUBAGENT ROLE` banner
  (ADR 0043) or your conversation began with a dispatch brief from another agent rather than
  a message from the owner. Otherwise you are the orchestrator (the main chat).
- **Orchestrator:** Do not perform substantive work directly in the main chat. All work is
  delegated to subagents (the Agent tool). The main thread only orchestrates, validates
  subagent output, and synthesizes results.
- **Subagent:** The delegation obligation above does not bind you. Do your brief's work
  yourself with your own tools. You may dispatch further subagents whenever that genuinely
  helps; say why in the dispatch prompt (a convention for auditability, not an enforced
  requirement). Rules 3 and 4 apply to any agent you spawn.
- Subagents must themselves follow Rule 1 (validate, don't assume).
- Exception (orchestrator): the Session Startup bootstrap (running the session-startup skill
  on the first message of a session) may run in the main thread. Everything else delegates.
```

## Reasoning

- The defect is a role-blind instruction loaded into a context that has a different role.
  Only the harness knows the role reliably — `agent_id` is present exactly in subagents
  (docs; S0 measured it absent in the main thread) — so the role statement is injected by a
  hook (L1), not inferred by the model.
- L2 removes the instruction that caused the loop at its source, for agents that load the
  file; L1 reaches every subagent, including ones that skip CLAUDE.md.
- Ordering (ratification, from the S0 transcripts): CLAUDE.md is in the system prompt, so a
  subagent reads Rule 2 *before* the banner, which lands as transcript lines 1–2 right after
  the brief (user line 05:57:32.824Z, hook attachment .841Z). The banner therefore precedes
  the subagent's first *action*, not its first *read* — which is why L2 is kept as a layer.
- L3 repeats the awareness at the one moment it matters — the spawn — without taking
  anything away, and its log turns "keeps delegating until the limit" from an anecdote
  into a per-session count readable with `tail`.

## Consequences

- Easier: subagents learn they are workers and stop treating Rule 2 as theirs; every nested
  spawn is visible in its caller's context and in the log; main-thread behaviour is
  untouched (L3 keys on `agent_id`).
- Harder / accepted losses:
  - **Awareness, not prevention.** A subagent that still re-delegates its whole brief is not
    stopped. Accepted by owner ruling; the log shows whether awareness was enough.
  - **No exact depth from the hook contract.** Hook stdin has no parent id or depth (S0).
    Depth is read best-effort from the undocumented on-disk `meta.json`; when unreadable it
    is omitted, never guessed. The harness's three-layer cap remains the only depth bound.
    Ratification measurement (S0 transcripts, `stat` birth time): the depth-1 `meta.json`
    was born at 05:57:33Z, *after* its SubagentStart hook finished (.841Z) — so expect L1
    to carry **no** depth in practice; only L3's log (caller's file, already on disk)
    reliably has it. The S1 check item stands to confirm.
  - **L3 is after-the-fact for the spawn it observes.** Docs: PreToolUse `additionalContext`
    is "added to Claude's context next to the tool result", so the notice reaches the caller
    once the spawn is issued; it informs the *next* decision and the log, not that call.
  - **Fail-open/silent.** Any hook error (no `jq`, bad JSON) produces no output, mirroring
    `port-precheck.sh`'s "never brick the machine" stance; S2's positive controls catch a
    silently dead hook.
- **Extreme-caution scope.** L1/L3 wiring edits `config/settings.json` (live via symlink)
  and L2 edits `config/CLAUDE.md` (live via symlink): ADR 0014 **T5** fires alongside **T6**.
  Merging to hq main *is* activation for both files. The 2026-09-17 main-push grant
  excludes committing/pushing `config/settings.json`, so activating L1/L3 is an owner step
  (plan S4b); merging the scripts alone is inert.
- **Owner confirmations folded into S4b (Rule 9; ratification).** The banner and notice
  wording state how Rule 2 binds, the `NESTING-REASON:` line is an agent-proposed
  convention, and the C5 log is a new append-only state file — memory
  `no-large-state-log-files` (owner, 2026-09-13) requires prior agreement for any such
  file. None is a restriction on spawning; each is presented verbatim at S4b for the owner
  to confirm, amend, or strike.
- Revisit if: the log shows subagents still re-delegating whole briefs despite L1/L2 — any
  stronger response is the owner's call, given the 2026-10-02 ruling.

## Alternatives considered

- **Nesting gate: PreToolUse deny unless the prompt has a `NESTING-REASON:` line** — rejected
  by the owner, 2026-10-02, as a restriction (ruling quoted in Context).
- **Lower `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`** (e.g. to 1) — rejected: removes nesting,
  which the owner explicitly wants kept.
- **`disallowedTools: ["Agent"]` on every agent definition** — rejected for the same reason;
  it also cannot touch built-in `general-purpose`/`claude`. Kept where it already fits
  (topology workers).
- **CLAUDE.md-only fix (L2 alone)** — rejected: Explore/Plan and `omitClaudeMd` agents skip
  the file, and text is not harness-injected; it is kept as one layer, not the fix.

## Non-goals

- No mechanism in this ADR may block or deny a spawn.
- No change to the default depth cap; no change to `agents/topology-worker*.md`.

## Links

- `architecture/subagent-role-contract.md` — components, interfaces, verification protocol.
- `plans/subagent-role-contract.md` — dispatch plan S0–S5.
- `decisions/0037-agent-topology-native-supersession.md`, `agents/topology-worker*.md`,
  `skills/agent-topology-router/SKILL.md` — leaf workers; unchanged by this ADR.
- `decisions/0014-model-tier-operating-policy.md` — T5/T6 ratification.
- `decisions/0027-claude-global-config-in-hq.md` — why `config/` edits are live.
- `tools/hooks/port-precheck.sh` — fail-open hook precedent.
