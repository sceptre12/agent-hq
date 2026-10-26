---
name: port-claim
version: 1.1.0
description: Check the hq-owned host port registry before binding, mapping, or exposing any TCP port, and register the claim before the bind (claim before bind, A.5.2). Use when about to `docker compose up`, start a dev server, add a port mapping, or pick a port for a new service — before the bind happens, not after a collision is discovered. Also use when auditing existing port claims for staleness, or before trusting a project's own port doc as ground truth.
---

## Trigger
Use when: about to bind, map, or expose a host TCP port for any service, anywhere under
`~/projects/` — before picking the number. Also use to register the claim before the bind
(claim before bind, INTERFACES A.5.2), and any time a project's own port doc is about to be trusted instead of
checked. hq owns `tools/ports.tsv`; this skill never edits any file outside hq
(architecture/port-registry.md §6).

## Steps
1. Before picking a port, check it: `~/projects/agent-hq/tools/port-check.sh <port>`.
   - Exit `0` → free in both registry and `lsof`. Proceed.
   - Exit `1` → taken (registry and/or live agree). Stop. Do not auto-pick the next port —
     report the collision and let a human choose, except for the one retry below.
   - Exit `2` → registry and live **disagree** (staleness signal). Stop — this is a hard stop for
     the candidate, never a warning: do not bind it. It is the exact failure class named in
     architecture §5.1. The one retry below applies exactly as for exit `1`.
   - The one retry, for exit `1` and exit `2` alike (INTERFACES 1.3.0 A.5.2, AM-3, owner OQ-2):
     on the first refusal of a candidate, make exactly one retry at candidate + 10, itself
     checked and claimed with `--claim` before any bind (the tool never picks it); a second
     refusal stops the line and is reported. Never a second +10.
   - Exit `3` → usage error, or the registry is unusable: missing, empty, or carrying a
     structurally malformed row (not 9 tab-separated fields, a non-numeric port field, or a
     status outside the closed enum). Fix the invocation or the row; the script fails closed
     rather than reporting a false "free". Report a malformed row — never delete it to move on.
2. If the candidate is inside a declared range (e.g. anywhere in `9000-9999`), still check the
   *specific* port — the script expands ranges numerically, so a range row correctly reports as
   taken even though its own text never mentions your exact number.
3. Claim the port before the bind, in the same session:
   `~/projects/agent-hq/tools/port-check.sh --claim <port> <bind> <container_port> <service> <project> claimed <source> <note>`
   — all 8 fields are positional and required; pass `-` for `container_port` or `note` when
   there is nothing to record. In a delivery run `<project>` is the `<run-id>` and `<source>` is
   `<run-id>-<subtask>` (A.5.2). `<port>` must be a single numeric port, 1-65535 — `--claim` does
   not accept a range (a range claim is out of scope for this skill: stop and report it), even
   though range *rows* are legal in the registry and are matched by the check path. The status
   field (here `claimed`) must be one of `live` / `claimed` / `reserved` / `unmerged` / `released` /
   `UNVERIFIED` — the enum is closed (architecture §2.1) and `--claim` refuses anything else with
   exit `3`. `--claim` re-runs the check first and refuses to append on a live conflict (exit `1`
   or `2`: do not bind; take the one +10 retry of Step 1 at most once, else report); only add a trailing `--force` when the conflict is understood and
   accepted — it is then recorded with note `forced` (or `forced: <note>`), never silently. In a delivery run never pass
   `--force`: a refusal gets the one +10 retry, then stop (`skills/resource-catalog/references/ports.md`).
4. Bind the port in the target project as normal, only after the claim returned exit `0`. This
   skill does not touch any file outside hq. If the bind fails, supersede the claim at once with a
   `released` row of the same port and the same `source`:
   `~/projects/agent-hq/tools/port-check.sh --claim <port> <bind> <container_port> <service> <project> released <source> <note>`
5. Before trusting a project's own port doc (a `LOCAL-PORTS.md`, a `CLAUDE.md` port list, etc.),
   run `~/projects/agent-hq/tools/port-check.sh --audit`. It classifies every non-`released` row (rows
   superseded by a later same-port, same-source `released` row are skipped) as MATCH / GHOST /
   SQUATTER / CONFLICT against live `lsof` truth.
6. Never hand-edit `tools/ports.tsv`, and never edit another project's port doc from this skill.
   Registration happens only via `--claim` — the registry is read-only toward every repo except
   hq, and it is not a conflict resolver (architecture §6): on a hit, stop and report.

## Red flags
| Rationalization | What to do instead |
|---|---|
| "The docker healthcheck is passing, so the binding is fine." | The healthcheck curls `localhost` *inside* the container. Run `lsof -nP -iTCP:<port> -sTCP:LISTEN` on the host. |
| "The project's own port doc says there's no collision." | That is the doc that was wrong on 2026-09-04. Run `--audit`; a doc is a claim, `lsof` is evidence. |
| "It's taken, I'll just use the next port up." | Refuse and report. Auto-picking is how four undocumented remaps happened. The only exception is the single claimed retry at candidate + 10 (A.5.2, OQ-2); never a second retry. |
| "I found the port number on a `docker-compose.yml` line, that's the mapping." | It may be a comment describing an old remap, not the live binding (a real incident: `:115` was a comment, the actual `- "host:container"` line was `:118`). Confirm against the literal mapping line or `lsof`/`docker ps`, not the nearest matching number. |
| "This project has no ports, I'll add a row saying so." | The registry holds claims, not projects (architecture §2.2). There is no placeholder port and no "not applicable" status — a zero-claim project is recorded in the architecture doc's §7.6 prose, and `command grep <project> tools/ports.tsv` returning nothing *is* the answer. |
| "I'll just fix this stale row directly in `ports.tsv`." | The registry is append-only on the hot path; a stale row is superseded by a new row (e.g. `status=released` repeating the claim's exact port and `source`; `--claim` warns if it supersedes nothing), never edited in place — hand-editing risks losing a concurrent agent's append. Use `--claim`, or leave compaction to a dedicated, serialized maintenance pass. |

## Exit criteria
- [ ] `tools/port-check.sh <port>` was run and returned exit `0` before the port was chosen —
      not after the bind was already attempted.
- [ ] If exit was `1` or `2`, the bind was NOT attempted and the collision/disagreement was
      reported instead of worked around or auto-remapped, except the single retry at
      candidate + 10, checked and claimed before any bind; a second refusal stopped the line.
- [ ] `tools/port-check.sh --claim ... claimed ...` was run and returned exit `0` (one row
      appended) before the bind, not after it.
- [ ] A bind that failed was followed by a `released` row of the same port and source.
- [ ] No file outside `~/projects/agent-hq/tools/ports.tsv` was edited to record or resolve the claim.
- [ ] If a project's port doc was consulted for this decision, `--audit` was also run, and any
      GHOST/SQUATTER/CONFLICT finding touching the port in question was reported, not dismissed.

## Provenance
Provenance: Hermes skill `learnings/port-collisions` (was learnings/port-collisions.md) (2026-09-04 host port collision — a service's MinIO wanted
host 9000 while agent-hq's agent-topology already held it; the container healthcheck passing, and
that project's own port doc separately asserting no collision on unrelated ports, both masked host-level
truth that only `lsof` revealed).
Ported into agent-hq 2026-10-26 for the delivery workflow (design §7 item 8); amended 2026-10-26, AM-1 A.5.2: claim before bind; amended 2026-10-26, INTERFACES 1.3.0 AM-3 / owner OQ-2: exactly one claimed retry at candidate + 10, then stop.
