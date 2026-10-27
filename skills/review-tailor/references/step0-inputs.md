# Step 0: input validation (INTERFACES 1.10.0 part D1, D2.1, D2.2 row 4; AM-1, AM-3)

Inputs are passed as `NAME=value` arguments. `DELIVERY_ROOT` is the environment variable only.
Check in this order. Print one line per failing field, then stop. Do not ask, do not retry.
Line form: `INPUT-ERROR <NAME> <reason>`, reason one of `missing|enum|path|unset|format`.

| # | Field | Valid when | Failure line |
|---|---|---|---|
| 1 | `DELIVERY_ROOT` (env) | set and non-empty | `INPUT-ERROR DELIVERY_ROOT unset` |
| 2 | `RUN_HOME` | given; an existing directory | `... RUN_HOME missing` / `... RUN_HOME path` |
| 3 | `SLUG` | given; matches `^[a-z0-9][a-z0-9-]*$` and ends `-<KIND>-<n>` (`n` digits), where `<KIND>` is the valid `KIND` (skip the suffix test when `KIND` is itself invalid) | `... SLUG missing` / `... SLUG format` |
| 4 | `ARTIFACTS` | given; comma-separated; every item an existing file or directory | `... ARTIFACTS missing` / `... ARTIFACTS path` |
| 5 | `KIND` | `doc`, `plan` or `diff` | `... KIND missing` / `... KIND enum` |
| 6 | `STAKES` | `reversible` or `one-way` | `... STAKES missing` / `... STAKES enum` |
| 7 | `CONTENTION` | `none` or `contested` | `... CONTENTION missing` / `... CONTENTION enum` |
| 8 | `NOVELTY` | `known` or `novel` | `... NOVELTY missing` / `... NOVELTY enum` |
| 9 | `SECURITY_AUDIT` | `guidance` or `full`; required, no default | `... SECURITY_AUDIT missing` / `... SECURITY_AUDIT enum` |
| 10 | `ORCHESTRATOR_TIER` | `design`, `execute`, `verify` or `mechanical` (D2.1 `tier`; the caller passes `state.md` `orchestrator_tier`, part A.2, AM-3 errata (g)); required, no default | `... ORCHESTRATOR_TIER missing` / `... ORCHESTRATOR_TIER enum` |

Rules:
- Every input is required like every NEW-skill input (task spec 16 RESOLVED Q2; INTERFACES D2.2
  transport "every caller passes them"); `SECURITY_AUDIT` and `ORCHESTRATOR_TIER` have no default.
- `SLUG` is minted by the caller (`<subtask|run>-<kind>-<n>`). Validate it, never mint or repair it.
- A bad value is `enum` (the example `STAKES=maybe` prints exactly `INPUT-ERROR STAKES enum`).
- Collect every failing field from the table, print them in table order, then stop. When all
  pass, print nothing for Step 0 and go on.
- Nothing is written to `RUN_HOME` unless every field passed.
- Rung values used in the record are exactly `0|1|2|2b|3|4`; `2b` has a lowercase b.
