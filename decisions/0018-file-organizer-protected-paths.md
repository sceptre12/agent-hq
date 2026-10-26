# 0018. file-organizer protected paths (legal-export safety invariant)

- **Status:** accepted
- **Date:** 2026-07-12
- **Context of:** file-organizer

## Context

`~/Documents` contains a `DIV-Divorce/` folder tree with multiple subfolders that form an
intentional legal-discovery export: a point-in-time snapshot pulled for a legal proceeding,
not an organic filing tree. The owner's scan found 389 duplicate groups in the Discovery
subfolder — these are **deliberate copies**, an artifact of how legal exports are produced,
not filing mistakes for `fileorg` to clean up. `fileorg` (`architecture/file-organizer.md`)
is gaining verbs beyond `place` (dedup, reorganize, junk-sweep) that read the whole
`~/Documents` tree and act on what they find. Without an explicit guardrail, a future verb
reasoning generically about duplicates or clutter would "correct" this tree — moving,
merging, or deleting exhibits from a legal record. That is not a filing bug; it is data
loss with legal consequences.

## Decision

We will add a `"protected"` list to `codes.local.json` (Layer 2). The live protected list
includes all discovery-related subfolders beneath DIV-Divorce:
- `DIV-Divorce/Discovery`
- `DIV-Divorce/GAL`
- `DIV-Divorce/Evidence`
- `DIV-Divorce/Court Transcripts`
- `DIV-Divorce/Custody`
- `DIV-Divorce/Communications`
- `DIV-Divorce/Financials`
- `DIV-Divorce/Separation`

**No `fileorg` verb — present or future (`place`, `dedup`, `reorganize`, `junk-sweep`,
or any verb added later) — may move, write, or delete anything inside a protected path**,
and `place` must never land a newly-classified file inside one, even as a placement target.
This is a structural invariant enforced by the tool itself, not a documentation note or an
operator convention to remember. **Note:** the `DIV-Divorce` root folder itself is
intentionally left unprotected and writable, so new documents can be filed there
temporarily; cross-tree duplication between root and subfolders is by design. Paired with
this decision: **duplicate existence never suppresses placement.** A loose file whose
`content_hash` matches a file already sitting inside a protected/legal tree is still a
distinct original on disk — `fileorg` files it normally at its own computed destination
(optionally tagging it `dup-of-protected` for information). It is never skipped or
merged away on the theory that "it already exists elsewhere" — inside a legal export,
that theory is exactly wrong.

**Match semantics (2026-07-13 — resolves doc-review ambiguity):** a path is "inside" a
protected path when the protected path equals it or is an ancestor directory of it,
compared segment-by-segment (subtree-prefix at path-segment boundaries) — so
`DIV-Divorce/Discovery` protects itself and everything beneath it, but not a sibling
like `DIV-Divorce/DiscoveryNotes`. Entries in `"protected"` are interpreted relative to
the Documents root. Matching is case-insensitive — conservative for a legal guardrail,
and consistent with APFS's default case-insensitivity.

## Reasoning

- The failure mode is asymmetric: an over-eager dedup/cleanup verb can destroy legal
  evidence in one run; a slightly less-tidy `Discovery` folder costs nothing. The rule is
  written to fail toward inaction inside protected paths.
- Scoping the guardrail to a config-driven path list (not a hardcoded `DIV` special
  case) keeps it generic — any future legally- or otherwise-sensitive tree can be
  protected the same way, and the mechanism lives in Layer 2 alongside the rest of the
  personal, non-synced configuration (§2 of the architecture doc, file-organizer-01.md).
- Making it binding on "any verb, present or future" — rather than auditing each new verb
  for this concern as it ships — means the invariant can't be silently dropped by an
  implementation that forgets to check it; it is the kind of rule that must be enforced
  once, centrally, not re-derived per verb.

## Consequences

- Easier: every future verb inherits the same guardrail from one config-driven check
  instead of re-solving "is this safe to touch" per verb; protecting a new sensitive tree
  is a one-line config edit, not a code change.
- Trade-off accepted: `Discovery`'s 389 duplicate groups stay on disk uncollapsed
  indefinitely (by design — they are not filing debt to pay down) and any loose file that
  happens to duplicate protected content still gets filed as a normal original, so exact
  duplicates can persist by design outside the protected tree too.
- Revisit if: a legitimate need arises to reorganize *within* a protected path (e.g. the
  legal matter closes and the export is later reclassified as ordinary filing) — that
  would be a deliberate one-time removal from the `protected` list, not a code change.

## Alternatives considered

- **Hardcode the `DIV-Divorce/Discovery` exemption in `fileorg`** — rejected: brittle
  (breaks if the folder is renamed), not reusable for other sensitive trees, and mixes a
  personal path into Layer-1 generic code (violates the PII boundary in §2 of the
  architecture doc, file-organizer-01.md).
- **Rely on operator discipline (never run destructive verbs near `Discovery`)** —
  rejected: the whole point of `fileorg` owning all moves is that no other safeguard is
  load-bearing; a convention that depends on remembering is exactly the gap a structural
  invariant closes.
- **Suppress placement of duplicates of protected files** — rejected: conflates
  "duplicate exists" with "should not be filed," which is false for a legal export by
  construction — every copy there is intentional, so the signal doesn't mean what it
  normally means.
