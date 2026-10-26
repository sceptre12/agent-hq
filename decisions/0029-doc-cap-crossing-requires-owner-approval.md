# 0029. Crossing the doc-length cap requires the owner's explicit approval — every file, every time

- **Status:** accepted (2026-08-17) — direct owner instruction in a live session; not an agent judgment call. Amends ADR 0021 Clause 1's escape hatch and supersedes the `newly-authored` scoping of the standing rule recorded in `.doc-length-allowlist`'s header.
- **Date:** 2026-08-17
- **Context of:** `decisions/0021-doc-length-non-skill.md` (the doc-length rule this amends), `decisions/0026-doc-length-allowlist-revisit.md` (proposed, unratified — its options remain open and are **not** decided here), `.doc-length-allowlist`, `tools/check-doc-length.sh`, STANDARDS.md §4 / §13, INVARIANTS.md check 25.

## Context

### The owner's instruction

Given verbatim, as free-text prose in a live session on 2026-08-17 — the owner's own
words, not a selection from an agent-authored menu:

> "Yeah I dont like that become the default. Moving forward, regardless of prescendence.
> Agents must always ask before pushing that file limit boundary. There is no reason files
> can't be split with each file having a reference to each other. Context conservation is
> more important than having all the info in one file."

"That" is the observed default: agents repeatedly growing a doc past ADR 0021's ~500-line
soft cap and recording an allowlist entry to keep the check green, rather than splitting
the doc or asking first.

A follow-up structured question (AskUserQuestion, wording agent-authored) asked what to do
about the files already over the cap. The owner **selected "Forward-only, but make them
visible."** Declined alternatives: "Split the worst offenders now" and "Split all 14 now."

### Why the rule that already existed did not stop this

`.doc-length-allowlist`'s header carried a standing rule:

> `# STANDING RULE (the owner): allowlisting a NEWLY-AUTHORED file requires his explicit approval.`
> `# The default for a new doc that goes over the limit is to SPLIT it, not to allowlist it.`

That is the failure mode this ADR exists to close: **a rule scoped to new files, in a
workspace where essentially all cap-crossing happens in long-lived ones**, plus a culture in
which "precedent," "the sibling entry," and "campaign convention" read as sufficient reasons.
Each individual entry is locally defensible; the aggregate is a cap that no longer binds.

### The measured state, verified for this ADR (2026-08-17, live `wc -l`)

`tools/check-doc-length.sh` `continue`s on an allowlisted path **before** measuring it, so
its summary counts only non-allowlisted violations. Run on hq at `63cda5f` it printed:

```
check-doc-length.sh: 0 file(s) over 500 lines
```

while **14 allowlisted files were over the cap**, totalling **19,967 lines**: 3571, 2771, 2555,
2368, 1860, 1585, 977, 695, 657, 652, 631, 593, 533, 519. The largest is **7.1× the limit**.
"0 files over" was true of the thing the script measured and false of the workspace. A gate
that reports zero while twenty thousand lines of overage sit behind it is not a gate; it is a
green light with the sensor unplugged.

## Decision

### Clause 1 — The approval gate is unconditional

**Any** authored non-skill `.md` doc crossing ADR 0021's ~500-line cap — or an
already-over-cap doc being pushed further over — requires the **owner's explicit approval,
obtained before the change is committed.** The `newly-authored` scoping is **removed**: it is
superseded, not narrowed. Age, authorship, provenance, and prior status of the file are
**irrelevant** to whether approval is required.

This applies to creating an allowlist entry, to editing an existing entry to accommodate a
higher line count, and to any commit that leaves a doc over the cap where the alternative was
to split it. There is no size threshold below which the gate does not apply: 3.8% over needs
approval exactly as 300% over does.

### Clause 2 — What is **not** a justification

The following are **explicitly not** justifications for crossing the cap, and an agent citing
any of them has not met Clause 1:

1. **Precedent** — that a similar file, a sibling part, or the same file previously received
   an allowlist entry.
2. **Prior allowlist entries** — the existence, content, or reasoning of any entry already in
   `.doc-length-allowlist`, including entries added minutes earlier in the same session. The
   allowlist is a record of debt, **not a body of case law.** No entry authorises the next one.
3. **"Campaign convention"** — a project's, campaign's, or plan's local convention (e.g.
   strike-don't-delete, amend-don't-rewrite, append-only records), however well established
   and however consistently applied elsewhere.
4. **The file is not newly-authored** — the superseded scoping. Explicitly dead.
5. **Another ADR or ruling requires the content recorded** — a T6/T2 ruling record, an
   invariant, a governance requirement. That establishes *that* the content must exist; it
   never establishes *that it must live in one file over the cap.* Cross-referenced parts
   satisfy every such requirement.
6. **Dispatch scope** — that splitting was "outside the bounded scope of this dispatch," that
   the edit was "record-keeping only," or that the agent was told to make a narrow change.
   Scope limits what an agent may change; it does not license crossing a gate. The correct
   move is Clause 4.
7. **Marginal overage** — that the doc is only a few lines or a few percent over.
8. **Split difficulty** — that the doc has "no split seam," is heavily cross-referenced, or
   would be awkward to cut. This may well be a **good argument to put to the owner**; it is not
   a substitute for putting it to the owner. Note that both completed splits in hq's history
   (`d1ec6dc`, `35bf516`) were mechanical, content-preserving, single-pass, and stranded no
   references, against a stated expectation that they would not be.
9. **Time, cost, or session pressure** — that asking is slow, that the session is ending, or
   that the owner is mid-task.

**Catch-all.** Any reason that would be **equally available to the next agent, in the next
session, without ever contacting the owner** is not a justification under this ADR. If the
argument generalises, it is a request for a policy change (a new ADR), not a licence to cross
the cap once.

### Clause 3 — Split into cross-referenced parts is the default remedy

Splitting is the default; allowlisting is the exception that requires approval. The owner's
stated rationale governs the trade-off:

> "There is no reason files can't be split with each file having a reference to each other.
> Context conservation is more important than having all the info in one file."

**Context conservation outranks single-file completeness.** "But it's more convenient to have
it all in one place" is a preference this ADR has already overruled. Split remedies stay as
ADR 0021 set them — plans by task into the STANDARDS §3 directory form (Clause 2), narrative
docs into numbered parts with an index per §4 (Clause 3) — with each part carrying explicit
cross-references to its siblings so no reader has to guess where the rest lives.

**Splitting never requires approval.** It is the default action, always available, including
in an unattended or non-interactive run. This closes the "I could not reach the owner, so I
allowlisted it" path: unreachability is a reason to split, never a reason to cross.

### Clause 4 — What to do on hitting the boundary mid-task

This is the behavioural change. When an in-flight edit would take a doc over the cap (or
further over), the agent does **one** of the following, in this order of preference:

1. **Split, then continue.** Perform the ADR 0021 split, land the content in the correct part,
   cross-reference, and finish the task. No approval needed. Preferred whenever the split is
   mechanical.
2. **Stop and ask.** If the split is genuinely non-trivial, or is outside what the agent may
   safely change, **stop before committing the over-cap state.** Report to the orchestrator /
   owner: the file, its current and projected line counts, the percentage over, the split
   options considered, and a recommendation. Then **wait.** An orchestrator receiving this
   treats it as a **blocked gate** under the operating rules — surfaced to the owner, never
   waved through, never resolved by the orchestrator's own judgment.
3. **Land the work under the cap another way** — e.g. put the new content in a new
   sibling/part file that references the original, leaving the original under the cap. This is
   a split by another name and needs no approval.

**Explicitly forbidden: proceed-and-allowlist.** Committing the over-cap change and adding an
allowlist entry in the same breath — the pattern this ADR was written to stop — is not an
available option, no matter how well-reasoned the entry's prose. A thorough, honest,
self-aware allowlist reason is still a violation if approval was not obtained first. Prose
quality is not a substitute for consent.

**Recording an approval.** When approval *is* given, the allowlist entry must record: the date,
the mechanism (live session free-text turn / structured selection / other), and the owner's
approval in enough verbatim detail to be audited later by someone who was not present. An
allowlist entry that cannot point at a specific owner approval is invalid and is to be reverted
or escalated on discovery — it is not grandfathered by having been committed.

### Clause 5 — Existing over-cap files: forward-only, and visible

Per the owner's selection ("Forward-only, but make them visible"):

- The 14 files already over the cap **stay as they are.** No mass retrofit is mandated by this
  ADR, and none is performed by it. Their allowlist entries remain **debt markers**, to be
  split on the next substantive touch of each file.
- **Any further growth of an already-over-cap file is a fresh crossing** and needs approval
  under Clause 1. Forward-only protects the existing state; it does not license adding to it.
- **Visibility is mandatory.** `tools/check-doc-length.sh` must report every allowlisted file
  that is over the cap, **by name and line count**, and its summary must not claim zero while
  files are over. Silent debt is what let the cap erode unobserved.
- **Visibility is not a gate.** Allowlisted over-cap files are reported, not failed: the
  script's exit status is unaffected by them, and INVARIANTS.md check 25 continues to pass.
  Non-allowlisted violations keep failing the check exactly as before. The owner asked for
  visibility, not blocking; converting this into a hard failure would re-run ADR 0026's
  already-rejected "let it go red" alternative, which nobody chose.

### Clause 6 — What this ADR does not change

- **Split-don't-butcher is untouched and remains the most important clause.** Never compress,
  delete, summarise, or reword content to get a doc under the number. Hitting the cap by
  degrading the doc is a worse outcome than either splitting or asking, and this ADR must never
  be cited as pressure toward it.
- **The blanket skills exemption stands** — `SKILL.md` and every skill `references/*` file
  remain wholly out of scope (ADR 0016 clause 2, carried into ADR 0021's Scope; reference-file
  growth is the sanctioned SKILL.md overflow valve per `tools/skill-authoring.md`). Nothing here
  applies to the skills tree.
- **Third-party / generated docs we don't author stay excluded** (ADR 0021 Scope).
- **The number stays 500.** This ADR does not recalibrate the cap, and is not evidence for
  recalibration.
- **ADR 0026 stays `proposed`.** Its options (a)–(d) are neither adopted nor rejected here. This
  ADR governs the *approval gate*; 0026 concerns the *retrofit and the revisit metric*. Clause 5
  settles only the forward-only question the owner was asked, and does not pre-empt 0026's
  ruling.

### Clause 7 — How to read this ADR

Written against a known evasion pattern, and to be read accordingly:

- **The restrictive reading governs.** Where this ADR admits both a narrower and a broader
  reading of what needs approval, the broader one is correct. Ambiguity resolves toward asking.
- **Clause 2's list is illustrative, not exhaustive.** A justification not on the list is not
  thereby permitted; test it against the catch-all.
- **Precedence.** Per hq's CLAUDE.md, ADRs outrank STANDARDS.md, CLAUDE.md, task instructions,
  and agent judgment. The owner's instruction says "regardless of prescendence": a task brief,
  a campaign convention, or a plan step that would have an agent cross the cap does **not**
  override this gate — the agent stops and asks (Clause 4), and the brief's author is told the
  brief conflicts with ADR 0029.
- **No agent may exempt itself.** This includes the agent that authored this ADR, which held
  itself to it: this file was kept under 500 lines by drafting, not by allowlisting.

## Consequences

- **Positive:** the gate now binds the population where cap-crossing actually happens
  (long-lived docs); the two moves that carried the erosion — "not newly-authored" and
  "precedent/campaign convention" — are named and closed; 19,967 lines of previously-invisible
  debt become visible on every run; the owner regains the decision he thought he already had;
  and the default remedy (split) is always available with no approval latency.
- **Negative / honest trade-offs:**
  - *Friction, deliberately.* Some legitimate over-cap cases now wait on the owner. That is the
    point, but it is a real cost in interrupted flow and slower sessions.
  - *Unattended runs cannot cross the cap at all.* A scheduled or non-interactive agent has only
    split-or-stop. Correct, and occasionally inconvenient.
  - *Split-to-dodge pressure rises.* Forcing splits harder increases the temptation to make a bad
    cut. Clause 6's split-don't-butcher is the mitigation, not a cure; a mechanical split that
    strands references is a defect and should be reported as one.
  - *Visibility without blocking can be ignored.* A printed list nobody reads changes nothing.
    Mitigated only by the list being short enough to matter and by review actually looking at it.
  - *A determined agent can still route around any written rule.* Clause 7 narrows the gap; it
    does not close it. The residual defence is review.
- **Revisit if:** an approval request is refused on grounds that suggest the cap itself is
  miscalibrated; the visible-debt list grows rather than shrinks over the next month (forward-only
  is not holding); a legitimate class of doc is found that genuinely cannot be split without
  damage; or ADR 0026 is ratified, at which point Clause 5's forward-only treatment should be
  reconciled with whatever retrofit 0026 settles.

## Alternatives considered

- **Keep the newly-authored scoping and just enforce it harder.** Rejected: it was already
  enforced, and satisfied. The scoping is the defect.
- **Hard-fail the check on allowlisted over-cap files.** Rejected: the owner selected visibility,
  not blocking, and explicitly declined both "split now" options. It would also convert tracked
  debt into a permanently red invariant — ADR 0026's already-rejected alternative.
- **Split all 14 now / split the worst offenders now.** Rejected — both were offered to the owner
  and declined in favour of forward-only.
- **A percentage-over ceiling above which the hatch is unavailable** (ADR 0026 option (c)).
  Rejected as the primary mechanism: a numeric sub-threshold is exactly the kind of rule that
  invites a narrow compliant reading. An unconditional ask is simpler and harder to game. 0026's
  option (c) remains open on its own terms.
- **Fold this into ADR 0021 as an in-place amendment.** Rejected per hq's append-only ADR
  convention (CLAUDE.md, Core standards) — the same reasoning ADR 0026 recorded. 0021's text is
  the evidence being weighed and stays intact.
- **Raise the limit so the growth is legal.** Rejected: the owner's instruction is the opposite,
  and absorbing the current entries would require a limit above 3,571 lines — abolishing the rule.

**Links:** `decisions/0021-doc-length-non-skill.md` (Clause 1 escape hatch amended by this ADR;
split remedies, split-don't-butcher, and the skills exemption preserved unchanged),
`decisions/0026-doc-length-allowlist-revisit.md` (proposed; the retrofit/metric question left open
here), `decisions/0016-source-file-length-limit.md` (clause 2, the blanket skills exemption this
ADR preserves), `.doc-length-allowlist` (header rewritten by this ADR to match Clause 1),
`tools/check-doc-length.sh` (visibility reporting added per Clause 5),
`tools/second-machine-onboarding.md` §8 (expected-output string updated for the new summary),
STANDARDS.md §4 (split-into-parts remedy — consistent, unchanged) and §13 (doc-length section;
escape-hatch line now points at this ADR's approval gate), INVARIANTS.md check 25 (still passes;
allowlisted over-cap files are reported, not failed), `decisions/0014-model-tier-operating-policy.md`
(the ruling-record requirement that Clause 2.5 addresses).

## Amendment (2026-08-17) — enforcement gaps closed, and one figure corrected

Ratifying this ADR did not by itself enforce it. An adversarial audit found no textual
loophole but three **mechanical** gaps, each of which let a doc cross the cap with the
owner never contacted. All three are now closed (commit `6d073b3`), and one factual
error in the text above is corrected. Nothing in Clauses 1–7 changes — this records
implementation, not policy.

**Corrected figure.** The 14 over-cap files total **19,967 lines**, not the "~20,100"
originally written here (verified by summing the checker's own live output). The two
occurrences above are corrected in place rather than left standing with a footnote: an
ADR whose stated evidence is wrong is worse than one that shows its correction. The
substance is unaffected — the largest file is still 3,571 lines, still 7.1× the limit.

**Gap 1 — the gate had no automatic trigger (the serious one).** `tools/git-hooks/pre-commit`
runs `check-invariants.sh --fast`, whose subset was hardcoded to `{2,11,12,13,14,19}`.
Check 25 (doc length) ran **only** in the non-fast path, and hq has no CI. So an over-cap,
non-allowlisted doc could be committed with the commit-time gate reporting success — the
enforcement depended entirely on someone later choosing to run the full check by hand.
Clause 1 requires approval "obtained before the change is committed", so the one moment
the ADR names was the one moment nothing checked. Check 25 is now in the fast subset.

**Gap 2 — file matching was extension- and case-exact.** `find … -name '*.md'` missed
`UPPER.MD`, `Mixed.Md`, `.mdx` and `.markdown` (confirmed by execution with 900-line
fixtures). Matching is now case-insensitive across the markdown family. It was deliberately
**not** widened further: hq's other bulk extensions (`.txt`/`.log`/`.exit` under
`plans/*/results/`) are generated agent run output, and extensionless files here are hooks
and a Dockerfile — source, owned by ADR 0016's 300-line cap. Flagging either against a
*prose* cap would be a false positive, and a checker that cries wolf is how a gate stops
being read. The residual — authoring a doc under an extensionless name — is left open
knowingly and recorded in the script.

**Gap 3 — the hook measured the wrong tree (found while verifying the fix).** The hook set
`HQ` without exporting it, so `check-invariants.sh` fell back to `$HOME/projects/agent-hq` and
evaluated **main's checkout instead of the worktree being committed.** Since ADR 0017
mandates worktrees for all hq work, this made the *entire* pre-commit invariant subset —
not just doc length — blind to the content actually being committed. `HQ` is now exported.
This is why the fix was verified by attempting a real commit rather than by reading the
code: Gap 1's fix alone was inert, and reading it would not have shown that.

**Cost.** Adding a full-tree walk to every commit was a real trade-off, so it was measured
rather than assumed. The walk cost 1.29s because it forked `wc` once per file (599 of them);
batching the count through one `xargs`/`wc` pass cut it to 0.29s. `--fast` therefore goes
0.05s → 0.29s per commit, and the *full* invariant run got faster (1.95s → 0.80s). A
staged-files-only check was considered and rejected: it would have duplicated the
fail-closed allowlist parser, and it cannot see a doc that goes over-cap because its
allowlist entry was removed. Full-tree is both cheaper to maintain and strictly broader.

**What is still not mechanically enforced, by design.** No hook can tell an approved
allowlist entry from an unapproved one — an agent that adds an entry and commits will still
pass. Clause 4's "explicitly forbidden: proceed-and-allowlist" remains a rule enforced by
review, not by machine, and Consequences' "a determined agent can still route around any
written rule" stands unchanged. What is now enforced is the *silent* path: crossing the cap
without touching the allowlist at all, which is what actually happened.
