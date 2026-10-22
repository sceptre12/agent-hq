# Consultation Triggers by Phase

This reference defines exactly when each panel member must consult another before proceeding.
The triggers are organized by workflow phase because that's when you'd actually use them —
"right now I'm writing a task spec, who do I need to talk to?"

---

## Phase 0: Cold Read (Document-Level Integrity)

Happens after 3+ iterative editing rounds on any architecture doc, task spec, or contract —
before promotion or dispatch.

**Why it exists:** Iterative review evaluates the delta, not the whole. Each edit can be
correct in isolation while the accumulated edits degrade document-level coherence. The panel
grades its own homework — reviewers fill in gaps mentally that an agent (or cold reader)
would not.

**The Cold Read check requires:**
1. Read the entire document end-to-end — not just changed sections
2. Assume zero context — pretend you've never seen this document or project
3. Apply the agent test: "If I handed this to an agent who wasn't in the room when we wrote
   it, would they produce the correct output?"
4. Check for: incomplete specs, redundant definitions, contradictory statements, rendering
   artifacts, scope confusion, ambiguous procedures

**Default owner:** Agent Context Designer (strongest lens for agent executability). Any panel
member can run it — the key requirement is a mental context reset.

---

## Phase 1: Contract Authoring

Happens once per project, before any agents run. Getting a contract wrong is the most
expensive mistake — it cascades through every task spec and every agent.

### Platform Engineer consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **DevOps Engineer** | Contract defines rules per Dockerfile layer | Does the rule translate into build commands for every runtime? Are there runtimes where package management makes the rule hard to enforce? |
| **Full Stack Engineer** | Contract says a module must be "importable" or "usable" | What does "importable" mean in each runtime? Is the consumption pattern consistent, or does each need its own spec language? |

### Integration Architect consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Platform Engineer** | Contract defines a response schema | Is every field sourced from a known location? Are there fields where the value source is ambiguous? |
| **DevOps Engineer** | Contract defines layer separation rules | Can a verification command prove an agent followed the rules? Is `docker history` sufficient? |

### DevOps Engineer consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Platform Engineer** | Contract defines size constraints | Are limits realistic given base image sizes? Any runtime where the constraint is physically impossible? |
| **Full Stack Engineer** | Contract specifies pre-installed packages | Will apps use these via import, or need their own copies? Is there a runtime where "pre-installed" ≠ "importable"? |

---

## Phase 2: Task Spec Writing

Highest-risk phase — most failures trace to gaps here. The Context Designer translates
contracts into agent-executable specs.

### Context Designer consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Platform Engineer** | Spec builds FROM a base image with importable modules | What modules does the base image provide? Import paths and APIs? Which packages must NOT be re-declared? |
| **DevOps Engineer** | Spec involves building Docker images or installable artifacts | Exact install mechanism per runtime. Exact Dockerfile commands (not pseudocode). Layer boundary enforcement. Size feasibility. |
| **Platform Engineer** | Spec involves consuming infrastructure services (Redis, Postgres, Traefik) | Connection patterns per runtime. Which layer owns which ENV vars. Credential sources. "Installed" vs "available" distinction. |
| **Full Stack Engineer** | Spec produces a module, library, or endpoint that app code will consume | Import/usage pattern per runtime. Cross-runtime symmetry. Exact fields in any JSON response. |
| **Integration Architect** | Spec output will be verified by a later wave or integration test | Acceptance criteria must catch contract violations, not just functionality. |
| **Orchestration Architect** | Spec covers 4+ files OR references 2+ contracts | Context budget manageable? Critical values from all referenced contracts inlined into the spec? |
| **Project Planner** | Same contract being implemented by multiple parallel agents | Each spec has runtime-specific implementation notes? Generic contract language translated to concrete commands per variant? |

### Full Stack Engineer consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Platform Engineer** | Spec where app code interacts with infrastructure services | Is the consumption pattern consistent with how the platform contract intends services to be used? |
| **Context Designer** | Spec produces a module but usage pattern isn't shown | Does the spec show a concrete import/usage example for downstream consumers? |

### Orchestration Architect consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Context Designer** | Reviewing specs before dispatch | Context budget manageable? More than 2 contracts need values inlined? |
| **Project Planner** | Preparing to dispatch a parallel wave | Worktrees set up? File-scope overlap truly zero? Hidden shared state? |

### DevOps Engineer consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Platform Engineer** | Task spec touches service configuration | Correct credential values, port numbers, network names match canonical sources. |

### Project Planner consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Orchestration Architect** | Considering parallelizing tasks in a wave | Zero file-scope overlap confirmed. Worktree feasibility. No hidden shared state. |

### Principal Frontend Engineer consults (active when UI work is in scope):

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Platform Engineer** | Spec involves frontend services connecting to infrastructure | Does infrastructure support frontend runtime needs? Hostnames, ports, proxy rules compatible with dev server? |
| **Full Stack Engineer** | Spec involves UI consuming an API from another spec | API contract finalized? Response shape matches frontend expectations? Error states defined? |

---

## Phase 2.5: Feedback Loop (L2 Review Sends Work Back)

When L2 Review discovers a gap, work loops back:
1. **Cosmetic** — fix directly in branch. No loop-back.
2. **Structural** (spec gap) — Context Designer determines if it's a one-off or affects
   other specs. If other specs affected, ALL unfixed branches held until specs updated.
3. **Systemic** (contract gap) — Integration Architect + Platform Engineer consulted.
   Contract update may cascade to multiple specs across multiple waves. All dependent work
   pauses.

**Decision authority for severity:** Integration Architect — they see cross-wave impact.

---

## Phase 3: L2 Review

After each agent completes, before merge. Must catch what the agent's L1 self-check
missed — especially contract compliance issues that functional tests don't reveal.

### Integration Architect (primary L2 reviewer) consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **DevOps Engineer** | Need to verify layer separation or build structure | Which layer installed which packages? Does `docker history` confirm right order? |
| **Full Stack Engineer** | Agent created a module — verify downstream usability | Can an app actually import and use this? Import path matches contract? API consistent across runtimes? |
| **Platform Engineer** | Agent used infrastructure values | Values canonical? ENV var in the right layer? Credentials match contract source of truth? |

### Context Designer (consulted during L2):

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Integration Architect** | L2 reveals issue that looks like spec gap, not agent error | One-off fix or systematic gap? Do other agents likely have the same issue? |

### Post-Merge Documentation

After branch merge, reviewer appends an **Implementation Patterns** section to the completed
task spec. This captures *how* the agent actually built it — helper function patterns,
library choices, discovery mechanisms, non-obvious design decisions. Labeled clearly as
post-execution and informational only.

---

## Phase 4: Retrospective

After each wave completes. Panel learns from execution data.

### DevOps Engineer (leads build retro) consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Platform Engineer** | Unexpected image size, failed layer check, runtime surprises | Size constraint realistic? Base image assumptions hold? Contract needs updating? |
| **Context Designer** | Agent violated contract because spec didn't specify build command | Which Dockerfile line was missing? What exact command should future specs include? |

### Orchestration Architect (leads wave retro) consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **All panel members** | After every wave | Context packages right level of detail? What was missing/excess? Agent assumptions indicating spec gaps? |

### Context Designer (leads spec retro) consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **Integration Architect** | Agent passed L1 but failed at L2 | Which acceptance criteria failed to catch the issue? How to tighten for next wave? |
| **DevOps Engineer** | Agent made runtime-specific violation | Spec didn't explain the runtime's package management model? What guidance would have prevented it? |

### Documentation Organizer (leads documentation retro) consults:

| Consults | Trigger | What to Confirm |
|----------|---------|-----------------|
| **All panel members** | After every wave | Learnings captured in the right places? Execution Log complete? Contracts updated? Framework updated? |
