# Enforcement Ledger

Routing of record for every architectural claim in the deep-module refactor.
One claim → one mechanism. A claim with no row is a routing bug.

Sources: `CONTEXT.md` (glossary), `docs/adr/` (decisions), `docs/prd/deep-module-refactor.md`
and yojana `swe-dashboard/4` (PRD). Governance was set up as a hybrid
adopt+seed pass (brownfield code + a target architecture whose seams are still
being built).

Buckets:
- **(a) live** — sutra constraint binding today
- **(b) deferred** — commented `# TRIGGER:` block in `.sutra/rules.toml`, binds at a named slice
- **(c) CLAUDE.md** — behavioral/process invariant, not graph-expressible
- **(d) test** — pinned by the test suite, pointed at its implementing slice

Staging: constraints current debt violates are **advisory now**, flipping to
**blocking** at the named slice.

| # | Claim (quote / source) | Bucket | Mechanism | Status |
|---|---|---|---|---|
| 1 | "Engine routes through the Ephemeris seam" — CONTEXT §Ephemeris, PRD ①, ADR-0002 | a | `confined_external swisseph_rs allowed_in=lib/core/**` | live, **blocking** (cutover complete @ `/29`; documented `/32`) |
| 2 | "Tabs use the kernel, not the runner" — PRD ② | a | `forbidden_dep lib/tabs/** → runner.dart` | live, **advisory** → blocking @ `/11` |
| 3 | "Tabs are independent" — PRD §Problem | a | `no_cycles lib/tabs` | live, **blocking** (clean today) |
| 4 | "Context bar / shell cycle removed" — PRD ⑥ | a | `no_cycles lib/widgets/context_bar` | live, **advisory** → blocking @ `/17` (1 cycle today) |
| 5 | "Calculation kernel stays acyclic" — PRD ② | a | `no_cycles lib/core/calculation` | live, **blocking** (bound @ `/7`) |
| 6 | "Kernel/Ephemeris are not god-hubs" — refactor goal | a | `max_fan_in run_tab_calc.dart threshold=30` | live, **advisory** (bound @ `/11`) |
| 7 | "No in-tree chart parsers" — PRD ③ | a | `confined_external charts_dart allowed_in=lib/widgets/context_bar/**,lib/core/**` | live, **blocking** (clean today, bound @ `/9`) |
| 8 | "Each recompute synchronous" — ADR-0001 reactive projection (trace-slice motivation retired with the trace subsystem @ `/47`; ADR-0002 separately removed the C-global await hazard) | c | CLAUDE.md invariant | routed → CLAUDE.md (rewritten `/32`, trace clause dropped `/60`) |
| 9 | "JD is canonical; civil is derived" — CONTEXT §Moment | c | CLAUDE.md invariant | routed → CLAUDE.md |
| 10 | "Locked Flags are a pure function of the Context" — CONTEXT §Locked Flag | c | CLAUDE.md invariant | routed → CLAUDE.md |
| 11 | "Reactive projection — no explicit Calculate trigger" — ADR-0001 | c | CLAUDE.md (Decision #1 update @ `/15`) | routed → CLAUDE.md |
| 12 | ~~trace↔emitter coverage (no silent drops) — PRD §Testing~~ | d | coverage test | **RETIRED @ `/47`** — trace subsystem deleted; the coverage test group was dropped with it |
| 13 | charts_dart per-format round-trips — PRD §Testing | d | round-trip tests | test @ `charts-dart/1` |
| 14 | Moment civil↔JD conversion — PRD §Testing | d | conversion tests | test @ `/6` |
| 15 | Kernel Result via fake Ephemeris — PRD §Testing | d | kernel tests | test @ `/7` |
| 16 | Tab registry completeness — PRD §Testing | d | registry test | test @ `/16` |
| 17 | "A series compute takes its Moment from the step, never the Context" — Time-Series PRD §Governed invariant | c | CLAUDE.md invariant + structural (computes are `(Ephemeris, Moment)` with no `ref`; `runTabCalcSeries` solely owns the Context-JD read and the step loop) | routed → CLAUDE.md (`/60`). A `forbidden_pattern` banning `jdUt`/`jdEt` under `lib/tabs/**` was **rejected as unsound** — those identifiers are legitimate there (compute params fed from `moment.ut`; Dates result fields `jdUt`/`jdEt`), so the ban would fire on ~100 valid sites. |

## Maintenance

- New track PRDs **append** rows here; never regenerate.
- A flip-to-blocking event checks its row's status off (advisory → blocking).
- Convention triage is deferred to **R1 (`/11`)** via vidhi-sutra-tend — FCA has
  settled data once the foundation lands.
- sutra-guard is wired as a PreToolUse (Edit|Write) hook in
  `.claude/settings.json` — blocking constraints are enforced on edits.
