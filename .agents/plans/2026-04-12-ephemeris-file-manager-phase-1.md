---
id: plan-2026-04-12-ephemeris-file-manager-phase-1
type: plan
date: 2026-04-12
source: "[[.agents/research/2026-04-12-ephemeris-file-manager]]"
---

# Plan: Ephemeris File Manager, Phase 1

## Context

The app ships a working 36 MB SE bundle in `assets/ephe/` (55 files, ~5400 BCE–2999 CE). `EpheSource.jpl` is modelled in state but `setJplFile` is never called — selecting JPL does nothing. The feature: a desktop-only screen that lets the user (1) point at an existing SE/JPL directory or use a managed one, (2) see a catalog of installed files with date ranges read from real file metadata via `swe_get_current_file_data`, (3) download missing files (JPL auto from `ephe.scryr.io/jpl/`; SE auto best-effort with manual-drop fallback), (4) see which file will actually be used for the current JD in the context bar (or "Moshier" sentinel if none covers it).

Research: `.agents/research/2026-04-12-ephemeris-file-manager.md` (full feasibility, confirmed symbols).

Applied findings: none (no compiled planning rules for this repo).

**Phase 1 scope:** directory picker + managed dir, catalog with probe-verified metadata, JPL `setJplFile` wiring, JPL auto-download with Range-resume, SE manual-drop (and best-effort auto-download), context-bar "which file" indicator, corruption = delete-only. Everything else (named asteroids, SHA manifests, .bsp→.eph conversion) is Phase 2+.

## Files to Modify

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `dio: ^5.x` (only new dep) |
| `lib/core/context_state.dart` | Add `String? jplFilename` to `ContextBarState` |
| `lib/core/calc_context.dart` | Add `jplFilename` to `EffectiveContext`; call `setJplFile` when `epheSource == jpl` in `_applyGlobals` |
| `lib/core/swe_service.dart` | `sweProvider` must rebuild when ephe dir changes; expose a reset-path helper |
| `lib/core/ephe/types.dart` | **NEW** — `EpheFile`, `BodyFamily` enum, `EpheFileStatus` enum |
| `lib/core/ephe/filename_parser.dart` | **NEW** — filename → family + JD range |
| `lib/core/ephe/dir_provider.dart` | **NEW** — `ephemerisDirectoryProvider` (SharedPreferences-backed, managed vs custom) |
| `lib/core/ephe/scanner.dart` | **NEW** — scan dir, run probe calcs, call `getCurrentFileData`, return `List<EpheFile>` |
| `lib/core/ephe/active_file.dart` | **NEW** — given JD + scan results → `EpheFile?` (null = Moshier will be used) |
| `lib/core/ephe/downloader.dart` | **NEW** — `EphemerisDownloader` with Range-resume, `.part` file pattern, MD5 verify |
| `lib/core/ephe/catalog.dart` | **NEW** — curated list of known SE + JPL files with canonical URLs + sizes + MD5s |
| `lib/widgets/ephe_manager/ephe_manager_screen.dart` | **NEW** — the main management screen |
| `lib/widgets/ephe_manager/file_row.dart` | **NEW** — one catalog row (filename, range, status, actions) |
| `lib/widgets/ephe_manager/license_notice.dart` | **NEW** — one-time SE license note on first download |
| `lib/widgets/context_bar/file_in_use_indicator.dart` | **NEW** — shows active file or "Moshier" |
| `lib/widgets/context_bar/context_bar.dart` | Insert `FileInUseIndicator` in row |
| `lib/layout/app_shell.dart` | Add overflow-menu entry → ephe manager screen |
| `test/ephe/filename_parser_test.dart` | **NEW** — parser unit tests |
| `test/ephe/downloader_test.dart` | **NEW** — mocked HTTP, Range + 416 handling |
| `test/ephe/scanner_integration_test.dart` | **NEW** — real SwissEph, scan bundled assets |
| `test/ephe/active_file_test.dart` | **NEW** — resolver unit tests |
| `test/ephe/pipeline_test.dart` | **NEW** — L2 pipeline integration test |

## Boundaries

**Always:**
- Desktop only (Linux/macOS/Windows). Web path must be a no-op / hidden nav entry.
- Zoom-safe UI per `CLAUDE.md` — no fixed-width SizedBox; use Wrap/LayoutBuilder.
- Preserve bundled `assets/ephe/` behavior. If user picks "managed dir" and it's empty, default to the currently-resolved `_ephePath` (so app keeps working out of the box).
- All network I/O gated by a confirmation button — never auto-download on startup.
- Download writes to `filename.part`, renames on success. Never overwrite a validated file in place.
- Corruption UX: delete-only. No auto-redownload. User re-triggers download manually from the catalog row after deletion.

**Ask First:**
- If `setJplFile` turns out to need absolute paths (live test in B1 will reveal), the design note for keeping `.eph` in the managed `ephe/` dir may need revision.
- If GitHub raw / Dropbox returns 200 instead of 206 on Range requests for SE files, B7 falls back to full redownload on failure (already specced in the `416` handler). Confirm this is acceptable UX.

**Never:**
- Do not auto-convert NASA `.bsp` → SE `.eph` in Phase 1 (out of scope; requires porting `precompile`).
- Do not manage named-asteroid files in Phase 1 (29+ GB catalog; its own sub-feature).
- Do not add SHA-256 manifest infrastructure in Phase 1 beyond the JPL MD5s already published at `ephe.scryr.io`.
- Do not touch the existing `assets/ephe/` bundle. The bundle is the fallback floor.

## Baseline Audit

| Metric | Command | Result |
|--------|---------|--------|
| Bundled ephe files | `ls assets/ephe/ \| wc -l` | 55 |
| Bundled size | `du -sh assets/ephe/` | 36 MB |
| `setJplFile` callers in app | `grep -rn 'setJplFile' lib/` | 0 |
| `EpheSource.jpl` references | `grep -rn 'EpheSource.jpl' lib/` | verified in `flag_state.dart:88`, `context_state.dart:137` |
| `file_picker` present | `grep 'file_picker' pubspec.yaml` | `file_picker: ^10.3.10` (line 20) |
| `path_provider` present | `grep 'path_provider' pubspec.yaml` | `path_provider: ^2.1.5` (line 19) |
| `dio`/`http` present | `grep -E '^\s*(dio\|http):' pubspec.yaml` | 0 |
| `shared_preferences` present | `grep 'shared_preferences' pubspec.yaml` | present (confirm exact version in issue B2) |
| swisseph API — `getCurrentFileData` | `~/.pub-cache/.../swiss_eph.dart:283-301` | confirmed |
| swisseph API — `setJplFile` | `~/.pub-cache/.../swiss_eph.dart:261-267` | confirmed |

## Implementation

### 1. Ephe Types + Filename Parser (Issue B3)

**`lib/core/ephe/types.dart`** (NEW):

```dart
enum BodyFamily { planets, moon, mainAsteroids, fixedStars, jpl, unknown }

enum EpheFileStatus { installed, missing, corrupt, downloading }

class EpheFile {
  final String filename;       // e.g. 'sepl_18.se1', 'de431.eph'
  final BodyFamily family;
  final double startJd;         // parsed from filename (0.0 if unknown)
  final double endJd;
  final int startYear;          // civil year (negative for BCE)
  final int endYear;
  final int? ephemerisNumber;   // from getCurrentFileData (null until probed)
  final int sizeBytes;          // filesystem size
  final EpheFileStatus status;
  final double? downloadProgress; // 0.0–1.0 when status == downloading

  const EpheFile({ required this.filename, required this.family, ... });
}
```

**`lib/core/ephe/filename_parser.dart`** (NEW):

```dart
EpheFile? parseEpheFilename(String filename, int sizeBytes) { ... }
```

- Recognize prefixes: `sepl`, `semo`, `seas`, `sepla` (BCE suffix `m`), `de\d+`/`de\d+[a-z]?\.eph`, `sefstars.txt`.
- For `sepl_NN.se1`: `startYear = NN * 600`, `endYear = startYear + 600`.
- BCE (`m` prefix): exact convention MUST be verified against a real file via `getCurrentFileData` before writing the parser. Procedure:
  1. Run a probe: `swe.calcUt(<rough JD in 600 BCE era>, seSun, 0)` after `setEphePath('assets/ephe')`.
  2. Call `swe.getCurrentFileData(0)` and record returned `startDate`/`endDate` (Julian Days).
  3. Convert those JDs to civil calendar years (using the Gregorian proleptic convention SE itself uses).
  4. The parser's BCE math must reproduce those exact years for `seplm06.se1`. Document the convention in `types.dart` as a code comment plus a test case. Do not ship B3 without this verification.
- Convert to JD via a pure Dart Gregorian→JD formula (avoid FFI in unit tests).
- For `de\d+\.eph`: family=jpl. Date range from `catalog.dart` lookup (not parseable from filename alone).
- For unknown filenames: return `EpheFile` with `family: unknown`, `startYear: 0`, `endYear: 0`.

### 2. JPL `setJplFile` Wiring (Issue B1)

**`lib/core/context_state.dart`**:

- Add `final String? jplFilename;` to `ContextBarState`. Default `null`. Add to `copyWith`, `==`, `hashCode`.
- Valid values: `'de200.eph'`, `'de406e.eph'`, `'de431.eph'`, `'de440.eph'`, `'de441.eph'` (basenames only; see research finding 8).

**`lib/core/calc_context.dart`**:

- Add `final String? jplFilename;` to `EffectiveContext` + `==`/`hashCode`.
- In `_applyGlobals`:
  ```dart
  if (epheSource == EpheSource.jpl && jplFilename != null) {
    swe.setJplFile(jplFilename!);
  }
  ```
- `effectiveContextProvider` propagates the field from `ContextBarState`.

### 3. Ephemeris Directory Provider (Issue B2)

**`lib/core/ephe/dir_provider.dart`** (NEW):

```dart
class EphemerisDirectorySettings {
  final bool useManaged;
  final String? customPath;
  const EphemerisDirectorySettings({required this.useManaged, this.customPath});
}

class EphemerisDirectoryNotifier extends StateNotifier<EphemerisDirectorySettings> { ... }

final ephemerisDirectoryProvider =
    StateNotifierProvider<EphemerisDirectoryNotifier, EphemerisDirectorySettings>(...);

final resolvedEphePathProvider = Provider<String>((ref) {
  final settings = ref.watch(ephemerisDirectoryProvider);
  if (settings.useManaged) return _managedPath;  // `<app-support>/ephe`
  return settings.customPath ?? _fallbackToBundled;
});
```

- On mutation, persist to SharedPreferences with keys `ephe.useManaged` (bool), `ephe.customPath` (String).
- On init, read keys; default `useManaged: true`.

**`lib/core/swe_service.dart`**:

Split lifecycle from path application — a Riverpod `Provider` rebuilds (and calls `onDispose`) whenever a watched dependency changes, so watching `resolvedEphePathProvider` inside `sweProvider` would dispose the `SwissEph` on every directory change. Split into two providers:

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

- App startup (`app.dart` / shell init) must `ref.read(ephePathApplyProvider)` once before any calc runs.
- Tab providers that should re-run when the path changes add `ref.watch(ephePathApplyProvider)` alongside their existing `ref.watch(sweProvider)`.
- `setEphePath` reapplies imperatively on the same C instance; no disposal, no in-flight calc crash.
- The managed dir (`<app-support>/ephe`) must exist at startup. Add dir-create to `swe_service_io.dart` init if missing.

### 4. Directory Scanner (Issue B4)

**`lib/core/ephe/scanner.dart`** (NEW):

```dart
class EphemerisScan {
  final List<EpheFile> files;
  final DateTime scannedAt;
  const EphemerisScan(this.files, this.scannedAt);
}

Future<EphemerisScan> scanEphemerisDirectory(SwissEph swe, String dir) async { ... }

final ephemerisScanProvider = FutureProvider<EphemerisScan>((ref) {
  final swe = ref.watch(sweProvider);
  final path = ref.watch(resolvedEphePathProvider);
  return scanEphemerisDirectory(swe, path);
});
```

Algorithm:
1. `Directory(dir).list()` → filter `.se1` + `.eph` + `sefstars.txt`.
2. For each match, call `parseEpheFilename(name, statSize)` → get `EpheFile`.
3. For SE files, run a probe `calcUt(startJd + 100, seSun, 0)` (SE), then `getCurrentFileData(fileNum)` where `fileNum = family == planets ? 0 : family == moon ? 1 : 2`. Fill in `ephemerisNumber` + verify `startDate`/`endDate` match filename-derived range. On mismatch or throw → `status: corrupt`.
4. For JPL files, no probe in Phase 1 — scanner just records presence + catalog-derived range. (Probing JPL requires temporarily `setJplFile` + `calcUt` with `SEFLG_JPLEPH`, which can disturb global state. Defer to Phase 2 when we have a probe-isolation pattern.)
5. Return `EphemerisScan`.

### 5. Active File Resolver (Issue B5)

**`lib/core/ephe/active_file.dart`** (NEW):

```dart
EpheFile? resolveActiveFile(EphemerisScan scan, double jdUt, BodyFamily family) {
  return scan.files.firstWhereOrNull((f) =>
      f.family == family &&
      f.status == EpheFileStatus.installed &&
      jdUt >= f.startJd && jdUt < f.endJd);
}

final activeFileProvider = Provider.family<EpheFile?, BodyFamily>((ref, family) {
  final jd = ref.watch(effectiveContextProvider).jdUt;
  final scan = ref.watch(ephemerisScanProvider).valueOrNull;
  if (scan == null) return null;
  return resolveActiveFile(scan, jd, family);
});
```

Null means "no file covers this JD for this family → SE will silently use Moshier."

### 6. Context-Bar File-in-Use Indicator (Issue B6)

**`lib/widgets/context_bar/file_in_use_indicator.dart`** (NEW):

- Small chip/badge reading `ref.watch(activeFileProvider(BodyFamily.planets))`.
- If non-null → show `sepl_18.se1` (filename only; tooltip shows full JD range).
- If null → show amber "Moshier" badge with tooltip: "No ephemeris file covers JD 2460412.5 — using analytical Moshier."
- Tap → navigates to ephe manager screen (uses route defined in B9).

Insert into the existing context bar row. Zoom-safe: use `Flexible` + intrinsic width.

### 7. Downloader (Issue B7)

**`pubspec.yaml`**: add `dio: ^5.x` (pick latest 5.x stable at implementation time).

**`lib/core/ephe/catalog.dart`** (NEW):

```dart
class CatalogEntry {
  final String filename;
  final BodyFamily family;
  final Uri url;
  final int? sizeBytes;
  final String? md5;
  const CatalogEntry({required this.filename, required this.family, required this.url, this.sizeBytes, this.md5});
}

const jplCatalog = <CatalogEntry>[
  CatalogEntry(filename: 'de200.eph', family: BodyFamily.jpl,
      url: Uri.parse('https://ephe.scryr.io/jpl/de200.eph'), sizeBytes: 43*1024*1024),
  CatalogEntry(filename: 'de406e.eph', ...),
  CatalogEntry(filename: 'de431.eph', ..., sizeBytes: 2700*1024*1024),
  CatalogEntry(filename: 'de440.eph', ...),
  CatalogEntry(filename: 'de441.eph', ...),
];

// SE catalog bound (Phase 1): bundled range ± 2 chunks per family.
//   Bundled AD: sepl_00–sepl_48, semo_00–semo_48, seas_00–seas_48
//   Bundled BCE: seplm06–seplm54, semom06–semom54, seasm06–seasm54
//   Phase 1 catalog adds: sepl_50, sepl_52; seplm56, seplm58 (and same for semo_, seas_)
// Total seCatalog size: ~12 entries (2 extra chunks × 3 families × 2 directions).
// Anything beyond this is Phase 2. Generate programmatically from this bounded range.
// URL template: https://raw.githubusercontent.com/aloistr/swisseph/master/ephe/<filename>
// Auto-download may fail if GitHub returns 200 on Range; downloader restarts gracefully.
const seCatalog = <CatalogEntry>[
  // Enumerate the 12 extension files here.
];
```

MD5 values for JPL: add to catalog once copied from `ephe.scryr.io/jpl/` page. Hash verification after download; mismatch → delete `.part`, mark status corrupt.

**`lib/core/ephe/downloader.dart`** (NEW):

```dart
class DownloadProgress {
  final int received;
  final int total;
  final double fraction;
  const DownloadProgress(this.received, this.total, this.fraction);
}

class EphemerisDownloader {
  EphemerisDownloader(this._dio);
  final Dio _dio;

  Stream<DownloadProgress> download({
    required CatalogEntry entry,
    required String destDir,
    CancelToken? cancel,
  }) async* {
    final partPath = '$destDir/${entry.filename}.part';
    final finalPath = '$destDir/${entry.filename}';
    final partSize = File(partPath).existsSync() ? File(partPath).lengthSync() : 0;

    try {
      final response = await _dio.download(
        entry.url.toString(),
        partPath,
        options: Options(headers: {'Range': 'bytes=$partSize-'}),
        onReceiveProgress: (r, t) { /* yield via controller */ },
      );
      // Status 206 = Partial OK, continue from partSize.
      // Status 200 = server ignored Range; .part was overwritten from 0. OK.
      // Status 416 = Range not satisfiable; delete .part and retry from 0.
    } catch (e) {
      if (/* 416 */) {
        File(partPath).deleteSync();
        // retry once from 0
      } else rethrow;
    }

    if (entry.md5 != null) {
      final actual = md5.convert(await File(partPath).readAsBytes()).toString();
      if (actual != entry.md5) {
        File(partPath).deleteSync();
        throw const FormatException('MD5 mismatch');
      }
    }

    File(partPath).renameSync(finalPath);
  }
}
```

Expose as `downloaderProvider`. Use a `StreamController` pattern to surface progress.

### 8. Ephe Manager Screen (Issue B8)

**`lib/widgets/ephe_manager/ephe_manager_screen.dart`** (NEW):

- Header: current resolved ephe directory path. "Change…" button → segmented control: "Managed" / "Custom…" → `file_picker.getDirectoryPath()` for custom.
- Two tables (or tabbed): **Swiss Ephemeris** and **JPL**.
- Each row uses `FileRow` widget (B8 sub-component):
  - Filename, family badge, date range (e.g., "1800 CE – 2399 CE"), size, status badge.
  - Action button:
    - `installed` → "Delete" (with confirm)
    - `missing` + catalog has URL → "Download" (triggers `downloader.download`)
    - `missing` + no URL → "Drop in file…" → `file_picker.pickFiles(allowedExtensions: ['se1', 'eph'])` → copy to dir → refresh scan.
    - `downloading` → progress bar + "Cancel" button.
    - `corrupt` → "Delete" (delete-only per scope).
- License notice (B8 sub-component): shown once on first download via SharedPreferences flag `ephe.licenseSeen`. Text: "Swiss Ephemeris files are distributed under AGPL-3 by Astrodienst. See astro.com/swisseph."

### 9. Navigation Entry (Issue B9)

- In `app_shell.dart` (or equivalent settings/overflow menu), add a menu item "Ephemeris Files…" → push the manager screen.
- Accessible from the Moshier-sentinel badge tap target (B6).

### 10. Tests

**`test/ephe/filename_parser_test.dart` (B10) — L1 unit:**

- `testParse_SeplAdFile`: `parseEpheFilename('sepl_18.se1', 1300000)` → `family: planets, startYear: 1800, endYear: 2400`.
- `testParse_SeplBceFile`: `parseEpheFilename('seplm06.se1', ...)` → `startYear: -599, endYear: 0` (or agreed BCE convention).
- `testParse_Semo`: `semo_18.se1` → `family: moon`.
- `testParse_Seas`: `seas_18.se1` → `family: mainAsteroids`.
- `testParse_JplDe431`: `de431.eph` → `family: jpl`; date range filled from catalog.
- `testParse_Unknown`: `readme.txt` → `family: unknown`.
- `testParse_Sefstars`: `sefstars.txt` → `family: fixedStars`.

**`test/ephe/downloader_test.dart` (B11) — L2 with MockDio:**

- `testDownload_FreshSucceeds`: server returns 200, full file, MD5 matches → `.part` renamed to final.
- `testDownload_ResumeAtOffset`: existing `.part` of size N, server returns 206, appends remainder → final matches.
- `testDownload_416Retries`: existing `.part`, server returns 416 → `.part` deleted, retry from 0, success.
- `testDownload_Md5MismatchDeletes`: bytes ok, MD5 wrong → `.part` deleted, throws FormatException.
- `testDownload_CancelMidStream`: cancel token triggers → `.part` survives for next resume.

**`test/ephe/scanner_integration_test.dart` (B12) — L2 real SwissEph:**

- Point scanner at `assets/ephe/` (or a fixture copy). Expect ≥ 55 files, all installed, no corrupt. Expect `ephemerisNumber` populated on `sepl_*.se1` (likely DE431 per swisseph bundling).
- Scan an empty temp dir → empty scan, no throw.
- Scan a dir with a garbage `sepl_18.se1` (random bytes) → that file `status: corrupt`.

**`test/ephe/active_file_test.dart` (B13, folded into B10's file or separate) — L1 pure:**

- `testResolve_InRange`: scan with `sepl_18.se1` (1800–2399), jd for 2000 CE → returns that file.
- `testResolve_OutOfRange`: jd for year 3000 → null.
- `testResolve_WrongFamily`: asks for moon when only planets file present → null.

## Conformance Checks

| Issue | Check Type | Check |
|-------|-----------|-------|
| B1 | content_check | `calc_context.dart` contains `swe.setJplFile(` |
| B1 | content_check | `context_state.dart` contains `jplFilename` |
| B2 | files_exist | `lib/core/ephe/dir_provider.dart` |
| B2 | content_check | `swe_service.dart` contains `ref.watch(resolvedEphePathProvider)` |
| B3 | files_exist | `lib/core/ephe/types.dart`, `lib/core/ephe/filename_parser.dart` |
| B3 | content_check | `filename_parser.dart` contains `parseEpheFilename` |
| B4 | files_exist | `lib/core/ephe/scanner.dart` |
| B4 | content_check | `scanner.dart` contains `getCurrentFileData` |
| B5 | files_exist | `lib/core/ephe/active_file.dart` |
| B5 | content_check | `active_file.dart` contains `activeFileProvider` |
| B6 | files_exist | `lib/widgets/context_bar/file_in_use_indicator.dart` |
| B6 | content_check | `file_in_use_indicator.dart` contains `Moshier` |
| B7 | content_check | `pubspec.yaml` contains `dio:` |
| B7 | files_exist | `lib/core/ephe/downloader.dart`, `lib/core/ephe/catalog.dart` |
| B7 | content_check | `downloader.dart` contains `Range` and `416` |
| B8 | files_exist | `lib/widgets/ephe_manager/ephe_manager_screen.dart` |
| B8 | content_check | screen contains `file_picker` usage and `EpheFileStatus.downloading` handling |
| B9 | content_check | `app_shell.dart` contains `EphemerisManagerScreen` navigation |
| B10–B14 | tests | `flutter test test/ephe/` |
| B14 | files_exist | `test/ephe/pipeline_test.dart` |
| Global | build | `flutter analyze` clean |
| Global | tests | `flutter test test/goldens/` (verify no regression from context-bar insert) |

## Verification

1. **Unit tests:** `flutter test test/ephe/`
2. **Analyzer:** `flutter analyze`
3. **Goldens (expect context-bar diff from indicator insert):**
   ```bash
   flutter test test/goldens/ --update-goldens
   git diff test/goldens/   # expect only context-bar strip changes
   flutter test test/goldens/
   ```
4. **Manual smoke:**
   ```bash
   flutter run -d linux
   # (a) Open ephe manager → see catalog with 55+ bundled files, all "installed".
   # (b) Set context JD to 3000 CE → context bar shows "Moshier" badge.
   # (c) Tap "Download" on de440.eph (100 MB) → progress increments, file appears in catalog.
   # (d) Switch EpheSource to JPL, set jplFilename = 'de440.eph' → calc still succeeds.
   # (e) Kill app mid-download → relaunch → resume completes, MD5 verifies.
   # (f) Pick custom dir via "Change…" → catalog repopulates from that dir.
   ```
5. **Live-test open questions during B1/B7:**
   - Does `setJplFile('/absolute/path/de440.eph')` work? If yes, document; if not, require JPL files live in managed dir.
   - Does `ephe.scryr.io` serve 206 Partial on Range? If only 200, `.part` handling gracefully restarts.

## Issues

### Issue B1: Wire `setJplFile` in `_applyGlobals`
**Dependencies:** None
**Acceptance:** `ContextBarState` + `EffectiveContext` both carry `String? jplFilename`. `_applyGlobals` calls `swe.setJplFile(jplFilename!)` when `epheSource == EpheSource.jpl && jplFilename != null`. Flag state logic in `flag_state.dart:88` unchanged. Manual test: set source=JPL + filename='de440.eph' (after that file exists) → `calcUt` returns values different from Moshier.

### Issue B2: Ephemeris directory provider + managed dir
**Dependencies:** None
**Acceptance:** `ephemerisDirectoryProvider` + `resolvedEphePathProvider` exist. Settings persist via SharedPreferences. `sweProvider` re-points SwissEph on change. Managed dir auto-created at app-support path. App still launches with bundled assets when `useManaged: true` and managed dir is empty (falls through to existing `_ephePath` logic or symlinks the bundle on first run — pick one in the implementation).

### Issue B3: Ephe types + filename parser
**Dependencies:** None
**Acceptance:** `types.dart` defines `EpheFile`, `BodyFamily`, `EpheFileStatus`. `filename_parser.dart::parseEpheFilename` handles SE (`sepl_*`, `semo_*`, `seas_*` + BCE `m`-suffix), JPL (`de\d+\.eph`), fixed stars, and returns `unknown` for anything else. Pure function, no FFI. B10 tests pass.

### Issue B4: Directory scanner
**Dependencies:** B2 (dir provider), B3 (types + parser)
**Acceptance:** `scanEphemerisDirectory(swe, dir)` returns `EphemerisScan` with all `.se1`/`.eph` files + `sefstars.txt` found. Each SE file probed via `getCurrentFileData`; `ephemerisNumber` and status filled. `ephemerisScanProvider` invalidates when dir changes. B12 integration test passes.

### Issue B5: Active file resolver
**Dependencies:** B3, B4
**Acceptance:** `resolveActiveFile(scan, jd, family)` returns an `EpheFile` only when `family` matches, `jdUt` falls in `[startJd, endJd)`, AND `status == EpheFileStatus.installed`. Returns null for any other case (corrupt files, missing files, wrong family, out-of-range JD) so the sentinel correctly reports "Moshier" when the file on disk won't actually be usable. `activeFileProvider` family-keyed Riverpod. B13 tests pass (including explicit corrupt-status case).

### Issue B6: Context-bar file-in-use indicator
**Dependencies:** B5
**Acceptance:** `FileInUseIndicator` renders filename when a planets file covers current JD, "Moshier" badge when none. Tooltip shows range/explanation. Tap navigates to ephe manager screen. Inserted into existing context bar row without layout regression. Golden-diff protocol: after `flutter test test/goldens/ --update-goldens`, run `git diff test/goldens/` and confirm every changed pixel falls within the context-bar horizontal strip. Any diff outside that strip is a regression — investigate before accepting.

### Issue B7: Dio dep + downloader + catalog
**Dependencies:** B3 (types)
**Acceptance:** `dio: ^5.x` added to `pubspec.yaml`. `EphemerisDownloader` streams `DownloadProgress`. Handles 200/206/416, `.part` rename pattern, MD5 verify (JPL only in Phase 1). `jplCatalog` populated with 5 files + MD5s from `ephe.scryr.io/jpl/`. `seCatalog` populated with GitHub raw URLs for `sepl_*`, `semo_*`, `seas_*` (best-effort; manual-drop fallback in B8). `download()` accepts a `Future<bool> Function(int sizeBytes) confirmLargeDownload` callback; downloader awaits callback before starting any transfer whose `entry.sizeBytes > 500 * 1024 * 1024`, and aborts if callback returns false. Retry policy: on `DioExceptionType.connectionError`, `receiveTimeout`, or `sendTimeout`, retry up to 3× with exponential backoff (1s, 2s, 4s); each retry preserves the `.part` file so resume continues naturally via Range. After 3 failures surface a `DownloadFailed` error with a user-actionable message. B11 tests pass (including retry + confirm-callback cases).

### Issue B8: Ephe manager screen
**Dependencies:** B2, B3, B4, B7
**Acceptance:** Screen renders two tables (SE + JPL), each row shows filename/range/size/status and an action button per status. "Change directory" toggles managed ↔ custom. "Drop in file" picker copies a user-supplied file and refreshes scan. License notice shown once before first network download (dismiss persists to SharedPreferences). Zoom-safe (Wrap + intrinsic widths). When a row's Download button fires and the catalog entry's `sizeBytes > 500 * 1024 * 1024`, show a confirm `AlertDialog` ("Download {filename} — {size MB}. This will use significant disk space and bandwidth. Continue?") wired into the downloader's `confirmLargeDownload` callback. If the downloader surfaces `DownloadFailed` after retries exhaust, the row shows a SnackBar with the message and keeps a "Retry" affordance.

### Issue B9: Navigation entry
**Dependencies:** B8
**Acceptance:** User can reach the manager screen from `app_shell.dart` (settings menu or equivalent) AND from the Moshier-sentinel tap in B6.

### Issue B10: Filename parser tests
**Dependencies:** B3
**Acceptance:** `test/ephe/filename_parser_test.dart` passes. Covers AD, BCE, all three SE families, JPL, fixed stars, unknown.

### Issue B11: Downloader tests
**Dependencies:** B7
**Acceptance:** `test/ephe/downloader_test.dart` passes with MockDio. Covers 200/206/416/MD5-mismatch/cancel.

### Issue B12: Scanner integration test
**Dependencies:** B4
**Acceptance:** `test/ephe/scanner_integration_test.dart` passes against bundled assets (or a fixture copy). Real SwissEph, not mocked. Handles empty dir and corrupt-file case.

### Issue B13: Active file resolver tests
**Dependencies:** B5
**Acceptance:** `test/ephe/active_file_test.dart` passes. Covers in-range, out-of-range, wrong-family, and explicit corrupt-status case (file on disk with `EpheFileStatus.corrupt` whose range covers the JD must return null — sentinel reports Moshier).

### Issue B14: Pipeline integration test
**Dependencies:** B4, B5
**Acceptance:** `test/ephe/pipeline_test.dart` — L2. Creates a temp directory, copies a known-good bundled file (e.g. `assets/ephe/sepl_18.se1`) in, runs `scanEphemerisDirectory` with a real `SwissEph`, then asserts `resolveActiveFile(scan, 2460000.0, BodyFamily.planets)` returns the copied file with `status == installed`. Deletes the file, re-scans, asserts resolver returns null (Moshier path). This proves the directory-provider → scanner → resolver seam connects — any break in B4/B5 integration is caught here rather than in manual smoke.

## File-Conflict Matrix

| File | Issues | Notes |
|------|--------|-------|
| `pubspec.yaml` | B7 | Only B7 |
| `lib/core/context_state.dart` | B1 | Only B1 |
| `lib/core/calc_context.dart` | B1 | Only B1 |
| `lib/core/swe_service.dart` | B2 | Only B2 |
| `lib/core/ephe/types.dart` | B3 | New |
| `lib/core/ephe/filename_parser.dart` | B3 | New |
| `lib/core/ephe/dir_provider.dart` | B2 | New |
| `lib/core/ephe/scanner.dart` | B4 | New |
| `lib/core/ephe/active_file.dart` | B5 | New |
| `lib/core/ephe/catalog.dart` | B7 | New |
| `lib/core/ephe/downloader.dart` | B7 | New |
| `lib/widgets/ephe_manager/*.dart` | B8 | All new, same wave |
| `lib/widgets/context_bar/file_in_use_indicator.dart` | B6 | New |
| `lib/widgets/context_bar/<existing>.dart` | B6 | Only B6 inserts the indicator |
| `lib/layout/app_shell.dart` | B9 | Only B9 |
| `test/ephe/*.dart` | B10–B14 | All new, independent |

No same-wave file collisions.

## Cross-Wave Shared Files

| File | Earlier Wave | Later Wave | Mitigation |
|------|--------------|------------|------------|
| `lib/core/ephe/types.dart` | W1 (B3) | W2 (B4, B10), W3 (B5, B8) | B3 writes the types once; later issues import only. |
| `lib/core/ephe/scanner.dart` | W2 (B4) | W3 (B5, B8), W4 (B12) | B4 writes scanner once; later issues import only. |
| `lib/core/swe_service.dart` | W1 (B2) | — | Single-wave touch. |
| `pubspec.yaml` | W1 (B7) | — | Single-wave touch. |

No destructive cross-wave overlaps.

## Execution Order

**Wave 1 (parallel, no deps):** B1, B2, B3, B7
**Wave 2 (parallel, after W1):** B4 (B2+B3), B10 (B3), B11 (B7)
**Wave 3 (parallel, after W2):** B5 (B3+B4), B12 (B4)
**Wave 4 (parallel, after W3):** B6 (B5), B8 (B2+B3+B4+B7), B13 (B5), B14 (B4+B5)
**Wave 5:** B9 (B8)

Critical path: B3 → B4 → B5 → B6 (or B8) → B9 (5 serial hops). Parallel tracks B1, B2, B7 finish early and stay parked.

## Post-Merge Cleanup

- `grep -rn 'TODO' lib/core/ephe/ lib/widgets/ephe_manager/` → address deferred items.
- Verify `flutter analyze` clean.
- Regenerate goldens for context-bar insert; eyeball each changed PNG.
- Update `doc/` (create `doc/ephe-manager.md` if not present) with user-facing docs.

## Next Steps

- `/pre-mortem` to stress-test this plan before execution.
- Then `/crank` or `/implement B1` (or any W1 issue) to begin.
- Phase 2 follow-up plan: named-asteroid sub-UI, SHA manifest infra, JPL probe-isolation, NASA `.bsp` conversion pipeline.
