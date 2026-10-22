# Tier overlays

An overlay is an optional per-project JSON fragment, `config/tiers/overlays/<project>.json`,
merged on top of a tier fragment when a profile is rendered
(`cprof new <name> --tier <t> --overlay <project>`; `architecture/permission-tiers.md`
§Components 2). It carries what one project needs beyond the base tier: extra denies and extra
sandbox allowances (e.g. the Supabase denies, `allowMachLookup` for iOS Simulator work, extra
`allowedDomains` for a local Supabase; `architecture/permission-tiers-02.md` §1 overlay bullets).

## Merge semantics (`architecture/permission-tiers.md` §Interfaces, "Settings render")

```
hq/config/settings.json + config/tiers/<tier>.json + config/tiers/overlays/<project>.json
  + claudeMdExcludes = <profile>/config/settings.json
```

- Scalars: later wins.
- `permissions.deny`: set-union.
- `sandbox.network.allowedDomains` and `sandbox.filesystem.allowWrite`: set-union.
- `permissions.allow` and `hooks`: from hq only; overlays do not set them.

## Naming

`<project>.json`, lowercase project slug (e.g. `<project>.json`). Underscore-prefixed keys
(`_overlay`, `_source`, `_note`) are provenance comments, not settings.

## Constraint

An overlay may only ADD denies and ADD sandbox allowances. It must never remove a base deny
or disable the sandbox (`"sandbox.enabled": false` and `allowUnsandboxedCommands: true` are
out). Set-union cannot remove a base deny by construction, so a base-deny exemption (such as the
E7 `pod install` footnote) needs a different tier fragment and an owner decision.

## Example

`<project>.json` is a worked example: the E12 denies (`mcp__supabase`, `Bash(supabase *)`,
provenance: `~/claude-profiles/<brain-profile>/config/settings.json:155-156`) and
`sandbox.network.allowMachLookup: true` (iOS Simulator XPC; `permission-tiers-02.md` §1).

## Control files

`lifecycle-allow.txt` stays in this directory. The executor fragment's `sandbox.filesystem.denyWrite`
(`~/projects/agent-hq/config/tiers`, `~/claude-profiles/_trust`) covers it and the trust ledger against
Bash writes by executors (panel F9b/F11; key to be measured at P5, pre-check e).
