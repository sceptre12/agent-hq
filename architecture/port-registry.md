# Port registry — architecture

One-line summary: an agent-hq-owned, append-only record of **host-visible TCP port claims** across
every project under `~/projects/`, plus the check-before-bind skill that reads it — so an agent
about to bind a port discovers another project's claim *before* picking, instead of after.

- **Scope:** host port bindings on this machine. Not a devops platform — see §6.
- **Provenance:** ported from hq `architecture/port-registry.md`. Ported into agent-hq 2026-10-26 (delivery workflow, port guard). Personal-project blocks were removed whole, so some `§` references (§0, §2.2, §7.1, §7.3-§7.7) and numbered-list gaps remain from the source; references to `plans/`, `inbox/`, survey files and `raw-lsof.txt` point at hq-only records.

## 1. Location and format

**Settled: a single tab-separated file at `tools/ports.tsv`, append-only.**

### Why `tools/`, not a new top-level folder

`agent-hq/CLAUDE.md` fixes the folder map and requires an ADR for a new top-level folder ("If you make
or suggest a structural change to agent-hq — a new folder … propose an ADR"). `tools/` already holds
non-script data files — verified by `ls tools/`: `scratch-sim-allowlist.txt`,
`ccusage-baseline-pre-stack.txt`. So `tools/ports.tsv` is precedented and needs no ADR, and the
build is not blocked on one. A dedicated `registry/` folder would read better; it is raised as a
recommendation in §8 rather than taken unilaterally.

### Why TSV, and why not the alternatives

The deciding constraint is that a human and an agent with only `bash`/`grep`/`Read` must query
it cheaply, **and concurrent agents must append without clobbering each other.**

| Candidate | Verdict | Reason |
|---|---|---|
| **TSV, one claim per line** | **chosen** | One `command grep -E '^9000\b'` answers "who has 9000". `awk -F'\t'` slices columns. A claim is *one line appended with `>>`* — no read-modify-write, so no lost update. |
| JSON / YAML | rejected | A structured document cannot be appended to; every write is parse → mutate → rewrite the whole file. Two concurrent claims = one silently lost. This is precisely the `next free number is shared state` failure that already burned two concurrent agents in this workspace. |
| Markdown table | rejected | Same whole-file-rewrite problem, plus column realignment. It would also fall under `tools/check-doc-length.sh` (LIMIT=500) and start competing with the doc cap. |
| Prose markdown | rejected | Not machine-queryable; this is the format that already failed us (`LOCAL-PORTS.md`, §5). |
| Many files (one per project) | rejected | The whole point is a *cross*-project view. N files means N greps and no single answer to "is 9000 free". |

### Concurrency contract (the load-bearing part)

- The registry is an **append-only log**. A row is never edited in place on the hot path.
- Writing a claim is exactly one `printf '%s\n' "$row" >> tools/ports.tsv`. A shell `>>`
  redirection opens with `O_APPEND`; a single short line written in one `write(2)` does not
  interleave with a concurrent appender on a local filesystem. Rows are ≪ 512 bytes.
- **Compaction** (collapsing superseded rows) is a deliberate, serialized maintenance action run
  by one agent in one worktree — never concurrent, never automatic. It is the only operation
  permitted to rewrite the file.

### Size discipline for the data file (the named gap)

Neither `tools/check-doc-length.sh` nor `tools/check-file-length.sh` covers `.tsv` — verified:
`check-doc-length.sh:43` sets `LIMIT=500` and scans `.md/.markdown/.mdx` only. No agent-hq rule governs
a registry data file.

**Decision: a soft budget of 200 active rows, warned (not failed) by the checker script; no hard
cap.** Reasoning: the doc cap exists because a long document costs *reader context* — a human or
agent reads it end to end. Nobody reads `ports.tsv` end to end; they grep one port, so length
does not carry that cost and the doc-cap rationale does not transfer. What length *does* degrade
is compaction and the audit run, which are O(rows). A warn at 200 active rows prompts compaction
without ever blocking a claim — a hard cap here would fail closed on the exact action (claiming a
port) the registry exists to make easy. This is stated so the next agent does not reach for the
`.doc-length-allowlist`, which does not apply to this file at all.

## 2. Fields

Nine tab-separated columns. Header line is a single `#`-prefixed row; readers use
`command grep -v '^#'`.

| # | Field | Why it earns its place | Why not more |
|---|---|---|---|
| 1 | `port` | The key. Single port (`9000`) or a declared range (`7777-7800`, `11100-11179`) — ranges are real claims here and dropping them would hide the two biggest ones. **Always numeric — `NNNN` or `NNNN-NNNN`, never a placeholder or sentinel (§2.2).** | — |
| 2 | `bind` | `127.0.0.1` / `0.0.0.0` / `*`. Two services *do* collide on the same port regardless of bind address, but the bind address is what decides reachability, and it is free — `lsof` already prints it. | — |
| 4 | `service` | Which process. Without it a row is an unactionable number. | — |
| 5 | `project` | The owning project — the field that makes this *cross*-project rather than N per-project docs. | — |
| 6 | `status` | `live` / `claimed` / `reserved` / `unmerged` / `released` / `UNVERIFIED`. Closed enum — see §2.1. | — |
| 7 | `source` | Provenance: `file:line`, or `lsof` / `docker` for a live capture. An uncited row is a rumour; §5's whole falsifiability mechanism keys off this. | — |
| 8 | `verified` | `YYYY-MM-DD` the row was last checked against its source. Turns "is this stale?" from a judgement call into a subtraction. | — |
| 9 | `note` | Free text, no tabs. Kept because the interesting rows (remaps, bans, unknown owners) are exactly the ones a fixed schema flattens. | — |

**Deliberately excluded:** `pid` and `owner_agent`. A PID changes on every restart and an agent id
is gone when the session ends; nothing would maintain either, and a permanently-wrong field is
worse than an absent one. Live PID lookup is one `lsof` away when actually needed.

### 2.1 Status values, and the unmerged-branch question

- `live` — a listener was observed by `lsof`/`docker` on the `verified` date.
- `claimed` — declared in a config file that is currently checked out, but not currently bound
  (service is down). Still blocks: starting it later will take the port.
- `released` — a supersession marker retiring earlier non-`released` rows with the identical `port` AND `source`.
- `unmerged` — **a claim that exists only in a branch or worktree that is not checked out anywhere
  on this machine.**
- `UNVERIFIED` — asserted by a source but not confirmed against it, or a live listener whose owner is
  unidentified (§7.7). Uppercase deliberately: a defect marker, not a steady state. It is what §7's
  seed rule ("anything unconfirmed is carried as `UNVERIFIED` rather than dropped or guessed")
  produces; its earlier absence from this enum was the first symptom of the §2.2 gap. **The enum is
  closed** — any other value is malformed and fails the whole registry closed (§5.3); no sentinel or
  "not applicable" value exists, because no row needs one (§2.2).

## 3. Scope: host ports only, container-internal ports excluded

**Settled: the registry records only host-visible bindings. Container-internal ports appear only
as the `container_port` attribute of a host row, never as rows of their own.**

The argument, with evidence:

## 4. The skill's read/write contract

### Check, before binding anything

`tools/port-check.sh <port>`

It does **both** halves, because either alone is what failed on 2026-09-04:

1. Registry lookup — `command grep` for a host-side match, a range containing `<port>`, and
   (reported separately) a container-side match.
2. Live truth — `lsof -nP -iTCP:<port> -sTCP:LISTEN`.

Exit codes: `0` free in both, `1` taken (registry or live), `2` **disagreement** between registry and
live — the staleness signal, a hard stop, not a warning — and `3` the registry itself is unusable
(missing, empty, or carrying a malformed row: §5.3).

### Claim, after binding

`tools/port-check.sh --claim <port> <bind> <container_port> <service> <project> <status> <source> <note>`

which appends exactly one line with `>>` (§1). Two properties matter:

- **No read-modify-write**, so two agents claiming different ports concurrently cannot lose each
  other's row.
- **A duplicate-key append is legal and is not silently merged.** If two agents claim the *same*
  port concurrently, both rows land and the audit (§5) reports it as a conflict. Losing one row
  would hide the collision; keeping both surfaces it. The registry's job is to make collisions
  visible, not to arbitrate them.

`--claim` re-runs the check first and refuses to append on a live conflict unless given an
explicit `--force` (which records `note=forced`), so the ordinary path cannot register a claim
that is already false at the moment it is written.

## 5. Staleness: how a wrong row gets caught

The registry's failure mode is the incident's failure mode — a document asserting "no collision"
and being believed. Two mechanisms, both mechanical.

### 5.1 The audit run

`tools/port-check.sh --audit`

walks every non-`released` row and compares it to `lsof -nP -iTCP -sTCP:LISTEN`, classifying:

- **MATCH** — registry says `live`, something is listening. Refresh `verified`.
- **GHOST** — registry says `live`, nothing is listening. The row is stale.
- **SQUATTER** — something is listening that no row accounts for. The registry is incomplete.
- **CONFLICT** — two non-`released` rows claim the same host port (a row superseded by a later
  same-port, same-`source` release no longer counts).

`--audit` is what makes the registry *falsifiable*: every row states a checkable prediction about
`lsof`, and the audit runs it. A `claimed` or `reserved` row predicts nothing about `lsof` and is
skipped rather than reported as a ghost.

### 5.2 A docker healthcheck is not evidence of a host binding

Stated in the skill's `## Red flags` table as a named rationalization, because it is exactly what
happened. `docker-compose.yml:125` health-tests `http://localhost:9000/minio/health/live` from
*inside* the container. It passes whether the host mapping is `9000:9000`, `9100:9000`, or absent
entirely. Likewise `docker ps` reporting `healthy` says nothing about the host side.

**The only evidence for a host binding is `lsof -nP -iTCP:<port> -sTCP:LISTEN`, or a curl from the
host to the host port.** Nothing observed from inside a container counts.

### 5.3 The checker script

Yes, a script belongs in `tools/`. agent-hq conventions, to follow exactly (verified against
`tools/sim-lease.sh:1-18` and `tools/check-invariants.sh:1-25`): `#!/usr/bin/env bash`,
`set -euo pipefail`, `script.sh [target]` argument shape, fails closed, and a heavy why-comment
header explaining the reasoning — not just the usage. **Under 300 lines**, per
`tools/check-file-length.sh` (`LIMIT=300`), which *does* cover `.sh`.

**Row-level integrity fails closed exactly like file-level integrity.** Before answering anything the
script validates every non-comment row — nine tab-separated fields, field 1 numeric (§2.2), field 6
one of §2.1's six values — and any violation prints the offending rows and exits `3`, as an
unreadable registry does and for the same reason: a registry that cannot be parsed supports no
verdict about any port, so "free" must not be an available answer. Deliberately *not* exit `1`,
which is reserved for registry-vs-live disagreement — a fact about the world, not about the file.
Skipping a bad row is the forbidden behaviour: a blank port field used to vanish silently from check
and audit alike, a silent "must be free" by another route, and it is how a non-port token reached
`--audit`'s CONFLICT dedup, which compares raw field-1 values.

One hard requirement in the script: **`command grep`, never bare `grep`.** This shell wraps
`grep` in a function that can silently return nothing; a false-negative grep here would report a
taken port as free, which is the one error the tool exists to prevent. The script must also carry
a positive control on its own registry read (a bare `command grep -c "" tools/ports.tsv`) and
fail closed if the registry reads as empty.

## 6. What the registry is NOT

Explicit non-goals, so the next agent does not grow this into a devops platform:

1. **Not a runtime allocator.** It does not hand out ports, hold leases, or arbitrate. It records
   and it reports. (`tools/sim-lease.sh` is the leasing pattern for a genuinely serial resource;
   ports are not that, and this is not a second one.)
4. **Not a monitor.** No daemon, no launchd job, no polling. `--audit` runs when a human or an
   agent runs it.
5. **Not authoritative over container-internal ports** (§3), nor over remote/production ports —
   this machine's host namespace only.
6. **Not a conflict resolver.** On a hit it stops and reports; a human picks.

## 7. Seed data

Rules for the seed: every row traces to a `file:line` or a live capture; anything unconfirmed is
carried as `UNVERIFIED` rather than dropped or guessed.

### 7.2 agent-hq / system — live

| port | bind | container | service | project | status | source | verified |
|---|---|---|---|---|---|---|---|
| 9000 | 127.0.0.1 | - | agent-topology MCP server | agent-hq | live | lsof (PID 68718 `node server.js`); `tools/agent-topology/config.js:81-82`; `~/.agent-topology/data/server.port` | 2026-09-04 |
| 9000-9999 | 127.0.0.1 | - | agent-topology port range | agent-hq | reserved | `tools/agent-topology/config.js:81-82` | 2026-09-04 |
| 7777-7800 | 127.0.0.1 | - | swarm-communication bus range | agent-hq | claimed | `architecture/swarm-communication-layer.md:81-82`; `swarm-communication-layer/.env.example:17-18` | 2026-09-04 |

## 8. Open questions and recommendations

1. **Does this warrant an ADR?** *Recommendation: yes — one ADR covering (a) the registry as
   agent-hq-owned cross-project state and (b) check-before-bind as standing practice.* It is a
   cross-cutting policy affecting every project, which is what `agent-hq/CLAUDE.md` reserves ADRs for.
   **No number is claimed here.** The highest existing ADR is 0036 and the next free number is
   contested shared state across concurrent agents; the owner should allocate it. If an ADR is
   written, it is also the natural place to settle §1's `tools/ports.tsv` vs a `registry/` folder.
6. **Range rows make the grep contract lossy.** `command grep -E '^9000\b'` will not match a row
   whose port field is `9000-9999`. The check script must expand ranges explicitly (a numeric
   comparison, not a text match) — a build requirement, and the single most likely place for the
   script to be quietly wrong. Its verification step must test a range hit specifically.
8. **No second machine.** The registry describes *this* host. `tools/second-machine-onboarding.md`
   exists in agent-hq; whether ports.tsv should ever be machine-scoped is deferred until that matters.

## Source lineage

