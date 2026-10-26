# 0004. Prefix freeze: cache-safe CLAUDE.md + frozen MCP list

- **Status:** accepted
- **Date:** 2026-07-01
- **Context of:** workspace-wide

## Context

Claude Code caches the prefix (CLAUDE.md files + MCP tool definitions) for multi-turn
efficiency. Any change to a cached file busts the cache for every subsequent turn.
Uncontrolled CLAUDE.md edits and an ever-growing MCP surface erode this benefit.

**Measurement caveat (Phase-1 observation):** this harness defers MCP tool schemas —
61 tools observed as 0 prefix tokens in /context. If schema deferral means tool
definitions are loaded on first use rather than at startup, tool-count prefix cost may
be low on this harness. Phase-2 rule: measure before trimming; record findings in
tools/cache-verification-runbook.md and in an addendum here.

## Decision

**Cache-safe CLAUDE.md rules:**
- Root `~/projects/CLAUDE.md` ≤ 15 lines; hq `CLAUDE.md` ≤ ~60 lines.
- No dates, timestamps, or session-volatile content anywhere in CLAUDE.md files.
- Stable ordering; no churn. Add only at Compound time, never inline during a session.
- Never-in-CLAUDE.md: agentmemory dump output, session transcripts, per-task notes,
  anything changing more often than once per month.

**Frozen MCP list (as of Phase 1):** authoritative record is `tools/mcp-frozen-list.md`.
Servers: serena, agentmemory (trimmed; trim thresholds set after Phase-2 measurement),
notion; headroom as outermost proxy (MCP off); ccusage as passive CLI (not MCP).

**Change-control for the frozen list:**
- No new MCP server without an ADR or ADR addendum.
- Trim decisions (agentmemory tool count, Serena tool count) recorded in
  tools/mcp-frozen-list.md after Phase-2 measurement confirms the need.
- If measurement shows deferred-schema tools cost 0 prefix tokens consistently,
  record that finding; trim thresholds may be set higher than ~5.

## Reasoning

Cache hits are the single largest latency/cost lever in long sessions. The freeze
locks in the benefit; change-control ensures any erosion is intentional and recorded.
Measurement-before-trim avoids cargo-culting a trim that may be unnecessary.

## Consequences

- Easier: predictable cache hits; prefix cost bounded; context budget protected.
- Harder: discipline to avoid CLAUDE.md churn; new MCP tools require explicit decision.
- Accepted: the ~5-tool agentmemory trim number is a placeholder until measured at Phase 2.

## Alternatives considered

- No freeze — cumulative drift; prefix grows without a forcing function to notice.
- Tighter freeze (fewer servers) — start permissive; can always tighten after measurement.

## Addendum (2026-07-02): Phase 3 empirical verification, outcome

Ran `tools/cache-verification-runbook.md` end to end against the live stack (Serena +
agentmemory + Headroom wrap + prompt caching, all live as of 2026-07-02). Full numbers,
methodology, and per-risk findings are recorded in that runbook's dated
"Phase 3 verdict (2026-07-02)" section; summary here:

- Deferred-schema mechanism **confirmed empirically**, not just assumed: Serena's 22
  tools and agentmemory's 53 tools both appear only by name in the harness's deferred-tool
  listing until resolved on demand (verified live via ToolSearch). `tools/mcp-frozen-list.md`
  updated with measured counts; no trim applied to either server — the ADR's trim
  condition ("if tool defs ARE prefix-loaded") does not hold.
- Cache-read ratio: naive full-day blended reading 91.63% vs. the 92.1% pre-stack
  baseline looks like a near-pass, but the baseline was computed with a different
  formula and captured only part of the day pre-stack. The rigorous, formula-matched,
  post-stack-only comparison shows a real ~2.3 percentage point dip, fully attributable
  to today's deliberately forced worst-case events (verified app restart, corroborated
  `/compact`, heavy subagent fan-out) — not to the stack itself. Overall verdict: **PASS**.
- `AGENTMEMORY_INJECT_CONTEXT` off — confirmed from three independent sources including
  the live launchd service's environment block. Hook-injection-position risk is
  structurally moot as a result.
- Namespace isolation (personal vs. work) is **UNTESTED** and remains user-parked. This
  does not block the cache verdict but does block any work-repo memory writes until a
  dedicated cross-namespace recall test is run.

**Standing rule:** any future change to the frozen MCP list (`tools/mcp-frozen-list.md`)
or to the Headroom/wrap config requires re-running `tools/cache-verification-runbook.md`
in full before the change is considered accepted. This applies regardless of how minor
the change appears — the Phase 3 result above is only valid for the configuration as
frozen on 2026-07-02.

## Addendum (2026-07-13): Headroom 0.28.0 → 0.31.0 upgrade — standing rule triggered

Headroom (the wrap/proxy config governed by this ADR's standing rule above) was upgraded
0.28.0 → 0.31.0 this session, with 4 new `base_env` keys added to
`~/.headroom/deploy/default/manifest.json` (`HEADROOM_SAVINGS_PROFILE=balanced` plus three
explicit compression/concurrency knobs). Full reasoning, the exact keys, and the
`savings_profile` mechanic that necessitated the change are recorded in
`decisions/0002-adopt-context-memory-stack.md` (Addendum, 2026-07-13) — not duplicated
here. `HEADROOM_MODE=cache` (tool-outputs-only) is unchanged, so this ADR's frozen-list
entry for headroom (`tools/mcp-frozen-list.md`, "Proxy / CLI" table) required only a
version-number update, not a role change.

This is a Headroom/wrap config change, so the standing rule above is triggered: a full
`tools/cache-verification-runbook.md` re-run is owed before this configuration is
considered re-frozen. That re-run is **not asserted complete by this addendum** — it is
out of scope for this documentation pass. Do not read this addendum as closing the
standing-rule obligation.

## Addendum (2026-07-14): Headroom removed — second standing-rule trigger, still open

Headroom was removed from the machine entirely on 2026-07-14 ~04:17 UTC (binary,
`~/.headroom`, `ANTHROPIC_BASE_URL`, launchd job, and port 8787 all confirmed
clean/absent). Full evidence and rationale: `decisions/0019-claude-subscription-cost-optimization.md`
(Finding 0) — measured zero benefit (9,858 log records, all `tok_saved=0`).
`tools/mcp-frozen-list.md`'s Proxy/CLI table updated the same date to mark the entry
removed rather than deleting the row (append-don't-erase).

Removal is itself a Headroom/wrap config change, so it triggers the same standing rule
as the 2026-07-13 addendum above — and compounds it, since that addendum's re-run was
never asserted complete either. As of this addendum, **two** re-run obligations were
outstanding: the 2026-07-13 version-bump and this removal. Neither is closed by this
addendum on its own; see the addendum immediately below, which closes both.

## Addendum (2026-07-14): standing-rule obligation CLOSED — runbook re-run complete, verdict PASS

`tools/cache-verification-runbook.md` was re-run in full against the current live
configuration (Headroom absent) — see that runbook's "Cache verification re-run
(2026-07-18, post-Headroom-removal)" section for full methodology, per-risk findings,
and evidence. Summary:

- Live state independently reconfirmed: no Headroom binary, no `~/.headroom`, no
  `ANTHROPIC_BASE_URL` (checked both in `~/.claude/settings.json` and the process
  environment), no launchd job, port 8787 free.
- Cache-read ratio (Step-1 formula, daily `ccusage`): 4-day pre-removal mean 84.41%
  (2026-07-10–13, Headroom present) vs. 5-day post-removal mean 86.18% (2026-07-14–18,
  Headroom absent) — a slight improvement, not a regression, and well within the
  day-to-day variance already documented in the 2026-07-02 verdict.
- Hook-injection position (agentmemory): re-confirmed off via the live launchd plist —
  unaffected by the Headroom change, PASS.
- Namespace isolation: unchanged, still UNTESTED/parked — orthogonal to this change, not
  closed by this re-run, remains an open item on its own track.
- **Verdict: PASS.** This closes **both** outstanding standing-rule obligations — the
  2026-07-13 version-bump (addendum above) and the 2026-07-14 removal (addendum
  immediately above) — as of 2026-07-18. The frozen-list configuration, now
  Headroom-absent, is considered re-verified and re-frozen as of this date. A future
  reader does not need to re-derive this: the obligation is closed, not merely
  documented as attempted.
