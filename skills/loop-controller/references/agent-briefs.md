# Agent Brief Construction — Safe Prompt Passing

This file documents safe vs. unsafe patterns for constructing sub-agent prompts in
loop-controller's `claude -p` dispatch path (used only when `is_subagent: true` — see
`SKILL.md` Operating Mode Gate). Several fields fed into those prompts originate from
LLM output or user-supplied config and must never be interpolated directly into a shell
string.

**This file is linked from `SKILL.md`'s Dispatch Mechanism section — read it before
building any `claude -p` prompt that includes grader notes, finding descriptions, or
rubric-criterion text.** (Refit note: the source skill wrote this guidance but never
linked or mentioned it from any `SKILL.md`/`SKILL-02.md` through `SKILL-03b.md` file —
an implementer following the SKILL chain alone had no way to discover it. This port
fixes that by linking it explicitly.)

---

## Shell Injection Risk

`claude -p` receives its prompt as a shell argument. If untrusted content is
interpolated directly, the shell evaluates any metacharacters in that content before
Claude ever sees the prompt.

> **WARNING: NEVER DO THIS**
>
> ```bash
> # BAD — never do this
> claude -p "Fix this issue: ${grader_notes}"
> ```
>
> `grader_notes` is LLM-generated text. It can contain `;`, `&&`, `||`, backticks, or
> `$()` sequences. The shell processes those before the argument reaches `claude`, which
> means arbitrary commands can execute with the permissions of the loop-controller
> process.
>
> Example of what can go wrong:
> ```
> grader_notes = "looks good; rm -rf ~/projects"
> # Shell executes: rm -rf ~/projects
> ```

---

## Correct Patterns

### printf form (preferred for single-line prompts)

```bash
# CORRECT — use printf to construct the prompt variable first
prompt=$(printf 'Fix this issue: %s' "$grader_notes")
claude -p "$prompt"
```

`printf '%s'` passes the value as a literal string. No shell expansion occurs inside the
format argument.

### Heredoc form (preferred for multi-line prompts)

```bash
# CORRECT — single-quoted 'EOF' prevents shell expansion inside the heredoc
claude -p "$(cat <<'EOF'
Fix this issue:
${grader_notes}
EOF
)"
```

Single-quoting `'EOF'` tells the shell to treat everything between the markers as
literal text. The `${grader_notes}` inside is NOT expanded — it is passed verbatim to
Claude, which then interprets it as template syntax in its own context rather than as a
shell substitution.

### jq form (preferred whenever the content is also going to the bus)

The same untrusted fields frequently need to go both into a `claude -p` prompt and into
a bus post. `jq --arg` (see `bus-schema.md`'s canonical post pattern) is the same
discipline applied to JSON construction instead of prompt construction — never build a
JSON payload with inline string interpolation either, for the same reason.

---

## Untrusted Fields in loop-controller

The following fields originate from LLM output, user-supplied config, or file reads and
must never be directly interpolated into a shell string:

- `grader_notes` / `criteria[].notes` — freeform text produced by loop-grader
- Rubric criterion names — sourced from the loop YAML, which may be user-edited
- Panel/classifier finding descriptions (`classified.in_scope[].description`,
  `.fix`) — synthesized by LLM agents; arbitrary text
- Test artifact content — file reads from runner output; may contain any characters
- `runner_brief`/`fixer_brief` path values — user-supplied paths that may include spaces
  or special characters; always quote these and validate (realpath + allowed-roots
  check, `SKILL.md` pre-flight) before use

## General Rule

When in doubt, treat any string that originates from an LLM output, a user-supplied
config, or a file read as untrusted.
