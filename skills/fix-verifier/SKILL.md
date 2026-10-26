---
name: fix-verifier
version: 1.1.0
description: >
  Fast, single-agent gate that verifies a fix (a targeted correction just applied by
  another agent) before routing to the next review rung or merging — runs 5 targeted checks
  against only the changed files and returns CLEAN or ISSUES_FOUND in under 60 seconds. No
  swarm bus, no waves, no quorum. Use when a fix agent has fully completed and written its
  output to disk and you need a fast quality signal before merging or before dispatching a
  heavier review (doc-reviewer re-pass or panel-review), or when confirming a correction
  landed inside a fix-verify loop. Not for first-pass document review (use doc-reviewer) or
  for validating existing panel-review comments on a PR (use review-validator).
---

## Trigger

Use fix-verifier when:
- A fix agent has fully completed and written its output to disk.
- You need a fast quality signal before dispatching panel-review.
- You are inside a fix-verify loop and need to confirm a correction landed.

Do NOT use fix-verifier when:
- Reviewing a document for the first time — use doc-reviewer instead.
- The change set is the whole document rather than a targeted fix — use doc-reviewer.
- You need to validate existing panel review comments on a PR — use review-validator.
- You need full domain coverage across 14 checks — use doc-reviewer or panel-review.

**Two roles recur throughout this skill and are defined here, not elsewhere:** the **fix
agent** is whatever agent applied the correction being verified — a named fix-agent skill,
a corrective skill, or a general-purpose agent instructed to make the change; it is a role,
not a specific named skill. The **corrective agent** is the agent dispatched to address an
ISSUES_FOUND verdict — it may be the same fix agent re-prompted, or a dedicated corrective
skill; that choice belongs to the orchestrator.

**Differentiation:**
- vs doc-reviewer: doc-reviewer runs 14 checks against the whole document;
  fix-verifier runs 5 targeted checks against changed files only.
- vs review-validator: review-validator validates existing panel review comments;
  fix-verifier verifies a specific fix landed correctly.
- vs panel-review: panel-review is an 11-agent swarm with bus deliberation; fix-verifier is
  a single lightweight agent with no bus.

## Steps

1. **Validate input.** `changed_files` must be a non-empty list of absolute paths. If
   empty, return `{ "error": "changed_files must be non-empty", "verdict": null }` — not a
   findings result. Reject relative paths. Note whether `diff`, `related_files`, and
   `session_context` were supplied (see Input Contract below for what each enables).
2. **Canonicalize and compute the project root** before reading anything — see Security
   below for the exact order and marker precedence. Reject traversal attempts per Security.
2a. **Step 0 for `FILE_SET`** (only when `FILE_SET` is supplied; absent is valid and changes
   nothing). A malformed value prints one line per failing field, `INPUT-ERROR FILE_SET
   <reason>` (`missing|enum|path|unset|format`), then stops with no retry and no prompt and
   no verdict. An empty `FILE_SET=` is `format`; an entry that escapes the project root is
   `path`. Detail: `references/file-set-check.md`.
3. **Run the 5 checks sequentially** against `changed_files` (full spec for each below):
   Check 1 Internal Consistency, Check 2 Cross-Reference Symmetry, Check 3 Fix
   Completeness, Check 4 No New Orphan References, Check 5 Line Limit Compliance.
4. **Apply the loop-iteration rule** from Loop Integration below, using
   `session_context.iteration`.
5. **Assemble and return the Output Contract** exactly as specified below. Do not write
   files, execute shell commands, or dispatch agents at any point in this flow.

### Workflow Position (canonical routing statement)

```
panel-review (Phase B findings)
        |
        v
fix agent dispatched
        |
        v
fix agent modifies files → outputs changed_files + optional diff
        |
        v
fix-verifier (this skill) runs on changed files only
        |
        +--[CLEAN]-----------> dispatch panel-review (or next fix in queue)
        |
        +--[ISSUES_FOUND]----> dispatch corrective agent
                                        |
                                        v
                               fix-verifier runs again (iteration incremented)
                                        |
                               (Blocking finding appended at iteration 3, ISSUES_FOUND returned)
```

fix-verifier does not dispatch anything. It returns a verdict and finding list. The
orchestrator decides next steps. After two ISSUES_FOUND results (iteration ≥ 3),
fix-verifier surfaces a Blocking finding and the orchestrator halts the loop. This is the
one place this routing rule is stated — later sections reference it rather than restating
it.

**Sequencing invariant:** fix-verifier MUST be dispatched only after the fix agent has
fully completed and its output is written to disk. Dispatching concurrently with the fix
agent produces undefined results — changed files may be partially written.

Whichever agent applies the fix MUST be instructed to return `changed_files` (and
optionally `diff`) in its Agent tool response. The orchestrator reads these fields and
passes them to fix-verifier before dispatching. Fix-verifier cannot be dispatched without a
`changed_files` list.

### Input Contract

```json
{
  "changed_files":  ["<absolute path>", "..."],
  "diff":           "<unified diff string — optional but strongly recommended>",
  "fix_description": "<brief description of what the fix was supposed to do>",
  "related_files":  ["<absolute path>", "..."],
  "session_context": {
    "iteration": 1,
    "session_id": "<string>"
  }
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `changed_files` | Yes | Non-empty list of absolute paths the fix agent modified. Authoritative list of what to read. If empty, return error — not a verdict. |
| `diff` | No | Unified diff of the fix. Strongly recommended — enables Check 3 to detect partial application. Without it, Check 3 degrades to prose-level analysis only. If the fix is identified by a commit or commit range rather than a diff string, the ORCHESTRATOR extracts the diff (`git diff <pre>..<post> -- <files>`) before dispatch and passes it here — never instruct the verifier itself to run git; the verifier executes no shell commands (see Security). |
| `fix_description` | Yes | Used as context for Check 3. Without it the verifier cannot assess whether all required locations were updated. |
| `related_files` | No | Files referenced by or depending on changed_files. If omitted, verifier auto-discovers by parsing references in changed files. Auto-discovery is best-effort — orchestrators that know related files should supply them. |
| `FILE_SET` | No | Comma list of repo-relative paths, UPPER_SNAKE `FILE_SET=a.md,b.md`, per fixer (one fixer per worktree, or disjoint sets per fixer). When set, any `changed_files` entry outside the set is a Check 3 Medium finding. Absent = today's behaviour; empty or traversal = `INPUT-ERROR FILE_SET format|path`. `related_files` are not changes and are never counted. |
| `session_context` | No | Loop metadata. `iteration` MUST be incremented by the orchestrator each re-run. If absent or `iteration` missing, treated as iteration 1 and an Advisory finding is appended. |

All paths in `changed_files` and `related_files` MUST be canonicalized absolute paths.
Relative paths are rejected as invalid input.

### The 5 Checks

**Check 1 — Internal Consistency.** Read each changed file in isolation. Detect
self-contradictions introduced by the fix: a term defined two ways, a step listed twice
with different values, a table conflicting with prose in the same file. Produces Blocking
or Medium findings per contradiction found.

**Check 2 — Cross-Reference Symmetry.** For each changed file that references another file
(by path, anchor, section name, or contract name): verify the target still contains the
referenced thing. Resolution order: use `related_files` if supplied, otherwise
auto-discover by parsing references in changed files and reading those targets. Skip
external URLs and same-file anchor links; resolve relative paths against the directory of
the referencing file. Unreadable or missing targets appear in `files_not_checked`. Produces
Blocking or Medium findings for each broken reference.

**Check 3 — Fix Completeness.** Within `changed_files` only: verify the fix was fully
applied across all changed files. A term/value change is any identifier, string literal,
numeric constant, path, or key name modified in the diff. With `diff` supplied: compare all
term/value changes extracted from the diff against all occurrences in changed_files
content, and flag any occurrence not updated. Without `diff`: use `fix_description` as
context and analyze changed files for evidence the described change was applied
consistently — prose-level analysis only, may miss partial applications. Scope is
`changed_files` only; files that should have been modified but are absent from
`changed_files` are out of scope — the verifier has no mechanism to detect these. Produces
Blocking findings for confirmed partial application, Medium for suspected incomplete
application without diff evidence.

**Check 4 — No New Orphan References.** After the fix, verify no file in the changed set
references a section, anchor, path, or contract name that no longer exists. Extract from
each changed file: Markdown links, backtick-quoted paths, `# Heading` references; verify
each target exists on disk. Same skip rules as Check 2. Produces Blocking findings for
confirmed orphan references.

**Check 5 — Line Limit Compliance.** Skip this check entirely for any changed file under a
`skills/` directory — both of hq's line-length ADRs exempt the skills tree wholesale (ADR
0016 `decisions/0016-source-file-length-limit.md` clause 2; ADR 0021
`decisions/0021-doc-length-non-skill.md` Scope). For every other changed file, apply hq's
own documented default for that file type instead of a flat number: non-skill `.md` docs
default to ≤~500 lines (ADR 0021 Clause 1 — a soft default, not a hard cap); source code we
author defaults to ≤~300 lines (ADR 0016 — same soft-default shape). A file over its type's
default does not block the fix: both ADRs explicitly reject a hard blocking cap (see each
ADR's "Alternatives considered" — no prose number is a validated defect threshold, and a
hard block invites the exact gaming split-don't-butcher exists to prevent). Flag it as
Advisory, recommending the file be split — or, if it genuinely belongs together, recorded on
the relevant `.file-length-allowlist` / `.doc-length-allowlist` with a reason — never
Blocking on this check alone.

**Check 3, file-set scope (only when `FILE_SET` is supplied).** Canonicalize each
`FILE_SET` entry against the project root, then compare with the canonicalized
`changed_files` (set comparison, no shell). Every changed file outside `FILE_SET` yields
one finding: `check: "3"`, severity Medium, `file` naming it, so the verdict is
`ISSUES_FOUND`. `recommended_fix`: the lead widens `FILE_SET` or the fixer reverts that
file. Files all inside the set add no finding. Detail: `references/file-set-check.md`.

### Output Contract

```json
{
  "verdict":           "CLEAN" | "ISSUES_FOUND",
  "findings":          [],
  "files_checked":     ["<absolute path>", "..."],
  "files_not_checked": ["<absolute path> — <reason>", "..."],
  "session_context":   {}
}
```

**Verdict rule:** `CLEAN` only when `findings` contains zero Blocking or Medium items.
Advisory findings do not block — they are surfaced for awareness and do not trigger a
corrective dispatch.

**Exception:** a timeout (check-0 Advisory finding) always produces `ISSUES_FOUND`
regardless of severity, to prevent routing a partial result to panel-review as if the
verifier ran cleanly.

**A finding object:**

```json
{
  "check":       "0" | "1" | "2" | "3" | "4" | "5",
  "severity":    "Blocking" | "Medium" | "Advisory",
  "description": "<what is wrong>",
  "file":        "<absolute path of the changed file>",
  "recommended_fix": "<what the corrective agent should do> | null"
}
```

`check: "0"` is reserved for system-level findings (timeouts, internal errors, loop
protection). The producer is the verifier itself, not the orchestrator.

**`files_not_checked`** lists any files skipped, each annotated with exactly one of these
four reason strings — each maps to exactly one condition, no overloading:
- `out of scope — not in changed_files` — file listed in `related_files` but not in
  `changed_files`.
- `access error — file not found` — file in `changed_files` but unreadable.
- `access denied — outside project root` — a `related_files` entry (or auto-discovered
  reference) that legitimately resolves outside the project root; this is the benign case.
- `access denied — path traversal attempt` — a path that only resolves outside the project
  root after canonicalization is applied (see Security) — the traversal-rejection case,
  distinct from the benign case above.

A non-empty `files_not_checked` is a partial result. The orchestrator decides whether to
proceed or re-run with corrected paths.

**`session_context`** is echoed verbatim from input — the verifier does not mutate it.
Orchestrators use the echoed `iteration` value to enforce the max-iterations rule without
tracking state externally.

### Agent Model

**Single synchronous agent. No swarm bus. No waves. No quorum.**

- Invoked via the Agent tool (not CLI subprocess — `claude -p` is not supported).
- Agent reads changed files, reads related files (supplied or discovered), runs the 5
  checks sequentially, returns the output schema in its response.
- Agent does not write to disk, does not dispatch agents, does not start a swarm bus.

**Run time target:** under 60 seconds for 1–5 changed files (~10 seconds per file for read
+ check).

**Timeout:** 90 seconds (1.5× the 60-second target, allowing for slow file access). If the
skill has not returned within 90 seconds, the orchestrator treats the result as
`ISSUES_FOUND` with a single check-0 Advisory finding:

```json
{
  "check": "0",
  "severity": "Advisory",
  "description": "fix-verifier timed out after 90 seconds — manual verification required",
  "file": "",
  "recommended_fix": "Re-run fix-verifier or proceed directly to panel-review"
}
```

Do not block the loop on a timed-out verifier.

### Loop Integration

The orchestrator manages the fix-verify loop. fix-verifier participates via
`session_context.iteration`.

| Iteration | Behavior |
|-----------|----------|
| 1 | Normal run. No special behavior. |
| 2 | Normal run. No special behavior. |
| ≥ 3 | Append the Blocking finding below. Verdict is ISSUES_FOUND regardless of other findings. (Two ISSUES_FOUND results means the third run is iteration 3 — this is the escalation trigger.) |

```json
{
  "check": "0",
  "severity": "Blocking",
  "description": "Max iterations reached — manual review required",
  "file": "",
  "recommended_fix": "Escalate to manual review or change the fix strategy"
}
```

**Missing session_context:** if `session_context` is absent or `iteration` is missing,
treat as iteration 1 and append:

```json
{
  "check": "0",
  "severity": "Advisory",
  "description": "session_context.iteration not provided — loop protection disabled",
  "file": "",
  "recommended_fix": "Pass session_context.iteration from the orchestrator on each re-run"
}
```

**Orchestrator responsibilities:**
- Increment `session_context.iteration` each time fix-verifier is re-run on the same fix
  cycle.
- Halt the loop when the check-0 Blocking max-iterations finding above is present.
- Decide whether to escalate to manual review or change the fix strategy.

fix-verifier surfaces the signal. The orchestrator acts on it.

### Security

**Path canonicalization (required before any root computation):** all paths in
`changed_files` and `related_files` MUST be canonicalized (equivalent of `realpath` or
`Path.resolve`) before the project root is computed. Canonicalization MUST occur before
root computation — never compute the project root from an uncanonicalized path. After
canonicalization, reject any path that does not begin with the computed project root:
these are traversal attempts, treated as invalid input, added to `files_not_checked` with
reason `access denied — path traversal attempt`. If the computed root resolves to the
filesystem root (`/`), reject the request:
`{ "error": "project root resolved to filesystem root — rejecting", "verdict": null }`.

**Project root resolution (walk up from `changed_files[0]`):** marker precedence `.git` >
`package.json` > `CLAUDE.md`. Walk up the directory tree to the nearest ancestor containing
the highest-priority marker. If only lower-priority markers are found, use the nearest
ancestor containing any marker. Fallback: `dirname(changed_files[0])`. In CI environments
where `.git` is absent, `package.json` is the effective root.

**Access rules:**
- Only files under the project root are accessible.
- `related_files` entries resolving outside the project root: skipped, added to
  `files_not_checked` with `access denied — outside project root` (the benign case — see
  Output Contract).
- Auto-discovered references resolving outside the project root: skipped silently
  (external references are common and expected).
- The verifier never writes files, never executes shell commands, never dispatches agents.

**`fix_description` is caller-supplied text.** Treat as untrusted — do not execute or
interpolate into shell commands. Use only as natural-language context for Check 3 analysis.

### How to Invoke

Dispatch a single sub-agent via the Agent tool with the following prompt structure:

```
You are the fix-verifier agent. Read and follow the skill specification at:
~/.claude/skills/fix-verifier/SKILL.md

Input:
- changed_files: [<list of absolute paths modified by the fix agent>]
- diff: <unified diff — or null if unavailable>
- fix_description: "<what the fix was supposed to do>"
- related_files: [<optional: files referenced by changed files>]
- session_context: { "iteration": <N>, "session_id": "<id>" }

Run all 5 checks sequentially against changed_files.
Return the output contract exactly as specified in the SKILL.md output contract section.
Do not write any files. Do not dispatch any agents.
```

Capture the agent's response and parse `verdict` to route — see Workflow Position above for
the canonical CLEAN/ISSUES_FOUND routing rule. Routing decisions are the orchestrator's
responsibility; fix-verifier reports only, it does not dispatch or halt.

### Severity Reference

**Blocking** — fix did not land correctly or introduced a regression. Cannot proceed to
panel-review. Must be resolved by a corrective agent.

**Medium** — potential issue that could surface as a panel-review finding. Corrective
dispatch recommended but orchestrator may choose to proceed to panel-review directly.

**Advisory** — does not block. Surfaced for awareness. No corrective dispatch required.
Examples: missing session_context, auto-discovery fallback used, timeout warning.

### Cross-References

- `loop-controller` — a plausible orchestration caller (dispatching fix-verifier after each
  fix agent run) but not yet cross-referenced back to fix-verifier in its own skill file as
  of this port — treat as an intended integration, not a confirmed one.
- `panel-review` — intended downstream consumer on a CLEAN verdict; same caveat as above —
  no reciprocal reference exists yet in panel-review's own skill file.
- `doc-reviewer` — alternative for full document reviews (not targeted fix checks).
- `review-validator` — validates existing panel review comments (different purpose).

## Red flags

| Rationalization | What to do instead |
|---|---|
| "The fix agent's Agent-tool response format is whatever it happens to return." | It MUST include `changed_files` (and ideally `diff`) — instruct whichever agent applies the fix to return this explicitly; fix-verifier cannot be dispatched without it. |
| "No diff was supplied, but Check 3 can still confirm the fix fully landed." | Without a diff, Check 3 is prose-level analysis only and may miss partial application — say so in the finding rather than reporting false confidence. |
| "This is a full document, but it's a small change — run fix-verifier instead of doc-reviewer." | fix-verifier only covers `changed_files`, not the whole document; a full first-pass review belongs on the review ladder (`tools/review-ladder.md`) at doc-reviewer (Rung 1) or above, not here. |
| "It's iteration 4 of the loop, but the fix is close — just run fix-verifier again." | At iteration ≥ 3, append the Blocking max-iterations finding and return ISSUES_FOUND regardless of other findings; the orchestrator halts, it does not keep re-running. |
| "A `files_not_checked` entry showed up, but the rest looks clean — call it CLEAN." | A non-empty `files_not_checked` is a partial result; surface it and let the orchestrator decide whether to proceed or re-run with corrected paths. |
| "The verifier timed out, but the checks that did finish were clean." | A timeout always produces ISSUES_FOUND via a check-0 Advisory finding, regardless of what finished — never let a partial run look like a full CLEAN pass. |
| "The extra file edit was needed for the fix, treat it as inside the set." | Report it: a change outside `FILE_SET` is a Check 3 Medium finding and `ISSUES_FOUND`. The lead widens `FILE_SET` or the fixer reverts. |

## Exit criteria

- [ ] All 5 checks ran sequentially against `changed_files` only (no scope creep into files
      outside the input contract).
- [ ] `verdict` is `CLEAN` only if `findings` contains zero Blocking or Medium items, and a
      timeout always forces `ISSUES_FOUND` regardless of severity.
- [ ] Every `files_not_checked` entry uses exactly one of the four canonical reason strings
      (Output Contract), with no overloaded meanings.
- [ ] `session_context` is echoed verbatim, and the iteration ≥ 3 Blocking finding is
      appended when applicable.
- [ ] No file was written, no shell command executed, no agent dispatched by fix-verifier
      itself — it reports only.
- [ ] When `FILE_SET` is supplied: it was validated first (`INPUT-ERROR FILE_SET <reason>` on
      failure), and every `changed_files` entry outside it has one Check 3 Medium finding.
      When absent, output equals the unmodified skill.

## Provenance
Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md; the recorded port friction)
Lineage: X-context-docs skills/fix-verifier@0e9281e
Extension: v1.1.0 adds the FILE_SET input (M24, D6); the v1 class_sweep proposal is dropped (D54 and D58 are advisory).
