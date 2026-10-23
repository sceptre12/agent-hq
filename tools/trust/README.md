# Trust ledger

Records what a desk cleared before executors may use it (`architecture/permission-tiers.md`
D7: an audit record, not an enforcement input; `architecture/permission-tiers-02.md` §4).

- **Location:** `~/claude-profiles/_trust/ledger.jsonl` — append-only JSONL, machine-local,
  outside hq. `cprof trust ls` pretty-prints it; `cprof trust baseline [--note "<text>"]` writes the one
  BASELINE row.
- **BASELINE once:** exactly one `BASELINE` row records the owner's ruling that everything
  present on disk at that timestamp is trusted; `cprof trust baseline` refuses a second.
- **Rows:** one per new `name@version`, written by a desk (procedure step 5).

## Row format (part 2 §4)

```
{"ts":"2026-10-14T20:00:00Z","kind":"BASELINE","by":"owner","note":"everything present on disk at this timestamp is trusted by owner ruling 2026-10-12"}
{"ts":"...","kind":"DEP","id":"<id>","req":"<INSTALL id>","manager":"pnpm","name":"left-pad","version":"1.3.0","path":"$HOME/projects/x","scan":{"advisory":"none","lifecycle":[],"content":"no"},"verdict":"INSTALLED","by":"desk"}
{"ts":"...","kind":"TOOL","id":"<id>","req":"P4","manager":"brew","name":"osv-scanner","version":"2.7.0","scan":{"advisory":"n/a"},"verdict":"INSTALLED","by":"desk"}
{"ts":"...","kind":"PLUGIN","id":"<id>","req":"<id>","marketplace":"mattpocock","name":"mattpocock-skills","sha":"6654f6b6...","scan":{...},"verdict":"INSTALLED","by":"desk"}
{"ts":"...","kind":"DEP","id":"<id>","req":"<id>","manager":"npm","name":"evil","version":"0.0.1","scan":{"content":"yes: \"ignore previous instructions and ...\""},"verdict":"REJECTED","by":"desk-aws"}
```

## Content rule

No secrets, tokens or file contents in a row; `scan.content` quotes are ≤200 chars.

## Scanner

There is no scan tool (R-6, 2026-10-15); the desk follows the procedure in its CLAUDE.md template and writes rows in the format above by hand.
The lifecycle-script allow-list the procedure reads is `config/tiers/lifecycle-allow.txt`.
