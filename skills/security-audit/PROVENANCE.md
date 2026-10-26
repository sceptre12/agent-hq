# PROVENANCE: skills/security-audit

- **Source:** https://github.com/cloudflare/security-audit-skill
- **Commit:** `c1c8a8c1471069fb0e188eeaff69b8e8db6564a8`
- **Installed by:** desk `INSTALL`, ledger row `desk-20261026T152909Z-1` (2026-10-26), on the owner's YES of 2026-10-26 (`architecture/delivery-workflow-sources/owner-decisions.md:77`).
- **License:** MIT (Copyright (c) 2025-2026 Cloudflare, Inc.; see `LICENSE` in this directory).
- **Modifications:** none to the vendored files, which are unmodified upstream copies. Added files: this note and the two code-gate wrappers `tests/test_validate-findings.sh` and `tests/test_validate-coverage-ledger.sh`. agent-hq's skill anatomy (`tools/skill-authoring.md`) is not applied to the vendored files.
- **How the delivery workflow uses it:** INTERFACES amendment AM-1 (`architecture/delivery-workflow/INTERFACES.md`, version 1.1.0): guidance mode in the security seat of `pre-pr-gate` and `pr-review`/panels; full audit mode only on an explicit operator request or a security-sensitive epic.
