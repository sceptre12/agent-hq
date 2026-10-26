# `security_sensitive`: the criterion (item 7 of the spec)

Status: **owner ruling OQ-1** (`architecture/delivery-workflow-sources/owner-decisions.md:88-89`; INTERFACES 1.4.0 amendment AM-3, `interfaces/part-a-state.md:71`). History: the criterion was the plan-check default (spec 15 RESOLVED Q2, `architecture/delivery-workflow/tasks/15-delivery-architecture.md:96`; `architecture/delivery-workflow/reviews/plan-check-w1-specs.md` §5 OQ-1) until the owner answered OQ-1; it is now that owner ruling.

## The header line

`architecture.md` carries exactly one header line, before item 1:
```
security_sensitive: yes
```
or
```
security_sensitive: no
```
The Architect sets it. The conductor reads it (INTERFACES 1.4.0 (`architecture/delivery-workflow/INTERFACES.md:3`) part A.2 `security_audit`, `interfaces/part-a-state.md:71`; D2.1 `security_audit`, `interfaces/part-d-enums-topics.md:34-68`; amendments AM-1 and AM-3) and sets `state.md` `security_audit: full` on `yes`; this skill never sets `SECURITY_AUDIT` in `state.md`.

## Criterion (owner ruling OQ-1; was the plan-check default)

The rule (OQ-1, as ruled): write `security_sensitive: yes` when the epic touches any of:
- auth;
- secrets;
- money;
- personal data;
- the e2e mock or auth-bypass gate (M25, M26);
- network-facing input parsing;
- a new third-party dependency.

Otherwise write `security_sensitive: no`. **When unsure, `yes`.**

Skill defaults (not part of the ruling; each only adds the full audit, never removes a control): session or token handling counts as auth, and credential sources count as secrets.

A `yes` only adds the full audit; it never removes a control (spec 15 RESOLVED Q2, `architecture/delivery-workflow/tasks/15-delivery-architecture.md:96`). Name, in `architecture.md` item 10 (risks), which item of the list made it `yes`.

## What this skill does and does not do

- Passes `SECURITY_AUDIT` to `review-tailor` exactly as `RUN_HOME/state.md` `security_audit` holds it (`guidance` when the key is absent, the A.2 default); the conductor sets that key (on an operator request or on this doc's `yes` line), so this skill never derives the value from its own `security_sensitive` line (`references/review-handoff.md`).
- Does not run `security-audit`, launches no `security-auditor` agent, writes no `security-audit/run-<N>/` directory and no audit file. Full mode runs later, per sub-task, into `RUN_HOME/<subtask>/security-audit/run-<N>/` (part A.5.3), with slot rows for its agents (part A.4) and `validate-findings.cjs` as a `pre-pr-gate` row.
- In guidance mode the security seat of the review loads `skills/security-audit` scoped to the artifacts, writes no file and launches no agent (D2.1).
