# Panel7 r1 s4 (H1 human gate and packet), arch15-r1-s4

id | sev | artifact file:line | defect | source file:line | fix
---|---|---|---|---|---
s4-1 | M | skills/delivery-architecture/SKILL.md:15; references/tree-rules.md:24 | H1.changes re-entry never moves aside the prior review-architecture.md (ARCH: ready) and h1-packet.md, nor handles drafts of dropped nodes; round counter on re-entry unstated | interfaces/part-a-state.md:98 (A.2.1) | Add a pre-write re-entry step: rename old record/packet, archive dropped drafts, rewrite index, restart counter at 1
s4-2 | M | references/h1-packet.md:26-27,46 | No place for G46-queued/unreviewed findings; Open findings block keyed to "round 3 reached" not to open B/M or queued items | references/review-handoff.md:47,58; owner-decisions.md:2 | Add Queued line; key block on any open or queued item
s4-3 | M | references/h1-packet.md:29-37 | "each artifact with sha256" is one row per class; no per-draft, per-contract hash, no paths; published drafts not pinned to accepted content | SKILL.md:30; part-a-state.md:98 | One row per file with abs path and sha256
s4-4 | L | references/h1-packet.md:46 | "note <k>" numbering undefined; item 13 mirroring vs accepted hash unstated | part-b-desk.md B8; templates/architecture.md:80-85 | Define note split/numbering; exclude item 13 from hash
s4-5 | L | references/h1-packet.md:3 (also review-handoff.md:3, decomposer-brief.md:3, tree-rules.md:3) | Cites INTERFACES 1.1.0, current is 1.3.0 | INTERFACES.md:3 | Update to 1.3.0

totals 0/3/2
