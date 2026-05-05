# Handoff

Last touched: 2026-05-05

## Completed

Both architecture waves are done and committed.

| Yojana | Commits | Status |
|---|---|---|
| `swe-dashboard/1` CalcSession | 3c3a384 | done |
| `swe-dashboard/2` EphemerisRunner | bc1d4ff, 42ab30a, 2f4754b | done |

All 19 golden tests pass. `flutter analyze` clean. App tested manually.

## Pick up next

### Export header bug

`lib/core/export_service.dart` `toTsv` and `toCsv` use
`rows.first.fields` as the column header. Breaks for tabs with
heterogeneous rows (Houses, Dates, Nodes/Apsides). Small fix (~20
lines). No Yojana task yet.

### Context hydration microtask

`ContextBarNotifier._loadPersisted()` returns `{}` and `AppShell`
patches state in a microtask after first frame. ~30 minute cleanup.

### v2 tracing

`doc/swe-dashboard-v2.md` — EphemerisRunner is now landed, providing
the seam for tracing-driven code generation. The runner's `run()`
method is the single choke point where trace hooks would go.

## Context for the next session

- Scanner (`lib/core/ephe/scanner.dart`) intentionally uses raw
  SwissEph, not the runner — it probes arbitrary directories for file
  metadata, not chart calculations.
- Golden test helper (`test/goldens/golden_helper.dart`) now provides
  sharedPrefsProvider mock, calcSessionProvider override (marks all
  tabs as run), and a 1% pixel tolerance comparator.
- Stars tab guards `ref.read` in dispose with try/catch — Riverpod
  StateError when ProviderScope tears down first.
