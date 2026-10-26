# Security seat and security-audit (SKILL step 9)

## Guidance mode (default, `SECURITY_AUDIT=guidance`)
The security seat loads `skills/security-audit` diff-scoped. It writes no file and launches no agent. `pre-pr-gate` passes `SECURITY_AUDIT` to `pr-review` unchanged (part D2.3 `pr-review`).

## Full mode (`SECURITY_AUDIT=full`)
Condition (part D2.1 `security_audit`): "only on an explicit operator request or a `security_sensitive: yes` epic". The conductor sets it; this skill never decides it.

Run order: after the G48 pre-round check, before round 1 of `pr-review`, because the security seat reads the latest `findings.json`. Not re-run per round unless the head changes (spec Resolution 3); when SKILL step 13 finds the head moved, re-run it on the new head.

- `output-dir` = `RUN_HOME/<subtask>/security-audit/run-<N>/`, `N` = 1 + the count of existing `run-*` directories; never the skill's `~` default (part A.5.3).
- Target code runs with no network (the skill's `execution_policy: sandboxed-source-and-local-only`).
- Every hunter and verifier gets a slot row before it starts: persona `security-auditor`, unit `-`, tier `verify` (part A.4). Agents start only into free slots (the free slot count at launch, A.4); no agent starts without a free slot.
- Gate row (part A.5.3): `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json`. A non-zero exit fails checklist row `C26`: `PREPR: STOP C26` (A.5.3 in INTERFACES 1.3.0).
- Open findings above the profile's Blocking rule go into the review loop like any seat finding.
