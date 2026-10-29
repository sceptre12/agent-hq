# hermes-agent — design record, part 5: Extension (2026-10-29) continued, Hermes on AWS Bedrock

Companion to `architecture/hermes-agent.md` (governing status header applies) and to
`architecture/hermes-agent-bedrock.md` (same §18, part 1: the original problem and Fixes 1-4).
Holds §18 part 2: Fix 5 and Fix 6, the two fixes — across two later sessions — that closed the
daemon's live AWS-credential path on the launchd-managed gateway. Split out once part 1 neared the
200-line cap, same precedent as the `hermes-agent-memory.md`/`hermes-agent-ops.md` split off
`hermes-agent.md`.

## 18. Extension (2026-10-29): Hermes on AWS Bedrock — consolidated record, part 2

**Status: session record, not a Proposed line pending ratification.** Picks up where part 1's Net
result left off: the daemon was running and HTTP-reachable, but its live request path still failed
on AWS credentials, for two separate reasons closed here in order.

### Fix 5 — plist carries `AWS_PROFILE`/`AWS_REGION`; SSO refresh stays manual

Closes the plist half of the gap part 1's Net result flagged: the launchd job's
`EnvironmentVariables` dict carried `HERMES_HOME`, `PATH`, and `HOME` only — no AWS identity, so
even a valid SSO session would never reach the daemon's boto3/botocore session. Added
`AWS_PROFILE=digital-foundations-nonprod` and `AWS_REGION=us-east-1` to the dict, in both the repo
template (`tools/hermes/setup/hermes-up.plist.example`) and the real installed plist
(`~/Library/LaunchAgents/local.Xavier.Thomas.hermes-up.plist`), so a future re-install doesn't
reintroduce this gap the same way Fix 4 handled the stale `GW_PY`/`PATH` string. `plutil -lint` on
the installed copy: OK.

Reloaded the LaunchAgent (`launchctl bootout` + `bootstrap`) to pick up the change.
`launchctl print` confirmed `state = running` with a stable PID (no respawn loop), and its own
`environment` block lists `AWS_PROFILE => digital-foundations-nonprod` and
`AWS_REGION => us-east-1` directly — independently reconfirmed against the live process with
`ps eww <pid>`, which showed both vars actually set in the launchd-spawned process's real
environment, not just in the plist source. That is the fix: proven mechanically correct and
independent of whether AWS itself can authenticate at any given moment.

**SSO status at verification time, and why that's a separate axis:** this session's
`aws sts get-caller-identity --profile digital-foundations-nonprod` succeeded — the SSO session
was valid, not expired as it had been ~4h earlier when part 1's Net result was written. SSO
session validity is time-bounded and intermittent by design (that's the whole point of SSO
expiry); it does not retroactively make that paragraph wrong, and it does not make this plist fix
any less necessary — without the env vars present, the daemon would still fail even with a valid
session, since `AWS_PROFILE` wouldn't be selected at all. Whenever the session is expired again
(expected, routine, not a bug), the daemon will fail the same `could not resolve credentials from
session` way until a human runs `aws sso login --profile digital-foundations-nonprod` in an
interactive browser flow. **This is intentional, not an oversight:** a background daemon should not
silently handle its own credential refresh — SSO re-auth is left as a manual, human-initiated step,
consistent with treating credential delivery into an always-on process as a security-relevant
decision rather than something to automate away quietly.

### Fix 6 — plist `PATH` was missing `/opt/homebrew/bin`; daemon credential refresh now works

Fix 5 got `AWS_PROFILE`/`AWS_REGION` into the daemon's environment and left SSO-expiry as the one
remaining, deliberately-manual axis. Testing afterward found a second, unrelated daemon-only bug on
the same credential path: every live request against the launchd-managed gateway failed, even with
a valid SSO session, because the plist's `PATH` — `.../python-3.14.9.../bin:/usr/bin:/bin` — had no
`/opt/homebrew/bin`, and that is where this machine's real `aws` CLI lives (`which aws` →
`/opt/homebrew/bin/aws`). AWS's `credential_process` script
(`~/.aws/creds-scripts/get-creds-digital-foundations-nonprod.sh`) shells out to `aws` to read/refresh
SSO credentials; under launchd's trimmed `PATH` that shell-out hit `aws: command not found`, which
botocore surfaced as a malformed multi-line `CredentialRetrievalError` that broke the HTTP response
outright (`curl` saw a dropped connection, exit 52 — not even a clean error status). Confirmed in
`agent.log` at `00:59:25`, same evening, before this fix: `SSO token expired — launching browser
login... aws: command not found` on the same request shape used to retest below.

**What changed:** added `/opt/homebrew/bin` to the `PATH` value in both the installed plist
(`~/Library/LaunchAgents/local.Xavier.Thomas.hermes-up.plist`) and the repo template
(`tools/hermes/setup/hermes-up.plist.example`), inserted after the pinned Python toolchain dir and
before `/usr/bin:/bin` — matching this account's own interactive-shell `PATH` convention, where
version-managed tool dirs (nvm, rbenv, the pinned Python here) lead, Homebrew sits ahead of the
system dirs, and `/usr/bin:/bin` trail last. New value:
`.../python-3.14.9+20261021-darwin-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin`. `plutil -lint` on the
installed copy: OK.

**Reload and verification:** `launchctl bootout` + `bootstrap` respawned the daemon on a new PID;
`launchctl print` confirmed `state = running`, and `ps eww <pid>` confirmed the live process's real
`PATH` now contains `/opt/homebrew/bin`. Retested the exact live smoke test that had just failed: a
`curl` to `/v1/chat/completions` asking for the single word `OK` returned `HTTP_STATUS:200` with a
correctly-shaped completion body, `"content": "OK"`. `agent.log` confirms this was genuinely
Bedrock-backed, not a stub: `API call #1: model=us.anthropic.claude-sonnet-5-5 provider=bedrock
in=11175 out=4 total=11179 ... id=msg_bdrk_z3onqpxkkipb2g42i6recrv2i27xha7z2m5evffdmdcwmznohdcq` —
token counts match the curl response's own `usage` block exactly, and the `msg_bdrk_` id prefix is
Bedrock's own. No SSO browser login was needed this time: this account's SSO session happened to
still be valid at retest time, so this run exercised (and closed) the PATH bug specifically, not the
separate SSO-expiry axis Fix 5 already declared out of scope for automation. `launchctl print` after
the call still showed `state = running` on the same PID — the daemon survived the request cleanly.

**Net effect:** the daemon's live Bedrock path is now confirmed working end-to-end, for the first
time, with no human step required beyond an already-valid SSO session. The only remaining
human-in-the-loop case is the one Fix 5 already named and left intentional — an expired SSO session
needs `aws sso login --profile digital-foundations-nonprod` in a browser; that is not this bug and is
not newly introduced by it.
