# Bundle header

Bundle-level fields for this spec (ADR 0054 A0). They sit in `spec_root`, so the
checkpoint key hashes them. A bundle that declares none of them (the legacy
3-wave form: waves 1-3 alone) validates and runs exactly as before.

- **session_id:** `example-audit-fix`
- **output_topic:** `example-audit-fix-output`
- **bus_endpoint:** `example-run/build/bus.endpoint`

`max_concurrent`, `invocation` and `tier_override` are invocation arguments, not
spec fields, so none of them appears here.
