# Brief: run-1-20261026
Intent: add a Badge widget with three sizes to demo-widgets.
## Scope
- New `Badge` component, sizes small, medium, large; no theming work.
## Human answers
- Q1 Which sizes? Recommended: small, medium, large. Answer: accepted.
- Q2 Where do worktrees live? Recommended: `<DELIVERY_ROOT>/worktrees`. Answer: accepted.
## Settled terms
- "size" means the `size` prop (enum), not pixel width.
## Open items
- ci.min_push_spacing_s, ci.max_open_pr_pipelines, jira.status_map, jira.archive_status, secrets.pattern_file, gates.parallel, gates.min_free_kb, gates.runner_slots, node.prefix_cmd, zephyr.read_ops, durations.*: unmeasured, answered before dispatch.
