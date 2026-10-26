#!/usr/bin/env bash
# desk-req-schema.sh: sourced by desk-req.sh. The closed per-verb request schema
# (INTERFACES part B4, the authority) and its checks. Bash 3.2, BSD userland.
# Each dr_* check prints nothing when the request is valid, else one short
# rule name for the `desk-req: schema: <rule>` line.

# The 20 verbs of B4.
DR_VERBS="push pr-create pr-attach pr-comment pr-comments-read pr-approval-state pr-merge branch-delete ci-status ci-logs ci-rerun ci-status-main fetch tag-push publish test-report-push jira-get jira-create jira-update jira-transition"
# Verbs only the conductor may send (B1): envelope subtask must be `run`.
DR_CONDUCTOR_RE='^(pr-merge|publish|tag-push|test-report-push)$'

# jq program: $verb is the verb, input is the fields object. Prints "" when
# valid, else "verb", "fields: not an object", "unknown key K", "missing K"
# or the name of the first mistyped key. Types follow the B4 "Field types"
# paragraph; a ref or tag may not start with "-" (no raw flag).
DR_JQ=$(cat <<'JQEOF'
def isstr: type == "string";
def rx($r): isstr and test($r);
def inl($a): . as $x | any($a[]; . == $x);
def ok($t):
  if $t == "abs" then rx("^/[^[:space:]]+$")
  elif $t == "branch" then rx("^[A-Z][A-Z0-9]+-[0-9]+(-[a-z0-9-]+)?$")
  elif $t == "ref" then rx("^[A-Za-z0-9._/][A-Za-z0-9._/-]*$")
  elif $t == "tag" then rx("^[A-Za-z0-9._/][A-Za-z0-9._/-]*$")
  elif $t == "sha" then rx("^[0-9a-f]{40}$")
  elif $t == "stk" then rx("^(st[0-9]+|pm)$")
  elif $t == "method" then (isstr and inl(["squash", "merge", "rebase"]))
  elif $t == "int" then (type == "number" and . == floor and . >= 0)
  elif $t == "ints" then (type == "array" and all(.[]; ok("int")))
  elif $t == "abss" then (type == "array" and all(.[]; ok("abs")))
  elif $t == "labels" then (type == "array" and all(.[]; rx("^[A-Za-z0-9._:-]+$")))
  elif $t == "job" then rx("^[^[:cntrl:]]{1,200}$")
  elif $t == "package" then rx("^(@[a-z0-9-]+/)?[a-z0-9._-]+$")
  elif $t == "semver" then rx("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$")
  elif $t == "step" then rx("^[a-z0-9-]+$")
  elif $t == "tool" then (. == "zephyr")
  elif $t == "bool" then (type == "boolean")
  elif $t == "jirakey" then rx("^[A-Z][A-Z0-9]+-[0-9]+$")
  elif $t == "to" then (isstr and inl(["Backlog", "In Progress", "In Review", "Blocked", "Verified", "Done", "archive"]))
  elif $t == "readable" then (type == "array" and all(.[]; isstr and inl(["summary", "description", "issuetype", "parent", "labels", "priority", "components", "status"])))
  elif $t == "jfields" then
    (type == "object"
     and all(keys_unsorted[]; inl(["summary", "description", "issuetype", "parent", "labels", "priority", "components"]))
     and all(.[]; isstr or (type == "array" and all(.[]; isstr))))
  else false end;
def spec: {
  "push": {repo: "abs", branch: "branch", expect_head: "sha"},
  "pr-create": {repo: "abs", branch: "branch", base: "ref", body_path: "abs", labels: "labels", record_path: "abs", expect_head: "sha"},
  "pr-attach": {repo: "abs", pr: "int", paths: "abss"},
  "pr-comment": {repo: "abs", pr: "int", body_path: "abs"},
  "pr-comments-read": {repo: "abs", pr: "int"},
  "pr-approval-state": {repo: "abs", pr: "int"},
  "pr-merge": {repo: "abs", pr: "int", subtask: "stk", method: "method", expect_head: "sha", predecessors: "ints", record_path: "abs"},
  "branch-delete": {repo: "abs", branch: "branch", merged_into: "ref", merge_sha: "sha"},
  "ci-status": {repo: "abs", pr: "int"},
  "ci-logs": {repo: "abs", ci_run_id: "int", job: "job"},
  "ci-rerun": {repo: "abs", ci_run_id: "int"},
  "ci-status-main": {repo: "abs", merge_sha: "sha"},
  "fetch": {repo: "abs", ref: "ref"},
  "tag-push": {repo: "abs", tag: "tag", sha: "sha", step_id: "step"},
  "publish": {repo: "abs", package: "package", version: "semver", step_id: "step"},
  "test-report-push": {tool: "tool", payload_path: "abs", dry_run: "bool"},
  "jira-get": {key: "jirakey", fields: "readable"},
  "jira-create": {parent: "jirakey", fields: "jfields"},
  "jira-update": {key: "jirakey", fields: "jfields"},
  "jira-transition": {key: "jirakey", to: "to"}
};
def epic: ((.fields? // null) | (type == "object" and .issuetype == "Epic"));
. as $f
| spec[$verb] as $s
| if $s == null then "verb"
  elif ($f | type) != "object" then "fields: not an object"
  else
    (if $verb == "jira-create" and ($f | epic) then ($s | del(.parent)) else $s end) as $s2
    | ([$f | keys_unsorted[] | select(in($s2) | not) | "unknown key " + .][0]
       // [$s2 | keys_unsorted[] | select(in($f) | not) | "missing " + .][0]
       // [$s2 | keys_unsorted[] | . as $k | select(($f[$k] | ok($s2[$k])) | not) | $k][0]
       // "")
  end
JQEOF
)

# dr_validate <verb> <fields-file>: structural and type check.
dr_validate() {
  /usr/bin/jq -r --arg verb "$1" "$DR_JQ" "$2" 2>/dev/null || echo "fields json"
}

# dr_resolve <abs path>: print the physical path (deepest existing directory
# resolved, the rest appended). rc 1 for a relative path, a "." or ".."
# component, or a symlink leaf. Doubled and trailing slashes are squeezed, not
# rejected: a TMPDIR ending in "/" yields "//" in roots and candidates alike and
# is not a traversal; root and candidate are canonicalized the same way.
dr_resolve() {
  local p=$1 rest="" d
  case $p in /*) ;; *) return 1 ;; esac
  while [[ $p == *//* ]]; do p=${p//\/\//\/}; done
  [ "$p" = / ] || p=${p%/}
  case "$p/" in */../*|*/./*) return 1 ;; esac
  [ ! -L "$p" ] || return 1
  while [ ! -d "$p" ] && [ "$p" != "/" ] && [ -n "$p" ]; do
    rest="/${p##*/}$rest"
    p=${p%/*}
    [ -n "$p" ] || p=/
  done
  d=$(cd "$p" 2>/dev/null && pwd -P) || return 1
  [ "$d" != "/" ] || d=""
  printf '%s%s\n' "$d" "$rest"
}

# dr_under <path> <root>: rc 0 when the resolved path is strictly under the resolved root.
dr_under() {
  local rp rr
  rp=$(dr_resolve "$1") || return 1
  rr=$(dr_resolve "$2") || return 1
  case "$rp" in "$rr"/?*) return 0 ;; esac
  return 1
}

# dr_fget <fields-file> <key>: a scalar field as raw text, empty if absent.
dr_fget() { /usr/bin/jq -r --arg k "$2" '.[$k] // empty | if type == "string" then . else tojson end' "$1"; }

# dr_paths <verb> <subtask> <fields-file> <run-home>: path-root checks (B4 per-field rules).
dr_paths() {
  local verb=$1 sub=$2 file=$3 rh=$4 v fs eh p
  for k in body_path payload_path; do
    v=$(dr_fget "$file" "$k")
    [ -n "$v" ] || continue
    if [ "$verb" = test-report-push ]; then
      dr_under "$v" "$rh/bodies" || { echo "$k root"; return 0; }
    else
      dr_under "$v" "$rh/review" || dr_under "$v" "$rh/bodies" || { echo "$k root"; return 0; }
    fi
  done
  fs=$(dr_fget "$file" subtask)
  v=$(dr_fget "$file" record_path)
  if [ -n "$v" ]; then
    eh=$(dr_fget "$file" expect_head)
    dr_under "$v" "$rh/review/${fs:-$sub}" || { echo "record_path root"; return 0; }
    [ "${v##*/}" = "record-$eh.md" ] || { echo "record_path name"; return 0; }
  fi
  if [ "$verb" = pr-attach ]; then
    while IFS= read -r p; do
      dr_under "$p" "$rh/${fs:-$sub}/lanes" || { echo "paths root"; return 0; }
    done <<EOF2
$(/usr/bin/jq -r '.paths[]' "$file")
EOF2
  fi
  return 0
}
