# Item 20 `pre-pr-gate` — Rung 1 loop record

- **Artifact:** `skills/pre-pr-gate/SKILL.md` and `skills/pre-pr-gate/references/*.md` (top level).
  `references/templates/` belongs to item 27 and was read as a source only.
- **Spec:** `architecture/delivery-workflow/tasks/20-pre-pr-gate.md`.
- **Loop:** one orchestrator (D35), and a separate agent for each role:
  - G48 pre-round screen: Haiku, a fresh agent per screen.
  - Review: Sonnet, running the installed `doc-reviewer` skill, a fresh agent per round.
  - Fix: Opus, one fixer agent for every round. It is never the author, a reviewer or a verifier.
  - Fix-verify: Sonnet, running the installed `fix-verifier` skill, a fresh agent per round.
- **Round cap:** 3 rounds (D7). Pre-round findings went to the fixer first.
- **Date:** 2026-10-26.
- **Sources:**
  - INTERFACES **1.3.0**. AM-3 landed during the build; the dispatch named 1.2.0.
  - `interfaces/part-a..d`
  - design `part-0*.md` (card 10 in part-02 §2.2; part-03 §3; part-04 §5.7-5.8b)
  - `delivery-workflow-sources/owner-decisions.md`
  - `tools/skill-authoring.md`
- **Lint and typo nits:** reviewers skipped them.
- **Working files:** SCRATCH `pp20/` holds the snapshots r0, r1, r2a and r2, the diffs and the findings files.

## Round 1

**G48 screen: 1 Blocking, 8 Medium, 5 Advisory.**
- `RECORD_PATH` was not absolute.
- Verified-By came before the validator, which is not card order.
- `install.rebuild_allowlist` and `e2e.dist_scan_cmd` are **not** in A.2.2. AM-2 added only `sensitive_paths[]` among the keys in the dispatch premise. The other two are design-only (part-04 §5.8).
- No key was named for the sensitive-path list.
- INTERFACES was cited as 1.1.0.
- The slot-row rule conflicted with the A.4 reserved-seat exemption.
- The `INSTALLED` row and grant lookup was undefined.
- D55 was unaddressed.
- The G48 artifact list was inconsistent.

**Review (doc-reviewer): 1 Blocking, 7 Medium, 4 Low. Verdict: NOT READY.**
- **Blocking:** "never re-picked" is overridden by AM-3 OQ-2: one claimed retry at `BUS_PORT + 10`, then stop the line. The coordinator relayed the same point mid-loop.
- **Medium:**
  - stale version citations
  - step-order and pointer errors
  - `sensitive_paths[]` not cited
  - the scope-check base
  - no route for failures in steps 2-7
  - bus teardown belongs to `delivery-cleanup`
  - the `full` audit is not re-run when the head moves

**Fix (Opus):** 14 fixed, 3 raised as owner questions, 0 rejected.

**Fix-verify: 0 Blocking, 0 Medium, 2 Low.** One Low was that the Q3 wording still chose a route.

## Round 2

**G48 screen after fix 1: 1 Blocking, 5 Medium, 9 Advisory.** These went to the fixer first.
- The skill decided owner Q3 (STOP).
- The rebase trigger compared the wrong shas.
- "CI-parity" was unsourced.
- The profile sha was not checked.
- G48 findings had no fixer route.
- There was no card-to-step map.

**Pre-fix (Opus):** all fixed.

**Review (doc-reviewer): 0 Blocking, 3 Medium, 5 Low. Verdict: ITERATE.**
- A bus-refusal stop wrote no token.
- G48 fix files collided with round fix files.
- A STOP never released the gate-runner leases.

**G48 screen of the pre-fix: 2 Blocking, 7 Medium, 7 Advisory.**
- The `gate-runner` lease deadlocked when the head moved.
- Tailored seat sets conflicted with D12 ("full 7 until recorded").
- STOP tokens were printed instead of written (D1.1).
- The `status/` path was wrong.
- PR base, the port-table path and the planned-row query were undefined.
- Some steps were declarative instead of imperative.

**Fix (Opus):** all fixed. New open points 3-8 were raised.

**Fix-verify: CLEAN, 0 Blocking, 0 Medium, 3 Low.**

**G48 screen after fix 2:**
- Medium: "Recommended:" answers sat inside the skill's open points.
- Medium: step 11 fixed the C12 outcome of open point 5.
- Low: the P8 table was cited without its template.
- Rejected: "`register` exit 3 unsourced". `INTERFACES.md:49` gives `catalog.sh` exit 3 as "lane-lease held".

## Round 3

**Fix (Opus): 2 Medium and 4 Low fixed.**
- The recommendations were moved out of the skill. They are recorded below.
- Step 11 no longer decides the C12 outcome.
- The P8 table is now cited to its template.
- Open point 9 was added.
- Step 1 now uses "PR base" in place of a hard-coded `main`.
- The exit criterion now covers review-loop fixes only.

**Fix-verify: CLEAN, 0 Blocking, 0 Medium, 1 Low.** The Low is punctuation at `steps-detail.md:42`.

**Final: 0 Blocking, 0 Medium, 1 Low open.** The loop closed in round 3, within D7.

## Owner questions (each recommended answer comes from the fixer and has not been decided)

Q1. **`INSTALLED` and grant lookup for a C11 sensitive-path or `CREEP` hit.** Where does the gate find the evidence?
Recommended: a file `RUN_HOME/<subtask>/grants/<path-hash>.md` holding the desk ledger row id or the human's grant line. Until then, a hit without evidence fails C11.

Q2. **D55 (plan-check before round 1) in this loop.** D6 adopts D55, but its applicability to `pre-pr-gate` is unstated.
Recommended: the stage 3 `RUN_HOME/plan-check.md` line `PLAN-CHECK: clean` satisfies it. The gate checks that line before round 1 and runs no new plan-check.

Q3. **A failure outside the review loop** (steps 1-7, 10, 15, 19): does it go to the fixer or stop the line?
Recommended: failures in steps 3-7 and 19 go to the step 12 fixer as Blocking findings. A C3 head mismatch or a failed final gate goes back to the lead.

Q4. **Does `fix-verifier` also verify G48 fixes?**
Recommended: yes, with `FILE_SET` set to the G48-flagged files.

Q5. **After a second bus-port refusal** (stop the line):
Recommended: write `PREPR: STOP C12`, and clear it only with a fresh human grant.

Q6. **The main ref for the rebase, merge-base and PR base.**
Recommended: the remote-tracking main as updated by the desk `fetch`, with its sha recorded in the checklist header.

Q7 (integrator). **D1 has no `INPUT-ERROR` reason for a `REPO_PROFILE` sha mismatch.**
Recommended: extend the meaning of `format` (as D2.2 row 6 already uses it).

Q8 (integrator). **The `catalog.sh list --live` semantics.**
Recommended: rows whose latest state is `planned` or `live`.

Q9. **A gate runner that dies without releasing its `gate-runner` lease:** who writes the `released` row?
No recommendation; this was raised in round 3.

## Integrator notes (outside item 20's write scope)

- **Spec 20 is stale.**
  - §4 "Port guard", RESOLVED Q2 and §8 say "never re-picked". AM-3 OQ-2 overrides this.
  - The spec cites INTERFACES 1.1.0.
  - The spec cites A.2.2 for `install.rebuild_allowlist` and `e2e.dist_scan_cmd`, which are only in part-04 §5.8.
- **A.2.2 has no keys for** `install.rebuild_allowlist`, `e2e.dist_scan_cmd`, `version_bump_rule`, the PR template path, or "the profile asks for a tailored seat set".
- **Stale step numbers in INTERFACES pointers.**
  - The A.2.2 `sensitive_paths[]` reader says "pre-pr-gate step 5", but it is step 7.
  - Part-b B7 says "step 4" for redaction, but it is step 6.
- **The AM-3 consumer list (INTERFACES.md:35) omits `pre-pr-gate`**, although step 11 implements OQ-2.
- **The item 27 template disagrees with the skill.**
  - Line 69 makes a third failing round `ESCALATE` (not a D1 token), where the spec and card say `STOP`.
  - C21 says the review-bus rows and leases are released by cleanup, which conflicts with A.5.1 and with the skill's step 18.
  - C1, C2, C4, C5 and C16-C20 have no producing step.
  - C20 ("pushed") cannot be true before the push.
- **D2.1 has no dedicated G48-checker persona.** The skill uses `gate-checker`.

## §9 done-condition

The round 3 fix-verifier did the non-author dry run. It copied the block from spec §9 and ran it with `bash -s`.
- Result: `SKILL-20-OK`, exit 0.
- The orchestrator re-ran the same block after every fix, and it printed `SKILL-20-OK` each time.

The review trio's final verdict is CLEAN. The done condition is met.
