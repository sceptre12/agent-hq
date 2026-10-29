## Worked examples

**Example 1 — Major: shipped default flip affects existing apps**

> Change description: `isZephyrBuild()`'s default `USE_ZEPHYR` resolution is
> being flipped, changing runtime behavior for apps already on the `^0.5.1`
> caret range.

```
Specifier: major
Justification: "flip or remove a shipped default that changes build output or runtime for existing apps" — caret-shipped channel
```

**Example 2 — Minor: new optional plugin option added**

> Change description: `withDefinePlugin()` gains a new optional option with a
> backward-compatible default; no existing default changes.

```
Specifier: minor
Justification: "a new optional option with a backward-compatible default" — caret-shipped channel
```

**Example 3 — Patch: bug fix restores documented behavior**

> Change description: `withDefinePlugin()` is fixed so `ENABLE_MOCKING` is
> always defined as documented, with no new observable behavior added.

```
Specifier: patch
Justification: "bug fix that restores documented behavior" — caret-shipped channel
```

**Example 4 — Ambiguous/mixed: template-only edit + shipped default change**

> Change description: the change touches both a template-only file (affects
> only newly generated apps) and a shipped plugin default (affects existing
> apps via the caret pin).

```
Channel classification:
  - Template-only piece: minor (new opt-in behavior, new-app-facing only)
  - Caret-shipped piece: major (shipped default change affects existing apps)

Specifier: major
Justification: "flip or remove a shipped default that changes build output or runtime for existing apps" — mixed channel, higher tier (major) taken over the template-only piece (minor) per the conservative-tier rule
```

**Example 5 — Ambiguity surfaced: channel cannot be determined**

> Change description: "Updated `rspack.base.config.ts.template` to change how
> plugins are wired in." (No statement of whether this also changes a
> shipped plugin default that affects existing apps, or is purely additive
> to newly generated apps.)

```
Ambiguity: cannot classify — channel unclear
Missing information: the description states a template file was edited but
  does not say whether the edit also changes a shipped plugin's default
  behavior (caret-shipped, would need Step 2 applied to that piece too) or
  is purely additive/template-only.
Clarification needed: Does this change alter the order, defaults, or
  presence of any plugin already wired into existing generated apps (e.g.
  reordering or removing an existing basePlugins entry), or does it only add
  new template content that newly generated apps will pick up?
```

## Historical validation notes (advisory only — do not silently agree with history)

The rubric occasionally diverges from what was actually shipped historically.
When validating this skill's output against CHANGELOG precedent, treat a
discrepancy as evidence worth recording — not as a signal to change the
recommendation to match history, and not as proof the rubric is wrong either.
Report both readings.

When this skill is used to validate a historical change and a discrepancy is
found, include it in the output rather than noting it only internally —
append a line to the normal output format:

```
Historical note: shipped as <tag's actual specifier> (<version>); this
  recommendation diverges because <one clause citing the rubric criterion>.
```

If no discrepancy is found, omit the line entirely — do not add "matches
history" noise to every recommendation.

| Version | What shipped | Actually tagged | Rubric says | Discrepancy |
|---|---|---|---|---|
| 0.6.1 (FOUND PCWA-7634) | `withDefinePlugin` fix so `ENABLE_MOCKING` is always defined | patch | patch ("bug fix that restores documented behavior") | None — matches |
| 0.7.0 (FOUND-1253) | `ScriptGenerator` type widened (breaking, types-only) | minor | major ("change a `with*` option or return type incompatibly") | Diverges — shipped as minor despite a literal-major-criterion match; record as a historical discrepancy, not as license to under-classify future type-widening changes |
| 0.6.4 (FOUND-1210) | `withVersionJson()` wired into `basePlugins` in the template | patch | minor if purely template-only and new-app-facing ("add a new `.template` file or new opt-in behavior") — check whether it also altered a shipped default (would raise it to major) | Diverges — shipped as patch; classify by channel and report the discrepancy rather than defaulting to the historical tag |

