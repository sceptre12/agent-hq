# repo-profile.md (fixture; one YAML document)
clones: ["FIXTURE_REPO_ROOT"]
linked_profiles: []
worktree_base: FILL_IN_BEFORE_DISPATCH
merge_method: squash
merge_reach: "main deploys to staging only"
ci:
  required_checks: ["test", "lint"]
  min_push_spacing_s: 60
  max_open_pr_pipelines: 2
durations:
  pr_review_min: 30
  ci_round_min: 15
  unit_median_min: 45
e2e:
  harness: none
release_tags:
  used: "no"
review_profile:
  mandatory_seats: []
  blocking_rules: []
