# agent-topology — ratification record, PART 7 (continues -06.md)

Split provenance: `agent-topology-ratification-06.md` measured 434 lines at ADDENDUM 21
time (`wc -l`, this dispatch); ADDENDUM 21 below cannot fit under the 500-line cap.
Per ADR 0029 clause 3/4.1, carved into this new part rather than committing an
over-cap state — the same split -06 made from -05 at ADDENDUM 18.

---

# ADDENDUM 21 — D15's pre-authorized `server.js` cap stop RESOLVED: extract
`single_instance.js` (R1), §13 row added (R2), reap wiring pinned (R3), D15.1 named (R4)
(2026-09-03)

Ratification authority dispatch (fresh instance), ruling on the stop D15 correctly took
per its own plan row ("STOP: ... `server.js` unable to land ≤300",
`plans/agent-topology.md` D15 row). Ruled at HEAD `a0f3f7c`, branch `wt/agent-topology`.
Docs only — no file under `tools/agent-topology/` is touched by this ADDENDUM. Every
load-bearing claim cites a file+line read at `a0f3f7c` or a command this dispatch ran
(`command grep` throughout; the one negative grep below carries a positive control).

The stop's arithmetic re-verified, not relayed: `server.js` is 291/300 (`wc -l`, this
dispatch); a conforming reap integration needs ~2 requires + call + redacted log
(~8-9 lines) → 300+. ADDENDUM 20 R4's own text anticipated exactly this: "if a
conforming integration cannot land ≤300, that is a STOP, not a silent split." The two
already-built D15 pieces were re-read and conform to their ADDENDUM 20 pins:
`config.js` getter `SPAWN_REAP_THRESHOLD_MS` (live getter, env override, default
600000, `created_at` anchor documented — `config.js:59-73,109`) and `registry_reap.js`
(96 lines; one `db.transaction`, `listAgents({status:'spawning'})`, ISO-lexicographic
JS filter, per-row `patchAgent({status:'dead'})`, zero raw SQL, sole export —
`registry_reap.js:86-100`).

## R1 — RULED: extract the §14 single-instance + port-file concern into a new
package-root module `single_instance.js`. SPLIT, never compress (ADR 0016's own text;
the `worker_session.js` precedent, ADDENDUM 13 R1).

Read `server.js` in full (291 lines, this dispatch) and weighed the three candidate
boundaries against the actual structure:

- **(a) the whole startup sequence** — REJECTED: `start()` (`server.js:241-270`)
  writes four pieces of module state (`db`, `bootstrapReport`, `resolvedPort`, plus
  `httpServer` listeners) that `healthPayload`/`handleMcp`/`shutdown` all read;
  extracting it threads that state through a wide parameter surface without removing
  real coupling.
- **(b) the HTTP/MCP request plumbing** (`healthPayload:147-163`, `handleMcp:171-188`,
  `createServer:190-203`) — REJECTED for the same reason: `healthPayload` reads
  `db`/`resolvedPort`/`startedAt`/`bootstrapReport`; `handleMcp` reads `db`. High
  state coupling, low cohesion gain.
- **(c) the single-instance + port-file cluster** — RULED. `portFilePath`/
  `readPortFile` (`server.js:76-94`), `probeLiveInstance` (`:96-115`),
  `assertSingleInstance` (`:117-141`), `releasePortFile` (`:225-230`), and the
  port-file write in `start()` (`:263-264`) form one cohesive concern — §14 clause 4
  discipline plus the port-file lifecycle — whose ONLY external dependencies are
  `config.DATA_DIR`, `fs`, `path`, and the `SERVICE`/`BIND_HOST` constants. It is the
  genuinely smallest interface, the same judgment shape that picked
  `launchWorkerSession` over `rollbackSpawn` at ADDENDUM 13 R1.

**Module name PINNED: `single_instance.js`**, package root (sibling to
`worker_session.js`/`registry_query.js`/`registry_reap.js`; NOT under `tools/` — that
directory is reserved for the uniform tool-export shape, §13 `tools/*.js` row).

**Export surface PINNED (five named exports, CommonJS):**
- `SERVICE` — the string `'agent-topology'`. This module OWNS the identity constant
  because it is the module that asserts identity (`/health`'s `service` field,
  `server.js:110` today); `server.js` re-imports it for its log lines and health
  payload. One source, zero drift.
- `BIND_HOST` — `'127.0.0.1'`. The probe target and the bind host must be the same
  loopback by construction; sharing the constant expresses that invariant. (A
  `config.js` getter for either was considered and REJECTED — `config.js` is pinned
  surface, the exact reasoning `server.js:26-29` already recorded for `PORT_FILE`.)
- `assertSingleInstance()` → `Promise<void>`; throws an `Error` carrying
  `.alreadyRunning = true` and `.port` when a live instance answers — the exact
  contract `server.js:275-283`'s exit-code branch keys on today, unchanged.
- `writePortFile(port)` → void — `fs.mkdirSync(config.DATA_DIR, {recursive:true})` +
  write, absorbing `server.js:263-264` as one call.
- `releasePortFile(port)` → void — unlink ONLY if the file still records `port`
  (current `:226-230` semantics; the module no longer reads `resolvedPort` state, the
  caller passes it).

`PORT_FILE_NAME` and `HEALTH_PROBE_TIMEOUT_MS` move in as module-PRIVATE constants —
the port-file name stays deliberately unpinned, preserving `server.js:23-29`'s recorded
choice. The stale-port-file diagnostic keeps its structured-stderr shape via a
module-private 3-line `log` helper (same JSON shape; carries no token — the file
handles no token at all).

**Line accounting (this dispatch's own simulation against the real 291-line file, not
an estimate from memory):** removing the header port-file note (7), the two now-unused
requires `fs`/`path` (2 — both are used ONLY by the moving code; verified by reading
every remaining use site), the four constants (4), lines 75-141 (67), 224-230 (7), the
port-file write pair (2), and the consumer-less `assertSingleInstance` re-export (1 —
`command grep -rln "server')" tools/agent-topology --include="*.js"` minus
node_modules matches only `server.js`'s own `./mcp-server` require; positive control:
the same grep for `require('./registry')` finds 6 tool files), then adding the
2-line header pointer, 2 requires, 1 `writePortFile` call, and the ~6-line reap block
(R3) lands **`server.js` at ~212 lines**. The new **`single_instance.js` lands at
~125 lines** (74 moved + ~22 header + requires/constants/log/`writePortFile`/exports).
Both comfortably under 300 with ≥85 lines of wording slack each — not barely.

**Consequence if wrong:** low — pure lift-and-shift of shipped, D13-verified logic; a
wrong name or export split is a rename, not a rewrite. The one behavior-sensitive edge
is `releasePortFile` taking `port` as a parameter instead of reading module state;
D15.1's done condition covers it (shutdown still removes only OUR port file).

## R2 — RULED: yes, a §13 row — applied in this commit.

Every package-root non-entry-point module has one (`registry_query.js`,
`registry_reap.js`, `worker_session.js`, `messages.js`, `bootstrap.js`,
`provision.js` — `architecture/agent-topology-02.md:179-184`); `single_instance.js`
is that class, not the entry-point class (`server.js`/`mcp-server.js` deliberately
have no rows, `server.js:26-27`, and still don't — that clause stays true). Row added
to `agent-topology-02.md` §13 after the `worker_session.js` row, pinning exactly the
R1 surface. `agent-topology-02.md` was 256 lines before the edit — no cap concern.

## R3 — RULED: the exact reap wiring.

**Location:** inside `start()`, in `server.js` (the orchestration stays home; the
split moves the instance/port-file concern, not the startup sequence) — a new step
between the current step 3 (`bootstrapRouter` + `bootstrapReport` freeze + the
`router_bootstrap` log, `server.js:250-256`) and step 4 (`bindExclusive`,
`server.js:259`). Re-verified against ADDENDUM 20 R2's original text — "one call,
immediately after `bootstrapRouter` (`server.js:250`), before serving": the port
binds only at step 4, so no request can arrive before the reap completes. Ordering
requirement satisfied exactly.

**Shape, pinned:**
```js
// 3.5. ADDENDUM 20 — reap stuck-`spawning` rows before the port ever binds.
const reaped = reapStuckSpawning(db, config.SPAWN_REAP_THRESHOLD_MS);
if (reaped.length > 0) {
  log('spawn_reap', 'Reaped stuck-spawning rows at startup',
    { count: reaped.length, agent_ids: reaped.map((r) => r.agent_id) });
}
```
plus `const { reapStuckSpawning } = require('./registry_reap');` in the require block.
`config.SPAWN_REAP_THRESHOLD_MS` read at USE time (ADDENDUM 6/7 convention,
`server.js:39-40`); the getter returns a finite number (default 600000,
`config.js:70-73,109`), satisfying `reapStuckSpawning`'s positive-finite check
(`registry_reap.js:87-91`).

**Redaction, confirmed:** `reapStuckSpawning` returns FULL rows carrying `token_hash`
(`registry_reap.js:41-44` return-shape header; ADDENDUM 20 R4). The pinned log emits
ONLY `count` + mapped `agent_id`s — never a row object, never `token_hash`, and the raw
token never existed in these rows' lifecycle server-side beyond mint time. No row
content, no token, is logged. Zero reaped rows → no log line (a non-event; the "loud
log" obligation in D15's row is a loud REAP, not startup noise).

**Consequence if wrong:** wiring before `bootstrapRouter` would reap against a DB the
router hasn't adopted (harmless but order-contract-violating); wiring after bind would
open a request window against un-reaped rows. Both are excluded by the pinned
location; D15.1's seeded-row test exercises the real path.

## R4 — RULED: distinct dispatch **D15.1**, the D6.2 precedent — not a re-dispatched D15.

ADDENDUM 13 resolved the identical situation (cap stop on otherwise-finished work) by
naming a NEW sub-dispatch, D6.2, to execute the split (`plans/agent-topology.md:132`).
Same here, for the same reasons plus two local ones: D15's partial result is already
committed (`a0f3f7c` — "server.js wiring STOPPED"), so a fresh number gives clean
provenance; and D15's items 4-5 (comment repoint, SKILL.md line) are concurrently
in flight under the D15 banner in sibling worktrees — reusing "D15" for a third
concurrent stream invites record collision. This is not an "unnecessary slice": it is
the one remaining slice, renamed for auditability.

**D15.1 scope, exact (nothing else):** (1) create `single_instance.js` per R1 — pure
lift-and-shift of `server.js:76-141,225-230,263-264` plus the four constants, no
behavior change; (2) rewire `server.js` (imports, `writePortFile`/`releasePortFile`
call sites, drop the dead re-export, 2-line header pointer); (3) add the R3 reap block.
**The two already-built D15 pieces are FROZEN — `config.js` and `registry_reap.js` are
not edited by D15.1.** They need no re-audit: D15.1's done condition exercises both
end-to-end (the seeded-row test path is getter → reaper → wiring), which IS their
re-verification. Tier: **Sonnet** — mechanical lift-and-shift + one pinned call, all
judgment settled here (the D6.2 tier, for the D6.2 reason). Single dispatch, Rule 7
exempt (plan-row note). Done condition and STOP: see the D15.1 plan row added by this
commit — headline: seeded over-threshold `spawning` row → `dead` after `start()`
(name re-spawnable, token → `PERMISSION_DENIED`); under-threshold row survives; `done`
row untouched; double-start still exits `EXIT_ALREADY_RUNNING` (3) and stale port file
still cleaned; shutdown removes only our port file; `spawn_reap` log carries
`agent_id`s only; Invariant-3 grep re-run with `reapStuckSpawning` in the banned-name
set finds NO hit in any `tools/*.js` (this dispatch's pre-check: `command grep -rn
"reapStuckSpawning" tools/agent-topology/tools/*.js tools/agent-topology/server.js` →
empty; positive control `command grep -c` in `registry_reap.js` → 7);
`check-file-length.sh` clean with BOTH resulting files ≤300. STOP: any fix requiring a
`middleware.js`, schema, `config.js`, `registry_reap.js`, or other pinned-surface
change; either file unable to land ≤300.

D15's ship gate stands unchanged: **D15 (now D15 items 1-6 + D15.1) blocks the final
acceptance declaration** (ADDENDUM 20). D15.1 does not reopen D13's acceptance.

## Named, not acted on

- `server.js`'s exported `httpServer`/`start` surface remains un-pinned in §13
  (entry-point class, `server.js:26-27`) — unchanged by this ruling.
- The `single_instance.js` probe's `fetch` dependency (Node ≥18 global) — already the
  shipped code's dependency (`server.js:105`), merely relocated.
- D15 items 4-5 (comment repoint, SKILL.md line) — in flight elsewhere, out of this
  ruling's scope by dispatch constraint.
