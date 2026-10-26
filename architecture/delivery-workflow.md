# Agent-team delivery workflow: design record

- **Status:** accepted by the owner (H1) 2026-10-26.
- **Date:** 2026-10-26. Design v2, revised after the 11-agent panel and the owner's rulings D1-D25.
- **Consolidated:** 2026-10-26 (W3 item 33): the INTERFACES design errata E1-E42 are applied to the parts, and every sentence an INTERFACES amendment (AM-1 to AM-7, `delivery-workflow/INTERFACES.md` at version 1.7.0) superseded is rewritten and tagged "(amended: AM-n)". Where a part and INTERFACES still differ, INTERFACES wins.

## Summary

The delivery workflow is a family of skills, built in `agent-hq`, that encodes the owner's process for agent-team delivery: grill, architecture, human acceptance, dispatch plan, a run of up to 30 agents per sub-task, pre-PR gate, CI fix loop, post-merge testing, release tracking and cleanup. Every git, GitHub and Jira action goes through one skill, `delivery-desk`, run by the desk session under the operator's own auth. Each sub-task runs in its own session with a tree-wide concurrency ledger, one PR per sub-task, and a human approving review before the agents merge. The family is built here, moved to the work environment by the owner and piloted on <pilot-app>.

## Index of parts

The design text was split at section boundaries to stay within the document length limit. Cross-references written as `§N` refer to the numbered sections of the original design; where a reference crosses parts, the part file is named beside it.

| Part | Sections | File |
|---|---|---|
| 1 | Header, §0 owner summary, §0.1 glossary, §0.5 work-type grounding, §1 process map | [part-01-summary-and-process-map.md](delivery-workflow/part-01-summary-and-process-map.md) |
| 2 | §2 skill inventory (§2.1 to §2.4) | [part-02-skill-inventory.md](delivery-workflow/part-02-skill-inventory.md) |
| 3 | §3 personas (§3.0 to §3.6), §4 the 30-agent concurrency model | [part-03-personas-and-concurrency.md](delivery-workflow/part-03-personas-and-concurrency.md) |
| 4 | §5 templates (§5.0 to §5.11, including §5.8b <pilot-app> repo-profile seed) | [part-04-templates.md](delivery-workflow/part-04-templates.md) |
| 5 | §6 execution constraints and profile mapping (§6.1 to §6.5) | [part-05-execution-constraints.md](delivery-workflow/part-05-execution-constraints.md) |
| 6 | §7 build plan and build record, §7b grounding in learnings, §8 open items, §9 sources | [part-06-build-plan-and-sources.md](delivery-workflow/part-06-build-plan-and-sources.md) |
| Changelog | v1 to v2: every panel finding and ruling mapped to a section (its `§` references use the original section numbers; map them with the table above) | [changelog.md](delivery-workflow/changelog.md) |

Evidence files cited by the design live in `architecture/delivery-workflow-sources/`.
