# agent-topology — T6 ratification record

- **Verdict:** RATIFIED-WITH-AMENDMENTS (all eight OQs now resolved — OQ2 by the owner,
  the rest ruled here).
- **Authority:** ADR 0014 trigger T6 (architecture ratification), Fable dispatch, 2026-09-02.
- **Scope:** `architecture/agent-topology.md` + `plans/agent-topology.md` at worktree
  `wt/agent-topology`. Every citation below was re-run/re-read by the ratifier, not
  inherited from the author.

## Independent verification of author claims

| Claim | Ratifier's check | Result |
|---|---|---|
| No prior art in hq | `command grep -rilE 'agent-topology\|spawn_agent\|registry_write\|write asymmetry\|hop_count\|router protocol' --include='*.md' .` (excl. the two artifacts) | 0 hits (controls: `router` 181, `registry` 54) — CONFIRMED |
| ADR 0016 cap 300, skills+tests exempt, `.sql` unscanned | `tools/check-file-length.sh:15` `LIMIT=300`; `:18` EXTENSIONS has no `sql`; `:22` and `:30` exclude `skills` + test dirs | CONFIRMED |
| STANDARDS §7 sibling rule | `STANDARDS.md:84` "Code repos are **siblings** under `~/projects/`, never nested inside `hq`" | CONFIRMED |
| ADR 0010 restates it | `decisions/0010-...md:34` "code repos never [live inside hq]" | CONFIRMED |
| 25 tracked Node files inside hq | `git ls-files plans/<project>/harness \| wc -l` → 25 | CONFIRMED |
| Bus is transport-only, identity self-reported | `swarm-communication-layer/schema.sql:5,15,29` (only `messages`/`message_receipts`/`sessions`; `agent_id` appears only as recipient key); `src/tools/send_message.js:26` `from_agent: z.string(...)`; `src/server.js` `sessionIdGenerator: undefined // stateless mode` | CONFIRMED |
| ADR 0009 global symlink install | `decisions/0009:19-25` | CONFIRMED |
| ADR 0014 T1 | `decisions/0014:55` second Opus failure → Fable, mandatory | CONFIRMED |
| "Contradictory precedent" on `claude -p` (OQ4) | `skills/loop-runner/SKILL.md:11,31` mandates `claude -p`; `skills/swarm-communication/SKILL.md:176` bans it ONLY for model-swap re-invocation inside that skill | **OVERSTATED — see OQ4** |
| Invariant 4 session→row half unenforceable | Falls with the OQ4 ruling | **OVERTURNED — see below** |

Repo ownership check before any integration step: `git remote -v` — hq →
`github.com/<owner>/hq.git`; swarm-communication-layer → `github.com/<owner>/swarm-communication-layer.git`.
This record proposes NO push and NO merge; integration stays orchestrator-controlled.

## Rulings

**OQ1 — RULED: capability token (author's option b).** Verified there is no runtime
identity channel: transport is stateless (`server.js` `sessionIdGenerator: undefined`) and
the only local precedent self-reports (`send_message.js:26`). Mechanism: `spawn_agent`
mints an unguessable ≥128-bit token per agent, stores a hash in the registry row, injects
the token into the Worker Preamble; every tool call carries `auth_token`; `middleware.js`
resolves token→row. The router's token is minted at server init and written to a mode-600
file under `$DATA_DIR`. The spec's "never from a self-reported `agent_id`" clause is
AMENDED to: "identity is never self-ASSERTED; a bearer token is caller-supplied but
unforgeable." Record this downgrade plainly (unforgeability, not runtime identity).
Consequence if wrong: a token echoed into a transcript enables impersonation — so tools
never print tokens, and D-briefs carry a redaction clause (Maestro-echo lesson).

**OQ2 — RESOLVED BY THE OWNER: build inside hq, as an explicit §7/ADR 0010 exception,
BECAUSE the system will be ported to a separate work environment.** Provenance: owner
ruling relayed by the orchestrator mid-dispatch, 2026-09-02, verbatim: "Keep this in hq
the exceptn here is that i will port thsi over to my work environment". The ratifier did
not witness the owner turn; the ADR must carry this provenance line. Conflict and
counter-precedent independently verified before resting on them (STANDARDS.md:84;
decisions/0010:34; `git ls-files plans/<project>/harness | wc -l` → 25).
Root is settled: **`tools/agent-topology/`** inside hq. The location question is closed —
but the stated reason promotes **PORTABILITY to a first-class requirement**, ruled on
below.

### Portability rulings (consequence of OQ2's stated reason)

The target environment must be assumed to have NO hq, NO swarm bus, NO ADR machinery —
only Claude Code and the ported directory. Therefore:

- **P1 — the portable unit is `tools/agent-topology/` in its entirety**, including both
  SKILL.md files, which MOVE INTO the portable root at
  `tools/agent-topology/skills/agent-topology-{router,worker}/SKILL.md` instead of hq
  top-level `skills/`. This deviates from ADR 0009's authorship location and goes in the
  ADR. Cap exemptions survive the move: both checkers exclude `skills` as ANY path segment
  (`check-file-length.sh:22`; `check-doc-length.sh:71,141` `-not -path "*/skills/*"`).
- **P2 — no hardcoded paths.** All paths env-driven with machine-neutral defaults in
  `config.js` only: `DATA_DIR` (default `~/.agent-topology/data/`), `CLAUDE_BIN` (default
  `claude` on PATH, new — the OQ4 spawn mechanism must not assume this machine's install),
  skills source resolved relative to the package root. Enforced by a grep-based
  portability check: `command grep -rn '/Users/\|projects/hq' tools/agent-topology
  --include='*.js'` → 0 hits, with a positive control (the harness precedent shows 0
  `/Users/` hits is achievable; control: `require` present).
- **P3 — no runtime dependence on hq tooling.** hq checkers/gates are authoring-time
  only; nothing under `~/projects/agent-hq` may be read at runtime. The OQ5 ruling (own message
  store, NOT the bus) is retroactively load-bearing here: a bus dependency would have made
  the system unportable to an environment where the bus does not exist.
- **P4 — OQ1 and OQ4 rulings survive relocation as made.** The capability token lives in
  the DB + `$DATA_DIR` file (no machine-specific identity source); the `claude -p` spawn
  needs only the CLI on PATH, and D6's smoke test doubles as the port-time preflight.
- **P5 — a "lift and port" procedure section is added to the architecture doc** (copy the
  directory, `npm install`, set env vars, project-scope-install the router skill, run the
  smoke test + acceptance gate). Documentation only; no porting tooling is built.

**OQ3 — RULED, two parts.** (i) Enums: the `status` reconstruction is not bare inference —
`done`, `escalated`, `dead` are each attested elsewhere in the same fetched spec
(build-spec lines 108, 111, 118). Acceptable. The `tier` tail is genuinely lost, but moot
under (ii). Still: add a cheap **D0 (Haiku)** that re-fetches the Notion table cell-by-cell
to confirm no further lost values; if Notion still truncates, the ADR-recorded sets below
govern and D0 is non-blocking. (ii) Ladder: as the ADR 0014 authority I rule **ADR 0014
governs inside hq**. Reconciliation: spec E3 = "escalate one tier up" and handles the first
hop; from Opus upward ADR 0014 owns it — first Opus failure → one retry with upgraded
spec, second → mandatory Fable, never a third Opus attempt (decisions/0014:55). Therefore
`tier` = **`light | default | strong | fable`** (fable rows router-dispatch-only), and
`status` = **`spawning | active | done | escalated | dead`**. Both recorded in the ADR.
Consequence if wrong: a schema CHECK migration — cheap, and D0 bounds the risk.

**OQ4 — RULED: option (a), scoped.** The claimed precedent contradiction does not hold:
`skills/swarm-communication/SKILL.md:176` bans nested `claude -p` only for model selection
inside that skill; `skills/loop-runner/SKILL.md:11,31` proves `claude -p` sub-agent
dispatch is supported and mandated in this environment. So: `spawn_agent` inserts the row
(`spawning`), spawns a detached `claude -p` child with preamble+task, updates to `active`
with `thread_ref` = pid+session ref; any failure rolls the row back. Atomicity preserved as
written; acceptance test A2 fully testable. **D6 opens with a smoke test** that `claude -p`
runs from a Node `child_process`; if it fails, STOP — the fallback (two-phase directive +
stale-`spawning` reaper) converts atomicity to convergence and needs owner sign-off before
anyone builds it. Bonus: under (a) the server owns worker pids, so the session→row half of
**Invariant 4 becomes enforceable** — the author's "half-enforceable" flag is overturned in
the good direction (`check_status` verifies pid liveness).

**OQ5 — RULED: spec defect, remedied in-system.** Verified the 8-tool surface has no
message-read path (build-spec lines 87–119) — the plan's own D7 done condition ("the Router
can read back") was untestable as written. Remedy: add a 9th tool **`read_messages`** (any
agent; middleware scopes results to messages addressed to the resolved caller) over the
topology's OWN `messages` table — NOT the bus. Grounds: `report_result` must write the
result message and the `done` status in one SQLite transaction (build-spec lines 107–108) —
a bus hop reopens exactly the drift bug the spec kills; the bus's identity is self-reported
(send_message.js:26); and a runtime dependency on a separate pm2 service is unjustified
for structural state. The bus stays untouched and complementary. Named, not built: this
creates a second unbounded message table (bus Issue-5 analog) — TTL/cleanup is future work.

**OQ6 — RULED: neither skill is globally symlinked.** ADR 0009 gets a recorded per-role
exception on BOTH steps (authorship location per portability ruling P1 — the skills live
inside the portable root, not hq top-level `skills/`): the router skill installs
project-scoped in the router's environment; `provision.js` installs the worker skill
project-scoped into each worker's working directory, by COPY from the package root rather
than symlink, so installs survive relocation of the source tree. Global install would leak both
procedures to every session (decisions/0009:22-24), violating Invariant 6. Enforceable
form of Invariant 6: (a) build-time marker grep = test A7, (b) a check that no
`agent-topology-*` symlink exists in `~/.claude/skills/`. Note plainly: Invariant 6 is
defense-in-depth — the middleware role gate, not skill visibility, is the hard boundary.

**OQ7 — RULED: forward-looking scaffolding, no relay path intended.** In a pure star
`hop_count` cannot exceed 1 (route_message takes `(to, kind, body)` with no inbound
envelope; workers hold no routing tool). The spec itself defers S5 ("needed once >3
concurrent workers or multi-hop tasks appear", build-spec line 138). Build D9 as the
validator layer; **A4 is re-scoped to a synthetic validator-level test** (construct an
envelope with `hop_count = MAX_HOPS+1`, assert rejection). The architecture must state that
production hop_count ≤ 1 so nobody later "fixes" the unreachable limit.

**OQ8 — RULED: the build spec governs.** The companion page is the pre-tooling manual
protocol ("Paste this block into your main chat's system prompt", companion line 10). The
build spec's own router SKILL.md supersedes Rule 3 explicitly: "Topology state lives in the
registry, not your memory. Never answer from memory" (build-spec lines 172–173). Rule 3's
working-context table is superseded by the registry; Rules 0, 2, and 5 (DECISION block,
tier triggers, bounce-back) remain live and are exactly the ones the skill cites by number.

## Also ruled

- **Invariants 4 and 6:** Invariant 4's flag is OVERTURNED (enforceable under OQ4a).
  Invariant 6 stays a provisioning/build-time property — the author was right to flag
  rather than invent, and OQ6 gives it its checkable form.
- **A7:** legitimate. Clearly labeled as author-added; it tests the one invariant the spec
  says to "assert in tests" (build-spec line 120) that had no acceptance test.
- **Module decomposition:** sound, needs no structural re-authoring for portability —
  `config.js` was already the single env surface, which is exactly the portable shape.
  Amend only: `identity.js` becomes token mint/verify; add `tools/read_messages.js`;
  `config.js` gains `CLAUDE_BIN`; skills relocate into the portable root (P1);
  `provision.js` copies rather than symlinks (OQ6).
- **Dispatch plan:** survives WITH the amendments below — no re-authoring, for
  portability or otherwise. The Rule 7 assessment survives (ADR 0024 verified to exist
  and be the Rule 7 ADR; D0 is serial-first and changes no lane; still 2 safely-parallel
  lanes of 14 dispatches). One Rule 7 re-check forced by P1: D11's target moves INTO
  `tools/agent-topology/` (its `skills/` subdirectory), the same tree the implementation
  lane writes — the lane stays safe because it runs in its own worktree (no shared
  branch/git state) and touches a file set no D1–D9 dispatch touches (no same-file edits,
  conflict-free merge), but the plan's D11 row must restate the safety argument in these
  terms rather than "zero file overlap with `tools/agent-topology/`", which P1 falsifies.

## Amendments required before execution (ordered)

1. OQ2 is settled (inside hq, portability first-class): D1's brief drops the two-branch
   hedge and fixes the root at `tools/agent-topology/`; D1 additionally scaffolds
   `CLAUDE_BIN` in `config.js` and the P2 no-hardcoded-path check; D11's target moves to
   `tools/agent-topology/skills/` per P1, with copy-based project-scoped installs per OQ6.
   The acceptance gate gains the P2 portability grep as a final check, and the
   architecture doc gains the P5 lift-and-port section.
2. Add **D0 (Haiku)**: re-fetch the Notion `agents` table cell-by-cell; confirm/extend the
   enum sets; non-blocking if Notion still truncates (ADR-recorded sets govern).
3. Architecture §4: replace the reconstruction caveat with the ratified sets
   `tier: light|default|strong|fable`, `status: spawning|active|done|escalated|dead`, and
   the ADR 0014 ladder reconciliation (E3 one-tier-up; T1 governs from Opus).
4. Architecture §5 + D3 brief: identity = spawn-minted capability token, hashed at rest,
   never printed; router token via mode-600 file; briefs carry a redaction clause.
5. D6 brief: detached `claude -p` spawn per OQ4a, opening smoke test, stop-on-anomaly to
   owner if the smoke fails. Architecture §6 row 4: upgrade Invariant 4 to enforceable.
6. D7 brief + architecture §3: add `read_messages` (10th handler file); D7's done condition
   becomes testable through it. Name (not build) the TTL/cleanup gap.
7. D9/A4: re-scope A4 as a synthetic validator test; record hop_count ≤ 1 in production.
8. D11 brief + provisioning: no global symlink for either skill; project-scoped installs
   per OQ6; extend A7 with the no-global-symlink check.
9. One ADR (orchestrator allocates the number) settling: the OQ2 exception to STANDARDS
   §7 + ADR 0010 with the portability rationale AND the owner-ruling provenance line
   (date, mechanism, verbatim selection); the tier ladder + `fable` slot vs ADR 0014; the
   ADR 0009 per-role authorship+install exception (P1/OQ6); the identity-token deviation
   from the spec's wording.
10. Architecture §9: mark ALL of OQ1–OQ8 RESOLVED per this record; G0 in the plan shrinks
    to "amendments 1–9 applied".

## Named, not acted on

- Author's positive-control counts (183/53) vs ratifier's (181/54): drift from the two new
  artifacts entering/leaving the corpus, not a contradiction.
- The second unbounded `messages` table (OQ5) inherits the bus's Issue-5 pattern — future
  TTL work, deliberately not in scope.
- The stale hq `CLAUDE.md` folder map and `tools/model-routing.md` rows the author named
  remain named-only here too.

---

# T2 ADDENDUM — OQ4 falsified; re-ruling (2026-09-02, second Fable dispatch)

ADR 0014 **T2 fired**: an independent Opus verifier falsified the OQ4(a) ruling above.
This addendum supersedes the OQ4 sections of this record and of `architecture/
agent-topology.md` (§6 "OQ4 RATIFIED", §9 OQ4, Invariant 4 row) pending amendment
application. Every verifier claim below was re-verified by this ratifier, not inherited.

## The falsification, accepted

**The prior OQ4(a) ruling was wrong, and the error is named:** the first ruling verified
that `claude -p` is locally precedented and permissible (loop-runner) but never checked its
PROCESS LIFETIME against the spec features that require a live recipient. `claude --help:152`:
`-p, --print` — "**Print response and exit**". A one-shot child cannot receive
`route_message` dispatch to an existing agent (spec:114-115), cannot meaningfully be
`check_status`-gated before routing (spec:119), and has no plural "work cycles" for
`heartbeat()` (spec:132). Verifier's negative greps reproduced exactly by this ratifier:
`command grep -cE 'poll|inbox|resume|work cycle|long-running|one-shot'` → 0 hits in all
three design docs (controls: `worker` 19/6/6). The route-to-existing half of the topology
was unbuildable as ruled.

## OQ4 re-ruling — RECOMMENDATION ONLY, OWNER DECIDES (decision in flight)

New CLI evidence changes the option space: `claude --help:191` `-r, --resume [value]`
(resume a conversation by session ID) and `help:205` `--session-id <uuid>` (use a specific
session ID) both exist.

- **Branch (i) — one-shot spawn kept; `route_message` route-to-existing, `heartbeat`, and
  live-staleness demoted to documented NON-GOALS.** Costs: spec:114-115 route-existing is
  amputated (and with it the working purpose of the registry's `scope` matching field);
  spec:119's check-before-route loses its object; A5 goes synthetic; the router skill's
  "route-existing" branch is cut. Keeps: everything in S1–S4 + worker exits, which the spec
  itself calls "a working system" (spec:136). Cheapest; matches hq's actual one-shot
  dispatch practice; delivers less than the FULL spec the owner approved.
- **Branch (ii) — genuinely long-running worker sessions** (supervised daemon/poll-loop
  harness per worker). Full spec semantics, real pid liveness. Costs: a new worker-runner
  harness module, process supervision, the largest failure surface, and zero hq precedent
  for persistent agent daemons.
- **Branch (iii) — RECOMMENDED: session-persistent, process-ephemeral workers.** The
  durable agent = registry row + Claude SESSION. The server mints the session id itself and
  passes `--session-id <uuid>` at first spawn (help:205), so `thread_ref` is known before
  the process starts; `route_message` to an existing agent = the server runs
  `claude -p --resume <session_id>` — a fresh one-shot process on the SAME session,
  preserving the agent's accumulated context (the actual value route-existing exists for).
  `heartbeat` = per-invocation ("work cycle" = one resumed invocation — genuinely plural);
  `last_active_at` staleness is meaningful across invocations. Caveat, stated honestly:
  flag EXISTENCE is verified from `claude --help`; the headless `-p --resume` combination
  is verified only by D6's smoke test, which expands to cover it. If that smoke fails, the
  fallback is branch (i) with owner sign-off. Cost over (i): resume plumbing in `spawn`/
  `route_message`; far below (ii); no daemon.

**Branch-dependent downstream rulings, both/all branches stated:**
- Invariant 4 session→row: (i) enforceable only during a task run (pid), row is a record
  afterwards; (iii) "live session" = session id + optional running pid — enforcement is
  row ↔ session, pid only mid-invocation; (ii) true pid liveness.
- `thread_ref` (F7): JSON string. (i) `{"kind":"oneshot","pid":N,"session_id":"<uuid>"}`;
  (iii) `{"kind":"session","session_id":"<uuid>","last_pid":N|null}`;
  (ii) `{"kind":"daemon","pid":N,"session_id":"<uuid>"}`.
- Blocked on the branch: **D6, D9, D11 (router-skill route-existing text), D12**, and the
  authoring of acceptance tests A2/A5. Branch-independent and NOT blocked: D1–D5, D7, D8,
  D10 (except A2/A5), D13.

## F1 — RULED: router bootstrap is **bootstrap-or-adopt**, idempotent, at server init

Verified: 0 hits for `bootstrap|first router|seed` across all four docs (control: `router`
19/8) — nothing inserts the first router row, and `arch:241` (token "at server init") did
collide with the Invariant-1 partial unique index (`arch:261`) on every restart.

**Ruling (branch-independent):** at server init, in one transaction: SELECT the active
router row. If none → INSERT it (server-minted `agent_id`) + mint token + write the
mode-600 file. If one exists → **ADOPT** it: reuse the row; if the token file exists and
its hash matches the row, reuse the token; else ROTATE (mint new token, update the row
hash, rewrite the file). No blind INSERT ever occurs, so the partial unique index is never
tripped by a restart; a crashed server's leftover active row is adopted, not duplicated.
**Assignment (reworded by ADDENDUM 5):** D3 owns the pure primitives (mint/hash); D4's
`bootstrapRouter()` owns adopt-vs-rotate AND all token-file I/O; D13 wires the init call. **New done conditions:** two consecutive server starts on the same
DB yield exactly one active router row with no uniqueness error; after a restart, `whoami`
with the router's token resolves to that row.

## F3 — RULED: D11's byte-match done condition is replaced

Confirmed: `auth_token` → 0 hits in `plans/` (control: `token` 1); the spec's §10 skill
text predates the token model and `read_messages`, so byte-matching would ship a router
skill that cannot authenticate and cannot read results. **Replacement done condition:**
both SKILL.md files DERIVE from spec §10 with an **archived diff in which every deviation
is annotated to its ruling** — (a) `auth_token` on every tool call (OQ1); (b) "Handling
worker exits" reads back via `read_messages` (OQ5); (c) a worker-skill note that the token
arrives via the preamble and must never be echoed (F4); (d) the route-existing text per the
owner's OQ4 branch. Done = the annotated diff exists with ZERO unannotated deviations, and
A7's marker test passes. D11 therefore now depends on the OQ4 owner ruling and no longer
starts "from the start"; it remains parallel to the implementation lane once unblocked.

## F4 — RULED: preamble token slot + redaction scope reconciled

Confirmed: `arch:106` scopes `preamble.js` to three placeholders while `arch:237-239`,
`ratification` OQ1, and ADR 0035:110-114 all require the raw token injected into the
preamble; D6's done condition checked only the three. **Ruling:** the Worker Preamble
template gains a fourth slot, `{auth_token}`; `arch` §3's `preamble.js` row and D6's done
condition check all FOUR interpolated, with the token non-empty and hash-matching its row.
**The redaction contradiction is resolved by scoping, stated plainly:** raw tokens must
never appear in server-side surfaces — tool results, logs, error messages — nor in any
router-side or orchestrator transcript. The worker's OWN session context necessarily
carries its token: the preamble IS the delivery channel, and the worker session's local
JSONL sits inside the same same-user trust boundary that already holds the mode-600 router
token file. Threat model: the token defends against cross-agent leakage through shared and
relayed surfaces, not against a same-user process reading local files — that adversary
could read the token file too. ADR 0035 §4's "no transcript may echo a raw token" is
amended to this scoped form.

## F7 — RULED: the five inventable interfaces, fixed now

1. **`messages` DDL (D2 owns; D2's done condition extends to it):** `message_id TEXT PK`,
   `from_agent TEXT NOT NULL REFERENCES agents(agent_id)`, `to_agent TEXT NOT NULL
   REFERENCES agents(agent_id)`, `task_id TEXT NOT NULL`, `hop_count INTEGER NOT NULL
   DEFAULT 0 CHECK (hop_count >= 0)`, `kind TEXT NOT NULL CHECK (kind IN
   ('task','result','escalate','status'))`, `body TEXT NOT NULL`, `created_at TEXT NOT
   NULL`, `read_at TEXT NULL`; index on `(to_agent, read_at)`.
2. **`read_messages` (D7 owns):** input `{ auth_token, filter?: { kind?, task_id?,
   unread_only? }, mark_read?: bool = true }`; returns only messages whose `to_agent` is
   the resolved caller (scoping in middleware), oldest-first; consumption = `read_at` set
   on return when `mark_read`; non-destructive — rows retained (TTL stays named future
   work).
3. **`thread_ref` format:** per-branch JSON strings as ruled under OQ4 above; opaque TEXT
   to the schema either way, so D2 is not branch-blocked.
4. **Worker working directory (D6 owns):** the server creates `$DATA_DIR/workers/
   <agent_id>/` per agent, `provision.js` copies the worker skill there, and the child is
   spawned with that cwd. Env-driven (portable, P2) and collision-free (the
   shared-scratchpad lesson: concurrent agents get unique subdirs).
5. **`auth_token` on every handler schema:** D3 defines one shared, exported schema
   fragment in `identity.js`; every handler composes it. **D5's done condition extends:**
   a check proves ALL 10 registered tools' input schemas include `auth_token`.

## Mechanical corrections — confirmed (one with a specific form)

1. **Tool count — CONFIRMED.** The spec's 8 numbered headers define 9 tools (spec:116 is
   two: `check_status` + `heartbeat`); with `read_messages` the surface is 10. Fix
   `arch:5`, `arch:353,355`, `ratification:109,111` ("8-tool"/"9th tool" → "9-tool"/"10th
   tool"), `plans:65` ("the 9 tool handlers" → 10, contradicting `plans:88` in the same
   file), and Hermes skill `retros/2026-07-model-tier-policy-eval` (was retros/2026-07-model-tier-policy-eval.md):73 ("9th tool" → 10th).
2. **`arch:27` — CONFIRMED:** `LIMIT=300` is at `tools/check-file-length.sh:15`, not `:18`
   (verified: `command grep -n 'LIMIT=300'` → 15). `:18` is `EXTENSIONS` and stays correct
   where cited for the no-`sql` claim.
3. **P2 grep — CONFIRMED, widened form ruled:** drop the `--include='*.js'` filter; the
   gate becomes `command grep -rn '/Users/\|projects/hq' tools/agent-topology
   --exclude-dir=node_modules` → 0 hits (positive control required), so `schema.sql`,
   `package.json`, and both SKILL.md files are inside the gate. Apply at `plans:123`,
   `arch:89-90`, `arch:413`.
4. **Verifier cells — CONFIRMED:** add "non-author" explicitly to D2, D4, D7, D8, D9, D12,
   D13. **Per-row stop-on-anomaly — confirmed with a specific form:** one bolded line
   above the dispatch table incorporates the blanket clause (`plans:136-139`) into every
   row by reference, and a row-specific `STOP:` fragment is added only where one exists
   (D3 redaction breach, D6 smoke failure, D4/D13 bootstrap uniqueness error). Duplicating
   the full blanket text into 14 rows adds bloat, not compliance; incorporation is
   explicit, which is what Rule 4 requires.
5. **D0 provenance gap — CONFIRMED:** the archived raw capture holds no `notion-search`
   output (`command grep -c 'search' raw-refetch.md` → 0 hits, control `fetch` → 2).
   Annotate the D0 OUTCOME subsection: the search half of the cited evidence is
   unarchived (archive-raw lesson) and only the re-fetch half is re-checkable; the
   substantive conclusion stands on the verifier's independent confirmation.
6. **ADR 0035:31 — CONFIRMED:** reword to "typed as free text into an AskUserQuestion
   prompt" — the mechanism was AskUserQuestion, the answer was free prose, and the record
   should say both precisely.

## Updated ordered amendment list (supersedes items 1–10 above where they conflict)

1. Owner rules the OQ4 branch (in flight — nothing that depends on it fires first).
2. Apply mechanical corrections 1–6 above (branch-independent).
3. Architecture §5/§3 + ADR 0035 §4: `{auth_token}` preamble slot + scoped redaction
   clause (F4); D6's done condition gains the four-slot + hash-match check.
4. Architecture + plan: bootstrap-or-adopt (F1) into D3/D4/D13 rows with the two new done
   conditions; state the restart/token-rotation policy in §5.
5. Architecture §4/§3 + plan D2/D7: the F7 interfaces (messages DDL, read_messages
   signature, worker cwd, auth_token schema fragment + D5 all-10-schemas check).
6. Plan D11: replacement done condition (F3) + its new dependency on the OQ4 ruling.
7. Once the branch lands: rewrite architecture §6 OQ4 block, Invariant 4 row, §9 OQ4, plan
   D6/D9/D12 rows, A2/A5, and the D6 smoke-test scope (branch (iii): add `-p --resume`)
   to the chosen branch; amend ADR 0035 only if the branch changes a recorded ruling.
8. Re-run a doc-consistency pass (tool counts, OQ4 references) before any dispatch fires.

**Implementation safety:** NOT safe to start as a whole. After amendments 2–6 land,
D1–D5, D7, D8, D10 (minus A2/A5) and D13 are branch-independent and may start at the
orchestrator's discretion; D6, D9, D11, D12 and A2/A5 authoring wait on the owner's OQ4
branch. The D1–D7 ship boundary cannot close before the branch lands.

---

# ADDENDUM 3 — D2 stop-the-line: the `token_hash` column (2026-09-02, third dispatch)

D2 stopped correctly rather than invent: §5 of the architecture, this record, and ADR 0035
§4 all say `spawn_agent` "stores a **hash** of it in the registry row", but §4's `agents`
column list — which D2 rightly treated as normative — never carried the column. The gap is
mine: the OQ1 ruling specified the mechanism and never amended the column inventory. Gap
accepted; ruled below. **§4's column list is henceforth the single normative column
inventory — a column absent from it does not exist in the schema**, which is exactly the
convention D2 enforced by stopping.

## The column — RULED

- **Name/type/nullability:** `token_hash TEXT NOT NULL CHECK (length(token_hash) = 64)`.
- **Content pinned** (so D3 cannot invent it): lowercase hex **SHA-256 of the raw token
  bytes**. The raw token stays as OQ1 ruled it — ≥128-bit cryptographically random; its
  string representation is D3's choice, the hash input is the raw token string's bytes.
- **Why NOT NULL:** every row-creation path mints the token before or within the creating
  transaction — `spawn_agent` mints at spawn time before the `spawning` INSERT (part 1 §5
  first bullet), and F1's bootstrap mints inside the same transaction as the router INSERT
  (part 1 §5: "INSERT it..., mint the token, and write the mode-600 file"). No legitimate
  hashless row exists, so NULL would only ever mask a bug.
- **Index:** `CREATE UNIQUE INDEX idx_agents_token_hash ON agents(token_hash)` — full, not
  partial. The middleware resolves `auth_token` → row on every tool call (the lookup needs
  the index), and UNIQUE guards accidental hash reuse. Stated plainly so nobody offloads
  authorization onto it: **the index does not authorize** — a `done`/`dead` row's token
  still resolves to its row, and it is D5's middleware status/role gate that must reject a
  non-live caller. Dead rows retain their (distinct, stale) hashes; TTL stays future work.
- **Bootstrap behaviour (F1):** populated at init, never NULL. The router row is born with
  its `token_hash` inside the bootstrap transaction.
- **F1 reuse-or-rotate re-verified against this exact shape:** ADOPT computes SHA-256 of
  the mode-600 file's token and compares it to the adopted row's `token_hash`; equal →
  reuse; unequal or file missing → ROTATE (mint new token, `UPDATE` the row's
  `token_hash`, rewrite the file). An UPDATE of a UNIQUE NOT NULL column to a fresh random
  hash cannot collide in practice and invalidates nothing else. The mechanism works
  unchanged against the ruled column.

## Ownership — RULED: a D2 amendment (D2.1), not D3/D4 work

`schema.sql` is D2's artifact and ALL DDL stays in one file — D3 (`identity.js`) consumes
the schema and must never define it; splitting DDL across dispatches recreates the drift
this registry exists to kill. **D2.1 scope:** add `token_hash` + `idx_agents_token_hash`,
widen `idx_active_name`'s predicate (below), refresh the schema.sql header comment that
cites §4 as its column authority. **Done condition:** fresh init carries the column NOT
NULL with the CHECK and the unique index; a second row INSERT reusing an existing
`token_hash` fails with `SQLITE_CONSTRAINT_UNIQUE`; `check-file-length.sh` and the P2 grep
stay clean. Non-author verifier, same as every dispatch.

## D2's two judgment calls

1. **`idx_active_name` — INTENT CONFIRMED, PREDICATE AMENDED** to
   `WHERE status IN ('spawning', 'active')`. §4's "unique among active" means unique among
   LIVE agents, and a `spawning` row is live-in-progress: the spawn path inserts a visible
   `spawning` row before the session exists (the process boundary means spawn is NOT one
   transaction), so with an active-only predicate two concurrent spawns of the same name
   both insert and collide only at the active flip — after a session was created — forcing
   the orphan-rollback path for a preventable race. Catch it at INSERT. `idx_one_router`
   stays exactly as shipped: Invariant 1 is the spec's verbatim "exactly one ACTIVE
   router", and no spawning-router path exists (`spawn_agent` mints workers only; the
   router row is born `active` inside F1's single transaction). Named, not changed.
2. **`thread_ref` NULLABLE — CONFIRMED.** The F1 router row never gets a session, so NOT
   NULL would block the D4 bootstrap transaction exactly as D2 reasoned; additionally,
   under branch (iii) a worker's `spawning` row also carries NULL `thread_ref` until the
   active flip writes the session-id/pid JSON. **And yes, §4 must be amended to state
   nullability explicitly** — inferred nullability is the same gap class that caused this
   stop. §4 now marks `parent_id`, `thread_ref` nullable and everything else NOT NULL.

## D3 dispatch safety

**D3 is safe to dispatch only AFTER D2.1 lands on `wt/agent-topology` and is
non-author-verified** — D3's module reads and writes `token_hash` on every mint/verify and
cannot be built against a schema that lacks it. D3's brief must carry: the pinned SHA-256
lowercase-hex form, the ≥128-bit raw-token requirement, and the scoped redaction clause
(F4). Unchanged and not softened: `claude` is logged out on this machine
(`{"loggedIn": false}` per the coordinator's run), so D6 and everything downstream of the
spawn mechanism stays gated regardless of this ruling.

---

# ADDENDUM 4 lives in `architecture/agent-topology-ratification-02.md`

This file reached the ADR 0021/0029 500-line doc cap at Addendum 3; later addenda
continue in the `-02` file (split, not butchered — same convention as the architecture
part 1/part 2 split).
