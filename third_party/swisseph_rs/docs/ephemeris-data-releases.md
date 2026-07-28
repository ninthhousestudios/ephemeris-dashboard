# Ephemeris data releases and the goldens pinned to them

`ephe/` holds the binary Swiss Ephemeris data and is git-ignored, so the data
release is invisible to git: nothing in the repo records when it changed or
what it changed from. A refresh of that directory silently invalidates every
expectation computed from a `.se1` file.

It used to be a symlink to `../swisseph-rs/ephe`. It is now a **real
directory** — the browser test server does not follow a symlink out of the
package root, so every fetch of `ephe/…` 404'd and the only web-side
Swiss-file test skipped itself for as long as it existed
(`swisseph-rs-dart/57`). Being a real directory also means this repo holds its
own snapshot of the data rather than aliasing a neighbour's, which is what
makes the release pin below meaningful.

This document is the record that git cannot keep. It names the pinned release,
inventories which tests depend on the data, and states what to do when the
release changes.

Enforcement lives in `test/integration/ephemeris_release_test.dart`, which
reads the release provenance out of the data files and fails legibly when it
drifts from the pin. That test is the machine-checked half; the inventory
below is the reviewed half.

## Pinned release

| Property | Value |
| --- | --- |
| File format | `SWISSEPH  3` (`.se1` header line 1) |
| Release | `Created for Astrodienst in Switzerland 2026/05/26, based on JPL Ephemeris DE441.` |
| Pinned files | `sepl_18.se1`, `semo_18.se1`, `seas_18.se1` |
| Fixed stars | `sefstars.txt`, SHA-256 `1f5cddff…9fe59bed` (no version line in the file) |

Every Swiss-file golden in the suite queries JD 2451545.0 (J2000.0), which
falls in the 1800–2400 AD segment — hence the `_18` files and no others.
`seas_18.se1` has no golden depending on it today; it is pinned because it
ships as part of the same Astrodienst release, so a partial refresh of `ephe/`
is caught rather than half-applied.

### History

| Date | Release | Note |
| --- | --- | --- |
| ≤ 2026-07-07 | DE431 | Goldens originally recorded against this. |
| 2026-07-19 | SE3 / DE441 (2026/05/26) | Upgraded in place. Moved the J2000 Sun longitude by ~2.9e-8 deg — 28x the 1e-9 positional agreement class. Surfaced only as an unexplained numeric drift in one test; diagnosed and re-recorded in `1d0d3f3`. This task (`swisseph-rs-dart/50`) is the generalization. |

The 2026-07-19 date is a file mtime, not a record — it was the only forensic
trace available. Entries from here on should be written when the swap happens.

## Inventory: what depends on the data

Audited 2026-07-27 across `test/` (the oracle harness in `test_oracle/` is
covered separately — it compares against the C engine reading the *same*
files, so a data swap moves both sides together and is invisible there).

### Data-dependent, with a hardcoded golden

| Test | File(s) read | Tolerance | Catches a release change? |
| --- | --- | --- | --- |
| `integration/ephemeris_test.dart` → `calcUt Sun longitude` → *Swiss-file: Sun at J2000 epoch* | `sepl_18.se1`, `semo_18.se1` | 1e-9 deg | **Yes** — this is the one test that caught DE431→DE441. |
| `integration/web_test.dart` → `Swiss-file path (MEMFS)` → *loadEpheFile → construct → calc* | `sepl_18.se1`, `semo_18.se1` | 1e-9 deg | **Yes**, since `swisseph-rs-dart/57`. Was 1e-3 deg behind a silent skip; now runs and asserts longitude, longitude speed, and distance, all three bit-identical to the C oracle and the native binding. |

### Data-dependent, but not a golden

| Test | File(s) read | Why it does not catch a release change |
| --- | --- | --- |
| `integration/fixstar_config_test.dart` → `fixstar2UtWithConfig`, `fixstar2WithConfig` | `sefstars.txt` (+ `.se1`) | Asserts a per-call config override equals a value computed in the same run. Catches override-plumbing bugs, not data drift. Requires `SWE_EPHE_PATH` (hard-fails without it rather than skipping). |
| `integration/web_memfs_test.dart` → *staged bytes are what the engine finds at /ephe* | none (feeds garbage bytes) | Exercises the `EphemerisSource.swiss` MEMFS path for error-type transitions only. |
| `integration/ephemeris_test.dart` → *bad ephePath throws FileNotFoundException* | none | Error path; validates file lookup failure, not data content. |

### Not data-dependent

Everything else. Worth stating explicitly, because the suite looks far broader
than its Swiss-file coverage actually is:

- `integration/cross_validation/cross_validation_test.dart` — all 12 groups
  (154 house-cusp combinations, 91 planet positions, 98 ayanamsa values, rise
  and set, topocentric, equatorial, …) run on the default `EphemerisConfig()`,
  which is Moshier. `SEFLG_SWIEPH` appears nowhere. Its planet positions span
  JD 2432412.5–2470172.5 (≈1948–2054), but no `.se1` file is touched.
- `stress/stress_test.dart` — every calc explicitly forces `CalcFlags.mosEph`.
  An `ephePath` is passed through config when `ephe/` exists but is never
  selected by a flag.
- `integration/share_test.dart`, the Moshier groups of `integration/web_test.dart`,
  and the web glue tests (`web_cachebust`, `web_glue_stall`, `web_retry`,
  `web_stall`) — default config, sharing the Moshier J2000 golden
  `280.36891967534336`.
- `unit/types_test.dart` — type, enum, and flag algebra.
- `differential/totality_test.dart` — static analysis of the public API
  surface; no ephemeris calls at all.
- `integration/web_reexec_test.dart` — DOM and script-tag assertions.

**Conclusion of the audit.** Swiss-file coverage is thin, and it is thin in
exactly the way the DE441 incident suggested: the apparent breadth of the
golden suite is Moshier breadth and does not exercise the data files. At the
time of the audit precisely one test carried a tight-tolerance golden tied to
`.se1` content; `swisseph-rs-dart/57` made the web-side test a second one, on
both the native and web legs. The release pin exists so that detection no
longer rests on either.

## Populating `ephe/`

`ephe/` is git-ignored, so a fresh clone has none of it. Populate it by
copying the data files — not by symlinking, which breaks the browser tests:

```sh
mkdir -p ephe
cp -p /path/to/swisseph/ephe/*.se1 \
      /path/to/swisseph/ephe/*.txt \
      /path/to/swisseph/ephe/*.md  ephe/
```

That is ~122 MB. Deliberately omitted: `de441.eph` (2.6 GB JPL binary — the
`JPLEPH` flag is only ever exercised as a precedence fallback and never opens
the file), `list.zip`, and the `ast*/`, `ep4/`, `sat/` subdirectories, which
nothing references. Add them if minor-planet work needs them.

`ephe/` must stay out of the published package. It already does: with no
`.pubignore` present, pub honours `.gitignore`, and the archive is 864 KB.
**Do not add a root `.pubignore` for this** — a `.pubignore` *replaces*
`.gitignore` for publishing rather than adding to it, so introducing one
pulls `rust/target/` and friends back in and the archive jumps to 125 MB
(measured). Verify with `dart pub publish --dry-run` if in doubt.

## When the release changes

1. `test/integration/ephemeris_release_test.dart` fails first and names the
   file, the pinned release, and the release on disk.
2. Treat downstream tolerance failures in the tests listed above as expected
   consequences, **not** as binding regressions, until step 3 is done.
3. Re-record those goldens against the new release, using the C oracle
   (`test_oracle/`, see `docs/enforcement-ledger.md`) pointed at the same
   `ephe/`.
4. Update the pin and add a row to the History table above.

Bumping the pin without step 3 defeats the mechanism.
