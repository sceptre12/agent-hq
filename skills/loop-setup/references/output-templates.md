# loop-setup output templates

Exact templates for the two files loop-setup writes. These shapes are contracts with
other skills (loop-controller reads `loop.yaml`; loop-grader reads `rubric.md`) — do not
improvise a different serialization.

---

## loop.yaml template

No `threshold` key, ever (`## Security` in SKILL.md). `rollback_on_regression` and
`runner_timeout_seconds` are optional — write them only if collected in Step 8.5;
otherwise omit the lines entirely (loop-controller defaults them to `false` and `1800`
respectively when absent).

```yaml
schema_version: 1
target_path: {target_path}
test_artifact: {test_artifact}
runner_brief: {runner_brief}
rubric_path: ~/projects/loops/{slug}/rubric.md
fixer_brief: {fixer_brief}
finding_classifier: {null or path}
max_iterations: {max_iterations}
log_path: null
# threshold belongs in rubric.md — never here
rollback_on_regression: {true or false}       # optional — omit line if not collected (default: false)
runner_timeout_seconds: {integer}             # optional — omit line if not collected (default: 1800)
```

---

## rubric.md template

Matches the schema loop-grader actually parses
(`~/.claude/skills/loop-grader/rubrics/default.md`,
`~/.claude/skills/loop-grader/references/grade-contract.md`). Every criterion carries
`name`, `description`, `weight`, `severity`, and `notes_guidance` — the last field tells
the grader what evidence to look for and is not optional filler; ask for it explicitly in
Step 6 (a one-line answer is enough: "what should the grader check for to justify this
score?").

```markdown
# Rubric — {slug}

## threshold: {threshold}

## Criteria

\`\`\`yaml
criteria:
  - name: {criterion_name}
    description: "{criterion_description}"
    weight: {float, default 1.0}
    severity: Blocking | Medium | Advisory
    notes_guidance: "{what evidence the grader should look for}"
  # one block per criterion collected in Step 6
\`\`\`
```

If the user has no answer for `notes_guidance` on a given criterion, write
`notes_guidance: "Score based on the description above."` rather than omitting the key —
loop-grader's parser expects the key to be present on every criterion block.

---

## Batch-config validation checklist

When a pre-filled YAML config is supplied (Inputs, batch-config path), validate every
field below before writing any output — this mirrors loop-controller's own pre-flight
checks (`~/.claude/skills/loop-controller/SKILL.md` step 2, items 2.1, 2.4, 2.5, 2.6,
2.7, 2.9, 2.11) so a config that would fail controller pre-flight also fails loop-setup
batch validation, before any file is written. (`runner_timeout_seconds` is the one
exception: it has no corresponding item in loop-controller's numbered pre-flight
sequence — its validation rule lives only in loop-controller's
`references/loop-yaml-schema.md`, never wired into the Steps list — so loop-setup
validates it here as its own stricter batch-mode gate, not as a mirror of a controller
pre-flight step.)

- [ ] `slug` matches `^[a-z0-9_-]+$`.
- [ ] `target_path` resolves (realpath) and falls under `~/projects/` or
      `~/.claude/skills/`.
- [ ] `test_artifact` exists.
- [ ] `runner_brief` and `fixer_brief` exist and contain a `## Security` section.
- [ ] `finding_classifier`, if non-null, is a string (presence/nullity only —
      loop-controller's own pre-flight step 2.4 does not check existence, readability, or
      a `## Security` section for this field; see
      `~/.claude/skills/loop-controller/references/loop-yaml-schema.md`'s
      `finding_classifier` entry — batch validation here must not be stricter than the
      controller pre-flight it's meant to mirror).
- [ ] `max_iterations` is an integer ≥ 1.
- [ ] `rollback_on_regression`, if present, is a bool.
- [ ] `runner_timeout_seconds`, if present, is an integer ≥ 1.
- [ ] the `loop.yaml` section of the batch config does **not** contain a `threshold` key
      — reject and tell the user to move it to the rubric section if it does.
- [ ] every rubric criterion has `name`, `description`, `weight`, `severity`, and
      `notes_guidance`.

**Overwrite behavior (fail-closed default):** if `~/projects/loops/{slug}/loop.yaml`
already exists, batch mode refuses to overwrite it unless the batch config sets
`force: true` explicitly. There is no user present in batch mode to confirm, so silence
means "no."
