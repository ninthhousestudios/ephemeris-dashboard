---
id: pre-mortem-2026-04-12-ephemeris-file-manager-phase-1
type: pre-mortem
date: 2026-04-12
source: "[[.agents/plans/2026-04-12-ephemeris-file-manager-phase-1]]"
mode: quick (inline, single-agent)
scope_mode: hold
prediction_ids:
  - pm-20260412-010
  - pm-20260412-011
  - pm-20260412-012
  - pm-20260412-013
  - pm-20260412-014
  - pm-20260412-015
  - pm-20260412-016
  - pm-20260412-017
  - pm-20260412-018
  - pm-20260412-019
---

# Pre-Mortem: Ephemeris File Manager, Phase 1

## Council Verdict: WARN

Three significant findings must be addressed before `/implement`. Seven moderate findings should be fixed in plan text. The plan is architecturally sound — directory provider, scanner with `getCurrentFileData` probes, range-resume downloader, and a pre-calc resolver for the context-bar sentinel are all well-chosen. Issues are concrete and fixable without redesign.

| ID | Judge | Finding | Severity | Prediction |
|----|-------|---------|----------|------------|
| pm-20260412-010 | feasibility | `sweProvider` as written disposes `SwissEph` on path change (rebuilds due to `ref.watch(resolvedEphePathProvider)`) — plan's own note says "do NOT dispose" but code does | significant | First path change at runtime → SwissEph closed mid-use → any in-flight calc in another tab crashes |
| pm-20260412-011 | missing-requirements | BCE filename parsing math is ambiguous: `seplm06.se1` → plan says `startYear = -(NN*600 + 599), endYear = -(NN*600) + 1` but the civil-BCE vs astronomical-year-0 convention is not resolved | significant | B10 tests pass with whatever convention implementer picks, then B4 scanner's probe JD lands in the wrong range, calcUt fails → all BCE files show "corrupt" |
| pm-20260412-012 | scope | seCatalog scope is unbounded — "generated programmatically from a range" without specifying that range. Could be 5 entries or 450 | significant | Implementer enumerates every 600-year chunk 5400 BCE–2999 CE × 3 families = ~450 rows; catalog UI drowns |
| pm-20260412-013 | spec-completeness | B6 plan says "modify `lib/widgets/context_bar/<existing>.dart`" — directory has multiple files; target is not named | moderate | Implementer edits wrong file or invents new one; pre-mortem-caught before drift |
| pm-20260412-014 | spec-completeness | B9 says "add to `app_shell.dart` (settings menu or equivalent)" — app has tabs, not an obvious settings menu | moderate | Feature ships with no discoverable entry point or with a misplaced tab |
| pm-20260412-015 | feasibility | B5 resolver matches by filename-derived range only, ignoring `EpheFileStatus.corrupt` — so a corrupt `sepl_18.se1` on disk shows as "covering 1800–2399" and the sentinel lies | moderate | User's de-corrupt diagnosis is hidden; they see "sepl_18.se1 in use" but actual calc silently Moshier-falls-back |
| pm-20260412-016 | feasibility | No disk-space pre-check. `de431.eph` = 2.7 GB, `de441.eph` = 2.7 GB. Downloader starts, fills disk, crashes app mid-write | moderate | Linux: partition fills, other processes affected; uglier failure than a pre-flight "not enough space" error |
| pm-20260412-017 | spec-completeness | B6 will regenerate every context-bar golden. Plan's verification section lists goldens regen generically — no B6-specific diff-review protocol | moderate | Golden review fatigue; real regression slips through on a bulk accept |
| pm-20260412-018 | test-pyramid | No L2 test covers "download file → scanner sees it → resolver reports it." B11/B12/B13 test layers in isolation; nothing proves the pipeline connects | moderate | Any of B4/B5/B7 integration seams break silently; caught only in manual smoke |
| pm-20260412-019 | missing-requirements | Downloader network-error retry policy is implicit. Plan specifies 416 handling and MD5 verify but not "connection reset mid-stream" or "TLS error" | moderate | User sees random "download failed" with no retry; Phase 1 UX rougher than it needs to be |

## Shared Findings

- Resolver (B5) and scanner (B4) both conflate "file present on disk" with "file usable by SE." Even if `getCurrentFileData` confirms the file is valid, the resolver doesn't re-check status. Status-aware resolver closes the gap.
- `seCatalog` vs `jplCatalog` are different shapes in practice: JPL = 5 hand-curated entries with MD5s; SE = a function of a year range. Different patterns; don't force them into the same const list.
- The "which file will be used" feature has two sources of truth: pre-calc resolver (B5) and post-calc `CalcResult.returnFlag` (researched, not in plan). Pre-calc is sufficient for Phase 1 IF the resolver is status-aware (M3).

## Known Risks Applied

None — no compiled pre-mortem checks in repo.

## Concerns Raised

### Significant (address before `/implement`)

**S1 — `sweProvider` rebuild disposes SwissEph (pm-010).**

The plan's B2 code reads:
```dart
final sweProvider = Provider<SwissEph>((ref) {
  final swe = _preloadedSwe ?? io.createDesktopSwissEph();
  final path = ref.watch(resolvedEphePathProvider);
  swe.setEphePath(path);
  ref.onDispose(() => swe.close());
  return swe;
});
```

Riverpod rebuilds a `Provider` whenever any `ref.watch(...)` dependency changes. On path change, Riverpod calls `onDispose` (closing `SwissEph`) then re-constructs the provider (creating a fresh `SwissEph`). The old comment "do NOT dispose" is violated by the code.

**Fix:** split the concern into two providers — one that owns the `SwissEph` lifecycle, one that re-applies path imperatively:

```dart
final sweProvider = Provider<SwissEph>((ref) {
  final swe = _preloadedSwe ?? io.createDesktopSwissEph();
  ref.onDispose(() => swe.close());
  return swe;
});

final ephePathApplyProvider = Provider<void>((ref) {
  final swe = ref.watch(sweProvider);
  final path = ref.watch(resolvedEphePathProvider);
  swe.setEphePath(path);
});
```

App startup (`main.dart` or `app.dart`) does `ref.read(ephePathApplyProvider)` once at init; tab providers that care about path changes do `ref.watch(ephePathApplyProvider)` alongside `ref.watch(sweProvider)`. `setEphePath` reapplies without disposing the instance.

Revise B2 acceptance to match.

**S2 — BCE year convention (pm-011).**

SE's `sepl_*.se1` filename spec is documented (see `sweph.h` / `sweph.c` in the SE distribution). Actual convention: the numeric suffix is the **century start** (× 100, not × 600) — wait, verify this. Research doc says 600-year chunks, `sepl_18.se1` = 1800–2399. If that's right, numeric suffix × 100 = start year. Then `seplm06.se1` = 600 BCE (astronomical year -599 or civil 600 BCE?).

**Action:** before B3 lands, run a probe on `assets/ephe/seplm06.se1` via `getCurrentFileData` and record the real `startDate` (JD) and `endDate`. Convert to civil years. Document the convention in `types.dart` as a code comment and test case.

Revise B3 acceptance: "BCE math verified against bundled `seplm06.se1` via `getCurrentFileData` probe; test asserts year-range matches the probe result."

**S3 — seCatalog scope bound (pm-012).**

Plan says "Generated programmatically from a range" — leaving scope undefined. Concrete proposal:

- Phase 1 seCatalog = **exactly the files the app already bundles, plus ±2 chunks** (one extra forward, one extra back per family). That's `sepl_00`–`sepl_50`, `seplm00`–`seplm56`, and equivalent for `semo`/`seas` — roughly 100 entries total. Any file outside this range stays Phase 2.

Alternative: catalog only the files the user might realistically want that aren't bundled. Cleaner.

**Action:** add an explicit `seCatalog` enumeration table to B7, with row count. Either inline or in `catalog.dart` with a comment documenting the bound.

### Moderate (fix in plan revision)

**M1 — context_bar file target (pm-013).** Name the exact file in B6 acceptance. Probably `lib/widgets/context_bar/context_bar.dart` or similar — confirm with `ls lib/widgets/context_bar/` before finalizing.

**M2 — nav target (pm-014).** Decision: add "Ephemeris Files" as an overflow-menu item in the app bar, OR as a tab in the "More" dropdown (per `tab_definitions.dart`). Recommend overflow menu — tabs are for calculations, not settings.

**M3 — status-aware resolver (pm-015).** B5 acceptance:
```dart
EpheFile? resolveActiveFile(EphemerisScan scan, double jdUt, BodyFamily family) {
  return scan.files.firstWhereOrNull((f) =>
      f.family == family &&
      f.status == EpheFileStatus.installed &&
      jdUt >= f.startJd && jdUt < f.endJd);
}
```
Already written this way in the plan's Implementation §5. Just promote into B5's acceptance criteria explicitly so B13 tests cover the corrupt-status case.

**M4 — disk-space pre-check (pm-016).** Add to B7:
```dart
final stat = await File('<destDir>/.probe').create().then((f) async {
  final fs = await FileStat.stat(destDir);
  // Platform-specific free-space check. dio doesn't expose this.
});
```
Actually — Dart has no cross-platform free-space API. Use platform channel or package `disk_space_plus`. For Phase 1, simpler: show catalog entry's size and require user confirmation on any download > 500 MB. Explicit opt-in is cheaper than a platform-channel dep.

Revise B7: downloader takes a `confirmLargeDownload: bool Function(int sizeBytes)` callback; B8's "Download" button shows a confirm dialog when size exceeds threshold.

**M5 — B6 golden protocol (pm-017).** Add to B6 acceptance: "Regenerate goldens. Run `git diff test/goldens/` — every changed pixel must be within the context-bar horizontal strip. Diff outside that region signals regression."

**M6 — End-to-end L2 test (pm-018).** Add Issue B14:
- `test/ephe/pipeline_test.dart` — L2. Create a temp dir, copy a known-good bundled file (e.g., `sepl_18.se1`) in, run scan via `scanEphemerisDirectory`, assert resolver reports it for JD 2460000. Then delete, re-scan, assert resolver returns null (Moshier).
- Dependencies: B4, B5. Runs in Wave 4.

**M7 — Downloader retry policy (pm-019).** Add to B7:
- 3 retries with exponential backoff on `DioExceptionType.connectionError`, `DioExceptionType.receiveTimeout`, `DioExceptionType.sendTimeout`.
- Retries preserve `.part` file (naturally resumed via Range on next attempt).
- After 3 failures, surface `DownloadFailed` error with user-actionable message; B8 shows it as a SnackBar and leaves the row actionable ("Retry" button).

## Error & Rescue Map

| Method | What Can Go Wrong | Rescued? | Rescue Action | User Sees |
|--------|-------------------|----------|---------------|-----------|
| `dio.download` — 416 Range | server ignores Range | Y | delete `.part`, retry from 0 | transparent restart |
| `dio.download` — network error | connection reset, timeout | Y after M7 | 3× exp-backoff retry then surface | SnackBar + "Retry" |
| `dio.download` — disk full | fs runs out of space | partial (M4) | confirm dialog for large files | confirm prompt |
| MD5 mismatch | corrupted bytes | Y | delete `.part`, throw | "corrupt" status + Delete button |
| `File.deleteSync` | permission denied | N | — | crash (rare on desktop user-owned dir) |
| `Directory.list` | dir deleted mid-scan | N | — | stale state; refresh button recovers |
| `swe.calcUt` probe | SweException | Y | mark corrupt | corrupt badge |
| `SwissEph.setEphePath` | nonexistent path | N | — | SE uses empty path silently; resolver will show all Moshier |
| `SharedPreferences` init | corrupt prefs | N | — | crash at boot (extremely rare) |
| `file_picker` cancel | user cancel | Y (null) | no-op | nothing happens |

Gap before fixes: M4 (disk full), M7 (network retry). After fixes: acceptable for Phase 1.

## Test Coverage

| Level | Planned | Post-Fix |
|-------|---------|----------|
| L0 contract | — (dio is external; mocked in L2) | Same |
| L1 unit | B10 parser, B13 resolver | Same |
| L2 integration | B11 downloader, B12 scanner | + B14 pipeline (M6) |
| L3 component | — (manual smoke) | Same |

Post-M6, coverage is sound.

## Timeline Risks

| Phase | Risk | Mitigation |
|-------|------|------------|
| Hour 1 (W1 setup) | S1 `sweProvider` redesign not caught until first path-change attempt | Resolve S1 in plan text before B2 starts |
| Hour 2 (W1 B7) | seCatalog scope left to implementer → bloat | Resolve S3 with explicit enumeration before B7 starts |
| Hour 4 (W2 B4 scanner) | BCE probe calcs land in wrong JD → all BCE files corrupt | Resolve S2 via `getCurrentFileData` probe on bundled `seplm06.se1` first |
| Hour 6+ (W3-W4) | B8 manager screen largest issue; scope risk | Prescribe visible-UI checklist; hold scope to the two tables, no settings sprawl |

## Scope Check (HOLD SCOPE posture)

Plan is already scoped to minimum viable Phase 1. No reduction recommended. Additions from pre-mortem (B14 pipeline test, M4 confirm dialog, M7 retry policy) are bulletproofing, not scope creep.

## Recommendation

**ADDRESS before `/implement`.** Three significant findings have concrete fixes that fit the existing plan; seven moderate findings are plan-text clarifications.

Action items:

1. Revise B2 Implementation §3 to split provider ownership from path-apply (S1).
2. Probe bundled `seplm06.se1` via `getCurrentFileData`; record real JD range; update B3 acceptance + document BCE convention in `types.dart` (S2).
3. Define `seCatalog` enumeration bound: bundled range ± 2 chunks per family. Add table or bounded generator in B7 (S3).
4. Name the context-bar target file in B6 acceptance (M1).
5. Name the nav insertion point in B9 acceptance — recommend overflow menu (M2).
6. Promote "status == installed" check into B5 acceptance; add corrupt-status case to B13 (M3).
7. Add confirm dialog for downloads > 500 MB in B7 + B8 acceptance (M4).
8. Add golden-diff protocol note to B6 (M5).
9. Add Issue B14 pipeline integration test; dependencies B4 + B5; Wave 4 (M6).
10. Add retry policy (3× exp-backoff on network errors) to B7 acceptance (M7).

After these edits, re-check and proceed to `/implement` (starting with W1 — B1, B2, B3, B7 in parallel).

## Decision Gate

- [ ] PROCEED — Council passed, ready to implement
- [x] ADDRESS — Fix concerns before implementing
- [ ] RETHINK — Fundamental issues, needs redesign
