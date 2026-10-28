# cprof AWS-profile health cache + live Bedrock probe + substitute search. Sourced by cprof.zsh.
# Design: architecture/claude-profile-02.md, Extension 2026-10-28 ("self-heal `new --auth bedrock`
# against a broken ambient AWS profile"). Used by `_cprof_bedrock_snapshot` (cprof-auth.zsh, at
# `cprof new ... --auth bedrock`) and `_cprof_doctor_bedrock_env` (both cprof-auth.zsh -- the latter
# called from cprof-checks.zsh's `_cprof_doctor`) so `cprof new` and `cprof doctor` keep the same
# cache warm with the same classification rules. Split into its own file (not cprof-auth.zsh)
# purely to keep each file under hq's 200-line guidance.
#
# Cache file: `${CPROF_ROOT:-$HOME/claude-profiles}/.aws-profile-health`, one line per AWS profile,
# tab-separated `profile\tstatus\tchecked_at\tdetail` (status: good|bad; checked_at: UTC
# `date -u +%Y%m%dT%H%M%SZ`, same stamp style as cprof-link.zsh's backup dirs). Mirrors link-src's
# persistence style: plain text, no JSON dependency, atomic tmp+mv write, umask 077. A write
# upserts in place -- the file never grows a second row for the same profile.

_cprof_aws_health_file() { print -r -- "$(_cprof_root)/.aws-profile-health" }

# _cprof_aws_health_read <profile>: sets $reply=(status checked_at detail) for <profile>'s row
# (mirrors cprof.zsh's `_cprof_scalars` $reply convention). Returns 1, reply=(), if there is none --
# callers treat that as "unknown", not "bad".
_cprof_aws_health_read() {
  local p=$1 f=$(_cprof_aws_health_file) pn pst pts pdet
  reply=()
  [[ -r $f ]] || return 1
  while IFS=$'\t' read -r pn pst pts pdet; do
    [[ $pn == $p ]] && reply=("$pst" "$pts" "$pdet")
  done < "$f"
  (( $#reply )) || return 1
}

# _cprof_aws_health_write <profile> <good|bad> <detail>: upserts <profile>'s row, atomic tmp+mv,
# umask 077. Never called with 'inconclusive' -- an inconclusive probe (needs a fresh login, aws
# missing, network error) is not a verdict on the profile and must not poison the cache.
_cprof_aws_health_write() {
  local p=$1 st=$2 det=$3 f=$(_cprof_aws_health_file) root=$(_cprof_root) ts pn pst pts pdet out= found=0
  [[ $st == (good|bad) ]] || { _cprof_err "internal: bad health status '$st'"; return 1; }
  det=${det//$'\t'/ }; det=${det//$'\n'/ }
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  ( umask 077; mkdir -p -- "$root" ) || return 1
  if [[ -r $f ]]; then
    while IFS=$'\t' read -r pn pst pts pdet; do
      [[ -z $pn ]] && continue
      if [[ $pn == $p ]]; then out+="$p"$'\t'"$st"$'\t'"$ts"$'\t'"$det"$'\n'; found=1
      else out+="$pn"$'\t'"$pst"$'\t'"$pts"$'\t'"$pdet"$'\n'; fi
    done < "$f"
  fi
  (( found )) || out+="$p"$'\t'"$st"$'\t'"$ts"$'\t'"$det"$'\n'
  ( umask 077; print -rn -- "$out" > "$f.tmp.$$" && mv -f -- "$f.tmp.$$" "$f" ) \
    || { rm -f -- "$f.tmp.$$"; _cprof_err "cannot write $f"; return 1; }
}

# _cprof_aws_health_latest_good: prints the profile name of the most-recently-checked 'good' row
# (checked_at compares lexically fine: fixed-width %Y%m%dT%H%M%SZ), or nothing + returns 1 if none.
_cprof_aws_health_latest_good() {
  local f=$(_cprof_aws_health_file) pn pst pts pdet best= bestts=
  [[ -r $f ]] || return 1
  while IFS=$'\t' read -r pn pst pts pdet; do
    [[ -z $pn || $pst != good ]] && continue
    [[ -z $bestts || $pts > $bestts ]] && { best=$pn; bestts=$pts }
  done < "$f"
  [[ -n $best ]] || return 1
  print -r -- "$best"
}

# _cprof_aws_is_credential_process <profile>: true iff <profile> uses credential_process (per this
# extension's verified finding, such a profile auto-runs `aws sso login` -- a browser popup -- on
# any credential-export failure; an sso_session profile instead fails fast, non-interactively). Uses
# `aws configure get`, which already resolves a profile's config; no hand-rolled ~/.aws/config parse.
_cprof_aws_is_credential_process() { [[ -n $(aws configure get credential_process --profile "$1" 2>/dev/null) ]] }

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
# via _cprof_aws_classify and caches a good/bad verdict (never an inconclusive one). A browser SSO
# login prompt may occur for a credential_process profile with a stale cached token -- accepted
# (owner ruling, this extension) -- so the bound below is generous: the AWS CLI's own
# --cli-connect-timeout/--cli-read-timeout bound the Bedrock API call itself once credentials are in
# hand (NOT the credential_process's own login retry -- killing that mid-prompt would wrongly read
# as a failure), plus an outer wall-clock bound via `timeout`/`gtimeout` when either is on PATH, to
# catch a truly stuck process without cutting off a real login in progress. Returns 0 always --
# classification is reported via $reply, never a shell-level failure.
_cprof_aws_bedrock_probe() {
  local p=$1 r=$2 out rc; local -a tmo
  if (( ! ${+commands[aws]} )); then reply=(inconclusive "aws not installed"); return 0; fi
  (( ${+commands[timeout]} )) && tmo=(timeout 180)
  (( $#tmo == 0 )) && (( ${+commands[gtimeout]} )) && tmo=(gtimeout 180)
  out=$("${tmo[@]}" aws bedrock list-inference-profiles --profile "$p" --region "$r" \
        --cli-connect-timeout 10 --cli-read-timeout 20 --no-cli-pager --no-paginate 2>&1)
  rc=$?
  _cprof_aws_classify "$rc" "$out"
  [[ $reply[1] == (good|bad) ]] && _cprof_aws_health_write "$p" "$reply[1]" "$reply[2]"
  return 0
}

# _cprof_aws_find_substitute <exclude> <region>: step-4 search order. 1) the most-recently-checked
# cached-good profile, if one exists and isn't <exclude> itself (a profile that just failed cannot
# substitute for itself). 2) else `aws configure list-profiles`, non-credential_process profiles
# first (cheap: they fail fast with no popup if also broken, so trying them costs nothing extra
# before risking a popup on a credential_process candidate), live-validating and caching each via
# _cprof_aws_bedrock_probe, stopping at the first good. Prints the winner and returns 0, or prints
# nothing and returns 1 once every candidate is exhausted; each attempt is reported via _cprof_err
# as it happens so a caller's eventual WARN is preceded by a full trail of what was tried and why.
_cprof_aws_find_substitute() {
  local exclude=$1 region=$2 cached p; local -a all cp nocp
  cached=$(_cprof_aws_health_latest_good)
  if [[ -n $cached && $cached != $exclude ]]; then print -r -- "$cached"; return 0; fi
  (( ${+commands[aws]} )) || return 1
  all=(${(f)"$(aws configure list-profiles 2>/dev/null)"})
  for p in $all; do
    [[ $p == $exclude ]] && continue
    if _cprof_aws_is_credential_process "$p"; then cp+=("$p"); else nocp+=("$p"); fi
  done
  for p in $nocp $cp; do
    _cprof_aws_bedrock_probe "$p" "$region"
    if [[ $reply[1] == good ]]; then print -r -- "$p"; return 0; fi
    _cprof_err "substitute search: '$p' -> $reply[1] ($reply[2])"
  done
  return 1
}

# _cprof_aws_heal_profile <candidate> <region>: resolves the AWS_PROFILE to snapshot for a new
# --auth bedrock profile. Cached good -> trust it, no live call (fast path once validated once).
# Cached bad -> skip straight to substitute search, no re-test. No cache entry -> probe live now and
# cache the verdict; good -> use it; inconclusive -> snapshot <candidate> as-is with a WARN (never
# cached); bad -> substitute search, falling back to snapshotting <candidate> anyway (unmissable
# WARN) if every candidate is exhausted with no good found. Always prints a profile name and returns
# 0 -- a failed heal is a WARN on stderr, never a `cprof new` failure.
_cprof_aws_heal_profile() {
  local cand=$1 region=$2 st det sub
  if _cprof_aws_health_read "$cand"; then
    st=$reply[1]; det=$reply[3]
  else
    _cprof_aws_bedrock_probe "$cand" "$region"
    st=$reply[1]; det=$reply[2]
  fi
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
