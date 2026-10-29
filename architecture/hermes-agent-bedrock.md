# hermes-agent — design record, part 4: Extension (2026-10-29), running Hermes on AWS Bedrock

Companion to `architecture/hermes-agent.md` (governing status header applies); pointer added there
(Companions line). Holds §18 part 1 (Fixes 1-4 and the interim Net result), the consolidated record
of everything it took to run Hermes on AWS Bedrock instead of its documented Anthropic-OAuth setup.
Split out as its own file rather than growing `hermes-agent.md` (already 262 lines) further — same
precedent as `hermes-agent-memory.md`, `hermes-agent-ops.md` and `claude-profile-02.md`/`-03.md`.
Fixes 5 and 6 (later sessions, closing the daemon's live AWS-credential path) continue in
`hermes-agent-bedrock-2.md` — same §18, same precedent, split again once this file neared the
200-line cap.

## 18. Extension (2026-10-29): Hermes on AWS Bedrock — consolidated record, part 1

**Status: session record, not a Proposed line pending ratification** except where a specific fix
below is itself flagged as needing one (none did; see Fix 4). Covers Fixes 1-4, in order, from the
first session; continues in `hermes-agent-bedrock-2.md` (Fixes 5-6).

### The original problem

`tools/hermes/setup/INSTALL.md` §1 documents one path only: an Anthropic OAuth token in a `cprof`
profile (`hermes setup-token`). Its own prerequisites line states plainly: "The Bedrock backend is
supported by Hermes but is not part of this setup and is unmeasured." Running Hermes on Bedrock
instead of OAuth therefore required real adaptation of agent-hq's own wrapper scripts, not just a
config flip — `hermes-up`/`hermes-gw` fail-closed on exactly the OAuth-token precondition that
Bedrock doesn't use.

### Fix 1 — bedrock-aware credential branch (commit `78f80c0`)

`hermes-gw` (LaunchAgent entry) and `hermes-up` (both launch paths) hardcoded a TOKFILE/OAuth-token
check with no Bedrock equivalent. Added a `model.provider`-aware branch, read-only from
`config.yaml`, that — for `provider: bedrock` only — skips the OAuth/TOKFILE check and instead
requires `bedrock.region` to be set (AWS credential resolution itself is left to the AWS SDK's own
chain). Any other value (`anthropic`, unset, absent, unparseable) falls straight through unchanged
to the original OAuth path. `hermes-up` carries its own copy of the detection (§6) because it is also
invoked directly in chat mode, without going through `hermes-gw`.

### Fix 2 — re-pin forward instead of rolling back (commit `cec9361`)

The installed clone at `~/claude-profiles/hermes/hermes-agent` had drifted 14 days past its
`908e4a4` pin through normal operation. Owner decision: accept the newer commit
(`bf0203a794a07aac3ff764972ab9087baa4e4f4e`) as the new pin rather than reset the clone backward.
Full design record already lives at §17 above (what changed, why, the two-separate-things note
about the clone's then-uncommitted patch) — not repeated here.

### Fix 3 — `UV_NATIVE_TLS=1`, no pinned-tree edit (commit `f420c87`)

Installing dependencies at all required working around this machine's corporate TLS-inspecting
proxy: `pm install`/`uv sync` failed with `UnknownIssuer` because uv's bundled webpki-roots don't
trust the proxy's re-signed certs. The first attempt patched this in-tree (`pm/index_config.py`,
adding `UV_SYSTEM_CERTS` to `FORWARDED_UV_SETTINGS`) — but that left the clone's `git status`
dirty, which is exactly what `hermes-up`'s own `code dir dirty` check exists to catch, so the
gateway refused to start. The actual fix needed zero pinned-tree changes: `UV_NATIVE_TLS` (the
deprecated alias of `UV_SYSTEM_CERTS`) was *already* present in the pinned commit's own
`FORWARDED_UV_SETTINGS` allowlist, and this machine's macOS System keychain already trusts the
corporate root CA — so exporting `UV_NATIVE_TLS=1` in `hermes-up` itself, scoped only to its own
exec'd process tree, was sufficient. The in-tree patch was reverted clean (`git status --porcelain`
empty, confirmed again this session).

### Fix 4 — `GW_PY` interpreter-version drift (this commit)

`GW_PY` in `hermes-up` is a path-selector only — `[[ -x "$GW_PY" ]]` is a plain existence/executable
check, not a hash or checksum of the interpreter — naming the installed Python toolchain directory
the gateway-mode config-check script runs under. It had drifted: hardcoded to
`python-3.14.7+20260901-darwin-arm64`, while the actually-installed toolchain (confirmed via the
real launcher's own exec line, `hermes-agent/.hermes/bin/hermes:2`) is
`python-3.14.9+20261021-darwin-arm64` — an upstream update since `GW_PY` was last written. Gateway
mode refused with `code-dir interpreter missing`.

**Governance check (INSTALL.md §8 vs §9):** unlike `PIN`, which §8 explicitly gates — "Moving the
pin is a design change: edit `PIN` in `hermes-up` through an agent-hq design record" — `GW_PY` sits
in §9's "Unmeasured on a new machine" list, which states plainly: "Changing the constant is a change
to `hermes-up`," with no design-record requirement. No design record was written for this specific
edit; this section documents the fix as part of the session's consolidated history, not as
ratification. `architecture/hermes-agent*.md` has no other mention of `GW_PY`.

**What changed:** `GW_PY` bumped to `python-3.14.9+20261021-darwin-arm64` in `tools/hermes/setup/hermes-up`
(repo) and the installed `~/claude-profiles/hermes/bin/hermes-up` (mode 555). `tools/hermes/test_hermes-setup.sh`'s
fixture (two hardcoded path occurrences) synced to match — fixture-only, no behavior change; full
suite 101/101 passing (same count as after Fix 3; this change touched no test cases, only paths).

**Found while verifying, fixed alongside it (same category as `GW_PY` — path config, not design):**
INSTALL.md §9 itself notes the bundled Python dir is a constant "in `hermes-up` (`GW_PY`) *and* in
the plist `PATH`" — the real installed LaunchAgent plist
(`~/Library/LaunchAgents/local.Xavier.Thomas.hermes-up.plist`) still carried the stale
`python-3.14.7...` string in its `PATH`; bumped it too (`plutil -lint`: OK), and the repo's
`hermes-up.plist.example` template, so a future re-install doesn't reintroduce the drift. Also found:
the installed `~/claude-profiles/hermes/bin/hermes-up` had never actually received Fix 3
(`UV_NATIVE_TLS=1`) — it predated that commit. Re-installed the full current template with
`install -m 555` (the `cp`-onto-mode-555 problem INSTALL.md §8 already documents); the installed
copy now diffs clean against the repo template.

**A stray ungated process, found and stopped, not a `hermes-up` bug:** after the plist/`GW_PY` fix,
the launchd job still couldn't bind port 8642 — Hermes's own CLI-level "one gateway per host" guard
reported an existing host gateway already serving profile `default` on PID 6578. That process was a
raw `hermes_cli.main --profile default gateway run --idle-exit` left running from the earlier
one-shot CLI/chat smoke test this session, started outside the fail-closed `hermes-up`/`hermes-gw`
wrapper entirely — exactly the unsupervised start the wrapper exists to prevent. Each launchd respawn
attempt was quietly checking in with it (resetting its idle timer) and exiting 75, a low-grade
respawn loop. Terminated it (`kill 6578`, clean exit, port freed) so the supervised launchd process
could take the port; this is process cleanup of this session's own residue, not a config or security
change.

### Net result

The launchd-managed, fail-closed gateway (`local.Xavier.Thomas.hermes-up` → `hermes-gw` →
`hermes-up gateway run` → `exec hermes-agent/hermes gateway run`) is confirmed **running and
HTTP-reachable**: `state = running`, PID 36853, stable (no new respawns) for the verification
window, listening on `127.0.0.1:8642`, confirmed independently via `tools/port-check.sh 8642`
(`RESULT: TAKEN (registry and lsof agree)`). A live `curl` to `/v1/chat/completions` returned HTTP
200 with a correctly-shaped OpenAI-compatible JSON body. Every fix above lives in agent-hq's own
wrapper scripts (`hermes-up`, `hermes-gw`, its plist) or this design record — **zero unauthorized
modifications to Hermes's own pinned upstream source tree** (`git status --porcelain` on the pinned
clone is empty).

**Not yet fully working end-to-end:** the HTTP 200 response's body was itself a Hermes-level error —
`"could not resolve credentials from session"` — because the launchd job's environment carries no
`AWS_PROFILE`/`AWS_REGION` (only `HERMES_HOME`, `PATH`, `HOME` are set in the plist), and this
account's SSO session token for this identity (`digital-foundations-nonprod`,
`d-9067da96c3.awsapps.com`) had separately already expired (~4h before this check) — it needs an
interactive browser re-login (`aws sso login`) that an unattended daemon cannot perform itself. The
one-shot CLI/chat smoke test earlier this session succeeded because it ran inside an interactive
shell carrying a then-valid `AWS_PROFILE`/SSO session; the persistent daemon has neither. Deciding
how to scope AWS credential delivery into an always-on background process (which `AWS_PROFILE`,
whether to accept SSO's periodic-reauth requirement or move to another credential source) is a
security-relevant, owner-level call — not made here. **Flagged for the owner, not fixed** at the
time this paragraph was written; see Fix 5 below for the plist half of the fix. The SSO-refresh
half is, by deliberate design, still not automated.

**First-verified note:** this is the first time agent-hq's tooling has gotten the Hermes gateway
process itself genuinely running and HTTP-reachable on AWS Bedrock, closing the "unmeasured" gap
INSTALL.md §1 flags for the Bedrock backend — with the one caveat above still open on the live
AWS-credential path for the daemon specifically (CLI/chat mode's Bedrock path was already clean).
Continued in `hermes-agent-bedrock-2.md`: Fix 5 closes the plist half of that caveat, and Fix 6
closes the remaining daemon-only bug that was still blocking every live request.
