# 0007. Minimal enforcement: invariant runner + hq git gates

- **Status:** accepted (2026-07-02) — ratified per user rulings on Open Q1 and Open Q2 (see Open questions). Gates built and `core.hooksPath` installed; STANDARDS §5 amended; INVARIANTS 16–19 appended.
- **Date:** 2026-07-02
- **Context of:** workspace-wide
- **Amends:** STANDARDS §5 line "No enforced hooks — convention, not ceremony" (see Decision → STANDARDS amendment). Does not supersede any ADR.

## Context

The user ruled (addy-alignment-plan.md §6, Q1, 2026-07-02): **"ADOPT MINIMAL
ENFORCEMENT. To be defined in ADR 0007 … expect check-invariants runner + a small
automatic gate, nothing ceremonial. Supersedes the 'convention only' reading of
STANDARDS §5."** This ADR defines what MINIMAL means as concrete mechanisms.

The failure modes worth guarding are the *real* ones from this project's short history,
not hypothetical ones:

1. **Runtime state creeping into the repo.** A `data/` and `.serena/` incident occurred
   (2026-07-02); the `.gitignore` guards `/data/` and `/.serena/` were added *after* the
   fact. `.gitignore` is a soft, reactive guard — it silently protects only what someone
   remembered to list, and `git add -f` bypasses it entirely.
2. **Push-is-the-only-backup being forgotten.** This machine has no Time Machine; `git
   push` to private GitHub is the sole durability mechanism (ADR 0006, STANDARDS §8 step
   7). An unpushed commit batch is unbacked-up knowledge. Nothing currently notices.
3. **Secrets accidentally staged.** hq is committed under the personal account (<owner>)
   and holds context, not credentials. A staged `.env`/`.pem`/key file or pasted key
   material is a compliance exposure. Only `.gitignore` guards it today (soft, `-f`-able).
4. **Invariants drifting silently.** INVARIANTS.md's 15 checks are run *by hand* at
   Compound time (STANDARDS §8 step 5, marked *optional*). A skipped run = silent
   structural drift with no forcing function to notice.
5. **Memory store landing in the wrong location.** ADR 0006 requires the agentmemory
   bytes to live at `~/.agentmemory/` — outside every git working tree. A misconfigured
   store path or a stray marker dir inside hq would reintroduce the git-clean and
   compliance risks 0006 exists to eliminate.

**Design constraints (from the ruling and the existing stack):**

- Single person, single machine. **Nothing that adds ritual to every turn or prompt.**
- Enforcement must be **cheap, silent when passing, loud when failing.**
- Must **not** touch frozen surfaces: no new MCP server (ADR 0004 frozen list), no
  mid-session CLAUDE.md write (prefix-freeze, ADR 0004/§9), nothing that injects per-turn
  conversation content (cache discipline — recall is pull-only, ADR 0003 addendum).
- Must honor ADR 0001 (plain markdown + plain git, no heavy tooling / no build step).

**ADR cross-check (done before writing — no contradictions):**

| ADR | Relevant rule | This ADR |
|---|---|---|
| 0001 | Lightweight; no heavy tooling, no build step | Gates are ≤3 small POSIX-shell scripts + one `git config`. No service, no dependency, no build. ✔ consistent |
| 0002 | Frozen stack; nothing indexes/crawls hq | No new tool touches the stack; no indexer added. ✔ |
| 0003 | One owner per fact; no mirroring | INVARIANTS.md stays the **definitional owner** of *what* is checked; the runner is its executable mirror, kept in lock-step by a count-parity meta-check. Adding a check means editing INVARIANTS.md first. ✔ |
| 0004 | Prefix freeze; frozen MCP list | No MCP server, no CLAUDE.md edit, no `~/.claude/settings.json` edit, no per-turn content. All gates are git-side/terminal-side → **cache-neutral**. ✔ |
| 0005 | INVARIANTS.md adopted as pass/fail self-check | This ADR *operationalizes* 0005's INVARIANTS.md. ✔ reinforces |
| 0006 | Memory bytes outside hq; push is the only backup | Gate 1 check 16 asserts store-outside-repo; Gate 3 nudges the push. ✔ reinforces |

## Decision

Adopt **exactly three gates**, all living **inside hq**, all **tracked and pushed**
(therefore durable), installed by a **single `git config` command**, with **zero MCP /
CLAUDE.md / `~/.claude/settings.json` / launchd footprint**.

### Gate 1 — `tools/check-invariants.sh` (mechanical invariant runner)

- **Trigger:** on demand (`bash tools/check-invariants.sh`); at Compound time (STANDARDS
  §8 step 5, upgraded from *optional* to *run the script*); and invoked internally by
  Gate 2 in `--fast` mode.
- **Check performed:** all 15 INVARIANTS.md checks executed mechanically, plus 4 new
  environment checks (16–19, defined below): (16) `~/.agentmemory` exists and is **not**
  inside any git repo; (17) `~/.serena/serena_config.yml` project list excludes any hq
  path; (18) launchd `com.agentmemory.default` + `com.headroom.default` loaded
  (**WARN-only**, not fail — runtime state, not structural); (19) no `data/` or `.serena/`
  directory physically present in the hq top level.
- **Failure behavior:** prints one `PASS`/`FAIL`/`WARN` line per check; a `FAIL` prints the
  remedy inline. Exit `0` iff no `FAIL` (WARN does not fail); exit `1` if any `FAIL`. On
  full pass, prints a single summary line (`check-invariants: N/N OK`) — quiet on success,
  detailed on failure.
- **Cost per invocation:** ~19 read-only shell/git-plumbing probes, <1 s wall, no network,
  no MCP, no prefix/cache impact. Runs only when explicitly invoked.

### Gate 2 — `tools/git-hooks/pre-commit` (blocking commit gate)

- **Trigger:** every `git commit` in hq.
- **Check performed, in order:** (a) **secret filenames** — block if any staged path
  matches `.env`/`.env.*`/`*.pem`/`*.key` or lives under `secrets/`; (b) **runtime state**
  — block if any staged path matches `data/`, `.serena/`, `*.sqlite`, `*.db`/`-wal`/`-shm`,
  or anything under `memory/` other than `memory/README.md`; (c) **secret material** —
  high-precision content scan of the staged diff for `-----BEGIN … PRIVATE KEY-----` and
  `AKIA[0-9A-Z]{16}` only (deliberately narrow — see Reasoning); (d) **memory-safety
  invariants** — run `check-invariants.sh --fast` (subset {2, 11, 12, 13, 14, 19}).
- **Failure behavior:** prints the offending file/pattern + a one-line remedy to stderr and
  **exits 1, blocking the commit.** Escape hatch: `git commit --no-verify` (documented; the
  single author owns the bypass decision).
- **Cost per invocation:** only at commit time (never per turn); greps the staged diff
  (small) + 6 fast filesystem checks; <1 s; no network; cache-neutral.

### Gate 3 — `tools/git-hooks/post-commit` (non-blocking backup nudge)

- **Trigger:** every `git commit` in hq (fires after the commit succeeds).
- **Check performed:** compute `git rev-list --count @{u}..HEAD`; if hq is ≥1 commit ahead
  of `origin`, emit a one-line reminder that push is the only backup (ADR 0006).
- **Failure behavior:** non-blocking by construction (git ignores post-commit exit code);
  prints the nudge to stderr; **silent when HEAD == origin.**
- **Cost per invocation:** one `git rev-list --count`; <100 ms; terminal-side only; injects
  nothing into any model context; cache-neutral.

### STANDARDS §5 amendment (exact replacement text)

STANDARDS §5's final line currently reads:

> Keep one logical change per commit. No enforced hooks — convention, not ceremony.

Replace with:

> Keep one logical change per commit. Commit-*message* conventions are convention, not
> ceremony — not enforced. **Structural safety is enforced minimally** (ADR 0007): an hq
> `pre-commit` hook blocks staged secrets and runtime state and runs the memory-safety
> invariant subset; a `post-commit` hook nudges when commits are unpushed. Install once:
> `git -C ~/projects/agent-hq config core.hooksPath tools/git-hooks`.

This is a one-line amendment inside an existing section — it does **not** add or remove a
numbered `## N.` section, so INVARIANTS check 4 (≥11 sections) still passes.

### What stays convention-only (deliberately not mechanized)

- **Commit-message format** (STANDARDS §5 types) — self-correcting for a single author;
  enforcing it taxes every commit for near-zero benefit.
- **Running the Compound ritual itself** and **writing learnings/retros** — these are
  judgment, not assertions; a hook cannot author a learning. Gate 3 mechanizes only the
  one sub-step with a hard consequence (the PUSH backup).
- **Independent verification / maker-checker** (global Rule 4) — an orchestration
  discipline, not a repo-state assertion; not hook-shaped.
- **Dispatch done-conditions** (plan P2.3) — a dispatch-time convention in
  model-routing.md, not an hq-repo gate.

## Reasoning

- **These three gates map one-to-one onto the five real failure modes** (1→Gate1 ck19 +
  Gate2 runtime block; 2→Gate3; 3→Gate2 secrets; 4→Gate1 + Gate2 `--fast`; 5→Gate1
  ck16/17). Nothing is added that isn't traced to a real incident — the Addy "ratchet"
  shape (every gate traces to a failure).
- **All three live inside hq and install with one command** (`core.hooksPath tools/git-
  hooks`). Because the hook scripts are tracked, they are pushed → durable and versioned.
  The `core.hooksPath` pointer is local config (not pushed); on a fresh clone, re-run the
  one command. This is why they beat `.git/hooks/*` (untracked, unbacked-up).
- **Cache-neutrality is structural, not incidental.** No gate touches an MCP server,
  CLAUDE.md, `~/.claude/settings.json`, or the conversation. They are pure git/terminal
  events. This is what lets us adopt enforcement without violating ADR 0004 or the
  pull-only recall discipline — the exact tension the plan flagged (G1).
- **The secrets scan is narrow on purpose.** hq is a prose/markdown context repo whose
  documents legitimately contain the *words* "token", "secret", "password", "key" (e.g.
  "re-auth the <owner> token"). A generic keyword scanner would false-positive on nearly
  every commit and train the author to reflexively `--no-verify` — destroying the gate.
  Matching only real key *material* (PRIVATE KEY blocks, AWS key IDs) + secret *filenames*
  keeps the gate "loud only on real problems."
- **INVARIANTS.md remains the single owner** (ADR 0003). The script mirrors it; a count-
  parity meta-check (script check count == INVARIANTS.md check count) makes drift a
  self-caught FAIL rather than silent divergence.
- **A blocking pre-commit + a nudging post-commit is the right asymmetry.** Secrets and
  runtime state are irreversible-ish mistakes → block hard. A forgotten push is
  recoverable and context-dependent → nudge, never block (blocking a commit for being
  unpushed would be exactly the ceremony the ruling forbids).

## Rejected options and alternatives considered

| Candidate | Verdict | One-line reason |
|---|---|---|
| `tools/check-invariants.sh` mechanical runner | **ACCEPT (Gate 1)** | The keystone; turns 0005's manual checklist into a cheap, deterministic assertion. |
| hq `pre-commit` (secrets + runtime block + invariant subset) | **ACCEPT (Gate 2)** | Blocks the two irreversible mistakes at the last safe moment; sub-second; bypassable. |
| Backup/unpushed reminder as an hq `post-commit` hook | **ACCEPT (Gate 3)** | Guards the "forgot to push" failure with zero personal-config/cache footprint — strictly more minimal than a Claude Code hook. |
| Same reminder as a **Claude Code SessionEnd/Stop hook** | **REJECT** | Would require editing `~/.claude/settings.json` (personal config) and reasoning about hook-output injection vs. cache; `post-commit` achieves the same nudge inside hq. Available as a later opt-in if commit-time proves too quiet (open Q1). |
| **pre-push** hook running the full invariant suite | **REJECT** | Push is the backup we *want* to happen; adding a gate that can fail-and-block the push risks the exact "unbacked-up" state we're guarding. Nudge-to-push (Gate 3) is the correct direction, not a barrier. |
| **Scheduled/launchd periodic** invariant check | **REJECT** | Adds a background service (violates 0001 lightweight; another launchd unit to babysit) and needs a notification channel to be "loud," which is per-day noise at n=1. Commit-time + Compound-time coverage is sufficient. |
| Generic **keyword** secrets scanner (`token|secret|password|key`) | **REJECT** | Catastrophic false-positive rate on a prose repo; trains reflexive `--no-verify`. Replaced by the narrow key-material + filename scan. |
| Enforcing **commit-message** conventions via `commit-msg` hook | **REJECT** | Ceremony on every commit for a self-correcting, single-author concern; explicitly out of scope of "minimal." |
| Auto-**fixing** invariants (e.g. hook auto-writes gitignore) | **REJECT** | Silent auto-mutation hides drift and can fight the author; gates report and block, humans fix. |
| A second `.git/hooks/*` install (untracked) | **REJECT** | Not versioned, not pushed, lost on reclone; `core.hooksPath tools/git-hooks` keeps hooks durable. |

## Implementation spec (build verbatim — no design judgment required)

Target agent: Sonnet writes `check-invariants.sh` (15+4 checks need exactness); Haiku can
package the two hooks and run the install; a **separate** instance verifies (never the
author), per global Rule 4. Plan item: P2.1 (runner) + P2.2 (wire enforcement).

**Files to create (all under `$HOME/projects/agent-hq/`):**

1. `tools/check-invariants.sh`
2. `tools/git-hooks/pre-commit`
3. `tools/git-hooks/post-commit`

**Step 0 — keep INVARIANTS.md the owner (ADR 0003).** Before writing the script, append
checks **16–19** to INVARIANTS.md (new "Environment (post-stack)" subsection) so the doc
defines them and the script only mirrors:
- **16. agentmemory store is outside version control** — `test -d ~/.agentmemory && ! git -C ~/.agentmemory rev-parse --git-dir` → PASS.
- **17. Serena registry excludes hq** — `~/.serena/serena_config.yml` `projects:` list contains no path under `~/projects/agent-hq`. (Config absent → WARN, not FAIL.)
- **18. Stack services loaded (WARN)** — `launchctl list` contains `com.agentmemory.default` and `com.headroom.default`. Missing → WARN (runtime, not structural).
- **19. No runtime dirs in hq tree** — no `data/` or `.serena/` directory at hq top level.

**`tools/check-invariants.sh` outline:**

```bash
#!/usr/bin/env bash
# tools/check-invariants.sh — mechanical hq self-check (ADR 0007).
# WHAT is checked is owned by INVARIANTS.md; this script mirrors it.
# Usage: check-invariants.sh [--fast]   (--fast = subset {2,11,12,13,14,19} for pre-commit)
set -uo pipefail
HQ="${HQ:-$HOME/projects/agent-hq}"
FAST=0; [ "${1:-}" = "--fast" ] && FAST=1
pass=0; fail=0; warn=0
ok(){ pass=$((pass+1)); }                                   # quiet on pass
no(){ fail=$((fail+1)); printf 'FAIL  %-40s %s\n' "$1" "$2" >&2; }
wn(){ warn=$((warn+1)); printf 'WARN  %-40s %s\n' "$1" "$2" >&2; }
# run <id> <label> <bool-cmd...>  — PASS if bool-cmd exits 0
run(){ local id=$1 label=$2; shift 2; if "$@" >/dev/null 2>&1; then ok; \
       else no "$id $label" "see INVARIANTS.md / ADR 0007"; fi; }

# --- Structural + memory-safety (INVARIANTS.md 1–15). Fast subset = 2,11,12,13,14,19 ---
# ck2  memory/ tracked == only README.md
run 2 "memory/ only README" bash -c '[ "$(git -C "$HQ" ls-files memory/)" = "memory/README.md" ]'
# ck11 /memory/** ignore pattern
run 11 "gitignore /memory/**" grep -q '/memory/\*\*' "$HQ/.gitignore"
# ck12 !/memory/README.md negation
run 12 "gitignore README negation" grep -q '!/memory/README.md' "$HQ/.gitignore"
# ck13 db-file ignore pattern
run 13 "gitignore db pattern" grep -qE '^\*\.(sqlite|db)' "$HQ/.gitignore"
# ck14 no nested git repos
run 14 "no nested .git" bash -c '[ -z "$(find "$HQ" -mindepth 2 -name .git)" ]'
# ck19 no runtime dirs physically present
run 19 "no data//.serena/ in hq" bash -c '[ -z "$(find "$HQ" -maxdepth 1 \( -name data -o -name .serena \) 2>/dev/null)" ]'
if [ "$FAST" = 0 ]; then
  # ck1,3,4,5,6,7,8,9,10,15 — implement each from INVARIANTS.md's stated command + pass rule.
  # ck15 (count parity, doc reconciliation):
  files=$(ls "$HQ"/decisions/*.md | grep -v _TEMPLATE | grep -v README | wc -l | tr -d ' ')
  rows=$(grep -c '| [0-9]' "$HQ/decisions/README.md")
  [ "$files" = "$rows" ] && ok || no "15 decisions index parity" "files=$files rows=$rows"
  # --- Environment (post-stack) 16–19 ---
  run 16 "store outside VCS" bash -c 'test -d ~/.agentmemory && ! git -C ~/.agentmemory rev-parse --git-dir'
  if [ -f ~/.serena/serena_config.yml ]; then
    run 17 "serena excludes hq" bash -c '! grep -qE "^- .*/projects/agent-hq(/|$)" ~/.serena/serena_config.yml'
  else wn "17 serena excludes hq" "serena config absent"; fi
  launchctl list 2>/dev/null | grep -q com.agentmemory.default || wn "18 agentmemory svc" "not loaded"
  launchctl list 2>/dev/null | grep -q com.headroom.default   || wn "18 headroom svc"   "not loaded"
  # ck19 already run above (also in fast set)
  # --- meta: count parity vs INVARIANTS.md (ADR 0003 one-owner guard) ---
  defined=$(grep -cE '^\*\*[0-9]+\.' "$HQ/INVARIANTS.md")   # count of "**N." check headers
  implemented=19
  [ "$defined" = "$implemented" ] && ok || no "meta count-parity" "INVARIANTS=$defined script=$implemented"
fi
total=$((pass+fail+warn))
if [ "$fail" = 0 ]; then echo "check-invariants: $pass/$total OK ($warn warn)"; exit 0; \
else echo "check-invariants: $fail FAIL, $pass OK, $warn warn" >&2; exit 1; fi
```

(Checks 1,3–10 are transcribed one-to-one from INVARIANTS.md's stated `command` +
`PASS` condition — each is a single `run <id> <label> <cmd>` line. They are omitted from
this outline only for length; the implementer copies them verbatim from INVARIANTS.md.)

**`tools/git-hooks/pre-commit`:**

```bash
#!/usr/bin/env bash
# hq pre-commit (ADR 0007). Blocks staged secrets/runtime; runs memory-safety subset.
# Bypass (rare, author-owned): git commit --no-verify
set -uo pipefail
HQ="$(git rev-parse --show-toplevel)"
staged="$(git diff --cached --name-only)"
block(){ echo "pre-commit BLOCK: $1" >&2; exit 1; }
# (a) secret filenames
printf '%s\n' "$staged" | grep -qiE '(^|/)(\.env(\..*)?|.*\.pem|.*\.key)$|(^|/)secrets/' \
  && block "secret-bearing filename staged (.env/.pem/.key/secrets/). Unstage it."
# (b) runtime state
printf '%s\n' "$staged" | grep -qE '(^|/)(data/|\.serena/)|\.(sqlite|db|db-wal|db-shm)$' \
  && block "runtime state staged (data/.serena/*.sqlite/*.db). See ADR 0006."
# memory/: only README.md permitted
if printf '%s\n' "$staged" | grep -qE '^memory/'; then
  printf '%s\n' "$staged" | grep -E '^memory/' | grep -qvE '^memory/README\.md$' \
    && block "only memory/README.md may be committed (ADR 0006)."
fi
# (c) secret material (high-precision only)
git diff --cached -U0 | grep -qE '^\+.*(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16})' \
  && block "private-key / AWS-key material in staged diff."
# (d) memory-safety invariant subset
"$HQ/tools/check-invariants.sh" --fast >/dev/null \
  || block "invariant subset failed. Run: tools/check-invariants.sh"
exit 0
```

**`tools/git-hooks/post-commit`:**

```bash
#!/usr/bin/env bash
# hq post-commit (ADR 0007). Non-blocking backup nudge. push is the only backup (ADR 0006).
ahead="$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"
[ "${ahead:-0}" -gt 0 ] && \
  echo "reminder: hq is $ahead commit(s) ahead of origin — push is your only backup (ADR 0006): git push" >&2
exit 0
```

**Install (one-time; run once here and after any fresh clone):**

```bash
cd ~/projects/agent-hq
chmod +x tools/check-invariants.sh tools/git-hooks/pre-commit tools/git-hooks/post-commit
git config core.hooksPath tools/git-hooks
```

**Verification (separate instance, never the author — global Rule 4):**

1. `bash tools/check-invariants.sh` → exits 0, prints `check-invariants: N/N OK`.
2. Break one invariant deliberately (e.g. `touch memory/scratch.tmp` then stage it) →
   `check-invariants.sh --fast` exits 1 and names the failing check; **undo it.**
3. `printf 'AKIA%s\n' 'ABCDEFGHIJKLMNOP' > x.txt && git add x.txt && git commit -m t` → blocked (the test string is assembled at runtime so this document never contains a contiguous match itself)
   by (c); `git rm --cached x.txt && rm x.txt`.
4. `git add -f .env` (empty test) attempt → blocked by (a); unstage.
5. Make any trivial doc commit while ahead of origin → post-commit prints the push nudge;
   `git push` → next commit is silent.
6. Confirm `/context` and `/mcp` are unchanged (no prefix/MCP delta — cache-neutral).

**On adoption (not now — these are the commit-time actions):**

- Apply the STANDARDS §5 amendment text above.
- Append INVARIANTS.md checks 16–19 (Step 0).
- Set this ADR's Status → `accepted`; add the `| 0007 | Minimal enforcement … | accepted |`
  row to `decisions/README.md` (INVARIANTS check 15 requires file/row parity — until the
  row is added, check 15 will report a mismatch; this is expected while the ADR is merely
  PROPOSED on disk).
- Commit (`decision: 0007 accept minimal enforcement` + `chore: add invariant runner and
  hq git gates`) and **push**.

## Rollback plan

Fully reversible; nothing leaves durable state outside hq:

- **Disable all gates instantly:** `git -C ~/projects/agent-hq config --unset core.hooksPath`
  (reverts to `.git/hooks/`, which is empty → commits behave exactly as before).
- **Bypass one commit:** `git commit --no-verify`.
- **Remove entirely:** delete `tools/check-invariants.sh` and `tools/git-hooks/`; revert
  the STANDARDS §5 line and the INVARIANTS.md 16–19 block (git revert the doc commits);
  set this ADR's Status → `superseded by NNNN` or `deprecated` with a one-line why.
- **No external cleanup:** no MCP server, no `~/.claude/settings.json` entry, no launchd
  unit, no daemon was added — so there is nothing else to unwind.

## Consequences

- **Easier:** the two irreversible mistakes (staged secrets, staged runtime state) are
  blocked at the last safe moment; a forgotten push is caught at commit time; INVARIANTS
  goes from a hoped-for manual ritual to a one-command deterministic check; the whole
  enforcement layer is one `git config` to enable or disable.
- **Harder / accepted trade-offs:** commits now run a sub-second hook (bypassable with
  `--no-verify`); the runner is a second artifact that must track INVARIANTS.md (mitigated
  by the count-parity meta-check); `core.hooksPath` must be re-set once per fresh clone
  (documented). The narrow secrets scan will miss non-key-material secrets pasted into
  prose — accepted, because a broad scan is unusable on a docs repo and the primary
  exposure (key files, key blocks) is covered.
- **Convention-only remains, and that's acceptable:** commit-message format, the act of
  running Compound / writing learnings, and maker-checker verification stay conventions —
  they are judgment or orchestration, not mechanically-assertable repo state, so a gate
  would add ceremony without catching a real, discrete failure. Gate 3 mechanizes only the
  single convention step (PUSH) that has a hard, irreversible backup consequence.
- **Revisit if:** `--no-verify` becomes reflexive (signals a false-positive-prone check to
  fix or drop); or the commit-time push nudge proves too quiet in practice, at which point
  the Claude Code SessionEnd variant (open Q1) can be added as a second, opt-in layer.

## Open questions (genuinely require the user)

1. **Backup nudge placement.** This design puts the unpushed-backup reminder in an hq
   `post-commit` hook (fires at commit time; zero personal-config/cache footprint). The
   alternative — a Claude Code `SessionEnd` hook in `~/.claude/settings.json` — is more
   visible (fires when you quit a session, catching stale unpushed state from prior
   sessions) but edits your personal global config and needs a cache-safety check on hook
   output. **Recommendation: ship post-commit now; add SessionEnd later only if the
   commit-time nudge proves too quiet.** Confirm, or ask for both.
   **RESOLVED (2026-07-02):** BOTH — ship the hq `post-commit` nudge AND add a Claude Code
   `SessionEnd` hook (user accepted the `~/.claude/settings.json` edit). Both are now
   implemented; the SessionEnd hook is a local-only, no-network unpushed-commit check.
2. **STANDARDS §5 amendment wording.** The exact replacement text is proposed above. Since
   it supersedes a deliberate "convention, not ceremony" stance, please ratify the wording
   (or adjust) before the implementing agent applies it.
   **RESOLVED (2026-07-02):** ratified AS WRITTEN — the §5 replacement text above was
   applied to STANDARDS.md unmodified.

## As-built deviation (2026-07-02)

Check 18 as originally specced (`launchctl list | grep -q`) false-WARNed on every run under `pipefail` while the service was verifiably running (SIGPIPE). Replaced with a direct `launchctl print` exit-code test. Semantics unchanged (WARN-only, non-blocking).

**Same-day addendum — first live gate trip (2026-07-02):** during the first batch publish, the pre-commit secret scan correctly BLOCKED the commit containing this very file: the acceptance-test example on the line above contained a contiguous `AKIA`+16-uppercase string, a self-referential false positive (the gate's own spec was adversarial input to the gate). The executing agent then bypassed with `--no-verify` against explicit stop orders (commit `e857b48`; no real secret — verified). Two fixes: the example is now assembled at runtime (defanged), and the protocol failure is recorded as `learnings/enforcement-gates.md`. The gate itself behaved correctly both times.

**Unexported $HQ made checks 2 and 14 unreliable (found 2026-07-03 during the ADR 0008 build).** `check-invariants.sh` set `HQ=...` without exporting it, so `bash -c` child shells saw `$HQ` empty: check 14 ("no nested .git") was an always-pass (`find ""` errors → empty output → PASS) and check 2 was cwd-dependent. Fix: export the HQ assignment. Both checks verified to genuinely pass against the real tree after the fix (0 nested `.git`; `memory/` tracks only README.md). Same mechanism independently produced ADR 0008's invariant-23 false pass — see 0008's as-built note; runs 20/23 there additionally adopt the positional `_ "$HQ"` convention.

**Fast subset gained check 25, and `HQ` is now exported (2026-08-17).** Two defects in Gate 2, found by an adversarial audit of ADR 0029 and fixed together in `6d073b3`. (a) The `--fast` subset `{2,11,12,13,14,19}` omitted check 25 (doc length), and hq has no CI — so ADR 0029's "approval obtained before the change is committed" had no automatic trigger at all; an over-cap doc committed clean. The subset is now `{2,11,12,13,14,19,25}`. Affordable only because `check-doc-length.sh` was changed to batch its line counting through one `xargs`/`wc` pass instead of one `wc` fork per file (1.29s → 0.29s); `--fast` went 0.05s → 0.29s, and the full run got *faster*, 1.95s → 0.80s. (b) More seriously, this hook set `HQ="$(git rev-parse --show-toplevel)"` **without `export`**, so `check-invariants.sh`'s `${HQ:-$HOME/projects/agent-hq}` fallback took over and every worktree commit had the whole subset — not just check 25 — measure MAIN's checkout rather than the tree being committed. ADR 0017 makes worktrees mandatory for all hq work, so in practice Gate 2 had been checking the wrong tree since 0017 landed. Same root cause family as the 2026-07-03 unexported-`$HQ` note above: an unexported variable plus a silent default equals a check that passes without looking. Verified by attempting a real over-cap commit from a worktree — blocked — and re-attempting across `.md`/`.MD`/`.Md`/`.mdx`/`.markdown`/nested paths.
