# 0006. Memory home: stores outside hq, hq/memory/ maps only

- **Status:** accepted
- **Date:** 2026-07-01
- **Context of:** workspace-wide

## Context

agentmemory needs stable store locations with a clear personal/work namespace split.
The stores are live, constantly-churning databases — they must never enter git history.
hq is committed and pushed under the personal account (<owner>), making work data
inside hq's directory tree a compliance exposure even when git-ignored (one .gitignore
regression or one cloud-sync decision away from a personal remote). This machine has
no Time Machine; the backup mechanism is git push to private GitHub.

## Decision

**Store locations — both OUTSIDE hq:**
- Personal store: `~/.agentmemory/personal/`
- Work store: `~/.agentmemory/work/`
- hq/memory/ contains ONLY `README.md` (the ownership map + pointers). No live bytes.
- Optional: ignored navigation symlinks (e.g. `memory/personal -> ~/.agentmemory/personal/`)
  MAY be added at install for convenience; they remain git-ignored.

**Rationale for outside-hq placement (two reasons):**
1. **git clean -x safety:** `git clean -x` deletes git-ignored files inside the working
   tree. Stores inside hq/memory/ would be destroyed by any cleanup run. Outside-repo
   placement is immune — this is a hard guarantee, not a soft one.
2. **Compliance:** work data physically inside a personal-account repo's working tree
   is an exposure regardless of gitignore. Physical separation is the only hard guarantee.

**Namespace keying = remote URL:**
The session hook maps repo remote URL to namespace:
- Patterns matching `<work-remote-pattern>` → work namespace.
- All other repos → personal namespace.
- Non-repo directories → personal namespace.
This aligns with the same mechanism family as the git-identity remote-URL autoswitch
(hasconfig remote-URL), so memory identity and git identity cannot disagree.
(ASSUMPTION at Phase 1: <work-remote-pattern> is an org remote — verify at autoswitch build.)

**Defense-in-depth gitignore** (in hq .gitignore — see ADR 0001 for why this is belt
and suspenders even though the bytes don't live here):
```
/memory/**
!/memory/README.md
*.sqlite
*.db
*.db-wal
*.db-shm
```
The `/memory/**` form (not `/memory/`) is required for the `!/memory/README.md`
negation to work — git cannot re-include a file inside an excluded directory.

**Durability model:**
- agentmemory stores are DISPOSABLE recall. Loss = lose continuity nuance, not
  decisions or learnings (those are in hq git).
- Durable knowledge: promoted via Compound (human-rewritten) → committed → PUSHED to
  private GitHub (<owner>). Every commit batch must be published. See STANDARDS §8.
- No git snapshots of agentmemory (would violate ADR 0003 no-mirroring rule).
- Prerequisite: <owner> GitHub token needs re-auth before first push (user action).

**Relocatability (Phase-2 verification — verify, don't assume):**
- (a) Store path configurable (env/config) → point stores at above paths directly.
- (b) Not configurable but plain path → move bytes to target dirs; symlink FROM the
  default app-data path TO them. (Note: no Time Machine on this machine, so symlink
  direction is a non-issue for backup scope.)
- (c) Neither → accept default paths; memory/README.md becomes pointer-only documenting
  real paths; namespace split via two instances/profiles, identity-keyed automatically.

**SSH note (recorded for Phase-2 autoswitch build):**
Personal key = existing `id_ed25519`. One work key shared for <work-remote-pattern> remotes. ASSUMPTION: <work-remote-pattern> is an organization remote — verify before configuring.

## Reasoning

Outside-repo placement converts two soft guarantees (gitignore + STANDARDS rule) into
one hard guarantee (bytes not present = cannot leak). git-clean risk is the decisive
factor; compliance is the reinforcing one. Both together make outside-repo the only
defensible location.

## Consequences

- Easier: `git clean -x` is safe; work data never physically inside personal-account
  repo; hq/memory/ always clean in git ls-files; no compliance exposure from work bytes.
- Harder: stores not co-located with hq directory; navigation requires knowing the
  ~/.agentmemory/ path or using the optional symlinks.
- Accepted: stores are disposable; backup is git push of hq content (not the stores).

## Alternatives considered

- Personal store at hq/memory/personal/ (PROPOSAL-v2 §3.1) — rejected: `git clean -x`
  would destroy it; physical-separation advantage outweighs navigational convenience.
- Both stores in hq/memory/ with gitignore — soft guarantee only; rejected for git-clean
  and compliance reasons.
- Single unified store — rejected; personal/work split is a hard compliance boundary.

---

## As-built deviation (2026-07-02)

**Fallback rung applied: (c)** — store path not relocatable; single hardcoded SQLite store.

**Actual store layout:**
- `~/.agentmemory/` — SQLite DB managed by iii-engine (agentmemory v0.9.27)
- `DATA_DIR` is hardcoded in `src/config.ts` as `join(homedir(), ".agentmemory")`. No
  env var override exists. Symlinks are not followed (iii-engine resolves realpath).
- Marker dirs `~/.agentmemory/personal/` and `~/.agentmemory/work/` created as navigation
  aids only. They are NOT actual DB locations — the SQLite file is at `~/.agentmemory/`.

**Namespace split implementation:**
- AGENT_ID + AGENTMEMORY_AGENT_SCOPE=isolated provides logical (not physical) namespace
  separation within the single SQLite store.
- Hook writes set AGENT_ID=work (<work-remote-pattern> remotes) or AGENT_ID=personal
  (all other repos / non-repo dirs), via namespace-wrap.sh at hook invocation time.
- AGENTMEMORY_AGENT_SCOPE=isolated: each hook-injected recall returns only memories from
  the current AGENT_ID. This is the isolation boundary.
- MCP tool reads (agentmemory MCP server): shared scope by default — all memories visible
  unless the calling tool also sets AGENT_ID. This is a known gap; Phase 3 must verify
  whether MCP reads respect isolation.

**Persistent daemon note:**
- agentmemory runs as a background daemon on port 3111 (must be started before sessions).
- MCP server requires the daemon to be running; proxy-only fallback exposes 7 tools instead
  of 53. Full tool surface: `agentmemory &` then restart Claude Code.

**Compliance status:**
- ADR 0006 compliance: SATISFIED. The bytes are at `~/.agentmemory/`, which is outside
  all git repos. `git clean -x` in any repo (including hq) cannot touch `~/.agentmemory/`.
- Physical personal/work separation: NOT ACHIEVED (single DB). Logical namespace
  separation via AGENT_ID is in place. Accepted as sufficient for Phase 2 given iii-engine
  hardcoding. Phase 3 must validate hook-injection isolation before work sessions begin.

**Accepted by user: 2026-07-02.**
**Phase 3 action required: verify hook-injection isolation before real work data writes.**
