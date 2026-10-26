# `security_sensitive`: the criterion (item 7 of the spec)

Status: **plan-check default, pending owner OQ-1** (`architecture/delivery-workflow/reviews/plan-check-w1-specs.md` §5 OQ-1; spec 15 RESOLVED Q2). No source gives the criterion; this list is in force until the owner answers OQ-1. It is not an owner ruling.

## The header line

`architecture.md` carries exactly one header line, before item 1:
```
security_sensitive: yes
```
or
```
security_sensitive: no
```
The Architect sets it. The conductor reads it (INTERFACES 1.1.0 part A.2 `security_audit`, D2.1 `security_audit`, amendment AM-1) and sets `state.md` `security_audit: full` on `yes`; this skill never sets `SECURITY_AUDIT` in `state.md`.

## Criterion (plan-check default, pending owner OQ-1)

Write `security_sensitive: yes` when the epic changes any of:
- authentication or authorization;
- session or token handling;
- secrets or credential sources;
- payment or money flows;
- personal data;
- the e2e mock or auth-bypass gate (M25, M26);
- input parsing reachable from the network;
- or adds a new third-party dependency.

Otherwise write `security_sensitive: no`. **When unsure, `yes`.**

A `yes` only adds the full audit; it never removes a control. Name, in `architecture.md` item 10 (risks), which item of the list made it `yes`.

## What this skill does and does not do

- Passes `SECURITY_AUDIT=guidance` to `review-tailor`, unless the conductor or the operator explicitly says `full` for this invocation; then it passes `full` (`references/review-handoff.md`).
- Does not run `security-audit`, launches no `security-auditor` agent, writes no `security-audit/run-<N>/` directory and no audit file. Full mode runs later, per sub-task, into `RUN_HOME/<subtask>/security-audit/run-<N>/` (part A.5.3), with slot rows for its agents (part A.4) and `validate-findings.cjs` as a `pre-pr-gate` row.
- In guidance mode the security seat of the review loads `skills/security-audit` scoped to the artifacts, writes no file and launches no agent (D2.1).
