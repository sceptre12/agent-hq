# claude-profile (`cprof`) — design record, part 3: Extension 2026-10-28 (`--auth bedrock` self-heal)

Part 3 of 3 of `architecture/claude-profile.md`; part 1 holds the status header (which governs this file), the
ratified 2026-10-01 design and Extension (2026-10-21) `cprof link`; part 2 (`architecture/claude-profile-02.md`) holds
Extensions 2026-10-26 `--auth bedrock` and 2026-10-27 (dynamic `cprof link` source root; self-contained `profile.env`),
which this extension builds on. Split out of part 2 on 2026-10-28 to keep each part under the 500-line cap (ADR 0029
Clause 3); the text below is unchanged apart from this header.

## Extension (2026-10-28): self-heal `new --auth bedrock` against a broken ambient AWS profile

**Status: owner-approved plan, code and this amendment land together.**
The 2026-10-27 extension made every new bedrock profile self-contained by snapshotting whatever `AWS_PROFILE` was
ambient at creation time. That closed the "no `profile.env` at all" bug, but not a sharper one: the owner's `adx-dev`
AWS profile silently resolves to a sandboxed account (`202533503908`) with an org-level SCP that explicitly denies
all Bedrock actions. Twice, a profile got created while `adx-dev` was ambient, snapshotted faithfully (exactly as
designed), and the breakage was only discovered later via a confusing 403 — both times hand-fixed by editing
`profile.env` to point at the known-working profile `digital-foundations-nonprod`. Owner requirement: `new --auth
bedrock` must work out of the box — no new flag, no new env var to remember to set — by detecting a broken ambient
profile and automatically recovering.

Verified finding shaping this design: every AWS profile on the owner's machine shares one SSO session
(`digital-foundations-nonprod`, in `~/.aws/config`'s `[sso-session digital-foundations-nonprod]`). Two profiles
(`digital-foundations-nonprod`, `adx-dev`) use a custom `credential_process` script that, on any credential-export
failure, unconditionally runs `aws sso login` — a browser popup — with no "is the cached token still fresh"
pre-check; the rest reference `sso_session` directly and fail fast, non-interactively, on an expired token. The
owner has explicitly accepted a browser login prompt occurring for whichever profile ends up actually adopted;
repeated/unnecessary prompts across profiles never asked for should still be minimized where possible, not
eliminated at the cost of not working.

### What changes vs the 2026-10-27 design

- The ambient `AWS_PROFILE` candidate is no longer snapshotted blindly. It is checked against a persistent health
  cache (new file, one line per AWS profile) before being written: a cached `good` verdict is trusted with no live
  call (fast path once a profile has been validated once); a cached `bad` verdict skips straight to a substitute
  search, also with no re-test; no cache entry at all (the normal first-time case) triggers one live
  `aws bedrock list-inference-profiles --profile <candidate> --region <region>` call, bounded by the AWS CLI's own
  `--cli-connect-timeout`/`--cli-read-timeout` plus an outer `timeout`/`gtimeout` wall-clock bound when either is on
  `PATH` (a browser SSO prompt during that call is accepted, never killed by the bound).
- **Classification is the crux of correctness** and is owner-approved, literal-text matching, not exit-code-only:
  `AccessDenied*` + `"explicit deny in a service control policy"` is the one signal that means "permanently broken
  for Bedrock" (`bad`). `ExpiredToken`/`UnauthorizedSSOTokenError`/`"Unable to locate credentials"`, or any other
  failure, means "needs a fresh login or could not be determined either way" (`inconclusive`) — routine, not a
  verdict on the profile, and never cached (an inconclusive probe must not poison the cache). A declined or failed
  login prompt is therefore never mistaken for a denied profile.
- A `bad` verdict triggers a substitute search: the most-recently-checked cached-`good` (profile, region) pair, if
  that profile isn't the candidate itself; else `aws configure list-profiles`, with non-`credential_process`
  profiles tried first (they fail fast with no popup risk if also broken, so trying them costs nothing before
  risking a popup on a `credential_process` candidate), live-validating and caching each until the first `good`.
  Fix-up pass B1: before a candidate is probed, it is checked for a same-named-minus-`-sso` sibling profile also
  present in `aws configure list-profiles` (the structural signal this machine's real `~/.aws/config` actually
  supports for "this is an internal raw SSO profile, not the one meant for direct use" -- see Fix-up pass below);
  if an untried, non-excluded sibling exists, the SIBLING is probed in that candidate's turn instead of the raw
  profile. A `good` result, from either path, is re-verified via a live `aws sts get-caller-identity` before being
  accepted as the final substitute -- a candidate that passes the narrow Bedrock probe but fails identity
  resolution is skipped. A clear message names the substitution and quotes the bad verdict's detail. If every
  candidate is exhausted with no `good` found, `new` falls back to snapshotting the ambient candidate anyway, with
  an unmissable WARN summarizing what was tried.
- Fix-up pass M2: probing, substitution search and `doctor` all resolve a candidate's region the same one way --
  that profile's OWN configured region in `~/.aws/config` (`aws configure get region`, a local read, never a live
  call) if it has one, else this shell's ambient `AWS_REGION`/`AWS_DEFAULT_REGION`, else `us-east-1`. Fix-up pass
  M1: the health cache is keyed by `(profile, region)`, not profile name alone -- a verdict cached under one region
  is never trusted under a different one; a region change for the same profile is a cache miss, forcing a fresh
  probe.
- `cprof doctor` gains the same live-validate-and-cache capability for every bedrock profile's recorded
  `AWS_PROFILE` (after the existing `aws configure list-profiles` pre-check from the 2026-10-27 fix-up pass), so a
  plain `doctor` run also keeps the cache warm for profiles a recent `new` never touched — catching drift (a
  profile that worked yesterday and is SCP-denied today) without waiting for the next profile creation. Like `new`,
  a cache hit (either verdict) is trusted with no re-probe.
- `AWS_REGION`/`AWS_DEFAULT_REGION` and the Anthropic model vars are untouched by any of this — only which
  `AWS_PROFILE` value ends up in `profile.env` can change.

### Components

- `tools/claude-profile/cprof-auth-health.zsh` (new file, sourced by `cprof.zsh`; kept separate from
  `cprof-auth.zsh` purely to keep each file under hq's 300-line file-size guidance, the actually-enforced limit
  per `test_cprof-auth.zsh`'s own `a14` assertion -- fix-up pass M6, earlier text here said 200): the health cache
  file `${CPROF_ROOT:-$HOME/claude-profiles}/.aws-profile-health`, one line per `(profile, region)` pair (fix-up
  pass M1), `profile\tregion\tstatus\tchecked_at\tdetail` (`status`: `good`|`bad`; `checked_at`: UTC
  `%Y%m%dT%H%M%SZ`, the same stamp style as `cprof-link.zsh`'s `link-src`) — plain text, no JSON dependency,
  atomic tmp+mv write, `umask 077`, upserting a `(profile, region)` row in place rather than appending a
  duplicate; both the profile name and the detail are sanitized for tabs/newlines before being written (fix-up
  pass M3 -- the profile name wasn't, originally). Functions: `_cprof_aws_profile_region` (the one region rule,
  M2); `_cprof_aws_health_read`/`_cprof_aws_health_write` (cache I/O, `$reply`-convention reads matching
  `cprof.zsh`'s `_cprof_scalars`); `_cprof_aws_health_lookup` (fix-up pass A1: the one accessor the cache-hit and
  live-probe paths both call, used by `_cprof_aws_heal_profile` here and `_cprof_doctor_bedrock_env` in
  `cprof-auth.zsh`, closing a latent reply-arity drift risk between the two); `_cprof_aws_health_latest_good`;
  `_cprof_aws_is_credential_process` (`aws configure get credential_process --profile <p>`);
  `_cprof_aws_raw_sso_sibling` and `_cprof_aws_verify_identity` (fix-up pass B1, see below); `_cprof_aws_classify`
  (the text-matching rule above, isolated and independently testable); `_cprof_aws_bedrock_probe` (the bounded
  live call; classifies and caches `good`/`bad`, never `inconclusive`); and `_cprof_aws_find_substitute` (the
  search order above, shared by `new` and `doctor`).
- `tools/claude-profile/cprof-auth.zsh`: `_cprof_bedrock_snapshot` now runs the `AWS_PROFILE` candidate through a
  new orchestrator, `_cprof_aws_heal_profile` (cprof-auth-health.zsh), before writing it; `_cprof_doctor_bedrock_env`
  consults the cache via `_cprof_aws_health_lookup` (probing and caching on a miss) for each profile whose
  `AWS_PROFILE` already resolves in `aws configure list-profiles`, using that profile's own resolved region
  (`_cprof_aws_profile_region`, M2) rather than `profile.env`'s stored `AWS_REGION` -- WARNing when the
  cached/just-probed verdict is `bad`.
- `tools/claude-profile/cprof.zsh`: one new `source` line for `cprof-auth-health.zsh`; no change to `_cprof_new`'s
  call sequence (still calls `_cprof_bedrock_snapshot` right after writing `auth` = `bedrock`).
- Fix-up pass M4: four `[[ == / != ]]` comparisons in `cprof-auth-health.zsh` whose right-hand side is a profile
  name (a variable, not a literal pattern) now quote that side (`[[ $pn == "$p" ]]`, not `[[ $pn == $p ]]`) --
  unquoted, zsh treats the right-hand side as a glob pattern, so a profile name containing a glob metacharacter
  could have matched the wrong cached row or the wrong exclude check.

### Interfaces (exact messages)

- Substitution found: `cprof: WARN: ambient AWS_PROFILE '<bad>' is denied for Bedrock (<detail>); substituting
  '<good>' instead -- pass a different AWS_PROFILE before 'cprof new' to override`.
- Nothing found: `cprof: WARN: ambient AWS_PROFILE '<bad>' is denied for Bedrock (<detail>) and no working AWS
  profile was found to substitute; snapshotting '<bad>' anyway -- fix its AWS access, or export a working
  AWS_PROFILE, before 'cprof new <name> --auth bedrock'` (the profile is still created, exit 0 — a healing failure
  is a WARN, never a `new` failure).
- Inconclusive: `cprof: WARN: could not validate AWS profile '<name>' for Bedrock (<detail>); snapshotting it as-is
  -- run 'cprof doctor' to re-check later`.
- `doctor`, per bedrock profile whose cached/probed `AWS_PROFILE` verdict is `bad`: `WARN: <name>'s profile.env
  AWS_PROFILE ('<value>') is cached bad for Bedrock (<detail>); see <root>/.aws-profile-health` (plain `print`, no
  `cprof: ` prefix, matching the other `doctor` rows from the 2026-10-27 extension).

### Non-goals

1. No new flag or env var: healing is always-on for `--auth bedrock`, per the owner's "works out of the box"
   requirement.
2. No automated repair of a *stale cached* verdict beyond re-probing on a cache miss: a `good`/`bad` row is trusted
   until something (a later `new` or `doctor` run for a profile with no entry yet) happens to re-probe it. There is
   no TTL/expiry and no `cprof` subcommand to force-invalidate a row; deleting `.aws-profile-health` by hand clears
   it.
3. No change to oauth profiles, to the 2026-10-26 `_cprof_auth_apply` pass-through semantics, or to the tiered
   render's region source.
4. No attempt to suppress or pre-empt a `credential_process` profile's own `aws sso login` retry: a browser prompt
   during the probe is accepted exactly as the owner ruled, never raced or killed by the outer timeout bound.

### Verification

`tools/claude-profile/test_cprof-auth.zsh`: hermetic cases (own isolated `CPROF_ROOT`, a mock `aws` on its own
`PATH` entry answering `configure get credential_process`/`configure list-profiles`/`bedrock
list-inference-profiles` purely from profile-name prefix and env vars, with a call log asserting both which
profiles were live-probed and in what order) cover: a cached-`good` candidate snapshotting unchanged with no live
call; a cached-`bad` candidate with a cached-`good` already available substituting straight from the cache, also
with no live call; a cached-`bad` candidate with nothing cached `good` triggering a live search that tries
non-`credential_process` profiles first and stops at the first `good`, caching every candidate it actually tried;
every candidate exhausted with no `good` found falling back to the broken ambient profile with the unmissable WARN;
an unknown candidate validated live and cached on success; `_cprof_aws_classify` in isolation (`AccessDenied` +
SCP-deny text is `bad`; `ExpiredToken`/`UnauthorizedSSOTokenError`/no-credentials/anything else is `inconclusive`;
exit 0 is `good`); an inconclusive probe writing no cache row; and `cprof doctor` live-validating and caching a
bedrock profile's `AWS_PROFILE` that `cprof new` never touched, then trusting that cache (no re-probe) on a later
run. The full existing suite (`test_cprof.zsh`, `test_cprof-link.zsh`, `test_cprof-checks.zsh`,
`test_cprof-auth.zsh`) passes unchanged.

Fix-up pass additions: `h2c` proves a cached-`good` row under a different region is a cache miss, forcing a fresh
live probe instead of being trusted (M1). `h8`/`h8b`/`h8c` are shaped directly like the real `~/.aws/config` (an
excluded ambient candidate, a raw `-sso` profile that sorts first, and its `credential_process` sibling) and prove
the substitute search returns the sibling, that the raw profile is never itself live-probed (only its sibling is,
via `STUBLOG`), and that a matching `sso_account_id` produces no spurious mismatch WARN -- this is B1's hermetic
proof. `h8d` proves a candidate that fails live identity verification is skipped, not accepted, even though its
Bedrock probe alone said `good`.

A real end-to-end check against the owner's actual AWS setup (browser login explicitly authorized, though none was
needed -- the cached SSO token was still usable) forced `AWS_PROFILE=adx-dev` ambient and ran `cprof new --auth
bedrock` for a scratch profile: `adx-dev` was correctly classified `bad` (the real response was `AccessDeniedException
... User: arn:...assumed-role/AWSReservedSSO_SGWS-SBX-PowerUser_.../Xavier.Thomas@sgws.com is not authorized to
perform: bedrock:ListInferenceProfiles ... with an explicit deny in a service control policy: arn:...`, account
`202533503908`; the classifier matched on the full response, the 220-char-truncated cached detail cuts off before
the "explicit deny" phrase itself) and auto-substituted with `digital-foundations-nonprod-sso` (account
`194872823696` -- the first non-`credential_process` profile in `aws configure list-profiles` order that validated
good; this was the B1 bug a 7-agent pr-review panel later found Blocking -- see Fix-up pass below), with
`.aws-profile-health` afterward showing both verdicts. A second scratch profile created with
`digital-foundations-nonprod-sso` already ambient and cached `good` confirmed the no-op path: `aws` was removed
from `PATH` entirely for that run, and it still succeeded unchanged, proving no live call was made;
`.aws-profile-health`'s `checked_at` for that row was unchanged afterward. Both scratch profiles were removed
afterward; the two real cache rows were deliberately left in place at the time (accurate, useful information, not
test debris) -- the Fix-up pass below re-ran the same real check after the fix and records what changed.

### Fix-up pass (pr-review panel, 2026-10-28): raw-SSO substitution was not a lucky/unlucky coincidence

A 7-agent local pr-review panel (never posted to GitHub) reviewed this extension before merge and returned NOT
READY: 1 Blocking (unanimous), 7 Medium, 4 Advisory, 1 Process/Meta. All were applied in one fix-up commit.

**B1 (Blocking):** the real end-to-end run above wasn't a coincidence of alphabetical sort -- it was close to
deterministic. `_cprof_aws_find_substitute` had no concept of a primary profile vs. an internal raw SSO profile not
meant for direct use, and tried non-`credential_process` profiles before `credential_process` ones purely to avoid
popups; since `digital-foundations-nonprod` (the intended profile) is itself `credential_process`-fronted and
`digital-foundations-nonprod-sso` (its raw, internal-only backing profile, commented "Do NOT use this profile
directly" in `~/.aws/config`) is not, the raw profile was always going to be tried -- and accepted -- first. The
panel rejected a louder warning as sufficient; the fix needed to be structural. Reading the real `~/.aws/config`
confirmed config SHAPE alone cannot distinguish the two: a raw-internal profile (`digital-foundations-nonprod-sso`,
`adx-dev-sso`) and a normal, directly-usable `sso_session` profile (`digital-proofweb-sandbox`, and every
"Additional accounts" profile) have the IDENTICAL field set (`sso_session`, `sso_account_id`, `sso_role_name`,
`region`, `output`) -- there is no shape signal to key off, contrary to one of the panel's two hypotheses. The
signal this file's actual content does support: every raw-internal profile here is named `<base>-sso` with a
sibling profile literally named `<base>` also present in `aws configure list-profiles` (its credential_process
front door). `_cprof_aws_raw_sso_sibling` (cprof-auth-health.zsh) checks exactly that -- name ends `-sso` AND a
distinct `<base>` exists in the profile list -- and `_cprof_aws_find_substitute` now probes that sibling in the
raw profile's turn in the search order instead of the raw profile itself, so the sibling gets first crack at the
slot the raw profile used to win by sorting earlier. This alone is still only a naming-convention heuristic, so it
is paired with a second, independent check per the panel's requirement: `_cprof_aws_verify_identity` runs a live
`aws sts get-caller-identity` on any candidate the Bedrock probe calls `good` before it is accepted as the final
substitute -- a candidate that passes the narrow Bedrock check but fails identity resolution is skipped, not
returned. When the winner came from a sibling swap, the raw profile's own configured `sso_account_id` (a local
config read, not a live call) is compared against the sibling's live-resolved account purely as an informational
WARN if they disagree -- not a hard gate, since there is no general "expected" account id to gate on for an
arbitrary substitute search; this machine's case happens to have one only because the raw profile's own config
carries it. Verified live (not just in the hermetic mock suite -- see Verification below): re-running the exact
scenario above now substitutes `digital-foundations-nonprod`, not `-sso`.

**M1 (region-keyed cache)** and **M2 (one region rule)**: see the `What changes`/`Components` sections above --
the cache key is now `(profile, region)`, and probe/substitution-search/`doctor` all resolve a candidate's region
the same one way (`_cprof_aws_profile_region`).

**M3:** `_cprof_aws_health_write`'s profile-name parameter is now sanitized for tabs/newlines, matching the
existing `detail` sanitization.

**M4:** the four unquoted `[[ == / != ]]` profile-name comparisons in `cprof-auth-health.zsh` now quote the
right-hand side (see `Components` above) -- unquoted, it is a zsh glob match, not a literal string comparison.

**M5:** the `Verified finding` paragraph above already correctly states `digital-foundations-nonprod` IS
`credential_process`-fronted; the error was confined to the old `Known gap` paragraph this Fix-up pass replaces,
which had said the opposite ("Both are non-credential_process") -- corrected by B1's description above, which
states the real relationship and why it made the bad substitution close to deterministic rather than a coincidence.

**M6:** "hq's 300-line file-size guidance" above was previously "200-line" in this doc and in
`cprof-auth-health.zsh`'s own header comment -- corrected to 300, the limit `test_cprof-auth.zsh`'s `a14` assertion
actually enforces for every `cprof*.zsh` file.

**M7:** `tools/claude-profile/README.md` and `tools/onboarding.md` now describe the B1 fix (sibling preference +
live identity verification), not just the always-on substitution feature with no caveat, and no longer claim a
substitute profile has the same account/access as the original ambient one beyond what was actually verified
(Bedrock-list-level reachability, not full IAM parity).

**A1:** `_cprof_aws_health_lookup` is the one accessor both the cache-hit and live-probe paths now call (see
`Components` above), closing the latent reply-arity drift between `_cprof_aws_heal_profile` and
`_cprof_doctor_bedrock_env`.

**A2 (doc-only):** the outer wall-clock bound on the live probe only applies when `timeout`/`gtimeout` is on
PATH -- absent on a bare macOS install by default. Without either, an unbounded hang is theoretically possible;
install one (`brew install coreutils` for `gtimeout`) to get the bound. Noted in `cprof-auth-health.zsh`'s
`_cprof_aws_bedrock_probe` comment; no code change (panel: a doc callout is sufficient).

**A3 (doc-only):** `.aws-profile-health` stores up to 220 chars of raw AWS CLI error text in plaintext
indefinitely -- can include ARNs, SSO session names, account IDs, possibly an email address. Mitigated by
`umask 077` and no network transmission; this file should be excluded from any future log bundling or sharing.

**A4:** not changed -- the hardcoded 180s Bedrock-probe timeout may be tight for a slow SSO+MFA flow; worst case is
a graceful `inconclusive` classification, not a crash. The panel accepted leaving this as-is.

**Process/Meta:** the original commit message claimed "13 new hermetic test cases"; the diff actually added 11
distinct `ok()` assertions (h1, h2, h3, h3b, h4, h5, h6, h6b, h7, h7b, h7c). That commit is not amended (this Fix-up
pass is a new commit on top); no other doc or comment text in this extension repeated the miscount.
