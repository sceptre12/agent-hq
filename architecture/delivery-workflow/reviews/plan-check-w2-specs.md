# Plan-check: the two W2 task specs (28 `delivery-run`, 29 `delivery-pipeline`; D55)

- **Date:** 2026-10-26. **Checker:** Plan-checker (verify persona; not an author of either spec). **Scope:** `architecture/delivery-workflow/tasks/28-delivery-run.md`, `29-delivery-pipeline.md`.
- **Authorities, in order:**
  1. INTERFACES 1.3.0, plus the pending AM-4 queue (`SCRATCH/am4-queue.md`), treated as decided.
  2. ADR 0054 and ADR 0055 (accepted).
  3. The design parts.
  4. Owner rulings.
  5. The W1 skills as built: `pre-pr-gate`, `ci-fix-loop`, `delivery-cleanup`, `ticket-clerk`, `delivery-shepherd`, `delivery-dispatch-plan`, `delivery-desk`, the 27b briefs, and the `wave-execution` EXTEND at W' head `526f82b` (attach contract of `297a8dc` unchanged).
  6. `reviews/plan-check-w1-specs.md`.
- **Method:** as in the W1 plan-check. Each `SPEC-QUESTION` was edited in place to `RESOLVED (<authority or PLAN-CHECK DEFAULT>): ...`. Cross-check defects were fixed in the specs as `RESOLVED PC-W2-<n>` lines and in the §3, §4, §7, §8 and §9 rows they touch. INTERFACES gaps were appended to the AM-4 queue as rows W2-1..W2-10 in exact text. INTERFACES, the ADRs, the design and the W1 skills were not edited. Nothing was committed.

**PLAN-CHECK: PASS.** No owner fork blocks either spec. Section 5 lists three owner-visible notes; each has a default in force.

## 1. Spec questions

| Spec | Q | Resolution | Authority |
|---|---|---|---|
| 28 | Q1 controller slot | **Yes, it takes a row.** Persona `wave-controller` (AM-4 W2-2), `unit` `-`. The row is written before the Agent call, so `max_concurrent` already subtracts it. Freed when the task returns. One live invocation per sub-task. | A.4 "every other agent get a row"; the session concurrency cap counts the controller as a live subagent (so the recommended "no row" could reach 31) |
| 28 | Q2 `spawns` / `cap - 5` | Counts all Agent calls in the lead session (own and hosted skills) plus dispatch-record lines. `<cap>` = env `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION`, fail closed. Pre-invocation check is `spawns + 1 + (dispatch_budget - recorded lines) <= cap - 5`. | A.3, C5.3; PLAN-CHECK DEFAULT; AM-4 W2-8 |
| 28 | Q3 port-check exit 3 | `stop_reason: port-refused`, no retry. A review-bus stop reported through `pre-pr-gate` gets the same value. | A.5.2; AM-4 27b; W2-1 |
| 28 | Q4 retry/candidate collision | Port spacing of 20 (section 3). | AM-4 W2-3 |
| 28 | Q5 Integrator `fetch` | The lead sends `fetch` before the `02-integrate.md` invocation and before each `pre-pr-gate` call. The Integrator never sends `DESK`. | B1 host rule; W2-4 |
| 29 | Q1 `H1.reject` | `stage: stopped`, then the abandoned-run `final` cleanup. No ticket event is written, because no ticket exists yet. | A.2.1, C5.1 (AM-2 row 14); PLAN-CHECK DEFAULT |
| 29 | Q2 status post | Printed at end of turn, with no file grammar. The content list is fixed in `stops-and-posts.md`. | D2.2 row 1; PLAN-CHECK DEFAULT |
| 29 | Q3 profile restore | Becomes a human step in the final post. The conductor never writes the profile. | A.2.2, R4-J1; W2-6 |
| 29 | Q4 counter / archive | The counter is the stage 8 `execution-log.md` row. Archiving is a human step. | template Part B; W2-6 |
| 29 | Q5 refused relay | The file is renamed `<id>.desk.refused` and gets a status-post line. The conductor writes no stop row (A.3 lead-only); the lead treats the file as terminal `sender`. | B1; W2-4 |

Totals: 10 questions resolved. 4 cite an authority directly, 6 are defaults or AM-4 rows. 0 remain open. `grep -rn SPEC-QUESTION tasks/` returns nothing.

## 2. Cross-check: conductor vs lead vs W1 hand-offs

| Point | Finding | Fix |
|---|---|---|
| Who arms the tick | Consistent. The lead arms the merged 10-minute tick (C7). The conductor arms only its 1-minute relay tick. Brief 27b `conductor.md` still says "arm the merged tick" (errata, already in 29). Whether a session cron fires inside `claude -p` is unmeasured. | 28 PC-W2-7: the C1.1 fallback applies |
| Who relays `DESK` | Consistent. A `claude -p` lead writes `outbox/<id>.desk` and the conductor relays it at 1 minute; an `agent-tool` lead sends `DESK` itself; hosted skills send through their host (B1). The refused-relay rename was undefined. | 29 Q5, 28 PC-W2-8, W2-4 |
| `state.md` / `substate.md` writers | Consistent: conductor-only and lead-only. However, A.2 maps any non-empty `stop_reason` to `stopped`, which is wrong for `spawn-cap` (a hand-over) and `invalidate` (the conductor's own pause). No rule cleared either value. | 29 PC-W2-9, 28 PC-W2-8, W2-5 |
| Escalations | C2 says the conductor's post lists open escalations, and D3 maps `ESCALATE` to `blocked`. Spec 29's tick did not read `escalations/`. | 29 PC-W2-10; tick-relay scope |
| Epic `jira-create` | Spec 29 listed it as the conductor's own request. `ticket-clerk` (running in the conductor, `run`) already creates the epic in wave 1, so this was a double-create risk. | 29 §3/§4: the clerk composes it; the conductor copies the key from `tickets.tsv` |
| **Merge precondition (Blocking, fixed)** | Spec 29's RESOLVED line had `pr-merge` key on `ci: GREEN` alone. The desk re-derives `record-<head>.md` on the landing head (B5, FROZEN). After CI fix pushes no such record exists, so every such merge would be refused `marker`. | 28 PC-W2-3 (the lead re-runs `pre-pr-gate` on the CI-fixed head, step 1 delta verify); 29 §7, §11; W2-7 |
| `CI: HUMAN` to `stop_reason` | `ci-fix-loop` says "the lead sets" `stop-the-line:D23` and `d7-round3`, but spec 28 had no mapping. | 28 PC-W2-4 |
| Launcher for `claude -p` leads | Spec 29 `launcher.md` covers `env -i`, the asserted `=30`, stdin, and `--disallowedTools` with Zephyr. An `agent-tool` lead is not launched, so nothing asserted its concurrency env. | 28 PC-W2-2 (ORCHESTRATOR-CHECK requires `>= 30`) |
| Machine ledger (200, rule 8) | Spec 28 had no machine-row step. C5.2 has the `agent-tool` lead register its own row, and nobody wrote a `claude -p` lead's row. | 28 PC-W2-1 (every lead writes its own row under the lock and re-sums); 29 §4; W2-9 |
| 30 slots | The controller is uncounted (Q1). The reserved `ci: 1` has to cover `ci-fix-loop`'s serial agents; its gate runner gets a row. `clerk: 1` is reserved in every lead but unused (the clerk runs only in the conductor). This is harmless and was left as is. | 28 Q1, PC-W2-6 |
| Nudge ownership | `delivery-shepherd` step 8 still calls "who nudges when the watchdog wrote the line" an owner question. AM-4 queue 23 already decided it: whichever side writes the line. | 28 PC-W2-5; item 33 updates the shepherd text |
| Stop packets | The set `d7-round3`, `stop-the-line:<row>`, `human`, `port-refused` maps to `stopped`, with ticket `blocked` and post paths. `spawn-cap` maps to relaunch and `invalidate` to pause. Spec 28's own stops write `substate.md`. Spec 29 never writes it. | 29 §8 criterion rewritten |
| Hand-off inputs | `pre-pr-gate` (row 10), `ci-fix-loop` (row 11), `delivery-cleanup` (row 9: `MERGE_RECORD` for `st<N>`, evidence for `pm`/`final`), `delivery-shepherd` (row 7) and `wave-execution` (`max_concurrent` always passed, since an absent value means unbounded) all match the specs. | none |

## 3. Port-table rule (28-Q4), recorded as AM-4 W2-3

- **Defect:**
  - With candidates at `<base> + 10·k`, the `st<N>` bus retry (`k = 2N`, +10) equals that sub-task's review-bus candidate (`k = 2N + 1`).
  - The review-bus retry then equals `st<N+1>`'s bus.
  - One refusal can therefore cascade along the table. The registry keeps this safe, but it turns one collision into several stops.
- **Rule:**
  - Candidates become `<base> + 20·k`, with the same `k` assignments (bus `2N`, review bus `2N + 1`, lanes by bind index). Every candidate is an even multiple of 10 from its base, and its single +10 retry lands on an odd multiple that no candidate uses.
  - Pre-dispatch checklist row 8 widens to cover all candidates plus all candidates + 10, across both bases and the fixed app ports, as pairwise distinct and at most 65535. Fixed app ports are the only place a retry could still meet a candidate, and this check catches that at plan time.
- **Consumers:** `delivery-dispatch-plan` (shared-files §3, template P8, checklist row 8); `pre-pr-gate` step 11 formula; the lead brief; `delivery-run`. `pr-review` and `port-claim` are unchanged, because the `BUS_PORT + 10` retry stays. The lead reads the P8 cell and never recomputes it.

## 4. AM-4 rows appended (`SCRATCH/am4-queue.md`, append-only)

W2-1 `port-refused` in A.3, plus exit 3. W2-2 `wave-controller` persona and its A.4 row. W2-3 port spacing 20. W2-4 B4 `fetch` requester and C5.1 `.desk.refused`. W2-5 A.2 stop-reason-to-state mapping and the clearing rule. W2-6 CYCLE DONE human steps (design errata). W2-7 merge precondition on a CI-fixed head, and the later-push rule. W2-8 `spawns` definition and `<cap>` source. W2-9 machine-row writers and `live_count`. W2-10 lead-brief errata.

## 5. Owner-visible notes (non-blocking; default in force)

- **N1, AM-4 approval:** W2-3 changes the port table that the W1 `delivery-dispatch-plan` already builds. It takes effect only through the AM-4 amendment (Rung 2b, owner via the item 33 packet). Until then, the specs cite it as decided, per the brief.
- **N2, `H1.reject`:** the default is a run stop plus abandoned-run cleanup, never an automatic re-plan. A human gate's "reject" is read as "stop". *Recommended answer:* keep it.
- **N3, CI-fixed head:** W2-7 makes every head that CI fixes moved pass `pre-pr-gate` again (a delta verify) before merge. This follows from frozen B5, not from a new choice. A lighter merge record for CI-fix heads would need an ADR 0055 change. *Recommended answer:* keep B5 as frozen.

## 6. Checks run

- `grep -rn 'SPEC-QUESTION' architecture/delivery-workflow/tasks/`: 0 lines.
- `bash -n` on the §9 block of 28 and of 29 (extracted with python3): both parse.
- `bash tools/check-doc-length.sh .`: 0 blocking files over 500 lines. Spec 28 is 149 lines and spec 29 is 144.
- W' `wave-execution` attach contract (step 4: halt on `session_id`/`topic` mismatch, no `cleanup()`, `max_concurrent` absent = unbounded) re-read against spec 28 §4 and §5: consistent.
