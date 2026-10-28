# cprof AWS-profile health cache + live Bedrock probe + substitute search. Sourced by cprof.zsh.
# Design: architecture/claude-profile-03.md, Extension 2026-10-28 ("self-heal `new --auth bedrock`
# against a broken ambient AWS profile"). Used by `_cprof_bedrock_snapshot` (cprof-auth.zsh, at
# `cprof new ... --auth bedrock`) and `_cprof_doctor_bedrock_env` (both cprof-auth.zsh -- the latter
# called from cprof-checks.zsh's `_cprof_doctor`) so `cprof new` and `cprof doctor` keep the same
# cache warm with the same classification rules. Split into its own file (not cprof-auth.zsh)
# purely to keep each file under hq's 300-line guidance (test_cprof-auth.zsh's a14 is the actually
# enforced check; fix-up pass M6 -- earlier doc/comment text here said 200, which was never the
# real limit).
#
# Cache file: `${CPROF_ROOT:-$HOME/claude-profiles}/.aws-profile-health`, one line per (AWS profile,
# region) pair -- fix-up pass M1: a verdict is only ever valid for the region it was actually probed
# in, so the key is the pair, not the profile name alone; a row cached under one region must never be
# trusted under a different one -- tab-separated `profile\tregion\tstatus\tchecked_at\tdetail`
# (status: good|bad; checked_at: UTC `date -u +%Y%m%dT%H%M%SZ`, same stamp style as
# cprof-link.zsh's backup dirs). Mirrors link-src's persistence style: plain text, no JSON
# dependency, atomic tmp+mv write, umask 077. A write upserts in place -- the file never grows a
# second row for the same (profile, region) pair. A pre-M1 row (the old 4-field
# `profile\tstatus\tchecked_at\tdetail` shape) is harmless, not a crash risk: read into this file's
# 5-variable loop it misaligns (the old status lands in the region column, the old checked_at in the
# status column, ...) so it can never literally match a real profile+region lookup or a literal
# 'good'/'bad' status comparison -- it is silently orphaned (ignored, not deleted) the first time
# anything here runs after this change, which is the correct outcome for a stale, region-naive cache
# entry, not a migration bug.

_cprof_aws_health_file() { print -r -- "$(_cprof_root)/.aws-profile-health" }

# _cprof_aws_profile_region <profile>: fix-up pass M2 -- probe, substitute search and doctor used to
# each pick region a different way (one shell's ambient AWS_REGION/AWS_DEFAULT_REGION, or a cprof
# profile's own stored profile.env AWS_REGION snapshotted from a possibly-unrelated past shell). One
# rule now, used everywhere a specific AWS profile is probed or cached: that profile's OWN configured
# region in ~/.aws/config (`aws configure get region`, a local config read, never a live/network
# call) if it has one; else this shell's ambient AWS_REGION/AWS_DEFAULT_REGION (_cprof_aws_region,
# cprof-auth.zsh); else `us-east-1`.
_cprof_aws_profile_region() {
  local p=$1 r=
  (( ${+commands[aws]} )) && r=$(aws configure get region --profile "$p" 2>/dev/null)
  [[ -n $r ]] || r=$(_cprof_aws_region)
  [[ -n $r ]] || r=us-east-1
  print -r -- "$r"
}

# _cprof_aws_health_read <profile> <region>: sets $reply=(status checked_at detail) for the
# (profile, region) row (mirrors cprof.zsh's `_cprof_scalars` $reply convention). Returns 1,
# reply=(), if there is none -- callers treat that as "unknown", not "bad".
_cprof_aws_health_read() {
  local p=$1 rg=$2 f=$(_cprof_aws_health_file) pn prg pst pts pdet
  reply=()
  [[ -r $f ]] || return 1
  while IFS=$'\t' read -r pn prg pst pts pdet; do
    [[ $pn == "$p" && $prg == "$rg" ]] && reply=("$pst" "$pts" "$pdet")
  done < "$f"
  (( $#reply )) || return 1
}

# _cprof_aws_health_write <profile> <region> <good|bad> <detail>: upserts the (profile, region)
# row, atomic tmp+mv, umask 077. Never called with 'inconclusive' -- an inconclusive probe (needs a
# fresh login, aws missing, network error) is not a verdict on the profile and must not poison the
# cache. Fix-up pass M3: <profile> is sanitized for tabs/newlines exactly like <detail> already was
# -- a profile name can come from ambient AWS_PROFILE or 'aws configure list-profiles', neither
# trusted input, and an unsanitized name could otherwise corrupt the row shape.
_cprof_aws_health_write() {
  local p=$1 rg=$2 st=$3 det=$4 f=$(_cprof_aws_health_file) root=$(_cprof_root)
  local ts pn prg pst pts pdet out= found=0
  [[ $st == (good|bad) ]] || { _cprof_err "internal: bad health status '$st'"; return 1; }
  p=${p//$'\t'/ }; p=${p//$'\n'/ }
  rg=${rg//$'\t'/ }; rg=${rg//$'\n'/ }
  det=${det//$'\t'/ }; det=${det//$'\n'/ }
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  ( umask 077; mkdir -p -- "$root" ) || return 1
  if [[ -r $f ]]; then
    while IFS=$'\t' read -r pn prg pst pts pdet; do
      [[ -z $pn ]] && continue
      if [[ $pn == "$p" && $prg == "$rg" ]]; then out+="$p"$'\t'"$rg"$'\t'"$st"$'\t'"$ts"$'\t'"$det"$'\n'; found=1
      else out+="$pn"$'\t'"$prg"$'\t'"$pst"$'\t'"$pts"$'\t'"$pdet"$'\n'; fi
    done < "$f"
  fi
  (( found )) || out+="$p"$'\t'"$rg"$'\t'"$st"$'\t'"$ts"$'\t'"$det"$'\n'
  ( umask 077; print -rn -- "$out" > "$f.tmp.$$" && mv -f -- "$f.tmp.$$" "$f" ) \
    || { rm -f -- "$f.tmp.$$"; _cprof_err "cannot write $f"; return 1; }
}

# _cprof_aws_health_lookup <profile> <region>: fix-up pass A1 -- the one accessor both the cache-hit
# and live-probe paths call, always setting $reply=(status detail), the same 2-element shape either
# way. Before this, _cprof_aws_heal_profile and _cprof_doctor_bedrock_env each duplicated this
# if/else by hand with different reply arity (a cache hit is 3 elements, status/checked_at/detail; a
# live probe's own reply is already 2, status/detail) -- harmless today but a latent drift risk the
# panel flagged (A1); both callers now share this one function instead.
_cprof_aws_health_lookup() {
  local p=$1 rg=$2
  if _cprof_aws_health_read "$p" "$rg"; then
    reply=("$reply[1]" "$reply[3]")
  else
    _cprof_aws_bedrock_probe "$p" "$rg"
  fi
}

# _cprof_aws_health_latest_good: sets $reply=(profile region) for the most-recently-checked 'good'
# row (checked_at compares lexically fine: fixed-width %Y%m%dT%H%M%SZ), or reply=() + returns 1 if
# none. Returns both halves of the key together (fix-up pass M1) -- a caller must never reuse a
# cached-good profile name under some other region than the one it was actually validated for.
_cprof_aws_health_latest_good() {
  local f=$(_cprof_aws_health_file) pn prg pst pts pdet bestn= bestr= bestts=
  reply=()
  [[ -r $f ]] || return 1
  while IFS=$'\t' read -r pn prg pst pts pdet; do
    [[ -z $pn || $pst != good ]] && continue
    [[ -z $bestts || $pts > $bestts ]] && { bestn=$pn; bestr=$prg; bestts=$pts }
  done < "$f"
  [[ -n $bestn ]] || return 1
  reply=("$bestn" "$bestr")
}

# _cprof_aws_is_credential_process <profile>: true iff <profile> uses credential_process (per this
# extension's verified finding, such a profile auto-runs `aws sso login` -- a browser popup -- on
# any credential-export failure; an sso_session profile instead fails fast, non-interactively). Uses
# `aws configure get`, which already resolves a profile's config; no hand-rolled ~/.aws/config parse.
_cprof_aws_is_credential_process() { [[ -n $(aws configure get credential_process --profile "$1" 2>/dev/null) ]] }

# _cprof_aws_raw_sso_sibling <profile> <" "-padded profile-list>: fix-up pass B1. Verified live
# against this machine's real ~/.aws/config: a raw SSO session profile meant ONLY for internal use by
# a credential_process script (e.g. `digital-foundations-nonprod-sso`, commented "Do NOT use this
# profile directly" in the file) is NOT structurally distinguishable from a normal, directly-usable
# sso_session profile (e.g. `digital-proofweb-sandbox`) by config shape alone -- both have the exact
# same fields (sso_session, sso_account_id, sso_role_name, region, output); there is no shape signal
# to key off. The one real signal this file's actual content supports is naming + pairing: every
# raw-internal profile on this machine is named `<base>-sso` and has a sibling profile literally
# named `<base>` (its credential_process-fronted front door) also present in
# `aws configure list-profiles`. <profile> must end '-sso' AND <base> must be a distinct profile in
# <profile-list> to count; prints <base> and returns 0, else prints nothing and returns 1 -- a
# profile that merely happens to end in '-sso' with no such sibling is left alone.
_cprof_aws_raw_sso_sibling() {
  local p=$1 all=$2 base
  [[ $p == *-sso ]] || return 1
  base=${p%-sso}
  [[ -n $base && $base != "$p" && $all == *" $base "* ]] || return 1
  print -r -- "$base"
}

# _cprof_aws_verify_identity <profile>: live `aws sts get-caller-identity`; prints the resolved
# account id on success, nothing (return 1) on failure or if aws is absent. Fix-up pass B1's second
# half: a candidate that passes the narrow `bedrock:ListInferenceProfiles` probe is not accepted as
# the final substitute until this independent call also succeeds.
_cprof_aws_verify_identity() {
  (( ${+commands[aws]} )) || return 1
  aws sts get-caller-identity --profile "$1" --query Account --output text 2>/dev/null
}

# _cprof_aws_classify <exit-code> <output>: sets $reply=(status detail), status one of
# good|bad|inconclusive. Match on literal response text (owner-approved rule): AccessDenied* +
# "explicit deny in a service control policy" is the one signal that actually means "permanently
# broken for Bedrock" -- everything about an expired/missing credential (ExpiredToken,
# UnauthorizedSSOTokenError, "Unable to locate credentials") means "needs a fresh login", which is
# routine, not a verdict on the profile, even when that login prompt failed or was declined.
# Anything else failing, or a non-zero exit with no recognizable text (network error, our own outer
# timeout firing, `aws` missing) is also inconclusive, never bad. The detail is extracted starting at
# the matched keyword itself (not the start of <output>) so a noisy preamble -- e.g. the
# credential_process script's own "SSO token expired -- launching browser login..." line, or a
# urllib3 TLS warning some credential_process setups trigger -- never crowds out the one line that
# actually matters; a plain truncation of raw <output> would otherwise surface exactly that noise
# instead of the error (seen live against adx-dev during this extension's real-world verification).
_cprof_aws_classify() {
  local rc=$1 out=$2 short
  if (( rc == 0 )); then reply=(good ok); return 0; fi
  if [[ $out == *AccessDenied* && $out == *'explicit deny in a service control policy'* ]]; then
    short=${out#*AccessDenied}; short="AccessDenied$short"
    short=${short//$'\n'/ }; short=${short//$'\t'/ }; short=${short[1,220]}
    reply=(bad "$short"); return 0
  fi
  if [[ $out == *ExpiredToken* ]]; then short=${out#*ExpiredToken}; short="ExpiredToken$short"
  elif [[ $out == *UnauthorizedSSOTokenError* ]]; then short=${out#*UnauthorizedSSOTokenError}; short="UnauthorizedSSOTokenError$short"
  elif [[ $out == *'Unable to locate credentials'* ]]; then short=${out#*'Unable to locate credentials'}; short="Unable to locate credentials$short"
  fi
  if [[ -n $short ]]; then
    short=${short//$'\n'/ }; short=${short//$'\t'/ }; short=${short[1,220]}
    reply=(inconclusive "needs fresh login: $short"); return 0
  fi
  short=${out//$'\n'/ }; short=${short//$'\t'/ }; short=${short[1,220]}
  reply=(inconclusive "$short")
}

# _cprof_aws_bedrock_probe <profile> <region>: live reachability check; sets $reply=(status detail)
# via _cprof_aws_classify and caches a good/bad verdict (never an inconclusive one) under the
# (profile, region) pair actually probed. A browser SSO login prompt may occur for a
# credential_process profile with a stale cached token -- accepted (owner ruling, this extension) --
# so the bound below is generous: the AWS CLI's own --cli-connect-timeout/--cli-read-timeout bound
# the Bedrock API call itself once credentials are in hand (NOT the credential_process's own login
# retry -- killing that mid-prompt would wrongly read as a failure), plus an outer wall-clock bound
# via `timeout`/`gtimeout` when either is on PATH, to catch a truly stuck process without cutting off
# a real login in progress. A2 (doc-only, panel-accepted): on a bare macOS with neither `timeout` nor
# `gtimeout` installed, this outer bound is simply absent and a genuinely hung `aws` call could block
# indefinitely -- install either (`brew install coreutils` for `gtimeout`) to get the wall-clock
# bound. Returns 0 always -- classification is reported via $reply, never a shell-level failure.
_cprof_aws_bedrock_probe() {
  local p=$1 r=$2 out rc; local -a tmo
  if (( ! ${+commands[aws]} )); then reply=(inconclusive "aws not installed"); return 0; fi
  (( ${+commands[timeout]} )) && tmo=(timeout 180)
  (( $#tmo == 0 )) && (( ${+commands[gtimeout]} )) && tmo=(gtimeout 180)
  out=$("${tmo[@]}" aws bedrock list-inference-profiles --profile "$p" --region "$r" \
        --cli-connect-timeout 10 --cli-read-timeout 20 --no-cli-pager --no-paginate 2>&1)
  rc=$?
  _cprof_aws_classify "$rc" "$out"
  [[ $reply[1] == (good|bad) ]] && _cprof_aws_health_write "$p" "$r" "$reply[1]" "$reply[2]"
  return 0
}

# _cprof_aws_find_substitute <exclude> <region>: <region> is only the ambient fallback
# _cprof_aws_profile_region falls back to when a candidate has no region of its own (fix-up pass M2).
# Search order: 1) the most-recently-checked cached-good (profile, region) pair, if that profile
# isn't <exclude> itself. 2) else `aws configure list-profiles`, non-credential_process profiles
# first (cheap: they fail fast with no popup if also broken, so trying them costs nothing extra
# before risking a popup on a credential_process candidate), live-validating and caching each via
# _cprof_aws_bedrock_probe (each candidate's OWN resolved region, M2), stopping at the first good.
# Fix-up pass B1: before a candidate is probed, _cprof_aws_raw_sso_sibling checks whether it is a
# raw-internal SSO profile with an untried, non-excluded sibling; if so, the SIBLING is probed in
# that candidate's turn instead, so the sibling gets first crack at the slot the raw profile would
# otherwise have won by sorting earlier in `aws configure list-profiles`. A raw profile whose sibling
# was already tried (and failed) still gets its own turn, unswapped. A "good" result is re-verified
# live via _cprof_aws_verify_identity before being accepted -- a candidate that passes the narrow
# Bedrock probe but fails identity resolution is skipped, not returned. When the winner came from a
# sibling swap, the raw profile's own configured `sso_account_id` (local config, no live call) is
# compared against the sibling's live-resolved account purely as an informational WARN, never a hard
# gate -- the sibling's own successful Bedrock probe + identity check is the stronger, authoritative
# signal, and there is no general "expected" account id to gate on (the panel's own framing: this
# machine's case has one because the raw profile's config happens to carry it, but a generic fix
# cannot assume that). Prints the winner and returns 0, or prints nothing and returns 1 once every
# candidate is exhausted; each attempt is reported via _cprof_err as it happens so a caller's
# eventual WARN is preceded by a full trail of what was tried and why.
_cprof_aws_find_substitute() {
  local exclude=$1 region=$2 p cand sib acct rawacct r allstr
  local -a all cp nocp
  local -A tried
  if _cprof_aws_health_latest_good; then
    [[ $reply[1] != "$exclude" ]] && { print -r -- "$reply[1]"; return 0; }
  fi
  (( ${+commands[aws]} )) || return 1
  all=(${(f)"$(aws configure list-profiles 2>/dev/null)"})
  allstr=" ${(j: :)all} "
  for p in $all; do
    [[ $p == "$exclude" ]] && continue
    if _cprof_aws_is_credential_process "$p"; then cp+=("$p"); else nocp+=("$p"); fi
  done
  for p in $nocp $cp; do
    (( ${+tried[$p]} )) && continue
    cand=$p
    if sib=$(_cprof_aws_raw_sso_sibling "$p" "$allstr") && [[ $sib != "$exclude" ]] && (( ! ${+tried[$sib]} )); then
      cand=$sib
    fi
    tried[$p]=1; tried[$cand]=1
    r=$(_cprof_aws_profile_region "$cand")
    _cprof_aws_bedrock_probe "$cand" "$r"
    if [[ $reply[1] == good ]]; then
      acct=$(_cprof_aws_verify_identity "$cand")
      if [[ -z $acct ]]; then
        _cprof_err "substitute search: '$cand' passed the Bedrock probe but failed account-identity verification; skipping"
        continue
      fi
      if [[ $cand != "$p" ]]; then
        rawacct=$(aws configure get sso_account_id --profile "$p" 2>/dev/null)
        [[ -n $rawacct && $rawacct != "$acct" ]] \
          && _cprof_err "substitute search: '$p''s configured sso_account_id ($rawacct) does not match '$cand''s live account ($acct); using '$cand' anyway -- its own Bedrock probe and identity check both succeeded"
      fi
      print -r -- "$cand"; return 0
    fi
    _cprof_err "substitute search: '$cand' -> $reply[1] ($reply[2])"
  done
  return 1
}

# _cprof_aws_heal_profile <candidate> <region>: resolves the AWS_PROFILE to snapshot for a new
# --auth bedrock profile. <region> is only the ambient fallback passed through to
# _cprof_aws_find_substitute for OTHER candidates (M2) -- <candidate>'s own probe/cache always uses
# its own resolved region via _cprof_aws_profile_region. Cached good -> trust it, no live call (fast
# path once validated once). Cached bad -> skip straight to substitute search, no re-test. No cache
# entry -> probe live now and cache the verdict; good -> use it; inconclusive -> snapshot <candidate>
# as-is with a WARN (never cached); bad -> substitute search, falling back to snapshotting
# <candidate> anyway (unmissable WARN) if every candidate is exhausted with no good found. Always
# prints a profile name and returns 0 -- a failed heal is a WARN on stderr, never a `cprof new`
# failure.
_cprof_aws_heal_profile() {
  local cand=$1 region=$2 r st det sub
  r=$(_cprof_aws_profile_region "$cand")
  _cprof_aws_health_lookup "$cand" "$r"
  st=$reply[1]; det=$reply[2]
  if [[ $st == good ]]; then print -r -- "$cand"; return 0; fi
  if [[ $st == inconclusive ]]; then
    _cprof_err "WARN: could not validate AWS profile '$cand' for Bedrock ($det); snapshotting it as-is -- run 'cprof doctor' to re-check later"
    print -r -- "$cand"; return 0
  fi
  if sub=$(_cprof_aws_find_substitute "$cand" "$region"); then
    _cprof_err "WARN: ambient AWS_PROFILE '$cand' is denied for Bedrock ($det); substituting '$sub' instead -- pass a different AWS_PROFILE before 'cprof new' to override"
    print -r -- "$sub"; return 0
  fi
  _cprof_err "WARN: ambient AWS_PROFILE '$cand' is denied for Bedrock ($det) and no working AWS profile was found to substitute; snapshotting '$cand' anyway -- fix its AWS access, or export a working AWS_PROFILE, before 'cprof new <name> --auth bedrock'"
  print -r -- "$cand"
}
