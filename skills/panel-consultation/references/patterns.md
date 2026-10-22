# Learned Failure Patterns (A through F)

These patterns were discovered through real execution failures on a past project, referred
to here as "Project Zero," running a multi-runtime Docker/Traefik infrastructure stack. They
are kept as illustrative historical case studies — concrete shapes of failure the panel
learned to watch for — not as a description of any current project's infrastructure. When a
present-day situation rhymes with one of these signatures, call it out explicitly regardless
of whether the specific tools involved match.

Each pattern includes: what happened, which consultation trigger was missed, the fix that
was applied, and the prevention rule going forward.

---

## Pattern A: Orphaned Convention File (Spec Gap)

**What happened:** Python agent created a `requirements.txt` listing all packages. No
Dockerfile referenced it — each layer installs packages via explicit `pip install` commands.
The file was dead weight.

**Missed trigger:** Phase 2 → Context Designer consults DevOps Engineer → "Spec involves
building Docker images" → DevOps would have said: "Python agents will reflexively create
requirements.txt. Spec must state Dockerfiles are the sole install mechanism."

**Prevention rule:** When a task spec targets a runtime with strong file conventions
(Python: requirements.txt/pyproject.toml, Node: package.json, Rust: Cargo.toml), the spec
must explicitly state which convention files are in scope and which are NOT to be created.

**Pattern signature:** An agent creates a file that's standard for the runtime but isn't
used by the actual build/deploy mechanism. Watch for any situation where "the normal way"
for a runtime diverges from the project's actual build pipeline.

---

## Pattern B: Cross-Contract Value Drift (Feedback Loop Gap)

**What happened:** Two contracts owned the same fact (version fallback value).
`health-check.md` said `"0.0.0"`. During fixes, `base-image.md` was updated to `"0.1.0"`.
Code followed the wrong one.

**Missed trigger:** Phase 2.5 → Integration Architect assesses severity → A contract update
is systemic. Should have cross-referenced all contracts mentioning the `version` field
before committing.

**Prevention rule:** Any contract edit that changes a field value must trigger a grep across
all other contracts for that field name. The contract closest to the consumer interface is
the authority (health-check for response fields, logging for log fields). Other contracts
defer.

**Pattern signature:** The same value appears in multiple documents. An edit changes it in
one place but not others. Watch for any situation where a shared value is being modified
without checking all its locations.

---

## Pattern C: Assumed Cross-Runtime Uniformity (Contract Gap)

**What happened:** Logging contract specified field names `msg` and `service`. Node (pino)
and Python (structlog) can produce these. Rust (`tracing-subscriber`) cannot — it outputs
`message` and has no built-in `service` field. The contract assumed all runtimes had equal
control over JSON field naming.

**Missed trigger:** Phase 1 → Platform Engineer consults DevOps Engineer → "Contract
defines rules per runtime" → DevOps would have tested whether each runtime's library can
actually rename fields.

**Prevention rule:** Any contract mandating specific output field names across runtimes
must include a per-runtime verification column showing the exact library API call that
produces each field. If a runtime can't produce the field natively, document the deviation
and path to compliance.

**Pattern signature:** A requirement that sounds universal ("all services must log field X")
but actually depends on library capabilities that vary per runtime. Watch for any
cross-runtime requirement that uses absolute language without per-runtime verification.

---

## Pattern D: Undocumented Base Image Module API (Spec Gap)

**What happened:** All three Wave 3 agents built FROM `dev-ready-node` but recreated their
own pino logger instead of using pre-installed `require('./logger')`. Two agents added
`pino` to their `package.json` with mismatched versions.

**Missed trigger:** Phase 2 → Context Designer consults Platform Engineer → "Spec builds
FROM a base image that provides importable modules" → Platform would have documented the
exact API and told agents NOT to add pino to their package.json.

**Prevention rule:** When a task spec builds FROM a base image, the Context for Agent
section must include a "Base Image Module API" block listing every importable module with:
import path, exported API, and explicit DO NOT guidance for packages already provided.

**Pattern signature:** An agent recreates something the base image already provides. Watch
for any situation where inherited capabilities aren't explicitly documented in the spec —
agents will default to building their own rather than using what's available.

---

## Pattern E: Accumulated Context Blindness (Review Process Gap)

**What happened:** The Verdaccio addendum went through 7+ iterative editing rounds. Each
was reviewed by the panel and passed. A cold read found 12 issues — including configs that
didn't match acceptance criteria, conventions defined three times with variations, and
contradictory descriptions.

**Root cause:** Iterative review creates a context ratchet — each reviewer builds on shared
understanding from prior rounds. This shared understanding masks document-level
inconsistencies because the reviewer knows what the author *intended*, not just what the
text *says*. An agent reads what's on the page, literally.

**Prevention rule:** After 3+ iterative editing rounds, a Phase 0 Cold Read is mandatory.
The reader assumes zero context and evaluates as an agent would. Check for: incomplete
specs, redundant definitions, contradictory statements, rendering artifacts, scope
confusion, ambiguous procedures.

**Pattern signature:** A document has been through many editing rounds and "feels done" to
everyone who worked on it. Watch for any artifact that's been collaboratively edited
extensively — the more rounds, the higher the risk of coherence drift that per-delta reviews
can't detect.

---

## Pattern F: Unverified Codebase Assumptions (Architecture-Implementation Gap)

**What happened:** The Verdaccio addendum was authored from architecture docs — correct for
high-level design, but insufficient for implementation-level detail. The author assumed
doctor.js used HTTP health checks (actually uses `execSync` with Docker commands), that
status.js needed code changes for a new service (actually auto-discovers containers), and
that Traefik labels followed a simple pattern (missed `entrypoints=web` from the contract).

**Root cause:** Architecture docs describe *what* services do, not *how* existing code
implements things. An addendum specifying changes to existing files must consult the actual
files (or completed task specs with Implementation Patterns sections).

**Key distinction from Pattern E:** Pattern E is a review failure (iterative reviews degrade
coherence). Pattern F is an authoring failure (first draft wrong because authored against
incomplete sources).

**Prevention rule:** When modifying existing code, verify implementation patterns before
writing the spec. Preferred source: completed task spec's "Implementation Patterns" section.
Fallback: read actual source code. Architecture docs are for *what* to build; task specs
(or source) are for *how* to integrate.

**Pattern signature:** A spec describes changes to existing files using language like
"probably uses," "should have," or "follow the existing pattern." Watch for any spec that
modifies existing code without citing specific implementation details from the actual
codebase.

---

## Using These Patterns in a Panel Session

When running a panel consultation, scan the problem for pattern signatures:

1. **Is a runtime convention at play?** → Check Pattern A
2. **Is a shared value being modified?** → Check Pattern B
3. **Is a requirement assumed to be runtime-universal?** → Check Pattern C
4. **Is work building on top of something with inherited capabilities?** → Check Pattern D
5. **Has the artifact been through many editing rounds?** → Check Pattern E
6. **Is the spec modifying existing code?** → Check Pattern F

If a pattern matches, the relevant panel member should raise it with the specific prevention
rule. The patterns compound — a spec can hit multiple patterns simultaneously (e.g., Pattern
D + Pattern F: building on a base image AND modifying existing files without checking either
the module API or the implementation patterns).
