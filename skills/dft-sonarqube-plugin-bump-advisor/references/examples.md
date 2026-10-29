## Worked examples

**Example 1 — Patch: bug fix preserving the target graph**
> Change description: "Fixed the ignore-path glob so `apps/examples-legacy`
> is correctly excluded (previously only `apps/examples` matched); no target
> names, executor references, or dependsOn edges changed."

```
BUMP: patch
JUSTIFICATION: PATCH — bug fix corrects ignore-path matching while preserving
  the emitted target graph exactly.
```

**Example 2 — Minor: additive surface growth**
> Change description: "Added a new `sonarProjectKeyOverride` pass-through
> option; when unset, behavior is identical to today's default."

```
BUMP: minor
JUSTIFICATION: MINOR — additive, backward-compatible pass-through option that
  defaults to today's output.
```

**Example 3 — Major: consumer-observable behavior change**
> Change description: "Renamed the `clean:lint` target to `lint:clean` and
> changed the package.json-vs-project.json conflict behavior from throwing to
> logging a warning and picking package.json."

```
BUMP: major
JUSTIFICATION: MAJOR — renames an emitted target and changes conflict
  behavior from throw to warn, both altering what an existing consumer
  observes or must do.
```

**Example 4 — Peer-pin bump, internal-only executor change**
> Change description: "Bumped the peer dependency
> `@sgwshub/dft-sonarqube-executor` from `1.0.1` to `1.1.0` (pin shape
> confirmed as an exact pin at the time of this change). The executor's own
> release notes describe it as an internal refactor and dependency update —
> no new option is required; the `:sonarqube` sub-executor name and its
> option semantics are unchanged."

```
BUMP: patch
JUSTIFICATION: PATCH — no new option is required, and the underlying executor
  change is internal-only, so it does not force a minor or major even though
  the peer's own version crossed into a new minor number.
PEER-PIN NOTE: The pin was confirmed exact at the time of this change, so
  this executor release forces a package.json edit regardless of its own
  impact; the bump level here is driven by the executor change being
  internal-only with no new forwarded option, not by the size of the peer
  version jump. (Re-check the pin's current shape before reusing this
  example as a template — see Background above; the real 1.1.0 release in
  Validation below shipped with a pin that moved from exact to a caret
  range in that same release, and was justified as MINOR because the
  executor's release notes described new forwarded capability rather than a
  pure internal refactor.)
```

**Example 5 — Peer-pin bump, executor major crosses a real boundary**
> Change description: "Bumped the peer dependency
> `@sgwshub/dft-sonarqube-executor` to `2.0.0`, landing outside the plugin's
> currently pinned range. The executor's major release notes state the
> `:sonarqube` sub-executor was renamed to `:analyze` and the
> `qualityGateWait` option was removed."

```
BUMP: major
JUSTIFICATION: MAJOR — the executor renamed its sub-executor and dropped an
  option this plugin forwards, so the plugin's own emitted graph now behaves
  differently for consumers, per the peer-major handling rule.
PEER-PIN NOTE: This executor release falls outside the plugin's currently
  pinned range (re-check whether that range is an exact pin or a caret range
  before stating which — see Background above), so it forces a
  package.json edit regardless of its own impact; here the underlying
  executor change is itself consumer-observable, so the major carries
  through.
```

## Validation against real history
