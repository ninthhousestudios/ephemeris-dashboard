# Code Review: 673de75f226fa2bcb0ef917e41649e46c9792860^..HEAD

**Feature:** Swiss Ephemeris call tracing with C/Dart code generation and code-view UI actions.
**Date:** 2026-05-08

## Verification

- Tests: **fail**. `/home/josh/.local/flutter/bin/flutter test` reached `+101 -1`; `AyanamsaTab compare mode goldens` fails because `ayanamsa_tab_compare_mobile_light.png` is missing.
- Clippy: **not applicable**; this is a Flutter/Dart repo. Equivalent `/home/josh/.local/flutter/bin/flutter analyze` fails with 5 analyzer infos: implementation imports in `swe_symbol_catalog.dart` and `tracing_swiss_eph.dart`, plus unnecessary `swisseph/src/constants.dart` / `swisseph/src/types.dart` imports in touched files.
- Formatting: **drift in 99 files**. `/usr/bin/dart format --output=none --set-exit-if-changed .` reports 99 changed files. I restored the accidental tracked-file rewrites from the first format check; only the pre-existing handoff changes remain outside this review file.

## Design

The feature is pointed in the right direction: tracing at the `SwissEph` boundary is the right layer if the app wants generated examples to reflect the actual API calls rather than hand-maintained UI guesses. The symbol catalog and emitter split also make sense as a foundation for multiple output languages.

The main design risk is that tracing is implemented as mutable side effects on a singleton runner while the app's calculations are Riverpod provider evaluations. Providers can recompute for reasons other than an explicit Calculate click, and traces are appended as those evaluations happen. That means the trace is not a stable artifact of a calculation session; it is a live log of whatever providers have happened to rebuild since the last clear. For a "show me the code for this result" feature, the trace should be an immutable output of the same calculation transaction that produced the visible result.

The emitter contract also needs tightening. `emitProgram` is advertised by the UI as a standalone program, but both emitters currently concatenate snippets that reuse local variable names. That is fine for isolated snippets, but it breaks as soon as a tab has multiple calls, which is the common path for planets, dates, crossings, eclipses, and table views.

## Findings

### [High] `emitProgram` produces non-compilable programs for normal multi-call traces

`CEmitter.emitProgram` writes a single `main` body and then concatenates snippets from `emitSection` ([code_emitter.dart:122](../../lib/core/ephemeris/code_emitter.dart#L122)). The snippets redeclare common locals like `xx`, `serr`, `ret`, `jd_cross`, and `geopos` in the same C scope ([code_emitter.dart:149](../../lib/core/ephemeris/code_emitter.dart#L149), [code_emitter.dart:151](../../lib/core/ephemeris/code_emitter.dart#L151), [code_emitter.dart:238](../../lib/core/ephemeris/code_emitter.dart#L238)). `DartEmitter.emitProgram` has the same problem: it concatenates snippets that repeatedly emit `final result = ...` in one `main` scope ([code_emitter.dart:969](../../lib/core/ephemeris/code_emitter.dart#L969), [code_emitter.dart:993](../../lib/core/ephemeris/code_emitter.dart#L993), [code_emitter.dart:1055](../../lib/core/ephemeris/code_emitter.dart#L1055)).

This makes the tab-level code button generate invalid "standalone" programs for ordinary traces with more than one calculation. Fix by separating snippet mode from program mode: either wrap every emitted call in its own block, generate unique variable names per entry, or have emitters maintain a declaration/name allocation context. Add tests that compile or at least parse emitted programs with two `calcUt` entries and mixed call types.

### [High] Trace data is a mutable provider side effect, so code views can show stale or duplicate calls

Trace clearing only happens in `CalcSessionNotifier.calculate` through registered callbacks ([calc_session.dart:26](../../lib/core/calc_session.dart#L26)), while `CallTrace` exposes `runner.traceEntries` directly as the live list ([runner.dart:18](../../lib/core/ephemeris/runner.dart#L18), [runner.dart:78](../../lib/core/ephemeris/runner.dart#L78)). Result providers append to that list whenever they evaluate, not only during the Calculate transaction; for example planets sets the tab tag and calls `runner.run` inside the provider body ([planets_provider.dart:123](../../lib/tabs/planets/planets_provider.dart#L123), [planets_provider.dart:140](../../lib/tabs/planets/planets_provider.dart#L140)).

After a tab has run once, changing watched inputs or causing providers to rebuild can append more entries without clearing the old ones. Visiting other tabs can also mutate the same runner log. The visible result list and the trace slice can diverge, so the code modal may include duplicate calls or calls for prior inputs. Fix by making traces immutable outputs of a calculation run: collect entries in a per-run recorder, store a copied `List.unmodifiable` trace on the calc session/result state, and avoid appending from provider rebuilds outside that run.

### [Medium] Ayanamsa code buttons omit the calculation call

The Ayanamsa provider computes values with `eph.getAyanamsaUt(ectx.jdUt)` inside `runScoped` ([ayanamsa_provider.dart:67](../../lib/tabs/ayanamsa/ayanamsa_provider.dart#L67), [ayanamsa_provider.dart:76](../../lib/tabs/ayanamsa/ayanamsa_provider.dart#L76)), but `TracingSwissEph.getAyanamsaUt` just delegates without adding a trace entry ([tracing_swiss_eph.dart:281](../../lib/core/ephemeris/tracing_swiss_eph.dart#L281)). The emitter supports `swe_get_ayanamsa_ex_ut`, but that is a different traced method ([code_emitter.dart:1152](../../lib/core/ephemeris/code_emitter.dart#L1152)).

As a result, the Ayanamsa card code action slices the tab trace ([ayanamsa_tab.dart:190](../../lib/tabs/ayanamsa/ayanamsa_tab.dart#L190)) and can show only sidereal-mode setup, not the call that produced the displayed value. Fix by tracing and emitting `getAyanamsaUt`, or switch this provider to `getAyanamsaExUt` if the flags/return contract is acceptable.

### [Medium] Nodes & Apsides code view omits visible result sections

The Nodes & Apsides provider displays optional orbital elements and distance extremes, but those calls are not captured. `getOrbitalElements` is invoked through `runner.run`, yet the tracing wrapper delegates it without recording ([nodes_apsides_provider.dart:73](../../lib/tabs/nodes_apsides/nodes_apsides_provider.dart#L73), [tracing_swiss_eph.dart:1056](../../lib/core/ephemeris/tracing_swiss_eph.dart#L1056)). `orbitMaxMinTrueDistance` bypasses the runner entirely by calling `swe` directly ([nodes_apsides_provider.dart:80](../../lib/tabs/nodes_apsides/nodes_apsides_provider.dart#L80)).

The code action is shared across all Nodes & Apsides cards ([nodes_apsides_tab.dart:254](../../lib/tabs/nodes_apsides/nodes_apsides_tab.dart#L254)), so users can open code from an orbital-elements card and receive a snippet that does not reproduce that card. Trace these methods and add emitter support, or do not attach the code action to result cards whose calculations are not reproducible yet.

### [Medium] Generated string literals are not escaped

Several emitters interpolate user/config strings directly into generated C or Dart string literals: ephemeris paths and JPL file names in C ([code_emitter.dart:199](../../lib/core/ephemeris/code_emitter.dart#L199), [code_emitter.dart:204](../../lib/core/ephemeris/code_emitter.dart#L204)), Dart paths ([code_emitter.dart:1036](../../lib/core/ephemeris/code_emitter.dart#L1036)), fixed-star names ([code_emitter.dart:1073](../../lib/core/ephemeris/code_emitter.dart#L1073)), and heliacal object names ([code_emitter.dart:1338](../../lib/core/ephemeris/code_emitter.dart#L1338)).

Any quote, backslash, newline, or platform path edge case can produce invalid code; copied snippets can also contain unintended extra code text. Fix with language-specific literal escaping helpers and tests for paths/names containing `'`, `"`, `\`, and newlines.

## Slop List

1. `tracing_swiss_eph.dart` imports `package:swisseph/src/types.dart`, which analyzer flags as both an implementation import and unnecessary ([tracing_swiss_eph.dart:2](../../lib/core/ephemeris/tracing_swiss_eph.dart#L2)).
2. `swe_symbol_catalog.dart` imports `package:swisseph/src/constants.dart`, which analyzer flags as an implementation import ([swe_symbol_catalog.dart:1](../../lib/core/ephemeris/swe_symbol_catalog.dart#L1)).
3. `test/ephemeris_runner_tracing_test.dart` and `test/tracing_swiss_eph_test.dart` import `package:swisseph/src/constants.dart`; analyzer says those imports are unnecessary.
4. The format check reports broad repo drift, including touched feature files such as `code_emitter.dart`, `tracing_swiss_eph.dart`, `trace_model.dart`, `emitter_provider.dart`, and the new emitter tests.
