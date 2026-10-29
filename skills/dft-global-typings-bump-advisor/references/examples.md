## Worked Examples (from FOUND-1827 Acceptance Criteria)

**Scenario 1 — MAJOR: filter glob change alters the affected set**
Input: "This PR removes `tools/**` from the exclude list, so tools projects
are now scanned for global types."
```
RECOMMENDED BUMP: major
JUSTIFICATION: MAJOR — edits the include/exclude filter globs (tools/** is
now included), which can add new projects to the affected set.
```

**Scenario 2 — MINOR: strictly additive coverage**
Input: "Adds detection for a new `common/types/*.mjs` file kind, off by
default via a flag, alongside the existing `.d.ts` detection. No existing
project's affected result changes."
```
RECOMMENDED BUMP: minor
JUSTIFICATION: MINOR — strictly additive coverage (new file kind, off by
default) that never removes an existing affected edge; existing projects'
affected results are unchanged.
```

**Scenario 3 — PATCH: crash fix with identical output**
Input: "Fixes a crash when `tsconfig.lib.json` is missing; for every
workspace that already built successfully, the emitted target set and inputs
are byte-for-byte identical to before."
```
RECOMMENDED BUMP: patch
JUSTIFICATION: PATCH — a crash/robustness fix that brings output in line with
already-documented intent, with no change to correct-case results.
```

**Scenario 4 — Ambiguous: no guess**
Input: "Refactored the internal file-walking logic for dft-global-typings."
```
RECOMMENDED BUMP: CANNOT DETERMINE
JUSTIFICATION: Cannot determine version-bump tier: the description doesn't
say whether the emitted globalTypeNoop target set/inputs change for any
workspace. Please clarify whether output is byte-for-byte identical
(PATCH) or whether any affected edge shifts (MAJOR/MINOR) before a
recommendation can be made.
```

