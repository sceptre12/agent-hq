# Contracts: one owning document, siblings cite by pin

Sources: card 3 ("contracts for every shared value, each cross-unit contract having exactly one owning document that siblings cite by pin and never restate"); D63 (`RLM:83`), D67 (`RLM:89`); `RLM:32` (`RLM` = `$HOME/claude-profiles/hermes/h1-home/skills/brain/review-loop-mechanics/SKILL.md`, outside W; key defined in `../SKILL.md` §Provenance) (about 55% of serious light-review findings were cross-document conflicts); INTERFACES 1.5.0 (`architecture/delivery-workflow/INTERFACES.md:3`) part A.6 (`interfaces/part-a-state.md:293-334`) and D6 (`interfaces/part-d-enums-topics.md:136-164`) (`contracts/` at the repo root, writer the Architect).

## What gets a contract

Any value that more than one unit, sub-task, repo or document reads or writes:
- API request and response shapes, error codes, status codes;
- events and message payloads, topic names;
- schemas, migrations' target shape, file formats, CSV or JSON columns;
- config keys and environment variable names (names only; never secret values, a default of this skill);
- fixed ports a component needs (the owning file holds port, bind, service and why fixed; `architecture.md` item 3 names it once as a sub-table row `port <port> <service>`, item 7 cites that row; the claim happens later, part A.5.2);
- shared enums and identifiers.

A value used by one unit only stays in that unit's draft.

## Owning document

- Default owner: one file `contracts/<name>.md` (or the repo's existing contract format, e.g. an OpenAPI or JSON Schema file, when step 1 found one: update it, do not add a parallel file).
- Each contract file opens with: `owner: <this file>`, `consumers: <slugs or docs>`, `version: <n>`, then the contract body.
- If an existing repo document already owns the value (step 1), it stays the owner; `contracts/` gets no copy, and the architecture cites the existing file.

## Citing by pin

- Siblings cite as `contracts/<name>.md@<sha>` (git blob id, `git hash-object <file>`) or `<file>:<line-range>`, plus the name of the value. They never paste the body, never paraphrase a field list, never restate a default.
- `architecture.md` item 3 lists each contract once in a contract sub-table placed under the template's component table (the template table has no consumers column, so a contract used by two components would repeat there): `| contract | owner path | consumers |`, one row per contract, fixed ports included. The component table's "owning document" cell cites the sub-table row.
- A draft's agent fields cite the contracts it reads or writes by pin. The step-3 drafts are written before `contracts/` exists, so they carry `PIN-TBD:<contract name>`; step 8 (always run on the first pass) replaces every placeholder with the pin of the finished file.
- After a fix changes a contract, every pin is refreshed in the same fix; the G48 pre-round check (C4) compares pins across the companion files.

## Check (K14 in `tree-rules.md`)

1. List every `contracts/*` file; each appears exactly once in the owner-path column of the `architecture.md` item 3 contract sub-table.
2. For each contract, take two distinctive lines of its body and `command grep -rnF` them across `architecture.md`, its parts, `test-plan.md`, `release-plan.md` and `drafts/`; any hit outside the owner is a restatement and fails.
3. Every pin in those files resolves: the file exists and, for an `@<sha>` pin, `git hash-object` equals the sha.
4. `command grep -rn 'PIN-TBD:'` over `architecture.md`, its parts, `test-plan.md`, `release-plan.md` and `drafts/` finds nothing.
