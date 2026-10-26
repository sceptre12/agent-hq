---
name: sim-lease
description: Acquire, release, check, or steal an iOS simulator lease via tools/sim-lease.sh before driving any simulator (Maestro, simctl, dev-client install). Use when about to run `simctl boot`, launch a Maestro flow, install a dev client, or otherwise drive a booted simulator — and at teardown to release. Also use when a lease looks stuck (held-by-other, or a suspected-dead holder) and a `status`/`steal` call is needed.
---

## Trigger

Use BEFORE any `simctl boot`, Maestro run, or dev-client install touches a simulator UDID —
acquire the lease first, every time, no exceptions for "just a quick check." Release at
teardown; a worktree merge counts as teardown (release before or as part of merge-and-cleanup,
never left dangling). A UDID is a serial resource — two drivers (Maestro, simctl scripting,
manual use) must never touch the same UDID concurrently. This mechanizes the interim manual
practice of assigning one UDID per ticket in the dispatch brief. Device contention destroys
capture data: an interleaved capture set must be discarded and re-captured on an exclusively
held device.

## Steps

1. **Before driving a simulator, acquire the lease for its UDID:**
   `~/projects/agent-hq/tools/sim-lease.sh acquire <udid> <ticket>`
   Use your ticket/dispatch id as `<ticket>`. Only proceed to `simctl boot` / Maestro / install
   after this prints `PASS`.
2. **Read the exit code if it is not 0** (see the table below) and act on the failure class —
   do not retry blindly and do not silently switch UDIDs without recording why.
3. **When work on that UDID is done, release it:**
   `~/projects/agent-hq/tools/sim-lease.sh release <udid> <ticket>`
   Use the SAME ticket id used to acquire — release is refused otherwise (exit 5). If your work
   unit ends in a worktree merge, release before or as part of that teardown; never leave a lease
   held past the work it was acquired for.
4. **To see what is currently held** (read-only, safe to run any time, including during testing):
   `~/projects/agent-hq/tools/sim-lease.sh status`
5. **Only if you have concrete evidence the holder is dead** (its lane/session terminated —
   cite where you confirmed this, e.g. an agent-hq lane record or session-end note), steal it:
   `~/projects/agent-hq/tools/sim-lease.sh steal <udid> --evidence '<why the holder is dead, cited>'`
   A steal with empty/missing `--evidence` is refused by the tool itself (exit 6) — this is not
   a formality to route around.
6. **The production simulator (the UDID configured as production in the tool, e.g. `$SIM_PRODUCTION_UDID`) is refused by default**
   on both `acquire` and `steal`. Do not pass the override flag
   (`--override-production-i-have-owner-authorization`) unless the owner has explicitly
   authorized production-simulator use for this specific task, with that authorization recorded
   (cite it in your work record) — never self-granted.
7. **One command per Bash call.** Permission rules prefix-match whole strings — do not chain
   `sim-lease.sh acquire ... && simctl boot ...` into a single call.

## Exit codes

| Code | Meaning | What it tells you |
|---|---|---|
| 0 | success | proceed |
| 1 | usage error | bad/missing args — check the command form, not the lease state |
| 2 | acquire refused, already held | pick a different UDID or wait — never share the device, never override |
| 3 | production UDID refused | not yours to override without recorded owner authorization (step 6) |
| 4 | no active lease on target | nothing to release/steal — the UDID is already free |
| 5 | release refused, ticket mismatch | you are not the recorded holder — use `steal` with evidence if you believe the real holder is dead |
| 6 | steal refused, no evidence | supply `--evidence '<why>'`; an empty/missing value is a hard refusal, not negotiable |
| 7 | state-dir/filesystem error | tool failed closed — investigate the state dir, do not treat as "no leases held" |

## Red flags

| Rationalization | What to do instead |
|---|---|
| "The sim looks idle, I'll just boot it." | "Looks idle" is not "unleased." Run `acquire` first — a busy Maestro flow between waypoints can look idle from outside. |
| "It's my lease, my teardown — I can skip the release." | Release is part of teardown, not optional cleanup. A worktree merge counts as teardown; release before or as part of it. |
| "The holder is probably dead, I'll steal without checking." | `steal` requires cited evidence the holder is dead (exit 6 refuses an empty one) — go find the evidence (lane/session record) before calling it, never guess. |
| "Production sim is the only one with the data I need." | That is exactly the case the refusal exists for. Get explicit owner authorization, record it, then use the override flag — never self-grant it. |
| "I'll chain acquire and boot in one command to save a round trip." | One command per Bash call — permission rules prefix-match whole strings, and chaining hides the acquire result. |

## Exit criteria

- [ ] Lease was acquired for the target UDID before any `simctl boot` / Maestro run / dev-client
      install, and the `acquire` call's exit code / PASS-or-FAIL was read before proceeding.
- [ ] Lease was released at teardown using the same ticket id it was acquired with.
- [ ] Any `steal` was accompanied by cited evidence the prior holder was dead — never an empty
      `--evidence` and never routed around the tool's refusal.
- [ ] The production UDID was never overridden without recorded owner authorization.

## Provenance
Provenance: device serialization (why a lease is needed at all); a capture set discarded, not
salvaged, after two drivers interleaved on one simulator; a run abandoned after a confirmed
concurrent-simulator consumer; `tools/sim-lease.sh` (the tool itself, 18/18 tests in
`tools/test_sim-lease.sh`).
Ported into agent-hq 2026-10-26 for the delivery workflow (design §7 item 8).
