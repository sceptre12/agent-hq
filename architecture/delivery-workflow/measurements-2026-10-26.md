# Delivery workflow: W0 measurements (items 1 and 4), 2026-10-26

Measured from an executor-tier session (bypassPermissions + deny list + OS sandbox), Claude Code 2.1.310, macOS (Darwin 25.6, arm64). Session cwd was the profile workspace, not an `agent-hq` checkout (subagents inherit it), so "in an `agent-hq`-cwd session" below means: the `agent-hq` tree was read through absolute paths. Every probe ran once; a block is recorded as a result and not retried or routed around. Nothing was written except this file (plus scratch outside the repo). Subagents used: 4 of the 6 allowed.

Legend: CONFIRMED = design §6.1 row holds as written. CHANGED = differs from the design. NEW = measured fact the design does not have. NOT MEASURED = could not be done from this session, with the reason.

## Item 1. §6.1 rows 1 to 7

### Row 1. Subagent concurrency default, env var, spawn depth

Source: read-only scan of the installed binary (`$HOME/.local/share/claude/versions/2.1.310`, 274 MB) with python3 `mmap`, no execution of it.

| Fact | Evidence (binary 2.1.310) | Verdict |
|---|---|---|
| Concurrent subagents default is 20, env var `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` | `var Y6r=20; function s0r(){return env.CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS??Y6r}` | CONFIRMED |
| Over the limit the spawn is refused | error text: `Concurrent subagent limit reached. You can run N subagents at once. Do not retry. If the user wants more concurrent subagents, ask them to increase CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS.` | NEW (the refusal says "Do not retry") |
| Spawn depth default 3, env var `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` | `var n=3; function Fk(){ env var if set; else GrowthBook flag "tengu_hazel_trellis" (integer >= 1); else n=3 }` | CONFIRMED, with a caveat: the effective default can be changed server-side by the GrowthBook flag, so 3 is the compiled fallback, not a guarantee |
| Depth rule | `callerDepth >= limit` refuses; the main session is depth 0. Error: `Subagent nesting limit reached (depth N of M). Complete this task directly using your tools instead of spawning another agent. If the user explicitly requested deeper nesting, ask them to raise CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH.` | NEW |
| A third variable `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` exists and is on the env allowlist | 3 hits in the binary; no compiled default found in the strings I read | NEW |
| `tools`/`disallowedTools` frontmatter can remove the Agent tool; `disable-model-invocation: true` blocks Skill-tool calls | not re-measured (documentation claim in the design) | NOT MEASURED |

Values in THIS session (a profile setting, not a default): the profile `settings.json` `env` block sets `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=50` and `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION=1000`; neither depth variable is set. Commands: `env | grep CLAUDE_CODE_MAX`; python3 reading `$CLAUDE_CONFIG_DIR/settings.json` key `env` (only the `CLAUDE_CODE_MAX*` keys printed). Consequence for the design: the "20 per session" cap that the build ledger assumes is the compiled default; a profile can raise both numbers, and this one does. Whether the session cap counts nested descendants is still unmeasured.

### Row 2. Nesting depth

See Item 4 (A). Result: three levels of subagents below the main session were spawned (main to A, A to B, B to C); C had no Agent tool, which is what depth limit 3 predicts.

### Row 3. macOS userland

| Command | rc | Result |
|---|---|---|
| `/bin/bash --version \| head -1` | 0 | `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)` |
| `zsh --version` | 0 | `zsh 5.9 (arm64-apple-darwin25.0)` |
| `which flock lockf shlock mapfile timeout gtimeout` | 1 | only `/usr/bin/lockf` and `/usr/bin/shlock` found; no `flock`, `mapfile`, `timeout`, `gtimeout` |
| `sed --version`; `date -d now`; `du -b /dev/null` | non-0 | `sed: illegal option -- -`; `date: illegal option -- d`; `du: invalid option -- b` (BSD userland) |
| `kill -0 $$` | 0 | succeeds |
| `lsof -nP -iTCP -sTCP:LISTEN \| head -2` | 0 | lists host listeners (header plus rows) |
| `/bin/ps -p $$`; `pgrep -x bash` | 126 / 1 | `/bin/ps: Operation not permitted`; `pgrep: Cannot get process list` (`sysmond service not found`) |

Verdict: row 3 CONFIRMED. NEW: `ps` AND `pgrep` are both blocked in this executor sandbox, so a shepherd's liveness test must be `kill -0 <pid>`, `lsof`, or a pid file; the design's own gate checks that shell out to `ps` do not run here (the Hermes seed helper's success path is the known example).

### Row 4. Concurrent appends

Command: 10 background `echo "<599 chars>" >> file` jobs, `wait`, then a python3 check of every line. Result: `lines 10 bytes 6000 all 599 chars uniform: True`. Verdict: CONFIRMED (this is the third run on this host: 10 of 10 intact each time; still not a stress test).

### Row 5. Learnings and retros

`ls -d <W>/learnings <W>/retros` gives `No such file or directory` for both (W = this worktree). `STANDARDS.md` lines 16, 72, 73 say learnings go to Hermes through its API door. `tools/hermes/setup/` holds: README.md SOUL.md config-edits.md config.active.yaml hermes-gw hermes-up hermes-up.plist.example pre-tool-call.sh seed-hook-allowlist. Verdict: CONFIRMED.

### Row 6. Skills that exist only in hq

| Skill | in hq `skills/` | in agent-hq main `c1ba30e` | in this worktree |
|---|---|---|---|
| review-7-panel | yes | no | yes, untracked |
| feature-change | yes | no | yes, untracked |
| port-claim | yes | no | yes, untracked |
| sim-lease | yes | no | yes, untracked |

Command: `git ls-tree -d --name-only c1ba30e skills/<name>` (0 for all four) and `git status --short -- skills` (`??` for all four). Verdict: CONFIRMED for main; the four directories now exist untracked in the worktree, i.e. work item 8 ports are already landing.

### Row 7. Proof Web platform facts (§5.8b)

The work-context store exists locally at `$HOME/projects/X-context-docs` (the design writes `x-context-docs`; the filesystem is case-insensitive). §5.8b has 16 table rows and cites 3 `XC/...` paths; all 3 exist. NOT re-verified: the content of the 16 rows against those files (this was an existence check only). Verdict: NOT MEASURED beyond path existence.

### Also requested: pm2 and bus startup, `claude -p`

| Probe | Command | rc | Result |
|---|---|---|---|
| pm2 binary | `which pm2` | 0 | found under the nvm node 22.13.0 bin dir |
| pm2 daemon | `pm2 ping`; `pm2 jlist` (earlier M-probe, same session type) | 1 | `connect EPERM $HOME/.pm2/rpc.sock`, then `EPERM ... open '$HOME/.pm2/pm2.log'` at `Client.launchDaemon` |
| bus code deps | `ls tools/swarm-communication-layer/node_modules` (main checkout and this worktree) | 2 | absent in both; `package.json` lists `get-port`; installing is not allowed in this session |
| bus data dir | `mkdir /tmp/probe-w0-$$` | 1 | `Operation not permitted`; `mkdir $TMPDIR/probe-w0-$$` succeeds |
| `claude -p` | `claude -p "reply OK" --model haiku` (earlier M-probe, same session type) | 1 | `Not logged in · Please run /login` |

Verdict: NEW. A per-session bus cannot be started from this session type for three independent reasons: pm2 cannot reach its daemon, the bus has no `node_modules`, and Step 1 of `pr-review` puts `DATA_DIR` under `/tmp`, which is not writable here (only `$TMPDIR` is). `claude -p` is unusable from this session type.

## Installed yes/no per REUSE row (design §2.1)

"installed" = `ls -L $HOME/.claude/skills/<name>` succeeds, or the skill ships in an installed plugin. "present" = a directory in agent-hq main `c1ba30e` `skills/`. The profile's own `skills/` matches `$HOME/.claude/skills` for every name below.

| Skill (verdict in §2.1) | installed | present in agent-hq main | note |
|---|---|---|---|
| `mattpocock-skills:grilling` (REUSE) | yes, plugin `mattpocock-skills@mattpocock` | no | plugin skill, not under `skills/` |
| `mattpocock-skills:domain-modeling` (REUSE) | yes, same plugin | no | plugin skill |
| `doc-reviewer` (REUSE + EXTEND) | yes | yes | |
| `panel-consultation` (REUSE) | yes | yes | |
| `review-7-panel` (REUSE) | no | no | hq only; ported untracked in the worktree (item 8) |
| `panel-review` (REUSE) | yes | yes | |
| `writing-plans` (REUSE) | yes | yes | |
| `wave-execution` (NEW + EXTEND base) | yes | yes | |
| `feature-change` (EXTEND base) | yes | no | installed as a link into hq; ported untracked in the worktree |
| `pr-review` (EXTEND base) | yes | yes | |
| `fix-verifier` (EXTEND base) | yes | yes | |
| `port-claim` (item 8) | yes | no | installed as a link into hq; ported untracked in the worktree |
| `sim-lease` (item 8) | yes | no | installed as a link into hq; ported untracked in the worktree |
| `superpowers:test-driven-development` (REUSE) | yes, plugin `superpowers@claude-plugins-official` (cache versions 6.4.1 and 7.0.0) | no | plugin skill |
| `superpowers:using-git-worktrees` (REUSE) | yes, same plugin | no | plugin skill |
| `superpowers:verification-before-completion` (REUSE) | yes, same plugin | no | plugin skill |
| `superpowers:dispatching-parallel-agents` (REUSE) | yes, same plugin | no | plugin skill |
| `mattpocock-skills:resolving-merge-conflicts` (REUSE) | yes, plugin `mattpocock-skills@mattpocock` | no | plugin skill |

Work-environment skills (§2.1b), all expected not installed here: `create-pr`, `harness-api`, `jira`, `jira-ticket-quality`, `package-release`, `pr-check-migration-needed`, `migration-assessment`: installed NO (neither `$HOME/.claude/skills` nor the profile), present in agent-hq NO; each exists as a directory in the read-only work-context store. The NLTA plugin: no skill dir named `nlta`, no plugin cache or marketplace entry matching `nlta` (0 hits). Command: `ls -L $HOME/.claude/skills/<name>`, `ls -L $CLAUDE_CONFIG_DIR/skills/<name>`, `git ls-tree -d --name-only c1ba30e skills/<name>`, and `find -L $HOME/.claude/plugins -name <skill>` for plugin skills.

## Item 4

### (A) One-level and two-level nested spawns

Method: Agent tool, `general-purpose`, model haiku, each agent told to dispatch exactly one subagent with the next prompt and to quote the result verbatim; the last agent attempts a fourth level. Plus one `topology-worker-light` agent asked only to report its tool list.

| Level | Who | Agent tool present | Result |
|---|---|---|---|
| 0 | main session | yes | dispatched A |
| 1 | A | yes | dispatched B, worked |
| 2 | B | yes (A reports B made its one tool call, the dispatch to C) | dispatched C, worked |
| 3 | C | NO. C's own words: "My tool list has no Agent tool. A ToolSearch for `select:Agent` returned 'No matching deferred tools found.'" | no fourth-level dispatch was possible; no depth error text was produced because the tool is withheld |
| n/a | `topology-worker-light` (1 level below main) | NO: "There is no `Agent` tool among my tools" | matches its definition (all tools except Agent) |

Reading: with spawn depth limit 3 the main session can reach three nested levels, and the Agent tool is removed (not refused with an error) at depth 3, so the effective rule is "main, then A, B, C; C cannot spawn". Caveats: one run; B's tool list is known only through A's report; the earlier M-probe (main to A to B) agrees. Not measured: the error text shown when a spawn is attempted at the cap (the tool was absent, so no attempt could be made), behaviour with many agents in flight, and whether nested descendants count toward the per-session cap. The `topology-worker*` types cannot orchestrate at all.

### (B) 3-seat `pr-review` RACI probe (dry run)

Bus: NOT STARTED. See the "pm2 and bus startup" table above: pm2 daemon EPERM, no `node_modules` for the bus, `/tmp` not writable for `DATA_DIR`. I did not run `pm2 start` because the first two are already measured and a daemon start could leave a crash-looping app on the owner's machine. Port check +10 from 7787 (what a fresh bus would need): `lsof -nP -iTCP:<p> -sTCP:LISTEN` for 7787 to 7797, all 11 ports have no listener. No bus was created, so there is nothing to clean up.

The RACI question is decidable without a bus because it depends only on `skills/pr-review/references/agent-roles.md` (parsed with python3, all 35 three-seat subsets of the 7 seats). Ten checks exist: `pr-check-cold-read` and `pr-check-1` to `pr-check-9`.

Responsible owners: cold-read = integration-architect and strategic-reviewer; 1 and 6 = platform-engineer; 2 and 3 = integration-architect; 4 = devops-engineer; 5 = security-engineer; 7 = fullstack-engineer; 8 = technical-writer; 9 = strategic-reviewer. Accountable closers: cold-read, 7, 9 = integration-architect; 2, 3, 4, 5 = platform-engineer; 1 and 6 = devops-engineer; 8 = fullstack-engineer.

| Measure over the 35 subsets | Result |
|---|---|
| Subsets that keep a Responsible seat for all 10 checks | 0 |
| Fewest checks that lose their Responsible seat | 4 (5 subsets) |
| Most | 7 (4 subsets); distribution 4:5, 5:14, 6:12, 7:4 subsets |
| Subsets that also keep every Accountable closer | 0; fewest lost closers is 1 |
| Best subset (4 lost R, 1 lost A) | devops-engineer, integration-architect, platform-engineer: loses R for checks 5, 7, 8, 9 and the closer for check 8 |
| Checks left with no Consulted seat in the best subset | none |

Answer: YES, any 3-seat subset loses at least four checks' Responsible agent (and at least one closer) under the current roles file. Three seats can only work as a RACI remap in which a kept seat absorbs the omitted seats' R and A checks; with 10 checks over 3 seats at least one seat must own 4, and the roles file already warns when one seat owns 3 (integration-architect: "You own THREE checks... post FINDING or PASS for ALL THREE"). So the D12 condition "no lost checks" is met only by a remap, never by dropping seats. What a real bus would add and this dry run did not test: the Phase 1/Phase 2 gate counts, the hard gate timeout and the synthesizer's expectations for a smaller roster.

## Not done, and why

- Row 1 `tools`/`disallowedTools` and `disable-model-invocation` claims: documentation facts, not re-measured.
- Row 7 content: path existence only.
- Item 4 (B) real bus: blocked by the sandbox and missing dependencies, see above; a session whose sandbox allows `~/.pm2` and a writable `DATA_DIR`, plus an installed `node_modules`, is needed.
- Per-session cap semantics (do nested descendants count) and the cap error text at depth 3: unmeasured.
