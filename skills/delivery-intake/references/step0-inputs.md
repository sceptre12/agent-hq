# Step 0 inputs for delivery-intake (part D1, D2.2 row 2)

Validate in this order. Check every field, print one line per failing field, then stop. No retry, no prompt, nothing written.

Line form: `INPUT-ERROR <NAME> <reason>`, regex `^INPUT-ERROR [A-Za-z_][][A-Za-z0-9_.]* (missing|enum|path|unset|format)$`.

| # | Field | Source | Valid when | Failing reason |
|---|---|---|---|---|
| 1 | `DELIVERY_ROOT` | environment variable | set, non-empty, matches `^/[^[:space:]]+$`, and is an existing directory | not in the environment: `unset`; set but empty or fails the regex: `format`; not a directory: `path` |
| 2 | `RUN_HOME` | `NAME=value` | given, absolute, an existing directory, and equal to `$DELIVERY_ROOT/<run-id>` with `<run-id>` matching `^[a-z0-9-]+$` | not given: `missing`; not absolute or not an existing directory or not directly under `DELIVERY_ROOT`: `path`; last component fails the run-id regex: `format` |
| 3 | `PLANS_DIR` | `NAME=value` | given, absolute, an existing directory (the conductor created it) | not given: `missing`; otherwise `path` |
| 4 | `PRIMARY_REPO` | `NAME=value` | given, matches `^/[^[:space:]]+$` (the `PROFILE:` line regex, D1.1, allows no whitespace), inside a git work tree (`git -C <path> rev-parse --is-inside-work-tree` prints `true`) | not given: `missing`; fails the regex: `format`; otherwise `path` |
| 5 | `INTENT` | `NAME=value` | given and non-empty text | `missing` |

Notes:
- `enum` has no field in this skill (no closed-set input).
- When `DELIVERY_ROOT` fails (`unset`, `format` or `path`), skip the checks that depend on it (the "directly under" test of field 2); still check the rest and print their lines.
- Intake mints neither the run-id nor `PLANS_DIR`; the conductor gives them (part A.1).
- Example, `DELIVERY_ROOT` unset, everything else valid: the single line `INPUT-ERROR DELIVERY_ROOT unset`.
- Example, two failures: `INPUT-ERROR PLANS_DIR path` then `INPUT-ERROR INTENT missing`, in field order.
