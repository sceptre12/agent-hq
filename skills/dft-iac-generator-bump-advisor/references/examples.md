## Worked Examples (from FOUND-1829 Gherkin acceptance criteria)

### Example 1 — MAJOR: moduleSourcePath change, no migration

**Input:** Diff to `bff/files/main.tf.template` changes the `module "bff" {
source = ... }` value. No accompanying `migrations.json` entry, no `moved {}`
block.

**Output:**
```
Recommended bump: major

Justification: Changing moduleSourcePath with no safe migration forces
destroy/recreate on existing projects — this is a MAJOR per the rubric's
explicit moduleSourcePath clause.
```

### Example 2a — MINOR: purely additive var

**Input:** Diff adds a new optional `var.enable_xray_tracing` to
`bff/files/main.tf.template`, defaulting to `false`, wired to an opt-in
resource block.

**Output:**
```
Recommended bump: minor

Justification: Purely additive output — a new optional var.* with a safe
default that yields update-in-place, not replace.
```

### Example 2b — MINOR: destructive rename neutralized by a migration

**Input:** Diff renames `module "bff_lambda"` to `module "bff_compute"` in
`bff/files/main.tf.template`, and the same PR adds a `migrations.json` entry
whose codemod emits a `moved { from = module.bff_lambda to = module.bff_compute }`
block for existing projects.

**Output:**
```
Recommended bump: minor

Justification: Otherwise-breaking module rename made non-destructive by a
shipped nx migrate codemod + moved block, so existing projects still plan
clean — downgraded from MAJOR to MINOR per the rubric's migration-downgrade
path.
```

### Example 3 — PATCH: no-op plan

**Input:** Diff only bumps `generator-version.json` stamps from `1.1.2` to
`1.2.0` across all sub-generators, with no `.tf.template`, resource-address,
or `var.*` change — the actual `update-1-2-0` migration pattern from the real
`1.2.0` release (2026-06-17; see [Validation against real
history](#validation-against-real-history) for the version-number caveat on
this exact release).

**Output:**
```
Recommended bump: patch

Justification: No-op terraform plan for existing generated projects —
a version-stamp-only bump matching the update-1-2-0 pattern, which the
rubric names explicitly as PATCH.
```

### Example 4 — Ambiguous: declines to guess

**Input:** "We tweaked how the `bff` generator writes `var.log_retention_days`."

**Output:**
```
Cannot classify with confidence: the description doesn't say whether
var.log_retention_days was renamed/removed (replace), given a new default
(in-place update), or just reformatted (no-op) — all three read as "tweaked."

Per the decision doc's PR-checklist item: state the expected terraform plan
verb (no-op / in-place / replace) for var.log_retention_days on existing
generated projects, then re-run this advisor.
```

## Validation against real history

Cross-checked against `packages/dft-iac-generator/CHANGELOG.md`:

| Version | Change | Rubric verdict | Actual shipped version number |
|---|---|---|---|
| `1.2.0` (2026-06-17) | `update-1-2-0`: generator-version.json stamp bump only | PATCH | `1.1.2`→`1.2.0` is a **minor**-shaped version-number increment — **mismatch**, see note below |
| `1.1.0` (2026-06-11) | Added control-plane workspace emission, `workspaceBranch` option, `baseDomain`→two-domain fallback, changed default `environments` set | MINOR (additive options + retained deprecated fallback; default-set change is a behavior change on new generations, not a destructive plan on existing ones) | `1.0.1`→`1.1.0` is minor-shaped — match |
| `1.1.0` (2026-06-11), Migration M1 note | Control-plane generator's `normalizeOptions` began *requiring* `appRepo`, `nonprodBaseDomain`, `prodBaseDomain` — programmatic callers that skip schema validation get a runtime throw if they omit these | MINOR, not MAJOR's "backward-incompatible schema option change" bullet — the throw only fires for callers bypassing schema validation on *new* generations; it does not change the terraform plan for any already-generated project, so it doesn't hit this package's infra-blast-radius surface the way a `.tf`/resource-address change would | Still ships under the same `1.1.0` minor-shaped bump as the row above — match, but flagged here explicitly rather than left unaddressed |
| `1.1.2` (2026-06-16) | Added `$schema` + companion `idp-product.schema.json`, editor/tooling-only, no `ajv` enforcement | PATCH (CHANGELOG's own note: "ships as a patch rather than a minor" because it's not a new enforcement boundary) | `1.1.1`→`1.1.2` is patch-shaped — match |

**Documented mismatch (1.2.0):** the rubric's *content-based* verdict for the
`update-1-2-0` change is PATCH (it's a no-op-plan, stamp-only change — no
`.tf`, no resource address, no `var.*` touched). But the actual released
version number went `1.1.2`→`1.2.0`, which is a minor-shaped increment by
semver arithmetic. This is a real discrepancy between this skill's rubric
verdict and the version number the package actually shipped under — not a
silent reconciliation. Do not treat the shipped version number as proof the
rubric verdict is wrong; the rubric judges plan-verb content, and release
tooling/conventional-commit labeling can diverge from that judgment for
reasons outside this skill's scope (e.g. how the triggering commit was
labeled). Surface this mismatch if asked to validate the skill against
history — do not report all three rows as clean matches.

