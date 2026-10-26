# Brief: run-1-20261026
Intent: add a Badge widget with three sizes to demo-widgets.
## Scope
- New `Badge` component, sizes small, medium, large; no theming work.
## Human answers
- Q1 Which sizes? Recommended: small, medium, large. Answer: accepted.
- Q2 Where do worktrees live? Recommended: `<DELIVERY_ROOT>/worktrees`. Answer: accepted.
- Q3 Mandatory review seats or Blocking rules for this repo? Recommended: none. Answer: accepted.
- Q4 Sensitive paths beyond the CI definitions (`^\.github/workflows/`)? Recommended: none. Answer: accepted.
- Q5 Other clones of this repo on this machine, or other repos in this epic? Recommended: none. Answer: accepted.
## Settled terms
- "size" means the `size` prop (enum), not pixel width.
## Open items
- `ci.min_push_spacing_s`: minimum seconds between pushes the CI tolerates (no concurrency setting in ci.yml); the human answers before dispatch.
- `ci.max_open_pr_pipelines`: open PR pipelines the CI tolerates at once (not in the repo); the human answers before dispatch.
- `jira.status_map`: Jira status string for each canonical status of project DEMO; the human answers (the workflow lives in Jira).
- `jira.archive_status`: Jira status string used to archive in project DEMO; the human answers.
- `secrets.pattern_file`: absolute path of the ERE secret-pattern file (no scanner config in the repo); the human answers.
- `zephyr.execute_tool`: Zephyr MCP `execute` tool name (no test-management tool named); the human answers or the move verifies it.
- `zephyr.read_ops`: Zephyr read operations (no test-management tool named); the human answers.
- `ports.bus_base`: bus port base for this machine (machine choice, no ports table given); the human answers.
- `ports.lane_base`: lane port base for this machine (machine choice); the human answers.
- `gates.command`: the per-push gate command (no affected-capable runner; full-repo scripts lint, typecheck, test, build, clean exist); the human answers.
- `gates.parallel`: gate parallelism on the run machine (machine fact); the human answers.
- `gates.min_free_kb`: minimum free disk for a gate run (machine fact); the human answers.
- `gates.runner_slots`: gate runner slots (machine fact); the human answers.
- `node.prefix_cmd`: activation command for Node v22.13.0 with the run machine's version manager (machine fact); the human answers.
- `durations.pr_review_min`: median PR review minutes (run history lives on the hosting service); the human answers.
- `durations.ci_round_min`: median CI round minutes (run history lives on the hosting service); the human answers.
- `durations.unit_median_min`: median unit build minutes (no local record); the human answers.
- `commands.pack`: the pack command (no pack script in package.json); the human answers.
