# Skill porting standard

One-line summary: the seven-gate intake pipeline (Gates 0–6) that takes a skill from an external,
read-only source corpus to an installed, hq-native skill — adapt, don't rebuild, and
never install a skill whose runtime dependencies aren't actually live.

- **Status:** active
- **Applies to:** any skill entering hq from an external source (currently: the
  X-context-docs corpus under ADR 0010; the pipeline is source-agnostic for future ports).
- **Governing decision:** ADR 0010 (direct-port authorization + authorship attestation).
- **Builds on:** `tools/skill-authoring.md` (native format, anatomy, §4 checklist, §5
  provenance rule) — this document does not restate that standard, it feeds ported skills
  through it.

Every ported skill passes through the seven gates below (Gates 0–6), in order. A skill can stop at any
gate (SKIP, PARK, RULING-NEEDED) — reaching Gate 6 is not guaranteed or required for a
given skill in a given pass.

## 1. Gate 0 — Intake & triage

**Entry:** a source snapshot exists (a commit hash, a fixed directory) and is read-only
for the duration of the port.

**Do:**
- Assign each skill one triage class:
  - **PORT** — general-purpose, wanted as-is (modulo Gate 2 hygiene).
  - **ADAPT** — wanted, but work-coupled; de-work-ification is required before Gate 2 can
    close.
  - **SKIP** — work-specific; not ported.
  - **RULING-NEEDED** — ambiguous; the user decides.
- Record a **dependency scan** per skill: does it call the bus (send/read/broadcast)?
  Does it assume a PM2-managed service? Does it call an external SaaS (Confluence,
  Harness, etc.)? Is it multi-file (`SKILL-02.md`, `SKILL-03.md`, …) rather than a single
  `SKILL.md`?
- Determine bus-dependency by **grep, not assumption** — a skill's own description
  claiming "no bus" or a docs-writer's expectation of "bus-dep expected" is a hypothesis;
  the source text is the check. Where grep and a prior expectation disagree, record the
  disagreement — don't silently pick one.

**Exit:** every skill in the snapshot has a triage class and a recorded dependency scan
(even if the answer is "none").

## 2. Gate 1 — Provenance & lineage

**Entry:** the skill has a triage class of PORT or ADAPT (SKIP and undecided
RULING-NEEDED skills don't proceed past Gate 0).

**Do:**
- The corpus-wide authorship attestation lives in **ADR 0010** — do not re-attest per
  skill; one link suffices.
- Each ported skill's `SKILL.md` carries, in its `## Provenance` section (per
  `tools/skill-authoring.md` §5):
  - A link to Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (the recorded friction this whole porting
    effort traces to).
  - A `Lineage:` line in the exact form `X-context-docs skills/<name>@0e9281e` — the
    source path and the snapshot commit, so the origin is traceable without needing
    write (or even read) access back to X-context-docs.

**Exit:** `## Provenance` in the ported `SKILL.md` has both the friction link and a
`Lineage:` line before Gate 2 work starts.

## 3. Gate 2 — Refit to hq standard

**Entry:** provenance recorded (Gate 1 done).

**Do:**
- Rewrite into the `tools/skill-authoring.md` anatomy: frontmatter within its limits, a
  "Use when …" trigger folded into `description` **and** restated as `## Trigger`,
  numbered `## Steps`, a `## Red flags` rationalization table, verifiable `## Exit
  criteria`. Run the full §4 checklist.
- Keep the `SKILL.md` body within the ≤5,000-token L2 budget (§3); move overflow to
  `references/` inside the skill directory and link it from the body.
- **Multi-file source skills** (the corpus has several: `loop-controller`,
  `pr-check-migration-needed`, `swarm-communication`, `wave-execution` each ship
  `SKILL-02.md`/`SKILL-03.md`/etc. alongside `SKILL.md`) are restructured to **one**
  `SKILL.md` entrypoint + `references/` — the native format has no multi-entrypoint
  concept; the source's file-splitting convention doesn't carry over as-is.
- **Hygiene pass:** strip work-machine paths, work URLs/hostnames, and account names;
  rewrite remaining paths `~`-relative. Run the leak scan before calling Gate 2 done,
  using the runtime-assembled-pattern technique in `skills/skill-export/SKILL.md` step 5
  (patterns built from split fragments at scan time, so neither the scanned file nor the
  scan itself ever contains a literal matchable hit).

**Exit:** the skill passes `tools/skill-authoring.md` §4 in full, and a step-5-style leak
scan of the refit skill directory returns zero hits. For review-mechanism skills, the
refit must also apply `tools/review-ladder.md` §5: the `description` states the skill's
ladder rung and points one rung up and down, and `## Red flags` includes one ladder row.

## 4. Gate 3 — Dependency gate

**Entry:** Gate 2 passed.

**Do:**
- Install a skill **only** when every runtime dependency recorded at Gate 0 is live on
  this machine: the bus is reachable, a required PM2 service is up, a required port/config
  file is present. Check, don't assume — the same discipline as Gate 0's bus-dep grep.
- If any dependency is missing, the skill **parks here**. Its plan status row says so
  (`parked — Gate 3, <missing dependency>`), and it does not proceed to Gate 4 or 5 until
  the dependency arrives.

**Exit:** either every declared dependency is verified live (proceed to Gate 4), or the
skill is recorded as parked with the specific missing dependency named.

This is what sequences bus-dependent skills behind the bus port **structurally** — a
missing dependency is a gate failure, not something to remember to check later.

## 5. Gate 4 — Independent verify

**Entry:** Gate 3 passed (dependencies live) or the skill has no runtime dependencies.

**Do:** a **separate agent instance — never the Gate 2 author** (global Rule 4) runs:
- The full `tools/skill-authoring.md` §4 checklist, independently.
- The Gate 2 leak scan, independently.
- A **diff-vs-source review**: compare the refit `SKILL.md` (+ `references/`) against the
  original X-context-docs source, confirming no behavior changed beyond the declared
  de-work-ification (Gate 0/2 changes). Unexplained behavior drift is a Gate 4 failure,
  not a nitpick.

**Exit:** the independent verifier reports pass on all three checks, or the skill returns
to Gate 2 with the specific defect named.

## 6. Gate 5 — Install & live test

**Entry:** Gate 4 passed.

**Do:**
- Commit the skill at `hq skills/<name>/`.
- Install via the ADR 0009 symlink mechanism (`~/.claude/skills/<name>` → the hq
  directory).
- Run **one real invocation** — dry-run if the skill is side-effecting; for bus-dependent
  skills, validate against the **live** bus (not a mock), since Gate 3 already confirmed
  it's reachable.

**Exit:** the skill is committed, symlinked, and has one recorded successful invocation
(or dry-run) against real dependencies.

## 7. Gate 6 — Record

**Entry:** Gate 5 passed.

**Do:**
- Flip the skill's row in its plan file to
  `done`, with the install commit hash as evidence.
- Any friction discovered **during** the port — a de-work-ification surprise, a dependency
  that wasn't where Gate 0 expected, a leak-scan miss — becomes its own Hermes learning (API door; recipe: `tools/brain/templates/member-CLAUDE.md`, Memory section).
  Ported skills are supposed to surface friction, not just resolve it silently.

**Exit:** the plan row is `done` with evidence, and any new friction has its own
Hermes learning (or an explicit note that none arose).

## 8. Red flags

| Rationalization | What to do instead |
|---|---|
| "It already works at work — skip Gate 2." | Work paths, work URLs, and the source's multi-file `SKILL-02`/`SKILL-03` structure all violate the native format here; Gate 2 isn't optional polish, it's the format conversion. |
| "Install now, the bus comes later." | Gate 3 exists precisely because a skill installed with a missing dependency fails confusingly at runtime, far from the point where the gap was knowable; park it instead. |
| "Let's just polish the source in X-context-docs while we're at it." | X-context-docs is read-only for this pipeline (ADR 0010) — any fix, however small, lands in hq, never back in the source. |
| "The grep didn't find a bus call, so obviously it's not bus-dependent — no need to record the mismatch with what we expected." | Record the mismatch anyway (Gate 0); a false expectation left uncorrected propagates into Gate 3 sequencing decisions for other skills. |
| "Gate 4 is just a formality since I already checked my own work in Gate 2." | Gate 4 is independent-verify by construction (global Rule 4) — the same agent instance that authored Gate 2 cannot also close Gate 4. |

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (2026-07-04 entry, "Skills have no standardized
export path" — the same gap in reverse: no standardized *import* path existed either,
until this pipeline).
