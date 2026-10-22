---
name: review-validator
description: >
  Triages an existing automated review's comments on a PR into what's genuinely actionable
  vs. false positive, duplicate, or opinion-only noise, then produces (and, on confirmation,
  posts) a clean Valid / Needs-Verification / Invalid report. Use when a PR already carries
  one or more automated review comments and you need a distilled "here's what you actually
  need to fix" view before the author acts on it, or when you suspect some findings are
  false positives, duplicates, or pure opinion. This is a downstream companion to the
  review-escalation ladder (tools/review-ladder.md), not a rung on it — it validates an
  existing review's output rather than generating one. For a fresh, fuller automated review
  (not just triage of one that already exists), escalate to panel-review instead (Rung 4).
  For a routine single-artifact review with no
  existing automated comments to triage, use doc-reviewer instead (Rung 1).
disable-model-invocation: true
---

## Trigger

Use when a PR already has one or more automated review comments and you need to separate
what's genuinely actionable from false positives, duplicates, or opinion-only advisory
noise — the author wants a distilled "here's what you actually need to fix" view.

Detection: any automated-review comment on the PR qualifies (bot-authored review comments,
or bodies with a findings/severity table). Legacy markers inherited from source —
'🤖 Automated panel review', '## Combined Review', '## Panel Review', '## Code Review
Panel' — are confirmed produced by NO current sibling (pr-review's synthesizer emits a chat
Phase B report, panel-review posts no PR comments); treat them as historical, not as the
gate.

**Resolved 2026-07-21:** detection relaxed to match any automated-review comment (see
above) rather than requiring pr-review to emit specific markers — see hq
Hermes skill `retros/2026-07-21-imported-skills-performance-eval-03` (was retros/2026-07-21-imported-skills-performance-eval-03.md).

This skill is a downstream companion to the review-escalation ladder
(`tools/review-ladder.md`), not one of its numbered rungs — it triages an existing review's
output rather than generating a review itself. If there's no existing automated review
comment to triage yet and the need is a routine single-artifact review, use doc-reviewer
instead (Rung 1). If the need is a fresh, fuller automated review — not just triage of one
that already exists — escalate to panel-review instead (Rung 4).

## Execution Model

Steps 1, 2, 5, 6 are mechanical (fetch, parse, format, post) and are candidates for
delegation to a cheaper model. Steps 3–4 require reading the diff and applying judgment —
do not delegate those.

If delegating the mechanical steps, dispatch via the Agent tool with an explicit model pin
per `tools/model-routing.md` (Rule 3/4) — state a verifiable done condition and a
stop-on-anomaly clause. Do not shell out to a nested `claude -p` CLI subprocess: hq's
dispatch convention doesn't support that path (fix-verifier's port settled this exact
question the same way — see its "Agent Model" section).

## Steps

1. **Fetch the diff and existing reviews.**
   ```bash
   gh pr diff <number> --repo <owner>/<repo> > <scratch-path>   # e.g. /tmp/pr-<number>-diff.txt
   gh api repos/<owner>/<repo>/issues/<number>/comments --jq '.[].body'
   gh api repos/<owner>/<repo>/pulls/<number>/reviews --jq '.[].body'
   ```
   `<scratch-path>` is illustrative — use whatever temp/scratch convention the running
   environment provides.

2. **Parse findings.** Extract every finding from each automated review comment. Look for:
   - Table rows with Blocking / Medium / Advisory in them.
   - Numbered findings in `## Findings` sections.

3. **Validate each finding against the diff** (requires judgment — do not delegate). For
   each finding:

   | Question | If NO → |
   |----------|---------|
   | Can you point to a specific file + line in the diff? | Likely invalid |
   | Does the file/path actually exist in the diff? | Invalid (hallucinated path) |
   | Does the code shown actually appear in the diff? | Invalid |
   | Is there a concrete fix, not just "consider refactoring"? | Advisory only |
   | Is this a runtime/correctness issue vs. a style preference? | Downgrade to Advisory |
   | Was this issue introduced in this PR (not pre-existing)? | Flag as pre-existing |

4. **Classify** each finding (requires judgment — do not delegate):
   - **VALID** — confirmed against the diff, concrete fix exists, real impact.
   - **NEEDS VERIFICATION** — plausible but requires author context to confirm.
   - **INVALID** — false positive, hallucinated file, opinion-only, duplicate, or
     pre-existing.

5. **Display the full validated report in chat before posting anything**, using the Output
   Format below, so the engineer running the skill can review it first.

6. **Only after the engineer explicitly confirms the Step 5 report**, post it to the PR:
   ```bash
   gh pr comment <number> --repo <owner>/<repo> --body "..."
   ```
   Do not chain Step 5 → Step 6 automatically. The confirmation is the point of Step 5, not
   a formality — an unconfirmed report does not get posted.

## Output Format

```markdown
## Review Validation — PR #[N] — [title]

### ✅ Valid Findings (Action Required)
| # | Original Finding | Severity | Confirmed Evidence | Action |
|---|-----------------|----------|-------------------|--------|

### ⚠️ Needs Author Verification
| # | Finding | Why Uncertain | What to Check |
|---|---------|--------------|---------------|

### ❌ Invalid / False Positive
| # | Original Finding | Why Invalid |
|---|-----------------|-------------|

---
**Net actionable items: X Blocking · Y Medium**
🤖 Review Validator
```

Advisory-severity VALID findings are intentionally excluded from the "Net actionable items"
tally (they still appear in the Valid Findings table) — the tally counts Blocking/Medium
only.

## Common False Positive Patterns

| Pattern | Why Invalid |
|---------|-------------|
| "This function is undocumented" | Advisory opinion, not a bug |
| "Consider extracting to shared utility" | Future suggestion, not actionable |
| Semver violation claim without checking actual version bump type | Verify package.json version before claiming |
| "Missing test" for a case that doesn't exist | Verify test scope matches actual code paths |
| Security finding on `console.log` without actual secrets | Not a security issue |
| Completeness finding where the "missing" case genuinely doesn't apply | Check if parallel case exists |
| Finding references a file path not in the diff | Hallucinated — mark INVALID |
| Same issue reported under multiple check IDs | Mark duplicates, keep the clearest one |
| Finding about pre-existing code not touched by this PR | Flag as pre-existing, not blocking |

## Network Unavailable

This skill's mainline steps make outbound calls via the `gh` CLI: `gh pr diff`, `gh api`
(x2 — issue comments and review bodies), and `gh pr comment` to post the triage report.

**Primary path (interactive):** if connectivity is unavailable, do not attempt any `gh`
call. Tell the engineer running the skill that validation could not complete and suggest
retrying once connectivity is restored.

This skill also carries the corpus-wide Network-Unavailable template (from the not-yet-
ported `network-check` skill) for parity with every other skill that makes outbound calls,
in case of future unattended invocation: log `[SKIPPED] network unavailable —
review-validator skipped` and exit 0 in script contexts (a non-zero exit would flip a
launchd-tracked service unhealthy for what was an intentional skip). As of this port,
though, review-validator is not listed among network-check's own "launchd apps"
integration — only among its "skills with outbound calls" — so treat the script/launchd
branch as forward-compatible, not a confirmed unattended path today.

**Connectivity pre-check:** run the connectivity pre-check at
`~/.claude/skills/network-check/scripts/check-network.sh` (exit 0 = reachable, exit 1 =
unreachable) before any `gh` call.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "There's no automated review on this PR yet, but I'll run review-validator anyway to get one." | review-validator triages an EXISTING review's output — it doesn't generate one. If there's nothing to triage, use doc-reviewer (Rung 1) for a routine review, or escalate to panel-review (Rung 4) for a fresh one. |
| "The report looks fine in chat, post it now." | Step 6 posts only after the engineer running the skill explicitly confirms the Step 5 report — don't chain Step 5 → Step 6 automatically; that defeats the reason Step 5 renders in chat first. |
| "The detection markers matched something, so this is a real automated review." | These marker strings aren't confirmed to be produced anywhere in the currently-ported skill set (see the Trigger caveat) — a string match isn't proof of provenance; if the source looks off, say so rather than trusting the match. |
| "No diff line for this finding, but the panel usually gets it right — count it VALID." | Step 3's six questions are diagnostic, not optional; a finding that fails "can you point to a specific file+line in the diff" is INVALID or NEEDS VERIFICATION, not VALID by default. |
| "It's just a style opinion, but it sounds urgent — keep it Blocking." | A concrete fix AND a runtime/correctness impact are both required for VALID; style-only or vague "consider" language downgrades to Advisory regardless of tone. |

## Exit criteria

- [ ] Every finding in the source review comment(s) was extracted (Step 2) and run through
      the six-question validation table (Step 3).
- [ ] Every finding is classified VALID / NEEDS VERIFICATION / INVALID (Step 4), each with
      confirmed evidence, an uncertainty reason, or an invalidity reason respectively.
- [ ] The full report was displayed in chat (Step 5) BEFORE any post to the PR.
- [ ] The engineer running the skill explicitly confirmed the report before Step 6 posted
      it — no automatic chaining from Step 5 to Step 6.
- [ ] The posted report's "Net actionable items" tally counts Blocking/Medium only;
      Advisory-valid findings appear in the table but are excluded from the tally.

## Provenance
Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md; the recorded port friction)
Lineage: X-context-docs skills/review-validator@0e9281e
