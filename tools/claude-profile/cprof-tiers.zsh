# cprof tier verbs: render, launch, sync, doctor tier row, trust ledger. Sourced by cprof.zsh.
# Design: architecture/permission-tiers.md (Components 3, Interfaces D2/D3, R-2) + permission-tiers-02.md (1, 4).
# HQ config dir: ${CPROF_HQ_CONFIG:-$HOME/projects/agent-hq/config} (env override is for tests).

_cprof_hqcfg() { print -r -- "${${CPROF_HQ_CONFIG:-$HOME/projects/agent-hq/config}:A}"; }
_cprof_sha() { shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1; }
_cprof_need_jq() { (( ${+commands[jq]} )) || { _cprof_err "jq not found; required for tier verbs"; return 1; }; }

# Merge (D2): .[0]=hq settings, .[1:]=tier/overlay fragments. Scalars later-wins; permissions.allow and hooks
# from hq only; permissions.deny, sandbox.network.allowedDomains, sandbox.filesystem.allowWrite set-union.
_CPROF_MERGE='
def un(p; a; b): ((((a|getpath(p))//[]) + ((b|getpath(p))//[])) | unique) as $u
  | if ($u|length) > 0 then setpath(p; $u) else . end;
.[0] as $h
| reduce .[1:][] as $x ($h; . as $a
    | ($a * ($x | del(.permissions.allow, .hooks)))
    | un(["permissions","deny"]; $a; $x)
    | un(["sandbox","network","allowedDomains"]; $a; $x)
    | un(["sandbox","filesystem","allowWrite"]; $a; $x))
| del(._tier, ._source, ._overlay, ._note, ._auth)'
# Keep what the profile already holds: claudeMdExcludes always; skipDangerousModePermissionPrompt only for non-executor
# tiers (executor: the fragment's true wins; the harness only ever writes true, so that write is absorbed).
_CPROF_KEEP='($c[0]) as $c
| (if ($c|has("claudeMdExcludes")) then .claudeMdExcludes = (((.claudeMdExcludes//[]) + $c.claudeMdExcludes)|unique) else . end)
| (if ($tier != "executor" and ($c|has("skipDangerousModePermissionPrompt"))) then .skipDangerousModePermissionPrompt = $c.skipDangerousModePermissionPrompt else . end)'

# _cprof_render <profile-dir> <tier> [overlay]: writes config/settings.json, tier, tier.src.
# Inputs, in merge order: hq settings, tier fragment, auth fragment (bedrock profiles only; <region> substituted), overlay.
_cprof_render_ins() {   # <profile-dir> <tier> <overlay>: sets the caller's ins, mode, region; 1 if a bedrock render has no valid region
  local hq=$(_cprof_hqcfg)
  mode=$(_cprof_auth_mode "$1"); region=; ins=($hq/settings.json $hq/tiers/$2.json)
  if [[ $mode == bedrock ]]; then
    region=$(_cprof_aws_region); ins+=($hq/tiers/auth-bedrock.json)
    _cprof_region_valid "$region" || { _cprof_err "AWS region '${region:-unset}' is not a region id; export AWS_REGION (or AWS_DEFAULT_REGION) before rendering a bedrock profile (the sandbox host list needs it)"; return 1; }
  fi
  [[ -n $3 ]] && ins+=($hq/tiers/overlays/$3.json)
  return 0
}
_cprof_render() {
  local d=$1 tier=$2 ov=$3 hq f new tn mode region; local -a ins
  _cprof_need_jq || return 1
  hq=$(_cprof_hqcfg); f=$d/config/settings.json
  _cprof_render_ins "$d" "$tier" "$ov" || return 1
  for tn in $ins; do [[ -r $tn ]] || { _cprof_err "missing render input: $tn"; return 1; }; done
  tn=$(jq -r '._tier // empty' $hq/tiers/$tier.json 2>/dev/null)
  [[ $tn == $tier ]] || { _cprof_err "$hq/tiers/$tier.json has _tier '$tn', expected '$tier'"; return 1; }
  new=$(_cprof_render_inputs "$mode" "$region" $ins | jq -s "$_CPROF_MERGE") || { _cprof_err "settings merge failed"; return 1; }
  if [[ -s $f ]]; then
    new=$(print -r -- "$new" | jq --arg tier "$tier" --slurpfile c $f "$_CPROF_KEEP") || { _cprof_err "cannot merge existing $f; left untouched"; return 1; }
  fi
  ( umask 077; print -r -- "$new" > "$f.tmp.$$" && mv -f -- "$f.tmp.$$" "$f" ) || return 1
  _cprof_apply_excludes "$d/config" || return 1
  ( umask 077; print -r -- "$tier" > "$d/tier"
    { for tn in $ins; do print -r -- "$(_cprof_sha $tn) $tn"; done
      [[ $mode == bedrock ]] && print -r -- "region $region${CPROF_SSO_REGION:+ sso=$CPROF_SSO_REGION}"
      print -r -- "rendered $(_cprof_sha $f)"; } > "$d/tier.src" )
}

# _cprof_tier_md <profile-dir> <tier> <name> <force>: install the tier's CLAUDE.md template into workspace/.
_cprof_tier_md() {
  local src=$(_cprof_hqcfg)/../tools/claude-profile/templates/$2-CLAUDE.md dst=$1/workspace/CLAUDE.md
  [[ -r $src ]] || { _cprof_err "missing template: $src"; return 1; }
  [[ -e $dst && $4 != 1 ]] && { _cprof_err "$dst exists; use --force to overwrite"; return 1; }
  local own=${CPROF_OWNER-}   # the GitHub account the template names; never defaulted, never a wildcard
  if [[ "$(<$src)" == *'<owner>'* ]]; then
    [[ -n $own ]] || { _cprof_err "CPROF_OWNER is unset or empty; the $2 template needs your GitHub account (export CPROF_OWNER=<account>)"; return 1; }
    [[ $own =~ '^[A-Za-z0-9][A-Za-z0-9-]*$' ]] || { _cprof_err "CPROF_OWNER '$own' is not a valid GitHub account name"; return 1; }
  fi
  ( umask 077; sed -e "s/<profile>/$3/g" -e "s/<owner>/$own/g" "$src" > "$dst" )
}

# _cprof_tier_state <profile-dir>: sets the caller's locals tier, ov (overlay name) and rec (recorded rendered hash) from tier/tier.src.
_cprof_tier_state() {
  local line
  tier=$(<"$1/tier"); tier=${tier//[[:space:]]/}
  rec=; ov=; for line in "${(@f)$(<"$1/tier.src")}"; do
    [[ $line == rendered\ * ]] && rec=${line#rendered }
    [[ $line == *' '*/tiers/overlays/*.json ]] && ov=${${line##*/}%.json}
  done
}
_cprof_handedit_err() {
  _cprof_err "'$1' settings.json hand-edited since last render (recorded ${2:-none}) -- '--force' discards ALL hand edits except claudeMdExcludes (a backup is written)"
}
# _cprof_tier_stale <profile-dir>: needs tier/ov from _cprof_tier_state. Exit 0 = stale (prints the changed inputs), 1 = fresh.
_cprof_tier_stale() {
  local p line mode region; local -a ins cur rec chg
  _cprof_render_ins "$1" "$tier" "$ov" 2>/dev/null || { print -r -- "region unset"; return 0; }   # a bedrock profile with no region: stale, and render will say why
  for p in $ins; do cur+=("$(_cprof_sha $p) $p"); done
  [[ $mode == bedrock ]] && cur+=("region $region${CPROF_SSO_REGION:+ sso=$CPROF_SSO_REGION}")
  for line in "${(@f)$(<"$1/tier.src")}"; do [[ $line == rendered\ * ]] || rec+=("$line"); done
  [[ "${(F)cur}" == "${(F)rec}" ]] && return 1
  for line in $cur; do (( ${rec[(Ie)$line]} )) && continue; [[ $line == region\ * ]] && chg+=(region) || chg+=(${line#* }); done
  print -r -- "${${(j:, :)chg}:-inputs changed}"
}
# _cprof_launch_fresh <name> <profile-dir> <dry>: launch step G. Returns 1 to abort the launch.
_cprof_launch_fresh() {
  local n=$1 d=$2 dry=$3 tier ov rec chg bak
  [[ -f $d/tier.src ]] || { _cprof_err "WARN '$n' has no tier.src; staleness not checked"; return 0; }
  _cprof_tier_state "$d"
  chg=$(_cprof_tier_stale "$d") || return 0
  if [[ $rec != "$(_cprof_sha $d/config/settings.json)" ]]; then
    _cprof_handedit_err "$n" "$rec"; _cprof_err "-- not re-rendered; launching on the current file"; return 0
  fi
  if (( dry )); then print -r -- "dry-run: render stale ($chg); would re-render"; return 0; fi
  bak=$d/config/settings.json.bak-$(date -u +%Y%m%dT%H%M%SZ)
  if ( umask 077; cp -- "$d/config/settings.json" "$bak" ) && chmod 600 "$bak" && _cprof_render "$d" "$tier" "$ov"; then
    _cprof_err "'$n' render was stale ($chg); re-rendered (backup: $bak)"; return 0
  fi
  _cprof_err "'$n' re-render failed; not launching (a stale executor could be missing a deny)"; return 1
}

_cprof_sync() {
  local name d tier ov rec line bak force=0
  name=$1; shift
  [[ -n $name ]] || { _cprof_err "usage: cprof sync <name> [--force]"; return 1; }
  [[ $1 == --force ]] && { force=1; shift; }
  (( $# )) && { _cprof_err "unknown option: $1"; return 1; }
  _cprof_valid_name "$name" || return 1; _cprof_need_jq || return 1
  d=$(_cprof_root)/$name
  [[ -f $d/tier && -f $d/tier.src ]] || { _cprof_err "'$name' has no tier/tier.src; nothing to sync"; return 1; }
  _cprof_tier_state "$d"
  if [[ $rec != "$(_cprof_sha $d/config/settings.json)" ]] && (( ! force )); then
    _cprof_handedit_err "$name" "$rec"; return 3
  fi
  if (( force )) && [[ -f $d/config/settings.json ]]; then
    bak=$d/config/settings.json.bak-$(date -u +%Y%m%dT%H%M%SZ)
    ( umask 077; cp -- "$d/config/settings.json" "$bak" ) && chmod 600 "$bak" || { _cprof_err "cannot write backup $bak; not re-rendering"; return 1; }
    print -r -- "backup: $bak"
  fi
  _cprof_render "$d" "$tier" "$ov" && print -r -- "re-rendered '$name' ($tier${ov:+ + $ov})"
}

# Launch (D3): the `use` environment in a subshell (never touches the caller's shell), then exec claude.
_cprof_launch() {
  local _cp_name=$1 _cp_dry=0 _cp_d _cp_tier _cp_tok _cp_a _cp_i _cp_mode; local -a _cp_args _cp_flag
  local _cp_acc='{"crossSessionInbound":"accept"}'
  [[ -n $_cp_name ]] || { _cprof_err "usage: cprof launch <name> [--dry-run] [-- <claude args>]"; return 1; }
  shift; _cprof_valid_name "$_cp_name" || return 1
  while (( $# )); do
    case $1 in
      --dry-run) _cp_dry=1; shift ;;
      --) shift; _cp_args=("$@"); break ;;
      *) _cprof_err "unknown option: $1"; return 1 ;;
    esac
  done
  _cp_d=$(_cprof_root)/$_cp_name
  [[ -d $_cp_d/config ]] || { _cprof_err "no such profile (or no token): $_cp_name"; return 1; }
  _cp_mode=$(_cprof_auth_mode "$_cp_d")
  _cprof_auth_token "$_cp_d" "$_cp_mode" _cp_tok || return 1
  [[ -f $_cp_d/tier ]] || { _cprof_err "'$_cp_name' has no tier file; create it with 'cprof new --tier' (or use 'cprof use')"; return 2; }
  _cp_tier=$(<"$_cp_d/tier"); _cp_tier=${_cp_tier//[[:space:]]/}
  case $_cp_tier in
    executor) _cp_flag=(--dangerously-skip-permissions) ;;
    desk) _cp_flag=(--permission-mode auto) ;;
    *) _cprof_err "'$_cp_name' tier file says '$_cp_tier'; expected executor or desk"; return 2 ;;
  esac
  for (( _cp_i = 1; _cp_i <= $#_cp_args; _cp_i++ )); do
    _cp_a=$_cp_args[_cp_i]
    if [[ $_cp_tier == executor ]]; then
      [[ $_cp_a == --permission-mode || $_cp_a == --permission-mode=* ]] || continue
    else
      [[ $_cp_a == *dangerously-skip-permissions* || ( $_cp_a == --permission-mode && $_cp_args[_cp_i+1] != auto ) \
         || ( $_cp_a == --permission-mode=* && $_cp_a != --permission-mode=auto ) ]] || continue
    fi
    _cprof_err "refused: '$_cp_a' contradicts the $_cp_tier tier of '$_cp_name' (D3: the flag comes from the tier file)"; return 2
  done
  (( _cp_dry )) || (( ${+commands[claude]} )) || { _cprof_err "claude not found on PATH"; return 1; }
  _cprof_launch_fresh "$_cp_name" "$_cp_d" $_cp_dry || return 1
  (
    if [[ -f $_cp_d/profile.env ]]; then () { setopt localoptions allexport; source "$1"; } "$_cp_d/profile.env"; fi
    _cprof_auth_apply "$_cp_mode" "$_cp_tok"; _cp_tok=   # also strips profile.env's higher-precedence auth vars (M1)
    export CLAUDE_CONFIG_DIR=$_cp_d/config
    export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1
    builtin cd -- "$_cp_d/workspace" || { _cprof_err "cannot cd to $_cp_d/workspace"; exit 1; }
    if (( _cp_dry )); then
      print -r -- "dry-run env: CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR $(_cprof_auth_dryrun "$_cp_mode") CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1"
      print -r -- "dry-run: cd $PWD && exec claude ${(j: :)_cp_flag} --settings '$_cp_acc'${_cp_args:+ ${(j: :)${(@q)_cp_args}}}"
      exit 0
    fi
    exec claude $_cp_flag --settings "$_cp_acc" "${_cp_args[@]}"
  )
}

# doctor: one tier row per profile that has a `tier` file.
_cprof_doctor_tiers() {
  local d n tier src cur rec flag deny sb sd am
  print -r -- "-- tier rows (profiles with a tier file) --"
  (( ${+commands[jq]} )) || { print -r -- "WARN: tier rows skipped: jq not installed"; return 0; }
  for d in "$(_cprof_root)"/*(N/); do
    n=${d:t}; [[ $n == _* || ! -f $d/tier ]] && continue
    tier=$(<"$d/tier"); tier=${tier//[[:space:]]/}
    cur=$(_cprof_sha $d/config/settings.json); rec=
    [[ -f $d/tier.src ]] && rec=$(sed -n 's/^rendered //p' "$d/tier.src")
    [[ -n $rec && $rec == $cur ]] && src="render matches" || src="render MISMATCH"
    [[ $tier == executor ]] && flag=--dangerously-skip-permissions || flag="--permission-mode auto"
    [[ $(_cprof_auth_mode "$d") == bedrock ]] && am="; auth=bedrock" || am=
    print -r -- "$n: tier=$tier$am; $src; launch=$flag"
    if [[ $tier == executor ]]; then
      deny=$(jq '.permissions.deny // [] | length' "$d/config/settings.json" 2>/dev/null)
      sb=$(jq -r '.sandbox.enabled // false' "$d/config/settings.json" 2>/dev/null)
      (( ${deny:-0} >= 40 )) && [[ $sb == true ]] \
        && print -r -- "  ok: deny=$deny sandbox.enabled=true" \
        || print -r -- "  WARN: executor needs deny>=40 and sandbox.enabled=true (deny=${deny:-?} sandbox.enabled=${sb:-?})"
      sd=$(jq -r 'if has("skipDangerousModePermissionPrompt") then (.skipDangerousModePermissionPrompt|tostring) else "absent" end' "$d/config/settings.json" 2>/dev/null)
      [[ $sd == true ]] || print -r -- "  WARN: executor needs skipDangerousModePermissionPrompt=true (is ${sd:-?})"
    fi
  done
  return 0
}

# trust ledger (permission-tiers-02.md 4; tools/trust/README.md). Audit record only (D7).
_cprof_trust() {
  local sub=$1 f=$(_cprof_root)/_trust/ledger.jsonl note row
  shift 2>/dev/null; _cprof_need_jq || return 1
  case $sub in
    ls)
      [[ -f $f ]] || { print -r -- "(no ledger at $f)"; return 0; }
      jq -R -r 'def s: tostring | gsub("[\u0000-\u001f\u007f]"; "?");
        (try fromjson catch null) as $r
        | if ($r|type) == "object" then [$r.ts, $r.kind, (if $r.name then "\($r.name)@\($r.version // "?")" else "-" end), ($r.verdict // "-"), ($r.by // "-")] | map(s) | join(" ")
          else "UNPARSEABLE line \(input_line_number)" end' "$f" ;;
    baseline)
      note="everything present on disk at this timestamp is trusted by owner ruling 2026-10-12"
      if [[ $1 == --note ]]; then note=$2; shift 2 2>/dev/null || { _cprof_err "--note needs a value"; return 1; }; fi
      (( $# )) && { _cprof_err "unknown option: $1"; return 1; }
      if [[ -f $f ]] && [[ -n $(jq -R -r 'fromjson? | select(.kind=="BASELINE") | .ts' "$f") ]]; then
        _cprof_err "a BASELINE row already exists in $f; refusing a second"; return 4
      fi
      row=$(jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg note "$note" '{ts:$ts,kind:"BASELINE",by:"owner",note:$note}') || return 1
      ( umask 077; mkdir -p -- "${f:h}" && print -r -- "$row" >> "$f" ) || return 1
      print -r -- "BASELINE row written to $f" ;;
    *) _cprof_err "usage: cprof trust ls | baseline [--note \"<text>\"]"; return 1 ;;
  esac
}
