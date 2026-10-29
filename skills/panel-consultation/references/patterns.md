# Learned failure patterns (A through F)

Six shapes of failure from real execution on a past multi-runtime container-infrastructure
project. They are kept as historical case studies, not as a description of any current project.
When a situation rhymes with a signature below, the seat tagged on it raises the prevention rule
as a finding on its own topic (or a C-NOTE on another seat's topic), regardless of whether the
specific tools match. Absence of a match is not a clean bill of health: say "checked, no
match", never "clean". Patterns compound; one artifact can hit several.

| Pattern | Name | Seat that checks it |
|---|---|---|
| A | Orphaned convention file | `platform-engineer` (seat 6) |
| B | Cross-contract value drift | `integration-architect` (seat 2) |
| C | Assumed cross-runtime uniformity | `platform-engineer` (seat 6) |
| D | Undocumented base-image module API | `platform-engineer` (seat 6) |
| E | Accumulated context blindness | `cold-reader` (seat 1) |
| F | Unverified codebase assumptions | `fact-checker` (seat 3) |

## Pattern A: Orphaned convention file (spec gap)

- **Signature:** an agent creates a file that is standard for the runtime but is not used by the
  actual build or deploy mechanism. Watch for any place where "the normal way" for a runtime
  diverges from the project's real pipeline.
- **Case:** a Python agent wrote a `requirements.txt` listing all packages; no Dockerfile read
  it, because each layer installed packages with explicit commands.
- **Prevention rule (default, carried from v1):** when a task spec targets a runtime with strong file conventions (Python
  requirements or pyproject, Node package.json, Rust Cargo.toml), the spec states which
  convention files are in scope and which are NOT to be created.

## Pattern B: Cross-contract value drift (feedback-loop gap)

- **Signature:** the same value appears in several documents; an edit changes one place and not
  the others. Watch for any shared value modified without checking all its locations.
- **Case:** two contracts owned one fact (a version fallback). One said "0.0.0"; a later fix set
  the other to "0.1.0"; code followed the wrong one.
- **Prevention rule (default, carried from v1):** any edit that changes a field's value triggers a search across all other
  documents for that field name. The document closest to the consumer interface is the
  authority; the others defer to it.

## Pattern C: Assumed cross-runtime uniformity (contract gap)

- **Signature:** a requirement that sounds universal ("every service logs field X") but depends
  on library capabilities that differ per runtime. Watch for absolute language with no
  per-runtime verification.
- **Case:** a logging contract fixed field names two runtimes could produce and a third could not
  (it emitted a different field name and had no built-in service field).
- **Prevention rule (default, carried from v1):** any contract that mandates output field names across runtimes carries a
  per-runtime column showing the exact library call that produces each field; a runtime that
  cannot produce it natively gets the deviation and its path to compliance documented.

## Pattern D: Undocumented base-image module API (spec gap)

- **Signature:** an agent recreates something the inherited base already provides. Watch for
  inherited capabilities that the spec does not document: agents default to building their own.
- **Case:** three agents built from a base image with a pre-installed logger, recreated their
  own logger, and two added the library to their manifests with mismatched versions.
- **Prevention rule (default, carried from v1):** when a spec builds from a base, its context block lists every importable
  module with import path, exported API and an explicit DO NOT for packages already provided.

## Pattern E: Accumulated context blindness (review-process gap)

- **Signature:** a document has been through many editing rounds and "feels done" to everyone
  who worked on it. The more rounds, the higher the risk of coherence drift that per-delta
  reviews cannot detect.
- **Case:** an addendum passed review after each of 7+ edit rounds; one cold read found 12
  issues: configs not matching the acceptance criteria, a convention defined three times with
  variations, contradictory descriptions.
- **Root cause:** iterative review ratchets shared understanding; reviewers know what the author
  intended, not just what the text says. An agent reads what is on the page, literally.
- **Prevention rule (default, carried from v1):** after three or more edit rounds a cold read is mandatory: zero context,
  evaluate as an agent would (incomplete specs, redundant definitions, contradictions, rendering
  artifacts, scope confusion, ambiguous procedures). In this skill the Cold Reader seat reads
  blind in every Full round; Focused rounds always include it (`references/scaling.md`).

## Pattern F: Unverified codebase assumptions (architecture-implementation gap)

- **Signature:** a spec describes changes to existing files in words like "probably uses",
  "should have", "follow the existing pattern", with no cited implementation detail.
- **Case:** an addendum was written from architecture docs; the author assumed health checks
  were HTTP (they ran shell commands), that a status tool needed code changes (it auto-discovered
  containers), and that routing labels followed a simple pattern (a contract entry was missed).
- **Difference from E:** E is a review failure (iteration degrades coherence); F is an authoring
  failure (the first draft was written against incomplete sources).
- **Prevention rule (default, carried from v1):** before writing a spec that modifies existing code, verify implementation
  patterns. Preferred source: a completed task spec's implementation-patterns section; fallback:
  the source code. Architecture docs say what to build; specs or source say how to integrate.

## Using the patterns in a round

1. Runtime convention at play? Pattern A.
2. Shared value being modified? Pattern B.
3. Requirement assumed runtime-universal? Pattern C.
4. Building on something with inherited capabilities? Pattern D.
5. Many editing rounds behind the artifact? Pattern E.
6. Spec modifies existing code? Pattern F.

Each seat's brief names the patterns its seat checks (table above). The matching seat raises the
prevention rule with the specific text from the artifact that triggers it.
