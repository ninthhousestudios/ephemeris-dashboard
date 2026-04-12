---
id: research-2026-04-12-ephemeris-file-manager
type: research
date: 2026-04-12
---

# Research: SWE Dashboard — Ephemeris File Manager Feature

**Backend:** claude-native-teams (Explore subagent)
**Scope:** Desktop-only (Linux/macOS/Windows) UI to manage Swiss Ephemeris (.se1) and JPL DE ephemeris files: directory picker, file catalog with JD range metadata via `swe_get_current_file_data`, HTTP download with Range-resume, manual drop-in fallback, and context-bar fallback-awareness (Moshier sentinel).

## Summary

Feasibility is high. Every integration point is confirmed in the codebase. The app already bundles a working SE file set in `assets/ephe/` (55 files, 36 MB), already models `EpheSource.jpl` as an enum value, and already calls `swe.setEphePath` at startup. The `swisseph-0.4.4` package exposes `getCurrentFileData` (returns `FileDataResult` with `startDate`, `endDate`, `ephemerisNumber`, `path`) and `setJplFile` exactly as the feature needs. The `http` package is **not** yet a dependency — `dio` is recommended for Range-resume. One significant scope clarification: Swiss Ephemeris reads JPL files in its own `.eph` binary format (not raw `.bsp`); the `.bsp` files at NASA are for SPICE, not SE. This must be resolved before Phase 1 JPL work begins.

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/swe_service.dart` | `_ephePath` init, `sweProvider`, `setEphePath` call (lines 10–47) |
| `lib/core/swe_service_io.dart` | Desktop ephe path discovery logic; `_isValidEpheDir`; asset extraction (lines 16–230) |
| `lib/core/calc_context.dart` | `EffectiveContext.calculate` — where `_applyGlobals` runs; `epheSource` field present (line 36) but `setJplFile` not yet called |
| `lib/core/context_state.dart` | `EpheSource` enum: `.swissEph`, `.jpl`, `.moshier` (lines 134–140) |
| `lib/core/flag_definitions.dart` | `seFlgJplEph` listed in `autoManagedFlags` (line 104); locked by `EpheSource.jpl` |
| `pubspec.yaml` | `path_provider: ^2.1.5` present (line 19); `file_picker: ^10.3.10` present (line 20); NO `http`/`dio` yet |
| `assets/ephe/` | 55 bundled files: `seas_`, `semo_`, `sepl_` for years 0–48 CE + `m06`–`m54` BC; `sefstars.txt` |
| `~/.pub-cache/hosted/pub.dev/swisseph-0.4.4/lib/src/swiss_eph.dart` | `getCurrentFileData` (lines 283–301), `setJplFile` (lines 261–267) |

## Findings

### 1. SE File Catalog and Naming Convention

From the GitHub mirror (`github.com/aloistr/swisseph/tree/master/ephe`) and the app's own bundled assets:

**Naming:** `sepl_NN.se1` where `NN` is a century offset from year 0. Each file covers **600 years** (6 centuries). `sepl_18.se1` covers the epoch starting at century 18 × 6 = 1800 CE through 2399. `sepl_00.se1` = 0–599 CE. The `m` suffix = BCE: `seplm06.se1` = 600–1 BCE, `seplm54.se1` = 5400–4801 BCE.

**File families confirmed in this repo:**
- `sepl_*.se1` — main planets (Sun–Pluto + nodes + asteroids in main file)
- `semo_*.se1` — Moon (higher precision, separate file)
- `seas_*.se1` — "main asteroid file" (Chiron, Pholus, Ceres, etc.; `fileNum=2` in `getCurrentFileData`)
- `seasm*.se1` / `semom*.se1` / `seplm*.se1` — BCE counterparts (m-suffix)
- `sefstars.txt` — fixed stars catalog

The GitHub listing also shows `sefstars.txt` and `swe_deltat.inactive.txt`. **No `seleapsec.txt` or `sedeltat.txt` present in the public repo** — these may be included in the SE source distribution separately. The app's bundled set omits them.

**Named asteroid files (`sepla_*.se1`, `s0001s.se1`…):** These live in a separate Dropbox-hosted directory (`all_ast` / `long_ast`), totalling 29 GB (main-belt) + 11 GB (extended). Not on GitHub. Each file is one numbered asteroid. Count: tens of thousands of files.

**File sizes:** The bundled set shows `sepl_`, `semo_`, `seas_` run roughly 600 KB–1.2 MB each. The app's full bundle of 55 files = 36 MB, so ~650 KB average per file. Full AD coverage (sepl_00 through sepl_162 = 29 files) would be ~19 MB for planets alone.

**Filename → JD range without opening:** Yes, for standard files. Given `NN` = numeric suffix and family prefix, the JD range is deterministic: `startJD = julday(NN * 600, 1, 1, 0)`, `endJD = julday(NN * 600 + 600, 1, 1, 0)`. BCE files use the `m` prefix. The file manager can compute display ranges from filenames alone and then verify against `getCurrentFileData` once loaded.

**HTTP Range on astro.com FTP:** The astro.com FTP is now redirect-only (points to GitHub / Dropbox). GitHub raw URLs do **not** reliably honor `Range` headers for large files. Dropbox shared links may support Range. **This is an open question** — the download strategy must handle sites that return 200 instead of 206. See Recommendation 4.

**Checksums on astro.com:** No SHA/MD5 file manifest found in the public repo or FTP redirect page. Fall back to file-size check + SE file-format probe (magic bytes or `getCurrentFileData` returning a non-zero result).

### 2. JPL DE Catalog — Critical Scope Flag

**File inventory at `ssd.jpl.nasa.gov/ftp/eph/planets/bsp/`:**

| File | Size |
|------|------|
| de200.bsp | 54 MB |
| de405.bsp | 62 MB |
| de406.bsp | 287 MB |
| de421.bsp | 16 MB |
| de430_1850-2150.bsp | 31 MB |
| de431t.bsp | 3.44 GB |
| de440.bsp | 114 MB |
| de441.bsp | 3.08 GB |

Linux binary format: `linux_p1550p2650.440` = 97.5 MB (DE440 core range 1550–2650).

**CRITICAL — `.bsp` vs SE `.eph` format:**

`swisseph-0.4.4` exposes `setJplFile(String filename)` which calls `swe_set_jpl_file`. The SE C library expects its own JPL binary format, traditionally distributed as `de431.eph`, `de406.eph`, etc. — **not** NASA's `.bsp` SPICE kernels. The SE source includes a conversion tool (`src/precompile/`) that converts NASA ASCII/binary to SE's `.eph` format. Pre-converted SE `.eph` files are distributed by Astrodienst separately from GitHub (via Dropbox). **If Phase 1 includes JPL, it must download Astrodienst's pre-converted `.eph`, not NASA's `.bsp`.** Attempting to point `setJplFile` at a `.bsp` will silently fail or produce wrong results.

**Action required before `/plan`:** Confirm canonical URL for Astrodienst's pre-converted `de431.eph` / `de440.eph`. The Dropbox links from `astro.com/ftp/swisseph/` would be the source; direct download automation may be blocked by Dropbox's anti-hotlink policy. Manual drop-in may be the only reliable path for JPL files.

### 3. swisseph.dart 0.4.4 API — Confirmed

From `/home/josh/.pub-cache/hosted/pub.dev/swisseph-0.4.4/lib/src/swiss_eph.dart`:

**`getCurrentFileData(int fileNum) → FileDataResult`** (lines 283–301):
- `fileNum`: 0 = planet file (`sepl_*.se1`), 1 = Moon file (`semo_*.se1`), 2 = main asteroid file (`seas_*.se1`)
- Returns `FileDataResult { path: String?, startDate: double, endDate: double, ephemerisNumber: int }`
- `path` is null / empty string if no file is currently loaded for that slot
- `startDate`/`endDate` are Julian Day numbers (ET)
- `ephemerisNumber` = DE number embedded in the file (e.g. 431, 440, 200)
- **Probe behavior:** this is a post-load query — it reflects which file is loaded after a `calcUt` call for the target JD, not a pre-open catalog. To catalog all installed files, the manager must trigger a lightweight calc for a JD in each file's expected range, then read back the result.

**`setJplFile(String filename)`** (lines 261–267): takes a bare filename (e.g. `'de431.eph'`), not a full path. SE finds it relative to the currently set ephe path.

**`setEphePath(String path)`** (line 244): sets the directory. Called at startup in `swe_service.dart:43`.

**`getLibraryPath()`** (line 270): returns the `.so`/`.dylib`/`.dll` path — useful for diagnostics but not for file management.

**No "probe file without calc" API.** There is no `swe_open_file` or `swe_probe_file`. To read metadata, the manager must call `calcUt` for a JD within the file's expected range, then call `getCurrentFileData`. This is low-cost (one calc per 600-year chunk) and fully viable.

### 4. Current App Wiring

**Ephe path today** (`swe_service_io.dart:16–88`): Desktop release → exe-relative `data/ephe/`; dev mode → swisseph pub-cache `ephe/` dir; mobile/macOS → asset extraction to `getApplicationSupportDirectory()`. The bundled `assets/ephe/` (55 files, 36 MB) covers years ~5400 BCE through ~2400 CE for `sepl`, `semo`, `seas` families.

**JPL wiring today:** `EpheSource.jpl` exists in the enum (`context_state.dart:137`) and is listed in `autoManagedFlags` as auto-managing `seFlgJplEph` (`flag_definitions.dart:104`). However, `setJplFile` is **never called** anywhere in the app currently. The JPL path is modelled in UI but not wired to `_applyGlobals`. This is a known gap and a Phase 1 deliverable.

**`file_picker: ^10.3.10`** is already a dep (`pubspec.yaml:20`) — the directory picker for "point at existing SE install" is zero-cost to add.

**`path_provider: ^2.1.5`** already present — managed directory (`getApplicationSupportDirectory()`) is ready.

**No HTTP client:** `http` and `dio` are both absent from `pubspec.yaml`. `dio` must be added for Range-resume downloads.

### 5. Fallback Semantics

From SE documentation and the app's existing behavior:

When `calcUt` is called for a JD with no matching `.se1` file in the ephe directory, SE **silently falls back to Moshier analytical ephemeris** — no exception, no Dart-visible error. The return `iflag` value has `SEFLG_MOSEPH` bit set instead of `SEFLG_SWIEPH`; the `serr` buffer may contain a warning string but the return code is ≥ 0. The app currently ignores `returnFlag` on `CalcResult`, so Moshier fallback is invisible to the user.

The context-bar "file in use" feature must inspect `CalcResult.returnFlag & seFlgMosEph` after each calc to detect fallback. `getCurrentFileData(0)` returning `path == null` is the pre-calc signal that no planet file is loaded for that JD.

### 6. Flutter Desktop HTTP with Resume

`http` package (pub.dev): supports `Request` with arbitrary headers including `Range`, returns a `StreamedResponse`. Viable for resume, but no built-in `download()` helper — caller manages stream-to-file I/O and partial-file state.

`dio` package: has `dio.download(url, savePath, onReceiveProgress, options: Options(headers: {'Range': 'bytes=N-'}))` — first-class Range-resume support, progress callback, cancellation token. Strongly recommended.

**Recommendation:** add `dio: ^5.x` as the single new dep for downloads. It subsumes `http` for this feature.

### 7. Checksums

**Astro.com / GitHub:** No SHA/MD5 manifest found in the SE GitHub repo or FTP redirect page. File integrity falls back to: (a) file size check against known sizes, (b) SE file format probe via `getCurrentFileData` returning a valid `startDate`/`endDate` pair, (c) magic bytes check (SE `.se1` files begin with a known 4-byte header `SEPL`/`SEMO`/`SEAS`).

**NASA JPL:** The `bsp/` directory contains individual files; no separate checksum manifest was found in the directory listing. The Linux DE440 directory contains `testpo.440` (838 KB) — a test point file for validation. This can verify correctness post-download.

**Design decision:** for Phase 1, implement size + magic-byte probe. Checksum infrastructure (SHA-256 sidecar file) can be a Phase 2 improvement if Astrodienst adds manifests.

### 8. Storage Conventions

`getApplicationSupportDirectory()` returns:
- Linux: `~/.local/share/swe_dashboard/` (XDG compliant)
- macOS: `~/Library/Application Support/swe_dashboard/`
- Windows: `%APPDATA%\swe_dashboard\`

These directories are fully writable and not size-limited by the OS. A 3 GB `de431.eph` download is feasible at all three paths.

**Windows path gotcha:** `swe_set_ephe_path` in the C library passes the path directly to `fopen`. Paths with spaces work on all platforms if passed as-is (no shell escaping needed). Backslashes on Windows: the SE C source handles both `/` and `\` on Windows via its own path normalization. Confirmed safe per SE source comments.

**`setJplFile` takes a bare filename**, not a full path — it searches the currently set ephe path. The manager must call `setEphePath` first, then `setJplFile(basename)`. This means JPL files must live in the same managed directory as `.se1` files, or a separate `swe_set_jpl_file` call with an absolute path override.

### 9. Licensing

**Swiss Ephemeris:** dual-licensed AGPL-3 + commercial. The `.se1` files are part of the SE distribution and covered by the same license. Redistribution is permitted under AGPL-3 (open-source apps) or requires a paid commercial license for closed-source. The `swisseph` pub package includes `sepl_18.se1`, `semo_18.se1`, etc. in its bundled `ephe/` directory — same terms. **A license-accept gate is not legally required for AGPL-compliant open-source use**, but a brief attribution notice in the UI is good practice.

**JPL DE files:** NASA public domain. No license gate required.

**Recommendation:** show a one-time informational note (not a blocking gate) on first download: "Swiss Ephemeris files are provided under AGPL-3. This app is open source. [astro.com link]"

### 10. File Format Robustness

**`.se1` header magic:** SE binary files begin with a 4-byte identifier. The file type is encoded in the filename prefix (`sepl`/`semo`/`seas`) and the internal header. A truncated or wrong file will cause `getCurrentFileData` to return `path == null` or `startDate == 0.0`, or `calcUt` may throw a `SweException` with an "error in file" message.

**Detection approach:**
1. After drop-in, call `setEphePath` on the directory, then do a probe `calcUt` for a JD in the expected file's range.
2. Check `getCurrentFileData` — if `path` is non-null and matches the dropped file, it's valid.
3. If `calcUt` throws `SweException` or returns `SEFLG_MOSEPH` for a date that should be covered, mark the file corrupt.
4. Optionally pre-check magic bytes (first 4 bytes) before calling SE at all — fast reject for totally wrong files.

**No SE API exists for "validate file without calc."** The probe pattern is the correct approach.

### 11. Bundled Minimum

The app already ships a comprehensive bundle in `assets/ephe/` (55 files, 36 MB):
- `sepl_00` through `sepl_48` = 0–2999 CE (planets)
- `seplm06` through `seplm54` = 600–5400 BCE
- Same ranges for `semo_` (Moon) and `seas_` (main asteroids)
- `sefstars.txt`

This covers practical astrological use (5400 BCE – 2999 CE). **No additional bundled files are needed for Phase 1.** The file manager extends coverage beyond this range or adds named asteroids on demand.

The `sepl_18.se1` + `semo_18.se1` pair (1800–2399 CE, ~1.3 MB each) are the minimum for "modern use" — already bundled. No change to `assets/ephe/` needed.

## Recommendations

### Phase 1

1. **Directory picker + managed dir.** `file_picker` already present. Add `EphemerisDirectoryNotifier` backed by `SharedPreferences` (also already present). Two modes: "use managed dir" (default: `getApplicationSupportDirectory()/ephe`) and "use existing dir" (user-chosen).

2. **File catalog screen.** On directory change or user refresh: scan `.se1` files by name, compute expected JD range from filename numerics, then run probes via `getCurrentFileData` to confirm actual range and `ephemerisNumber`. Show table: filename | body family | start year | end year | DE# | status (ok/missing/corrupt).

3. **Wire `setJplFile` in `_applyGlobals`.** `calc_context.dart:_applyGlobals` currently ignores `epheSource == EpheSource.jpl`. Add `if (epheSource == EpheSource.jpl) swe.setJplFile(jplFilename)`. Requires a `jplFilename` field in `EffectiveContext` (or in `ContextBarState`). This is a 1-file change.

4. **Download with Range-resume.** Add `dio: ^5.x`. Download to `filename.part`, rename on completion. On 416 (Range Not Satisfiable = server ignores Range) restart from 0. Retry on network error. Progress shown in file catalog row.

5. **Context-bar fallback sentinel.** After each `calcUt`, inspect `CalcResult.returnFlag & seFlgMosEph`. If set, surface "Moshier" badge in context bar. `getCurrentFileData(0)` pre-calc check gives the "which file would be used" answer without a full calc.

6. **JPL Phase 1 scope:** Wire `setJplFile` + automated download from `https://ephe.scryr.io/jpl/` (confirmed 2026-04-12 — hosts de200.eph 43 MB, de406e.eph 360 MB, de431.eph 2.7 GB, de440.eph 100 MB, de441.eph 2.7 GB, with MD5 checksums). Manual drop-in remains the fallback per feature spec.

### Phase 2+

- Automated SE file downloads from a stable canonical URL (once HTTP Range support on the host is confirmed).
- Named asteroid file management (tens of thousands of files, 29+ GB — needs its own sub-UI).
- `seleapsec.txt` / `sedeltat.txt` update mechanism.
- SHA-256 integrity verification if Astrodienst publishes manifests.
- JPL automated download from NASA if direct `.bsp`→`.eph` conversion proves viable in-app (non-trivial: requires porting SE's `precompile` tool to Dart/FFI).

### Open Design Questions

**Resolved (2026-04-12):**

1. ~~**JPL `.eph` download URL:**~~ **RESOLVED** — `https://ephe.scryr.io/jpl/` confirmed as canonical host with MD5s. Treat as the JPL download root. Files: `de200.eph`, `de406e.eph`, `de431.eph`, `de440.eph`, `de441.eph`.

2. **Fallback detection:** **CONFIRMED IN SCOPE** — context bar surfaces "Moshier" sentinel via `CalcResult.returnFlag & seFlgMosEph` post-calc; pre-calc `getCurrentFileData(0)` answers "which file would be used" without computing.

3. ~~**Corruption recovery UX:**~~ **RESOLVED** — delete-only. No redownload offered. User manually re-triggers download from the catalog row after deletion. This keeps the state machine simple (one action per corrupt row).

**Still open (must answer before `/plan`):**

4. **SE file download host:** astro.com now redirects to GitHub/Dropbox. GitHub raw honors Range for files <100 MB (the per-file `.se1` size range); Dropbox behavior uncertain. Needs a HEAD + Range probe during planning. If unreliable, SE-file auto-download stays Phase 2 and Phase 1 ships SE as manual-drop-only.

5. **`setJplFile` path semantics:** Does it accept an absolute path, or only a basename relative to `setEphePath`? SE C source suggests basename only. Confirm with a live test during plan/implement (drives whether `.eph` files must live inside the managed `ephe/` dir or can live anywhere).

6. **Mixed-directory model:** Can `.se1` and `.eph` coexist in one `setEphePath` dir? Likely yes (SE ignores unknown extensions). Confirm. Default plan: they coexist.

## Next Step

`/plan` to decompose Phase 1 into trackable issues. Dependencies: directory picker → catalog scan → probe loop → fallback sentinel → JPL wiring → download (with `dio` dep add).
