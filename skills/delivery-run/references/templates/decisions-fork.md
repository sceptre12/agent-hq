# Template: `.decisions/<unit>.md` (fork record)

Purpose: the one place a unit agent stops and records a fork instead of guessing (the Decision Gate of the unit task spec, section 11). The unit then reports `ESCALATE` or stays blocked (C2) and the slot is freed per the lead.

**Writer / Reader:** the fork entry (Fork to Outcome) is written by the unit agent; the Resolution and Re-dispatch sections are written by the lead, or by the human when the lead escalates (A.6, design 5.10). Readers: the lead (`delivery-run`), the conductor, the human via the inbox item. Plane: repo, committed (D6). Path: `.decisions/<unit>.md`, one file per unit; further forks append a numbered block.

```
# Decision: <unit> <slug>

## Fork
<What was found, with evidence: file:line, command output, the two contract values. One paragraph.>

## Options
1. <option>: <effect, risk>
2. <option>: <effect, risk>

## Recommendation
<option number and one-line reason, or "none: needs human".>

Outcome: Blocked

## Resolution
resolved_by: lead|human
date: YYYY-MM-DD
decision: <chosen option and wording; for a human answer, quote it>

## Re-dispatch instruction
<What the re-dispatched agent does differently: the exact value to use, the file to touch, the tier (`tier_override <unit>=<tier>` if raised, C1.1). Until this section is filled the unit stays blocked.>
```

Rules:
- `Outcome: Blocked` is literal and stays until the lead sets the resolution; the lead never edits the Fork or Options text.
- A fork that touches an owner ruling or a one-way decision goes to the human (`resolved_by: human`); the agent never fills Resolution.
- An unmeasured value is recorded as `FILL_IN_BEFORE_DISPATCH`, not guessed.
- Dates are `YYYY-MM-DD`; shas are 40-hex.
