# Global Rules (HIGHEST PRIORITY — apply to every session and task)

## Rule 1 — Zero Trust: Never Assume, Always Validate
- Never assume. Investigate, check, and validate before making ANY assertion or claim.
- Validate even statements the user asserts as true. If the user says "X is true," confirm X against actual files, commands, or authoritative sources before acting on it.
- This is a zero-trust environment: everything is validated. Evidence before assertions, always.
- If validation is not possible, say so explicitly rather than guessing.

## Rule 2 — Delegate All Work to Subagents
- Do not perform substantive work directly in the main chat.
- All work is delegated to subagents (the Agent tool). The main thread only orchestrates, validates subagent output, and synthesizes results.
- Subagents must themselves follow Rule 1 (validate, don't assume).
- Exception: the Session Startup bootstrap (running the session-startup skill on the first message of a session) may run in the main thread. Everything else delegates.

## Rule 3 — Always Pin the Subagent Model Explicitly
- Every subagent dispatch (Agent tool) MUST set the `model` parameter explicitly. Never rely on default or inherited model selection.

## Rule 4 — Match Model to Task (Cost vs. Difficulty)
- Before every dispatch, make a best-effort assessment of which model best fits the task, weighing cost against task difficulty.
- Heuristic: Haiku for mechanical / low-ambiguity work (file edits, lookups, running commands, simple verification); Sonnet for standard investigation, research, and moderate coding; Opus for complex reasoning, architecture, hard debugging, or high-ambiguity synthesis.
- Main seat: Opus for all orchestration. Fable never holds the main seat; it is dispatch-only (design ratification, trigger-fired escalation, post-incident assessment) — bounded one-shot dispatches with curated context.
- Ladder top: first Opus failure → retry once with upgraded spec + verification rigour; second Opus failure → mandatory Fable dispatch. Never a third Opus attempt.
- Fable escalation is MANDATORY when any ADR 0014 trigger fires (T1 two Opus failures; T2 falsified working hypothesis; T3 unresolved safety-stop or gate-bypass pressure; T4 cross-system failure; T5 extreme-caution-file scope; T6 architecture ratification; T7 user says hard/stuck/escalate). No discretion to skip a fired trigger; discretionary escalation is allowed in addition, never instead.
- Qualifying incidents get a post-incident assessor per ADR 0014 (curated input packet, ≤10-line steering output); a "fix wrong / masks deeper cause" verdict is stop-the-line.
- Log every trigger fire and assessor verdict as one line in the current eval log (per ADR 0014 Appendix B).
- When dispatching, state the chosen model and a one-line rationale.
- Escalate, don't retry: if a subagent stalls, fails, or hits genuine ambiguity, stop it and re-dispatch one model tier up — never re-run the same tier hoping for a better result.
- Design expensive, execute cheap, verify independently: settle designs once with a top-tier model; mid/low tiers execute the settled spec; verification goes to a separate agent instance, never the author.
- Every dispatch states an explicit, verifiable done condition and a stop-on-anomaly clause; subagent reports are checked against the done condition before acceptance. A blocked gate or safety stop in any report is stop-the-line for the orchestrator — never bypassed, never assumed benign.
- A harness classifier block on a dispatched action is itself a stop-the-line, not a tooling glitch: it clears ONLY via a fresh owner-witnessed grant carried into the retry with verbatim provenance (date, mechanism, selection) — never by rewording, rerouting through another agent, or retrying unchanged. (Compound 2026-08-30.)

## Rule 5 — Architecture First, Dispatch Plan Second, Action Last
- Before any substantive build or change work, two artifacts must exist, in order:
  1. **Architecture / plan** — WHAT is being built and WHY: components, interfaces, constraints, and the settled design decisions. Ratified before anything executes.
  2. **Dispatch plan** — HOW it gets built: the ordered subagent dispatches derived from the architecture, each with its model (Rule 4), done condition, and independent verification step.
- Only then execute, dispatch by dispatch. Never design and execute in the same breath.
- Prefer existing architecture docs over recreating from scratch — locate them, validate their currency against ground truth (Rule 1), and update them; a stale doc is corrected, not duplicated.
- In hq-governed work: architecture lives in `~/projects/agent-hq/architecture/`.
- Exemption: sub-threshold mechanical work (single-file edits, lookups, status flips, memory updates) proceeds without the ceremony.

## Rule 6 — Repo Work Happens in Worktrees; the Default Branch Is for Integration Only
- In any git repo, EVERY work unit — even a one-line, single-commit change — runs in a dedicated worktree (`git worktree add <repo>-worktrees/<slug> -b wt/<slug>`), never authored directly on the default branch (main/master/trunk). No exemptions.
- On completion, integrate: validate in the worktree (the repo's own checks/gates), then either merge to the default branch locally and push immediately, or — in repos with a PR-based flow — push the branch and integrate via PR. Then remove the worktree and delete the wt/ branch. A finished work unit never leaves the default branch un-updated or a worktree dangling.
- The default branch is for integration and repair only: merges, pushes, and arrival fixes — never for authoring new work.
- Concurrency is normal: other sessions work in the same repos, so the default branch moving ahead of your last-known state is EXPECTED, not an anomaly — give new commits a light provenance glance (real commit? conflicts with my work?) and proceed.
- The ONLY anomalies: a dirty working tree, unpushed local commits (anyone's unintegrated work — backup gap), failing checks/invariants, or a dangling worktree.
- Arrival duty: starting work in a repo showing any anomaly above — fix-or-surface that first, before any new work.
- Repo-local decisions (e.g. hq ADR 0017, which supersedes ADR 0013's exemption) may tighten but not loosen this rule.

## Rule 7 — Assess Parallelization at Plan-Authoring Time
- **Trigger/scope:** This fires any time ANY plan or spec is authored, anywhere — not limited to hq's Rule 5 dispatch-plan step. It covers Rule 5 dispatch plans, `writing-plans` specs, `wave-execution` spec_roots, and any other multi-step implementation plan, in any repo or project.
- **Stress-test framing:** The author imagines up to ~30 agents being available for the work as a thought-experiment ceiling, NOT a literal fleet-size target. Its purpose is to force genuinely checking which pieces could run concurrently, instead of defaulting to serial structure or reflexively over-splitting. The actual agent count used is whatever the safety and cost bars below allow — usually far below 30.
- **Safety bar:** A split counts as "safe" ONLY if the parallel pieces share no mutable state. That covers, at minimum: no same-file edits; no shared git-checkout/branch state (per Rule 6, concurrent pieces need their own worktree even when they don't overlap on files — this is why `subagent-driven-development` bans parallel implementation dispatch even absent file overlap); no shared external resources (ports, dev servers, databases, rate limits, lockfiles); and no output-to-input dependency between them. These examples are illustrative of the shared-mutable-state principle, not an exhaustive list — anything with cross-task dependencies stays serial, or becomes a later phase/wave once the dependency resolves.
- **Cost bar:** The primary cost to weigh is coordination/verification overhead, not raw token or wall-clock spend — every parallel split adds its own rendezvous point and its own independent verification step (cross-reference Rule 4's "verify independently" principle). Don't split finer than the point where the added verification/coordination overhead would exceed what parallel execution actually saves.
- **Documentation requirement:** The plan must carry a brief explicit note recording the assessment, e.g. "N of M tasks are safely parallel (no shared state); assessed against a ~30-agent ceiling; kept serial because X." This makes the reasoning auditable rather than assumed.
- **Exemption:** Extends Rule 5's exemption pattern — sub-threshold mechanical work (single-file edits, lookups, status flips, memory updates) skips this assessment entirely, plus one addition specific to this rule: plans with only 1-2 tasks are also exempt. (Rule 5 itself has no task-count criterion — this threshold is new here, not inherited from Rule 5.)
- **Relationship to existing tooling:** This rule is self-contained and portable across all projects — it is not a thin pointer that only works inside hq. It is the **planning-time counterpart** to `wave-execution`'s `dispatch_budget` (ADR 0023) and its deferred `max_concurrent` cap: those are *runtime* preflight backstops that refuse or limit an over-large dispatch once a plan already proposes one — before any agent is actually spawned (ADR 0023's rule 11 halts at validation time, not mid-execution); Rule 7 is what should keep a plan from proposing an unsafe or uneconomical split in the first place. The two are cross-referenced, not redundant, not duplicative.

## Rule 9 — No Agent Makes a Rule; Only the Owner Does
- No agent invents, adopts, generalizes, or propagates a standing rule, policy, convention, retention practice, or prohibition unless the owner has explicitly approved it — recording a FACT an agent measured is fine; converting that fact into a standing constraint that binds future work is not.
- An agent that believes a rule is needed proposes it to the owner and waits — it does not adopt it, and does not write it into a learning, a memory note, a brief, or a doc where later agents will read it as binding.
- Existing written guidance that cannot be traced to owner approval is a suggestion, not a rule: surface it, don't obey it silently.
- Owner instruction, 2026-09-21: "No agent makes any rule unless approved by me."

## Rule 10 — hq Code Ships Through PR Review and Mapped Tests
- Owner, 2026-10-01 (verbatim): "Any code thats getting created to be pushed to hq main must go through a round of pr-review additionally tests should be written for it so that the merge to main in the future for changes to that specific fiel runs those tests"
- **Scope:** executable files in hq — shell/zsh/python/js scripts, hooks and tools (e.g. `tools/**`, `*.sh`, `*.zsh`, `*.py`, `*.js`). Markdown docs, ADRs, learnings, SKILL.md prose, `config/settings.json` and `plans/**` evidence scripts are excluded. *(owner ruling 2026-10-01)* The vendored swarm bus (`tools/swarm-communication-layer/**`) is also excluded. *(owner ruling 2026-10-22, verbatim: "no need to review something thats already stable")*
- **Review:** a work unit that changes in-scope code pushes its `wt/` branch, opens a GitHub PR, and runs the `pr-review` skill on it; it may merge only at 0 Blocking / 0 Medium. Doc-only work keeps the local-merge flow (Rule 6).
- **Tests:** every in-scope file has its test(s) in a versioned file→test map; a git hook installed via `core.hooksPath` runs the mapped tests for each changed file and blocks the push on failure. A changed in-scope file with no mapped test blocks the push.
- **Existing untested code:** editing a grandfathered (untested) file requires writing its test in the same change; the grandfather list may only shrink.
- **Integration:** local merge → push `main`. Never merge an hq PR on GitHub (GitHub cannot enforce checks on this plan). Never use `--no-verify` or a `core.hooksPath` override on hq. A code-gate block is stop-the-line (Rule 4).

## Rule 11 — Planned Work and Runs Are Auto-Approved (owner 2026-10-11)
- Owner, 2026-10-11 12:58Z (verbatim): "Make this a rule moving forward alll runs for the work we're doing re apprpoved do not stop or deny that from happening again"; 12:59Z (verbatim): "Makie the rule moving forward regarding auto approving all runs and work that we plan out"; 13:02Z: "Yes that should be apart of the global rules".
- Every run (pipeline rounds, sets, relaunches, new set ids) and every work unit that comes out of a plan produced under Rule 5 (architecture + dispatch plan, plan-checked where Rule 7 applies) is approved for execution the moment the plan exists. Plan first, then execute. Never hold, stop, deny, or ask "may I proceed" for such work or runs; never park execution behind an approval question.
- Only the owner's own pause/stop instruction halts a run or a work unit; a lift is the owner's word (plus removal of any PAUSED marker the pause created).
- Unchanged by this rule: stop-the-line safety stops (classifier block, isolation BREACH, failing gates/checks, Rule 6 and Rule 10 anomalies) are reported and stop the line; Rule 9 (only the owner makes rules) and genuinely owner-only choices (new rules, money, external publication, deleting data) are still asked, one question per message, without blocking the rest of the plan.

## Rule 12 — Reviews Use the Review Skills; Pick the Rung by Complexity (owner 2026-10-16)
- Owner, 2026-10-16 (verbatim): "Whenever a review needs to be done by any agent it should reach for the skills that exist on the system for doing reviews. There are instructions with the skills so you know the appropriate skill to use based on the complexity of the task"
- Scope: any review of any artifact (docs, plans, specs, designs, code, fixes), by the orchestrator or any subagent.
- Before dispatching a review, select the skill from hq `tools/review-ladder.md` and the skills' own descriptions; take the lowest rung that covers the risk. Do not improvise ad hoc review prompts where a review skill covers the artifact.
- Unchanged by this rule: Rule 4 (verifier is a separate instance, never the author), Rule 10 (pr-review for hq code), and repo-local decisions, which may tighten or specify.

## Rule 13 — Learnings Live in Hermes: Recall Before Work, Capture After Verification (owner 2026-10-21)
- Owner, 2026-10-21 (verbatim): "D-2 approve but this does not impact agents running in the pipeline just the brain".
- SCOPE (owner-set 2026-10-21): this rule applies to EVERYONE across the system — the brain (orchestrator + members) and every other non-experiment agent or session — not the brain alone. The ONE exclusion is the experiment agents running inside the pipeline: NO rule of this learning system (and no brain/global rule of this kind) binds them; they stay fully isolated from Hermes. (Owner clarification, verbatim: the Hermes learning system is "technically for everyone", and "none of those rules are for the pipeline experiments".)
- Hermes skills are the single store of learnings and standards (for everyone this rule covers); hq keeps tools and decisions; agentmemory is an observation plane, never a learnings store.
- Before design, build, review or verification work, recall what is known: ask the door for the topic, or when it is down or slower than 90 s read the skill files directly; record `recall: <skills|skipped: why>`; cite what was used as DATA, never as a rule (Rule 9). No work is ever blocked on the door.
- Every skill carries kind (standard|fact|default|question), status (proposed|verified|adopted|retired), topic and provenance (source path@sha or ledger id, date, verified-by). Agents write facts, defaults and questions; only the owner's quoted words make a standard or adopt one.
- A learning is captured after a different agent has verified it, as one skill per topic: update the existing skill, never add a near-duplicate; door down, queue it and capture at the next window. Verifiers read the capture back before PASS and record `capture: <slug|none>`.
- A finding marked "owner to decide" becomes a parked owner question in the same tick; a change that depends on it does not merge before the question is parked.
## Rule 14 — rm Commands Name Every Target by Full Path (owner 2026-10-28)
- Owner, 2026-10-28 (chat, verbatim): "Moving forward any commands that have rm inside of it must spell out the full paths for all the things that are being removed."
- Owner, 2026-10-28 (chat, verbatim): "ADd that as a global rule for all agents that rm commands names the full path of everything it removes, with no variables, wildcards or bash -c scripts hiding the target"
- Every command containing rm names the full path of everything it removes, with no variables, wildcards or bash -c scripts hiding the target.
- Scope: all agents.
