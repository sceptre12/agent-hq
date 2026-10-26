# D12 gate: smaller seat sets for code stay off

Owner ruling D12 (`owner-decisions.md`), quoted: smaller seat sets are allowed only after
(a) a RACI remap moving every dropped role's checks to a kept role and (b) a 3-seat probe
showing no lost checks; until then the full 7.

## Status: OFF
Neither condition is recorded in `INTERFACES.md` (part D2.3, `pr-review` row: "seat count 7
until the D12 remap and probe are recorded here"). So:

- `KIND=diff` always writes `RUNG: 3 seats: 7` and these seven ids, whatever the risk surface
  (the `pr-review` Step 4 list): `platform-engineer`, `devops-engineer`, `fullstack-engineer`,
  `integration-architect`, `security-engineer`, `technical-writer`, `strategic-reviewer`.
- There is no code path, flag, env var or runtime detection that lowers the count. The skill
  does not read any file to learn whether D12 is on.
- Risk surface for a diff changes only each seat's `reason` text (what that seat will look
  at in this diff), never the seat set.

## Check that keeps code at 7 (run in Step 7 and again before writing)
1. `KIND=diff`? Then `n=7`, rung `3`, ids exactly as above in this order.
2. Row count equals 7 and `seats:` equals 7.
3. Any other value is a defect: stop and write nothing.

## Turning it on
Not an edit of this skill alone. It is an INTERFACES amendment (remap plus probe recorded,
consumer re-check M21) together with a skill change. Until then a request to use fewer seats
for code is refused with one line: `D12 off: code diff stays at 7 seats`.
