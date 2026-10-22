---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `superpowers:using-git-worktrees` skill at execution time.

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Parallelism Assessment

Before offering an execution choice, build a lightweight conflict graph directly from
the **Files:** and **Interfaces:** blocks you already wrote into every task — no new
authoring burden, no new fields.

**1. Build the conflict graph.**
- **Conflict edge** between two tasks if either holds:
  - (a) they share any file in Create/Modify (a same-file conflict), OR
  - (b) one task's `Consumes` names something the other task's `Produces` provides (a
    dependency edge — order matters, so they can't run concurrently either).
- Two tasks with neither kind of edge between them are conflict-free with each other.

**2. Compute the ratio.** For each task, check whether it has zero conflict edges
against every other task in the plan. Count `N` = tasks with zero conflicts against
anything, over `M` = total task count.

**3. Always state the ratio.** Report it verbatim in the plan-completion message to
the human, regardless of how low or high it is — this is the plan's own Rule 7
assessment note, and it satisfies global Rule 7's per-plan documentation requirement
automatically. Use this framing:

> "N of M tasks are safely parallel (no shared state); assessed against a ~30-agent
> ceiling per Rule 7."

Do this even when N is 0 or N equals M — the ratio is informational context for the
Execution Handoff choice below, never a gate that hides an option.

## Execution Handoff

After saving the plan, run the Parallelism Assessment above, then offer execution choice —
**always all three options**, regardless of the computed ratio:

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. [State the N of M
ratio from the Parallelism Assessment here.] Three execution options:**

**1. Subagent-Driven (recommended for serial/tightly-coupled plans)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**3. Wave-Execution (recommended when the ratio above shows real parallelism)** - Package
the plan's tasks into a `wave-execution` spec_root and run them as parallel waves of
sub-agents, gated per wave

**Which approach?"**

Never threshold-gate which of the three appear — the ratio informs the choice, it never
decides it. Offer all three every time, even when the ratio is 0 of M.

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review

**If wave-execution chosen:**
- **REQUIRED SUB-SKILL:** Use wave-execution

Package this plan's tasks into a `wave-execution` spec_root, then run it. Follow this
procedure in full — it is deterministic, run it exactly as written:

1. **Level the conflict graph into waves.** Using the conflict graph from the
   Parallelism Assessment: each task's wave = `1 + max(wave of its dependency-edge
   predecessors)`; a task with no dependency-edge predecessors starts at wave 1.

2. **Check for same-wave file conflicts.** After leveling, check same-file conflicts
   that have NO dependency edge between them (pure file collisions with no logical
   ordering). If two same-file-conflicting tasks land in the same wave, bump the
   later-numbered task (by the plan's original Task N ordering) to the next wave.

3. **Cascade the bump — never decreasing.** A bump changes that task's wave, so
   recompute the wave of every task that `Consumes` one of the bumped task's
   `Produces` entries: new wave = `max(its current wave, 1 + max(wave of its
   dependency-edge predecessors))`. Take the max against the task's own current wave —
   never overwrite outright — so a wave number can only ever go up, never down. This
   may bump further downstream consumers in turn; keep cascading until it settles.

4. **Iterate to a combined fixed point.** Re-run the same-file-conflict check again
   (step 2) — the new waves from step 3 can produce new same-wave collisions — then
   re-cascade (step 3) if it does. Alternate the two passes (file-conflict-bumping,
   dependency re-leveling) until one full round of both changes nothing. This
   terminates: task count is finite and every bump only increases a wave number, so
   the process cannot cycle.

5. **Compact wave numbers for contiguity.** The fixed point's used wave numbers may
   have gaps (e.g. {1, 2, 4} with wave 3 empty, if a bump skipped past it). Renumber
   the used set into a contiguous `1..W'` range, preserving relative order (in the
   example, wave 4 becomes wave 3). `wave-execution`'s own preflight rule 4 requires
   contiguous `1..W` numbering — do this compaction before writing anything out. Only
   after compaction is the wave assignment final.

6. **Assemble the spec_root.** Each task becomes exactly one `work_item` in its
   assigned wave. Each wave's `exit_criteria` comes from its tasks' own already-defined
   testable deliverables (the "run test, verify it passes" step every task already
   ends with). Each wave's `outputs` = the union of its tasks' `Produces` entries
   (these feed the next wave's `inputs`). Write this out following the exact `spec_root`
   contract in `wave-execution/references/spec-format.md` — read that file for the
   precise 6 required fields (`goal`, `inputs`, `work_items`, `agents`,
   `exit_criteria`, `outputs`), the Option A/B layout choice, and the preflight
   validation rules; do not re-derive the contract from memory here.

7. **Worktree-per-work_item, always.** Every task's Step 5 is a commit — and two
   tasks with zero file/interface overlap, dispatched concurrently in the same wave,
   would otherwise commit against the SAME shared working directory. So: each wave's
   `work_item` dispatch instructions must direct its sub-agent to unconditionally
   create its own nested worktree before executing any of its task's steps (including
   its own Step 5 Commit), via the raw command:
   ```bash
   git worktree add <repo>-worktrees/<slug> -b wt/<slug>
   ```
   **Do NOT invoke the `using-git-worktrees` skill by name for this step.** That
   skill's own Step 0 tells an agent already inside a linked worktree (the overall
   plan-execution run, per Rule 6, is already running inside one) to NOT create
   another worktree — "nested worktree inside an existing one" is one of its own
   listed Common Mistakes. That guard is written for a different case: one agent
   deciding whether it needs isolation from the outer workspace it was launched into.
   Here the case is sibling-vs-sibling isolation among multiple concurrent work_items
   that are all already nested inside one already-isolated outer worktree — invoking
   the skill by name would trip that Step-0 guard incorrectly and silently
   reintroduce the same-checkout hazard this mechanism exists to close. Issue the raw
   `git worktree add` command directly, unconditionally, every time — never route
   through the skill.

8. **Merge back at wave completion.** After a wave's `exit_criteria` passes, merge
   each work_item's worktree branch back into the plan's base branch — one at a time
   — before the wave is considered done, then remove each worktree once merged. "The
   plan's base branch" here means the branch already checked out in the outer Rule-6
   worktree the whole plan execution is running inside — not the repo's true
   default/main branch, which only gets updated later, once, via the separate
   `finishing-a-development-branch` flow, after this entire wave-execution run
   completes.

9. **Review the generated spec_root.** Dispatch the `doc-reviewer` skill (as-is,
   unmodified) against the generated spec_root. `doc-reviewer` pauses for a
   findings-review/approval decision between its Discovery and Resolution phases — it
   is not a silent auto-apply pipeline. Only apply the fixes that get approved.

10. **Verify the fixes.** After approved fixes are applied, dispatch the
    `fix-verifier` skill (as-is) to confirm they landed correctly. Only then is the
    spec_root ready to run.

**Residual risks (acknowledged, not fixed by this procedure):**
- Shared-external-resource conflicts (ports, dev servers, rate limits, lockfiles)
  aren't detectable from Files/Interfaces at all — this remains a plan-author judgment
  call, not something steps 1-10 automate.
- The merge-back's conflict-freedom guarantee rests entirely on each task's
  self-declared Files/Interfaces fields, never on the work_item sub-agent's actual
  diff — a task that touches an undeclared file could still surface a real git
  conflict during the one-at-a-time merge in step 8.
