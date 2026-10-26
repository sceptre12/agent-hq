# 0008 (part 2) — container execution lane

Part 2 of [ADR 0008](0008-container-execution-lane.md); context, decision, rejected options and reasoning are in part 1.

## Implementation spec (build verbatim — no design judgment required)

Target agent: **Sonnet** authors the Dockerfile + `hqx-run.sh` + entrypoint (exactness matters,
moderate surface); **Haiku** can run the one-time build/install and the acceptance tests; a
**separate** instance verifies (never the author — global Rule 4). All artifacts live under
`$HOME/projects/agent-hq/tools/container-exec/`. **This ADR builds nothing** — the blocks below
are the executor's source of truth.

**Files to create (at adoption):**

1. `tools/container-exec/Dockerfile`
2. `tools/container-exec/entrypoint.sh`
3. `tools/container-exec/hqx-run.sh`

**`tools/container-exec/Dockerfile`:**

```dockerfile
# hqx-claude — bare Claude Code runner (ADR 0008). No token is ever baked in.
FROM node:22-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates tini \
 && rm -rf /var/lib/apt/lists/*
# Pin to the host Claude Code version for behavioral parity (bump deliberately).
ARG CLAUDE_VERSION=2.1.199
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION}
# Non-root: a dangerous-mode agent must not run as root.
RUN useradd -m -u 1000 agent
COPY entrypoint.sh /usr/local/bin/hqx-entrypoint.sh
RUN chmod +x /usr/local/bin/hqx-entrypoint.sh
USER agent
WORKDIR /work
ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/hqx-entrypoint.sh"]
# NOTE: no ENV/ARG carries CLAUDE_CODE_OAUTH_TOKEN. Invariant 23 enforces this.
```

Build once: `docker build -t hqx-claude:latest tools/container-exec/`.

**`tools/container-exec/entrypoint.sh`** (runs inside the container):

```bash
#!/usr/bin/env bash
# hqx entrypoint (ADR 0008). Bare Claude Code, full-auto, results to /out.
set -uo pipefail
MODE="${HQX_MODE:-clone}"        # clone (default) | rw
MODEL="${HQX_MODEL:-opus}"
SLUG="${HQX_TASK_SLUG:-work}"

if [ "$MODE" = clone ]; then
  git clone --no-hardlinks /src-ro /work
fi
cd /work
BASE="$(git rev-parse HEAD)"
git switch -c "hqx/${SLUG}-$(date +%s)"

# Headless, full-auto. NOT --bare (bare ignores CLAUDE_CODE_OAUTH_TOKEN).
set +e
claude -p "$(cat /task/spec.md)" \
  --dangerously-skip-permissions \
  --model "$MODEL" \
  --output-format stream-json --verbose \
  2>&1 | tee /out/session.stream.jsonl
rc="${PIPESTATUS[0]}"
set -e

# Results-out: inert bundle + diff (no push authority).
git add -A
git -c commit.gpgsign=false commit -m "hqx: ${SLUG} result" || true
if git rev-parse "${BASE}..HEAD" >/dev/null 2>&1 && \
   [ -n "$(git rev-list "${BASE}..HEAD")" ]; then
  git bundle create /out/result.bundle "${BASE}..HEAD"
  git diff "${BASE}..HEAD" > /out/result.diff
else
  : > /out/result.diff   # no commits produced
fi

# Usage-measurement copy-out (D8 blind-spot mitigation).
mkdir -p /out/usage
cp -r "${HOME}/.claude/projects" /out/usage/ 2>/dev/null || true

exit "$rc"
```

**`tools/container-exec/hqx-run.sh`** (runs on the host; the orchestrator calls this):

```bash
#!/usr/bin/env bash
# hqx-run.sh — host runner for the ADR-0008 container execution lane.
# Usage: hqx-run.sh --repo <path> --task <spec.md> --out <dir> [options]
set -uo pipefail

IMAGE="hqx-claude:latest"
MODEL="opus"
MODE="clone"                       # clone | rw
KC_SERVICE="hqx-claude-oauth"      # Keychain service (D2)
KC_ACCOUNT="${USER}"
MAX_CONCURRENT="${HQX_MAX_CONCURRENT:-2}"
REPO="" TASK="" OUT="" NAME=""

die(){ echo "hqx-run: $1" >&2; exit "${2:-2}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="$2"; shift 2;;
    --task)  TASK="$2"; shift 2;;
    --out)   OUT="$2";  shift 2;;
    --image) IMAGE="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --rw)    MODE="rw"; shift;;
    --name)  NAME="$2"; shift 2;;
    -h|--help) echo "Usage: hqx-run.sh --repo <path> --task <spec.md> --out <dir> [--rw] [--image T] [--model M] [--name N]"; exit 0;;
    *) die "unknown arg: $1" 2;;
  esac
done

# --- preflight (exit codes are contractual) ---
[ -n "$REPO" ] && [ -n "$TASK" ] && [ -n "$OUT" ] || die "need --repo, --task, --out" 2
docker version >/dev/null 2>&1 || die "docker unreachable" 3
docker image inspect "$IMAGE" >/dev/null 2>&1 || die "image $IMAGE missing (docker build tools/container-exec/)" 4
TOKEN="$(security find-generic-password -w -s "$KC_SERVICE" -a "$KC_ACCOUNT" 2>/dev/null)" \
  || die "token not in Keychain ($KC_SERVICE). Add: security add-generic-password -U -s $KC_SERVICE -a $KC_ACCOUNT -w" 5
running="$(docker ps -q --filter label=hq.lane=container-exec | wc -l | tr -d ' ')"
[ "$running" -lt "$MAX_CONCURRENT" ] || die "concurrency cap reached ($running >= $MAX_CONCURRENT); shared subscription quota" 6
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $REPO" 7
mkdir -p "$OUT" 2>/dev/null && [ -w "$OUT" ] || die "out dir not writable: $OUT" 7
[ -f "$TASK" ] || die "task spec not found: $TASK" 7

REPO="$(cd "$REPO" && pwd)"; OUT="$(cd "$OUT" && pwd)"; TASK="$(cd "$(dirname "$TASK")" && pwd)/$(basename "$TASK")"
SLUG="$(basename "$REPO" | tr -c 'a-zA-Z0-9_.-' '-')"
NAME="${NAME:-hqx-${SLUG}-$(date +%s)}"

# Token rides the runner's ENV (never the docker argv → invisible to ps).
export CLAUDE_CODE_OAUTH_TOKEN="$TOKEN"; unset TOKEN

# Mount surface: /src-ro (RO source) OR /work (RW), /task (RO spec), /out (writable).
mounts=( --mount "type=bind,src=${TASK},dst=/task/spec.md,readonly"
         --mount "type=bind,src=${OUT},dst=/out" )
if [ "$MODE" = rw ]; then
  mounts+=( --mount "type=bind,src=${REPO},dst=/work" )
else
  mounts+=( --mount "type=bind,src=${REPO},dst=/src-ro,readonly" )
fi

docker run --rm --name "$NAME" \
  --label hq.lane=container-exec --label "hq.repo=${SLUG}" --label "hq.task=$(basename "$TASK" .md)" \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e "HQX_MODE=${MODE}" -e "HQX_MODEL=${MODEL}" -e "HQX_TASK_SLUG=$(basename "$TASK" .md)" \
  "${mounts[@]}" \
  "$IMAGE"
rc=$?

unset CLAUDE_CODE_OAUTH_TOKEN
echo "hqx-run: done (rc=$rc). Results in $OUT (review result.diff, fetch result.bundle, then push from host)." >&2
exit "$rc"
```

**Exit-code contract (host runner):** `0` success · `1` agent/container runtime failure
(propagated) · `2` usage error · `3` docker unreachable · `4` image missing · `5` token not in
Keychain · `6` concurrency cap reached · `7` bad repo/out/task path.

**Pre-commit secret-gate extension (adopt-time edit to `tools/git-hooks/pre-commit`, line (c)).**
Extend the existing alternation to add the Anthropic token family. Replace the current line:

```bash
git diff --cached -U0 | grep -qE '^\+.*(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16})' \
  && block "private-key / AWS-key material in staged diff."
```

with:

```bash
git diff --cached -U0 | grep -qE '^\+.*(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|sk-ant-(oat|ort|api)[0-9]{2}-)' \
  && block "private-key / AWS-key / Anthropic-token material in staged diff."
```

The added subpattern `sk-ant-(oat|ort|api)[0-9]{2}-` is a **prefix** match (high precision — that
prefix does not occur in prose) and, like the `AKIA` regex, **does not match its own text** (the
character after `sk-ant-` in the pattern is `(`, not a family tag), so the hook file itself is
safe to commit. This ADR contains no contiguous literal token for the same reason.

**Keychain setup (one-time, host):**

```bash
claude setup-token                       # prints a 1-year token; copy it
security add-generic-password -U -s hqx-claude-oauth -a "$USER" -w
#   ^ -w is LAST with no value → secure interactive prompt; paste the token there
#     (keeps it out of shell history and argv)
```

Verify readback without logging the full value:
`security find-generic-password -w -s hqx-claude-oauth -a "$USER" | cut -c1-7   # expect the sk-ant- prefix`

**Install (one-time; and after any fresh clone):**

```bash
cd ~/projects/agent-hq
chmod +x tools/container-exec/hqx-run.sh tools/container-exec/entrypoint.sh
docker build -t hqx-claude:latest tools/container-exec/
```

**INVARIANTS additions (adopt-time — add to INVARIANTS.md, then bump the script).**
Append checks 20–23 to INVARIANTS.md in the existing style, and — because
`check-invariants.sh` carries a hardcoded `implemented=19` and a meta count-parity guard
(`defined = grep -cE '^\*\*[0-9]+\.' INVARIANTS.md`) — **bump `implemented=19` → `implemented=23`
and add the four `run …` lines in the same commit**, or count-parity will FAIL. (This is the same
one-owner discipline ADR 0003/0007 established: INVARIANTS.md defines, the script mirrors.)

- **20. No Anthropic token material committed in hq** —
  `! git -C ~/projects/agent-hq grep -qE 'sk-ant-(oat|ort|api)[0-9]{2}-'` → PASS (no tracked file
  contains the token family; this ADR uses only the non-matching regex form).
- **21. Runner script present and executable** —
  `test -x ~/projects/agent-hq/tools/container-exec/hqx-run.sh` → PASS.
- **22. Base Dockerfile present** —
  `test -f ~/projects/agent-hq/tools/container-exec/Dockerfile` → PASS.
- **23. Image build never bakes the token** —
  `! grep -qE 'CLAUDE_CODE_OAUTH_TOKEN' ~/projects/agent-hq/tools/container-exec/Dockerfile` → PASS
  (the token is injected at run, never in an image layer).

Corresponding script lines (fast set unaffected; these run only in the full pass):

```bash
run 20 "no anthropic token in hq" bash -c '! git -C "$HQ" grep -qE "sk-ant-(oat|ort|api)[0-9]{2}-"'
run 21 "hqx-run.sh executable"     test -x "$HQ/tools/container-exec/hqx-run.sh"
run 22 "hqx Dockerfile present"    test -f "$HQ/tools/container-exec/Dockerfile"
run 23 "image never bakes token"   bash -c '! grep -qE "CLAUDE_CODE_OAUTH_TOKEN" "$HQ/tools/container-exec/Dockerfile"'
# and: implemented=23   (was 19)
```

**On adoption (not now — these are the commit-time actions):**

- Create the three files under `tools/container-exec/`; `docker build` the image; store the token
  in Keychain (all above).
- Apply the pre-commit secret-gate extension; append INVARIANTS 20–23; bump `implemented=23`.
- Set this ADR's Status → `accepted`; add the `| 0008 | … | accepted |` row to
  `decisions/README.md` (INVARIANTS check 15 file/row parity — until the row is added, check 15
  reports a mismatch; expected while this ADR is merely PROPOSED on disk).
- Commit (`decision: 0008 accept container execution lane` + `chore: add hqx container runner and
  gates`) and **push** (the only backup — ADR 0006).

## Rollback plan

Fully reversible; nothing durable lands outside hq or the local Docker/Keychain:

- **Stop using the lane instantly:** don't invoke `hqx-run.sh`. It is inert when not called (no
  daemon, no launchd unit, no background service).
- **Remove the image:** `docker rmi hqx-claude:latest` (and `docker ps -aq --filter
  label=hq.lane=container-exec | xargs -r docker rm -f` to sweep any stray containers).
- **Revoke the credential:** invalidate the setup-token in the Anthropic console; delete the
  Keychain item — `security delete-generic-password -s hqx-claude-oauth -a "$USER"`.
- **Remove the tooling:** delete `tools/container-exec/`; revert the pre-commit secret-gate line;
  revert INVARIANTS 20–23 and restore `implemented=19`; set this ADR's Status →
  `superseded by NNNN` or `deprecated` with a one-line why.
- **No external cleanup:** no MCP server, no `~/.claude/settings.json` entry, no host session
  config, no Headroom/wrap change was made → nothing else to unwind, and ADR 0004's cache
  verification is not implicated.

## Acceptance tests (defanged per the ADR 0007 convention)

Run by a **separate** instance (never the author — Rule 4). Trigger strings are assembled at
runtime so this document never contains a contiguous matchable secret (the `enforcement-gates.md`
lesson).

1. **Preflight guards fire with the right exit codes.**
   `tools/container-exec/hqx-run.sh` (no args) → exit 2. With `--repo /not/a/repo …` → exit 7.
   With docker stopped → exit 3. With a bogus `--image` → exit 4. With the Keychain item absent
   → exit 5. With one lane container already running and `HQX_MAX_CONCURRENT=1` → exit 6.
2. **Token never on the docker argv.** While a run is live, `ps -Ao args | grep -c
   CLAUDE_CODE_OAUTH_TOKEN=` → `0` (the value rides the env, not the command line). And
   `docker inspect <name> --format '{{.Config.Cmd}}'` contains no token.
3. **Secret-gate blocks a token paste (defanged).**
   `pre='sk-ant-'; fam='oat01-'; body="$(head -c 40 </dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 40)";`
   `printf 'token=%s%s%s\n' "$pre" "$fam" "$body" > t.txt && git add t.txt && git commit -m t`
   → **blocked** by line (c) (assembled at runtime → this test file never holds a contiguous
   match); then `git rm --cached t.txt && rm t.txt`.
4. **RO default protects the host repo.** In `clone` mode, a task that runs `rm -rf /work/*`
   destroys only the container copy; the host repo at `--repo` is unchanged
   (`git -C <repo> status` clean). Attempting to write under `/src-ro` inside the container fails
   (read-only mount).
5. **Results-out is inert and reviewable.** After a successful run, `/out` contains
   `result.bundle`, `result.diff`, `session.stream.jsonl`, `usage/`. The container performed **no**
   push (`git -C <repo> log` on the host shows no new commits until the human fetches the bundle).
6. **Image carries no token and no dev-mesh drift.**
   `docker image inspect hqx-claude:latest --format '{{range .Config.Env}}{{println .}}{{end}}'`
   shows no `CLAUDE_CODE_OAUTH_TOKEN` and no `REDIS_URL`/`DATABASE_URL`/`TRAEFIK_*`.
7. **Cache-neutrality.** `/context` and `/mcp` on the host are unchanged by using the lane (no
   host `CLAUDE.md`, MCP, or `~/.claude/settings.json` delta) → ADR 0004 verification not
   triggered.
8. **Usage copy-out.** After a run, `/out/usage/projects/**/*.jsonl` exists and
   `ccusage --path /out/usage` parses it (documents, not closes, the blind spot).

## Consequences

- **Easier:** long/build/network-heavy tasks run unattended in full-auto without host permission
  prompts; a rogue `rm -rf` is contained to a disposable container; the credential is Keychain-at-
  rest, off-argv in flight, gate-blocked from commits, and console-revocable; results return as an
  inert bundle the host reviews before pushing; the whole lane is one script + one image with no
  daemon.
- **Harder / accepted trade-offs:** (1) **Open egress** is the exfiltration surface for a bearer
  token — accepted for v1 on a single-user machine with trusted inputs and a revocable inference
  token; the allowlist path is pre-designed for the moment inputs become untrusted. (2) **Usage
  blind spot** — container quota is invisible to host ccusage; mitigated by copy-out, not fully
  closed. (3) **Shared quota** — host + lane draw one subscription pool; the default concurrency
  cap of 2 (user override of the designer's recommended 1) is still conservative but less so, and
  the shared-quota caution stands. (4) An **image build** exists (bounded ADR
  0001 tension) and must be rebuilt when the pinned claude version bumps. (5) `--rw` mode is a
  loaded footgun kept behind an explicit flag.
- **Revisit if:** the lane starts running untrusted specs/repos (→ enable the allowlist firewall);
  quota accounting drift becomes material (→ integrate the copy-out into a host ccusage routine);
  or measured need justifies Headroom-in-container (explicitly out of v1).

## Open questions — RULED (user, 2026-07-03)

1. **v1 network egress policy — RULED: OPEN for v1, ratified as recommended.** Ship **open
   egress** (pragmatic; compensated by an inference-scoped, revocable token on a single-user
   machine); the allowlist firewall (`api.anthropic.com` + repo host) remains the pre-designed
   tightening path. **Ruling: the recommended default stands** — the documented trigger to
   tighten the instant the lane runs untrusted task specs or repos is unchanged and remains in
   force.
2. **Concurrency cap `HQX_MAX_CONCURRENT` — RULED: USER OVERRIDE, default = 2.** One shared
   subscription pool (5h + weekly). The designer recommended **1** as the conservative default
   (host + at most one lane container). **The user overrode this and set the default to 2**
   (host + at most two lane containers). The designer's caution stands regardless of the number
   chosen: host and all lane containers still draw on the **same shared subscription quota
   pool**, so raising the cap raises the risk of exhausting the 5h/weekly pool faster with no
   per-container quota meter visible to the host (see D8). Every occurrence of the concurrency
   default in this ADR's spec blocks and in the built scripts is **2** per this ruling.
3. **`--rw` bind-mount mode — RULED: KEEP, ratified as recommended.** It enables fast in-place
   iteration but lets a dangerous-mode agent delete host files. **Ruling: keep it, gated behind
   the explicit `--rw` flag and human approval per run** (default remains RO-clone).
4. **Token store fallback — RULED: macOS Keychain, ratified as recommended.** Default is a
   Keychain generic password. The `0600` file fallback (**outside every repo**, e.g.
   `~/.config/hqx/token`) remains documented as an acceptable fallback only if Keychain is
   unwanted (plaintext-at-rest trade-off noted), but **the ruled default is Keychain**.

## As-built deviations (2026-07-03)

**1 — UID collision in the base image (build FAIL, deterministic).** The spec'd
`RUN useradd -m -u 1000 agent` fails on `node:22-slim` with `useradd: UID 1000 is not
unique` (rc=4): the base image ships a built-in `node` user already holding UID/GID 1000
with home `/home/node` (verified: `docker run --rm node:22-slim id node` →
`uid=1000(node) gid=1000(node)`). Fix: **reuse that user** — the `useradd` line is dropped
and `USER agent` becomes `USER node`. Semantics unchanged: still non-root, still UID/GID
1000 (UID 1000 was the deliberate bind-mount choice; the name was cosmetic), the
entrypoint's `${HOME}/.claude` usage copy-out is unaffected (`HOME=/home/node`), and
`WORKDIR /work` — declared after `USER node` — is created node-owned and writable under
BuildKit (probe-verified). No edits to entrypoint.sh or hqx-run.sh. Acceptance test 6
gains one assertion: `docker image inspect hqx-claude:latest --format '{{.Config.User}}'`
→ `node`. Rejected: `useradd -o` (duplicate-UID passwd ambiguity), a different UID
(silently changes the deliberate UID-1000 bind-mount assumption), `userdel node` first
(passwd churn for zero gain over reuse).

**2 — Missing in-container git identity (latent, found while ruling on #1).** A fresh
container has no git `user.name`/`user.email`; the entrypoint's safety-net commit
(`git -c commit.gpgsign=false commit … || true`) fails rc=128 ("Please tell me who you
are") and the `|| true` swallows it — every clone-mode run would silently emit an empty
`result.diff` and no bundle, nullifying D4 (probe-verified both ways). Fix,
Dockerfile-only: bake a neutral identity after `USER node` — `git config --global
user.name "hqx"`, `user.email "hqx@container.invalid"` (reserved `.invalid` TLD). This
also covers commits the agent itself makes during the task. Entrypoint unchanged.

**3 — Invariant 23 was a self-referential false positive AND a false pass (two stacked
defects; the enforcement-gates.md pattern again).** (a) The spec'd Dockerfile's final
comment contained the token env var's literal name — the exact string invariant 23 greps
the Dockerfile for; the gate's own spec was adversarial input to the gate (same failure
class as the AKIA incident, ADR 0007 addendum). (b) It went unnoticed because the check
never ran against the real file: `run 23 … bash -c '… "$HQ/…"'` expands `$HQ` in a child
shell where it is unset (check-invariants.sh does not export it), so grep targeted a
nonexistent path and the negation always passed (mechanism verified; `run 1`'s
`_ "$HQ"` positional-arg form was the correct in-script convention and the run-20/23
lines deviated from it). Fixes: the Dockerfile comment is defanged (states the rule
without naming the variable) and runs 20/23 now pass `$HQ` positionally — check 23 fails
when, and only when, the Dockerfile really names the token variable. Also **flagged
upstream, not fixed here (ADR 0007's artifact):** 0007-era checks 2 and 14 use the same
in-child `$HQ` pattern — ck14 ("no nested .git") is currently an always-pass (`find ""`
errors → empty output → PASS) and ck2 is cwd-dependent. Remedy (`export HQ`, or the
positional convention) belongs under ADR 0007's own as-built note. Real-state check at
time of writing: both pass once fixed (0 nested `.git`; `memory/` tracks only README.md).

**4 — Live-fire acceptance completed (2026-07-03).** Full matrix executed against a
throwaway repo: exit-7 and exit-6 (cap=2) contract PASS; token-hygiene PASS (in-flight
argv/inspect sweeps 0 matches, env var present in-container count=1); RO isolation PASS
(28/28 host checksums identical; all /src-ro writes refused at the kernel: "Read-only
file system"); results-out PASS (`git bundle verify` okay, diff exactly the task's
change, no push — inert until a human fetches); usage copy-out PASS (jsonl valid,
failure-tolerant — copies out even on failed runs). Exit-3 (docker-stopped) deliberately
skipped as disruptive to the shared daemon. Two findings: (a) doc drift — current
ccusage has no `--path` flag; invoke as `CLAUDE_CONFIG_DIR=<out>/usage ccusage daily`
(recorded here; spec block left as written). (b) defense-in-depth bonus — Claude Code's
built-in dangerous-rm guard refused `rm -rf /work/*` even under
`--dangerously-skip-permissions`, so Test 4's /work sub-clause is unreachable as
written; the host-protection property is proven by checksums + kernel RO errors
regardless. Credential provisioning cost three iterations (wrong Keychain account from
an orchestrator-paraphrased install command; a leading space; ~9 trailing characters
lost in the original copy) — all external to the lane; see
learnings/credential-provisioning.md.

**5 — Results-in publish flow refinement: fresh host commit, never a bundle merge
(adopted at the first production publish, P2.3, host commit `933b1ed`; used for all
queue publishes since).** D4 as specced has the host fetch and merge `result.bundle`.
In practice the host publishes container output by applying `/out/result.diff` as a
**fresh host commit**; the git bundle is **never fetched or merged**. Reason:
pre-commit hooks fire only on `git commit` — commits arriving via fetch/merge would
land in the host repo without ever passing the blocking gate (ADR 0007), so a merged
bundle would silently bypass the exact enforcement point D4 names as the reason the
host publishes. Re-materializing the work as a fresh host commit makes the gate fire
on the real content. The bundle is retained as provenance only. See
`learnings/enforcement-gates.md` (gate-bypass addendum).

**As-built deviation (2026-10-08, task-pipeline U1, R-l).** Pin set to the host-installed version 2.1.294 on 2026-10-08 (task-pipeline U1, R-l; `--build-arg CLAUDE_VERSION=2.1.294`, Dockerfile default updated to match); host parity re-measured (acceptance tests 2 and 6 re-run; alias table in `plans/task-pipeline/evidence/U1-pin.md`). Evidence: T-20261007-84.
