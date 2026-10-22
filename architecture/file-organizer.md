# file-organizer — Architecture & Design

Local, single-user system for maintaining an ongoing filing system for `~/Documents` —
the `fileorg` CLI, its SQLite schema, and the taxonomy. Split into numbered parts per
ADR 0021 §4 / STANDARDS.md §4 (§13 covers enforcement); see the section map below for
which part file holds which content.

## Section map

| Section | Title | Part file |
|---|---|---|
| §1 | Overview & goals | [file-organizer-01.md](file-organizer-01.md) |
| §2 | Architecture | [file-organizer-01.md](file-organizer-01.md) |
| §3 | Components | [file-organizer-01.md](file-organizer-01.md) |
| §4 | Data model | [file-organizer-01.md](file-organizer-01.md) |
| §5 | Taxonomy | [file-organizer-01.md](file-organizer-01.md) |
| §6 | Safety rules | [file-organizer-01.md](file-organizer-01.md) |
| §7 | Scanner classification (non-taxonomy items) | [file-organizer-01.md](file-organizer-01.md) |
| §8 | Phasing | [file-organizer-02.md](file-organizer-02.md) |
| §9 | Out of scope / YAGNI | [file-organizer-02.md](file-organizer-02.md) |
| §10 | Open questions | [file-organizer-02.md](file-organizer-02.md) |
| §11 | Phase 2: Automated Sweep | [file-organizer-02.md](file-organizer-02.md) |
| §12 | Phase 3: LLM Content-Based Classification for Staged Files | [file-organizer-02.md](file-organizer-02.md) |
| §13 | hq governance artifacts | [file-organizer-02.md](file-organizer-02.md) |

**Quick pointer:** §1–§7 → [file-organizer-01.md](file-organizer-01.md); §8–§13 →
[file-organizer-02.md](file-organizer-02.md).
