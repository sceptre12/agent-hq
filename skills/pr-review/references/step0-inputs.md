# PR Review — Step 0 input table (D1)

Run before Step 1. Print one `INPUT-ERROR <field> <reason>` line per failing field (reason in
the D1 enum `missing|enum|path|unset|format|sha`; no row below uses `unset` or `sha`), then
stop: claim no port, register no catalog row, start no bus. "Unset" means the field is absent from the
dispatch prompt; an empty value is a set value and is validated like any other.

| Input | Rule | On failure |
|---|---|---|
| `PR_REVIEW_MODE` | `local-diff` (default when unset) or `pr` | `INPUT-ERROR PR_REVIEW_MODE enum` |
| `ROLES` | unset = all 7 seat ids; if set, the comma list must equal the set of the 7 ids of `references/agent-roles.md` (any order, each once). Anything else (fewer, more, unknown, duplicate, empty) is refused (`references/roles-subset.md`) | `INPUT-ERROR ROLES enum` |
| `SECURITY_AUDIT` | `guidance` (default when unset) or `full` | `INPUT-ERROR SECURITY_AUDIT enum` |
| `STACK_BASE`, `STACK_HEAD` | local-diff only (ignored in pr mode); both 40-hex shas or both unset | `INPUT-ERROR STACK_HEAD missing` (or `STACK_BASE`); non-hex: `... format` |
| `REPO_DIR` | local-diff: absolute path of a git checkout | `missing`, `path` |
| `BASE_REF`, `HEAD_REF` | local-diff without the stack pair: both set; not required when `STACK_BASE`/`STACK_HEAD` are set | `missing` |
| `RECORD_PATH` | local-diff: absolute, outside `REPO_DIR`; inside a run it must match the A.6 path `$RUN_HOME/review/$SUBTASK/record-<head>.md` with `<head>` 40-hex (Step 8 stops if `<head>` is not `HEAD_SHA`) | `missing` if unset, `path` if relative, inside `REPO_DIR` or (in a run) not the A.6 path |
| `REPO`, `PR_NUMBER` | pr mode: `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`, `^[0-9]+$` | `missing`, `format` |
| `BUS_PORT` | integer 1-65535; required when `RUN_HOME` is set; standalone optional: when set it is the candidate port of the standalone pre-bind check (`bus-start-standalone.md`), else 7777 | `INPUT-ERROR BUS_PORT missing` (inside a run), `... format` |
| `RUN_HOME` | set = inside a run; absolute path of an existing directory | `path` |
| `RUN_ID` | required when `RUN_HOME` is set; `^[a-z0-9-]+$` (A.1) | `missing`, `format` |
| `SUBTASK` | required when `RUN_HOME` is set; `^(st[0-9]+\|pm)$` (A.1) | `missing`, `format` |
| `SEAT_ID`, `MEMBER_SESSION_NAME` | local-diff (record line 2): `^[a-z0-9-]+$` (A.6) | `missing`, `format` |
| `TASK_ID` | local-diff (record line 2): `^[A-Za-z0-9_-]+$` (A.6) | `missing`, `format` |

`ROLES` derives from the seat table of `review-tailor-<slug>.md` (lines 2+, `seat-id<TAB>role<TAB>reason`).
The D2.3 `pr-review` inputs (INTERFACES 1.5.0, AM-5 10-B2) are `ROLES`, `SEAT_ID`, `RUN_ID`, `SUBTASK`,
`BUS_PORT`, `SECURITY_AUDIT`, `PR_REVIEW_MODE`, `STACK_BASE`, `STACK_HEAD` and `RECORD_PATH`; `RUN_ID` and
`SUBTASK` are the in-run identity of the review-bus path `RUN_HOME/review/<subtask>/<review-id>/bus/`
(A.1, D5), and `BUS_PORT` is required when `RUN_HOME` is set, optional standalone (D2.3). The other rows
are dispatch-prompt fields validated here. Record line 2 is never written with an empty field.
