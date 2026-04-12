---
id: plan-2026-04-12-code-view-phase-1
type: plan
date: 2026-04-12
source: "[[.agents/research/2026-04-12-code-view-feature]]"
---

# Plan: SWE Dashboard v2 — Code View Feature, Phase 1

## Context

The v2 design doc (`doc/swe-dashboard-v2.md`) adds a "C ⋯" button to every ResultCard, ContextBar, FlagBar section, and Tab. Clicking it opens a modal containing runnable source code for the calculation, generated from a call-trace of the actual swisseph.dart methods invoked. Research (`.agents/research/2026-04-12-code-view-feature.md`) confirmed feasibility: single SwissEph instance via `sweProvider`, atomic context-global application in `EffectiveContext.calculate`, unused `onPin` button slot available on `ResultCard`, 45 unique swisseph methods currently called, 180 constants in `swisseph/lib/src/constants.dart`.

Phase 1 is the minimum viable slice from the design doc: **per-card only, C-only, snippet mode, hardcoded emitter (no TOML plugins), single pilot tab**. Phase 2+ extends to other surfaces, Dart, and TOML plugins.

Applied findings: none (no planning-rules or findings registry present for this repo).

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/call_trace.dart` | **NEW** — `CallEntry`, `CallCategory`, `CallTrace` types |
| `lib/core/tracing_swiss_eph.dart` | **NEW** — `TracingSwissEph` decorator wrapping the 45 used methods |
| `lib/core/swe_service.dart` | Wrap `sweProvider`'s instance in `TracingSwissEph`; add `traceSinkProvider` |
| `lib/core/calc_context.dart` | Wrap `_applyGlobals` + `calculate` bodies with category markers (`context`, `calc`, `teardown`) on the trace sink |
| `lib/core/code_view/constants_map.dart` | **NEW** — int → C `#define` name reverse lookup (≈180 entries) |
| `lib/core/code_view/flag_decompose.dart` | **NEW** — decompose composite `iflag` int into `SEFLG_X \| SEFLG_Y` |
| `lib/core/code_view/c_emitter.dart` | **NEW** — snippet-mode C emitter for one `CallEntry` |
| `lib/widgets/code_view_modal.dart` | **NEW** — scrollable/resizable modal with copy button |
| `lib/widgets/result_card.dart` | Replace pin button (lines 130–134) with "C" button; add `trace` and `traceHeader` params; remove `onPin` |
| `lib/tabs/planets/planets_provider.dart` | Attach `CallTrace` to each `PlanetResult` so cards can render their own C |
| `lib/tabs/planets/planets_tab.dart` | Pass the per-planet trace entry into its ResultCard |
| `test/code_view/c_emitter_test.dart` | **NEW** — emitter unit tests |
| `test/code_view/tracing_swiss_eph_test.dart` | **NEW** — wrapper tests (pass-through + recording) |
| `test/code_view/flag_decompose_test.dart` | **NEW** — composite flag decomposition tests |
| `test/code_view/constants_map_test.dart` | **NEW** — sanity round-trip test for key constants |

## Boundaries

**Always:**
- Preserve existing behavior — `SwissEph` calls return identical values with or without tracing. The wrapper must be a pure pass-through except for appending to the sink.
- Golden tests in `test/goldens/` must still pass. Replacing the pin button with a C button is a visible change; regenerate affected goldens after review.
- Zoom-safe: the C button must follow the existing IconButton sizing conventions (`size: 18`) from `result_card.dart:131`.
- The C modal must not block layout recalculation — use `showDialog` with `scrollable: true`.

**Ask First:**
- Whether to keep pinning as a future feature elsewhere in the UI, or drop it entirely. Current plan removes `onPin` outright; if you want pinning preserved, the parameter stays and the button slot needs a different home.
- Whether Phase 1 should include the "C ⋯" language-picker dropdown (no, per design) or ship just "C" and defer the `⋯` to Phase 3.

**Never:**
- Do not introduce TOML plugin loading in Phase 1.
- Do not add Dart, Python, or any non-C emitter in Phase 1.
- Do not wire the C button on ContextBar, FlagBar, or per-tab in Phase 1 — card-only.
- Do not change `swisseph` version pin in `pubspec.yaml` as part of this work.

## Baseline Audit

| Metric | Command | Result |
|--------|---------|--------|
| swisseph.dart public methods used | `grep -rn 'swe\.\w\+(' lib/ \| sed -E 's/.*swe\.([a-zA-Z0-9_]+)\(.*/\1/' \| sort -u \| wc -l` | 45 |
| swisseph.dart public method surface (v0.4.4 cached) | manual count of non-underscore method defs in `swiss_eph.dart` | 89 |
| Constants in swisseph.dart | `grep -c '^const ' ~/.pub-cache/hosted/pub.dev/swisseph-0.4.4/lib/src/constants.dart` | 180 |
| ResultCard callers | `grep -rln 'ResultCard(' lib/` | 10 files |
| `onPin:` callers in lib | `grep -rn 'onPin:' lib/` | 0 |
| Existing tests | `find test -name '*.dart' \| wc -l` | 2 files + goldens dir |
| Tabs following provider pattern | `lib/layout/tab_definitions.dart:3–33` | 16 tabs |

## Implementation

### 1. Trace Types (Issue A1)

In `lib/core/call_trace.dart` (NEW):

```dart
enum CallCategory { context, flags, calc, teardown, metadata }

class CallEntry {
  final String name;
  final List<Object?> args;
  final Object? result;
  final CallCategory category;
  final Object? cardKey; // body int, house system code, ayanamsa mode, etc.

  const CallEntry({
    required this.name,
    required this.args,
    required this.result,
    required this.category,
    this.cardKey,
  });
}

class CallTrace {
  final List<CallEntry> entries = [];

  /// All calc-category entries for a card key. Excludes metadata (e.g.
  /// getPlanetName lookups that run alongside the headline calc).
  List<CallEntry> forCard(Object key) =>
      entries.where((e) => e.cardKey == key && e.category == CallCategory.calc).toList();

  /// The single headline call for a card — e.g. `calcUt` for planet cards.
  /// Use this, not `forCard().lastOrNull`, to pick the line that represents the card.
  CallEntry? headlineForCard(Object key, String callName) => entries.firstWhere(
        (e) => e.cardKey == key && e.category == CallCategory.calc && e.name == callName,
        orElse: () => _missing,
      ) == _missing ? null : entries.firstWhere(
        (e) => e.cardKey == key && e.category == CallCategory.calc && e.name == callName,
      );

  List<CallEntry> byCategory(CallCategory c) =>
      entries.where((e) => e.category == c).toList();

  void clear() => entries.clear();
}

const _missing = CallEntry(name: '', args: [], result: null, category: CallCategory.metadata);
```

No code path reads `CallTrace` yet; this is pure type scaffolding.

### 2. Tracing Wrapper (Issue A2, depends on A1)

In `lib/core/tracing_swiss_eph.dart` (NEW):

- Import `SwissEph` from `package:swisseph/swisseph.dart`.
- `class TracingSwissEph implements SwissEph`. `SwissEph` is a concrete class with `late final` private FFI fields (`_lib`, `_bind`), but Dart allows `implements` on concrete classes by treating them as implicit interfaces.
- Satisfy the full 89-method interface using a hybrid approach:
  - **45 typed overrides** — one per method currently called by the app (enumerated in research doc section 2). Each override forwards to `_inner.<method>(...)`, captures the return, appends a `CallEntry` to `_sink` with `_currentCategory` and `_currentCardKey`, returns the captured value.
  - **44 untyped forwards** via `noSuchMethod`:
    ```dart
    @override
    dynamic noSuchMethod(Invocation inv) => Function.apply(
      _inner.noSuchMethod, [inv],
    );
    ```
    This satisfies the analyzer (no missing-concrete-implementation errors) while keeping hand-written code to just the 45 methods that need recording. The 44 unused methods silently pass through; when a future tab starts calling one, add a typed override to record it.
- Add `void setScope({required CallCategory category, Object? cardKey})` and `void clearScope()` for the tab providers to tag subsequent calls. Default scope is `CallCategory.calc` with `cardKey == null`.
- Add `CallTrace get trace => _sink`.

Reuse: none. This is a pure decorator.

### 3. Integrate Wrapper into sweProvider (Issue A3, depends on A2)

In `lib/core/swe_service.dart`:

- Modify `sweProvider` (line 40–47). Replace:
  ```dart
  final swe = _preloadedSwe ?? io.createDesktopSwissEph();
  ```
  with:
  ```dart
  final inner = _preloadedSwe ?? io.createDesktopSwissEph();
  final swe = TracingSwissEph(inner, CallTrace());
  ```
- Keep `setEphePath` and `onDispose(close)` calls (they now route through the wrapper — record as `context` and `teardown` respectively; see Issue A4).
- Add a sibling provider returning the live trace:
  ```dart
  final traceProvider = Provider<CallTrace>((ref) => (ref.watch(sweProvider) as TracingSwissEph).trace);
  ```

### 4. Category Markers (Issue A4, depends on A3)

In `lib/core/tracing_swiss_eph.dart`, add a cast-safe helper exported from the same library:

```dart
void markScope(SwissEph swe, {required CallCategory category, Object? cardKey}) {
  if (swe is TracingSwissEph) swe.setScope(category: category, cardKey: cardKey);
}

void clearScope(SwissEph swe) {
  if (swe is TracingSwissEph) swe.clearScope();
}
```

Downstream callers use `markScope(swe, ...)` instead of `(swe as TracingSwissEph).setScope(...)`. Non-tracing paths (tests with a mock SwissEph) no-op cleanly rather than throwing.

In `lib/core/calc_context.dart`:

- At the top of `EffectiveContext.calculate<T>` (line 43), before `_applyGlobals`, call `markScope(swe, category: CallCategory.context)`.
- After `_applyGlobals` returns, change scope to `CallCategory.calc` before invoking `fn`.
- Wrap in try/finally that calls `clearScope(swe)`.
- In each per-tab provider that kicks off a Calculate, clear the full trace before the first `EffectiveContext.calculate` call via `ref.read(traceProvider).clear()` (add this to the planets tab only in Phase 1; other tabs remain untraced until their time comes).

In `lib/core/swe_service.dart:43` — the `setEphePath` call happens during provider construction; mark it as `context` by calling `markScope` before it.

### 5. Constants Map (Issue A5, no deps)

In `lib/core/code_view/constants_map.dart` (NEW):

- Two maps:
  ```dart
  const Map<int, String> cBodyNames = { 0: 'SE_SUN', 1: 'SE_MOON', /* … */ };
  const Map<int, String> cFlagNames = { 1: 'SEFLG_JPLEPH', 2: 'SEFLG_SWIEPH', /* … */ };
  const Map<int, String> cHouseSystems = { /* from houses_provider.dart:47–72 */ };
  const Map<int, String> cAyanamsaModes = { /* from ayanamsa_provider.dart:27–72 */ };
  ```
- Build from `swisseph/lib/src/constants.dart` (180 entries). Copy constant names, convert camelCase to UPPER_SNAKE (`seSun` → `SE_SUN`, `seFlgSpeed` → `SEFLG_SPEED`).
- Provide `String? cNameForBody(int id)`, `String? cNameForAyanamsa(int id)`, `String? cNameForHouseSystem(int id)`.

### 6. Flag Decomposition (Issue A6, no deps)

In `lib/core/code_view/flag_decompose.dart` (NEW):

```dart
List<String> decomposeFlags(int value, Map<int, String> bitNames) {
  final parts = <String>[];
  var remaining = value;
  for (final entry in bitNames.entries) {
    if (entry.key != 0 && (value & entry.key) == entry.key) {
      parts.add(entry.value);
      remaining &= ~entry.key;
    }
  }
  if (remaining != 0) parts.add('/* unknown bits: 0x${remaining.toRadixString(16)} */');
  if (parts.isEmpty) parts.add('0');
  return parts;
}

String cFlagExpression(int value) => decomposeFlags(value, cFlagNames).join(' | ');
```

Edge cases: `value == 0` → `"0"`. Bits set without a matching name → preserved as a hex comment.

### 7. C Emitter (Snippet Mode) (Issue A7, depends on A1, A5, A6)

In `lib/core/code_view/c_emitter.dart` (NEW):

```dart
String emitCSnippet(CallEntry e) {
  switch (e.name) {
    case 'calcUt':
      final (jd, body, flags) = (e.args[0], e.args[1] as int, e.args[2] as int);
      final bodyName = cNameForBody(body) ?? body.toString();
      return 'double x[6]; char serr[AS_MAXCH]; '
          'int iflgret = swe_calc_ut($jd, $bodyName, ${cFlagExpression(flags)}, x, serr);';
    case 'houses':
      // ...
    case 'getAyanamsaUt':
      // ...
    // … one case per method used by the pilot tab (planets) + any shared helper calls captured as context.
    default:
      return '// TODO: C binding missing for swe_${e.name}';
  }
}
```

Phase 1 only needs coverage for calls emitted by the planets pilot: `calcUt`, `setEphePath`, `setTopo`, `setSidMode`, `getPlanetName`. All others use the fallback TODO comment — acceptable since other tabs aren't wired yet.

**Snippet preamble (M5):** Phase 1 emits only the single headline call for the card (one line of C). Prepend a one-line comment reminding the reader that setup calls are implied: `// Assumes swe_set_ephe_path(), swe_set_topo(), swe_set_sid_mode() have been called per the context header above.`. Program mode in Phase 2 will emit full setup.

### 8. Code View Modal (Issue A8, depends on A1)

In `lib/widgets/code_view_modal.dart` (NEW):

- `Future<void> showCodeViewModal(BuildContext context, {required String code, required String title})` that calls `showDialog(...)` with a `Dialog` whose child is:
  - A resizable `AlertDialog` or custom `Dialog` with constrained min/max size.
  - Title row with language label ("C") and close button.
  - Body: `SingleChildScrollView` (vertical) wrapping another `SingleChildScrollView(scrollDirection: Axis.horizontal)` wrapping a `SelectableText.rich` with monospace style.
  - Action row with a "Copy" button that calls `Clipboard.setData` inside a try/catch. On success, show a `SnackBar` with "Copied". On failure, show a `SnackBar` with "Copy failed — select text to copy manually".
- Zoom safety: no fixed-width SizedBox. Use `LayoutBuilder` and relative constraints (see `CLAUDE.md` architecture rules).

### 9. ResultCard Button Swap (Issue A9, depends on A8)

In `lib/widgets/result_card.dart`:

- Remove `final VoidCallback? onPin;` (line 28) and the constructor parameter (line 35).
- Replace the pin `IconButton` block at lines 130–134 with:
  ```dart
  if (codeViewEnabled)
    IconButton(
      icon: const Icon(Icons.code, size: 18),
      tooltip: 'View C code',
      onPressed: trace == null
          ? null
          : () => showCodeViewModal(context, code: _renderCode(), title: 'C'),
    ),
  ```
- Add three new params:
  - `final bool codeViewEnabled;` (default `false`) — gates the button entirely. Non-pilot tabs pass `false` in Phase 1 so the button is not rendered at all.
  - `final CallEntry? trace;` — the headline call entry for this card.
  - `final String traceHeader;` — comment block with date/JD/location/ephemeris source.
- Add a private `String _renderCode()` that concatenates `traceHeader + emitCSnippet(trace!)`.
- Behavior matrix:
  - `codeViewEnabled == false` → button not rendered (non-pilot tabs).
  - `codeViewEnabled == true && trace == null` → button rendered, disabled ("disabled until first calc" per design doc).
  - `codeViewEnabled == true && trace != null` → button rendered, enabled, opens modal.

**Golden-diff protocol (M4):** before accepting regenerated goldens, run `git diff test/goldens/` and confirm every changed pixel is within the action-row area of a planets-tab ResultCard. Any diff outside that region signals a layout regression and must be investigated before committing.

### 10. Wire Planets Tab (Issue A10, depends on A2, A3, A4, A5, A6, A7, A9)

In `lib/tabs/planets/planets_provider.dart`:

- In `PlanetResult`, add `final CallEntry? traceEntry;`.
- In the provider's body, before the loop over selected bodies, call `ref.read(traceProvider).clear()`.
- For each body, split metadata lookups from the headline calc using distinct scopes (S2):
  ```dart
  markScope(swe, category: CallCategory.metadata, cardKey: body);
  final name = swe.getPlanetName(body);

  markScope(swe, category: CallCategory.calc, cardKey: body);
  final r = swe.calcUt(ectx.jdUt, body, flags);
  ```
  `getPlanetName` is tagged `metadata`, so it never pollutes `forCard(body)` (which filters to `CallCategory.calc` only).
- After the loop, attach the headline entry: `final entry = trace.headlineForCard(body, 'calcUt');` — this picks exactly the `calcUt` entry for the card, not whichever entry happened to land last.

In `lib/tabs/planets/planets_tab.dart`:

- For each `ResultCard(...)` that renders a `PlanetResult`, pass `codeViewEnabled: true, trace: result.traceEntry, traceHeader: _buildHeader(ectx)`.
- All other tabs continue to construct `ResultCard` without `codeViewEnabled` — default `false` hides the button entirely in Phase 1 (M2).

### 11. Tests (Issues A11 through A14)

- **`test/code_view/c_emitter_test.dart` (A11):** call emitter on a synthetic `CallEntry(name: 'calcUt', args: [2460412.5, 0, 258])` → expect `swe_calc_ut(2460412.5, SE_SUN, SEFLG_SWIEPH | SEFLG_SPEED, …)`. Covers happy path + unknown method fallback.
- **`test/code_view/tracing_swiss_eph_test.dart` (A12):** wrap a fake `SwissEph`; call 3 methods; assert trace has 3 entries with correct names/args/categories. After A4 lands, extend to assert `markScope` sets category correctly and a `metadata`-scoped call does not appear in `forCard()`.
- **`test/code_view/flag_decompose_test.dart` (A13):** table-driven test: (`0`, `258`, `259`, `0x10000000 | 2`) → expected strings.
- **`test/code_view/constants_map_test.dart` (A14):** assert `cNameForBody(0) == 'SE_SUN'`, and that the map size is ≥ expected count (40 bodies, 44 ayanamsas, 25 house systems — pulled from the code paths the research identified).
- **`test/integration/trace_pipeline_test.dart` (A15):** spin up a `ProviderContainer` with the real `sweProvider`, read `traceProvider`, drive the planets provider with a fixed JD and body list, assert:
  1. trace has one `setEphePath` entry tagged `context`.
  2. trace has one `calcUt` entry per selected body tagged `calc` with correct `cardKey`.
  3. `getPlanetName` entries exist but are tagged `metadata`.
  4. `headlineForCard(SE_SUN, 'calcUt')` returns exactly the expected entry.
  This test is the one that proves A3+A4+A10 integrate correctly. L2 integration.

## Conformance Checks

| Issue | Check Type | Check |
|-------|-----------|-------|
| A1 | files_exist | `lib/core/call_trace.dart` |
| A2 | files_exist | `lib/core/tracing_swiss_eph.dart` |
| A2 | content_check | `lib/core/tracing_swiss_eph.dart` contains `implements SwissEph` |
| A2 | content_check | `tracing_swiss_eph.dart` contains `noSuchMethod(Invocation` |
| A2 | content_check | `tracing_swiss_eph.dart` contains `void markScope(SwissEph` |
| A3 | content_check | `lib/core/swe_service.dart` contains `TracingSwissEph(` |
| A3 | content_check | `lib/core/swe_service.dart` contains `final traceProvider` |
| A4 | content_check | `lib/core/calc_context.dart` contains `markScope(swe, category:` |
| A5 | files_exist | `lib/core/code_view/constants_map.dart` |
| A5 | content_check | `constants_map.dart` contains `SE_SUN` and `SEFLG_SWIEPH` |
| A6 | files_exist | `lib/core/code_view/flag_decompose.dart` |
| A7 | files_exist | `lib/core/code_view/c_emitter.dart` |
| A7 | content_check | `c_emitter.dart` contains `case 'calcUt'` |
| A8 | files_exist | `lib/widgets/code_view_modal.dart` |
| A8 | content_check | `code_view_modal.dart` contains `Clipboard.setData` |
| A9 | content_check | `lib/widgets/result_card.dart` does NOT contain `onPin` (`grep -c 'onPin' = 0`) |
| A9 | content_check | `result_card.dart` contains `tooltip: 'View C code'` |
| A9 | content_check | `result_card.dart` contains `Icons.code` |
| A9 | content_check | `result_card.dart` contains `bool codeViewEnabled` |
| A10 | content_check | `lib/tabs/planets/planets_provider.dart` contains `traceEntry` |
| A10 | content_check | `planets_provider.dart` contains `CallCategory.metadata` |
| A10 | content_check | `lib/tabs/planets/planets_tab.dart` contains `codeViewEnabled: true` |
| A11–A14 | tests | `flutter test test/code_view/` |
| A15 | files_exist | `test/integration/trace_pipeline_test.dart` |
| A15 | tests | `flutter test test/integration/trace_pipeline_test.dart` |
| Global | tests | `flutter test test/goldens/` (after golden regeneration) |
| Global | build | `flutter analyze` with no new errors |

## Verification

1. **Unit tests:**
   ```bash
   cd /home/josh/nhs/soft/astrology/swe_dashboard
   flutter test test/code_view/
   ```
2. **Analyzer:** `flutter analyze`
3. **Golden regen (expect pin → C diff):**
   ```bash
   flutter test test/goldens/ --update-goldens
   # Review each changed PNG for ONLY the button swap
   git diff test/goldens/
   flutter test test/goldens/
   ```
4. **Manual smoke test:**
   ```bash
   flutter run -d linux
   # Load planets tab → before Calculate, verify C button disabled.
   # Press Calculate → verify C button enabled on each planet card.
   # Click C → modal opens, code is copyable, matches JD and planet body.
   ```
5. **Regression:** planets tab values unchanged across the wrapper insertion — snapshot result values before and after.

## File-Conflict Matrix

| File | Issues | Notes |
|------|--------|-------|
| `lib/core/call_trace.dart` | A1 | New file |
| `lib/core/tracing_swiss_eph.dart` | A2 | New file |
| `lib/core/swe_service.dart` | A3 | Wave-unique |
| `lib/core/calc_context.dart` | A4 | Wave-unique |
| `lib/core/code_view/constants_map.dart` | A5 | New file |
| `lib/core/code_view/flag_decompose.dart` | A6 | New file |
| `lib/core/code_view/c_emitter.dart` | A7 | New file |
| `lib/widgets/code_view_modal.dart` | A8 | New file |
| `lib/widgets/result_card.dart` | A9 | Wave-unique |
| `lib/tabs/planets/planets_*.dart` | A10 | Wave-unique |
| `test/code_view/*.dart` | A11–A14 | New files, independent |
| `test/integration/trace_pipeline_test.dart` | A15 | New file |

No same-wave file collisions.

## Cross-Wave Shared Files

| File | Wave | Reason |
|------|------|--------|
| `lib/core/swe_service.dart` | W3 (A3) only | Single-issue touch |
| `lib/widgets/result_card.dart` | W4 (A9) only | Single-issue touch |

No cross-wave collisions.

## Issues

### Issue A1: Trace types
**Dependencies:** None
**Acceptance:** `lib/core/call_trace.dart` exists with `CallCategory`, `CallEntry`, `CallTrace`. File compiles (`flutter analyze` clean on this file).

### Issue A2: TracingSwissEph wrapper
**Dependencies:** A1
**Acceptance:** `lib/core/tracing_swiss_eph.dart` exists. `class TracingSwissEph implements SwissEph` with 45 typed recording overrides for the methods the app calls today. Overrides `noSuchMethod` to forward all other swe_* calls to the wrapped inner instance via `Function.apply(_inner.noSuchMethod, [inv])`. Exposes `setScope`, `clearScope`, and the module-level `markScope`/`clearScope` cast-safe helpers. `flutter analyze` clean — no "missing concrete implementation" errors for the 44 unused interface methods. Pass-through test in A12 passes.

### Issue A3: Integrate wrapper into sweProvider
**Dependencies:** A2
**Acceptance:** `sweProvider` returns a `TracingSwissEph`. `traceProvider` exposes the live trace. `flutter run -d linux` launches without runtime error. Planets tab still produces identical numeric output.

### Issue A4: Category markers
**Dependencies:** A3
**Acceptance:** `EffectiveContext.calculate` wraps `_applyGlobals` in `context` scope and `fn` in `calc` scope. `setEphePath` call in `swe_service.dart` is tagged `context`. A12 wrapper test extended to assert scopes.

### Issue A5: Constants reverse-lookup map
**Dependencies:** None
**Acceptance:** `cBodyNames`, `cFlagNames`, `cAyanamsaModes`, `cHouseSystems` populated. Map sizes ≥ 40 / 20 / 44 / 25 respectively. A14 test passes.

### Issue A6: Flag decomposition helper
**Dependencies:** A5
**Acceptance:** `cFlagExpression(258) == 'SEFLG_SWIEPH | SEFLG_SPEED'` (or equivalent OR order); `cFlagExpression(0) == '0'`; unknown bits preserved as hex comment. A13 test passes.

### Issue A7: C emitter (snippet mode)
**Dependencies:** A1, A5, A6
**Acceptance:** `emitCSnippet(entry)` produces valid one-line C for `calcUt`, `setEphePath`, `setTopo`, `setSidMode`, `getPlanetName`. Unknown methods produce `// TODO: C binding missing for swe_<name>`. A11 test passes.

### Issue A8: Code view modal
**Dependencies:** None
**Acceptance:** `showCodeViewModal` opens a scrollable + resizable dialog with a Copy button. `Clipboard.setData` wrapped in try/catch; success shows SnackBar "Copied", failure shows SnackBar "Copy failed — select text to copy manually". Zoom-safe (no fixed-width SizedBox). Manually verified at 1.0x, 1.5x, 2.0x text scale.

### Issue A9: ResultCard button swap
**Dependencies:** A7, A8
**Acceptance:** `onPin` removed from params and from the widget body. New params `codeViewEnabled` (default `false`), `trace`, `traceHeader`. Button uses `Icons.code` with tooltip `'View C code'`. Button is *not rendered* when `codeViewEnabled == false`; rendered-but-disabled when `codeViewEnabled == true && trace == null`; rendered-and-enabled when `trace != null`. Golden diffs reviewed — only action-row pixels in planets-tab cards differ (M4 protocol); goldens regenerated.

### Issue A10: Wire planets tab
**Dependencies:** A3, A4, A7, A9
**Acceptance:** Each planet's ResultCard receives its own headline `CallEntry` via `trace.headlineForCard(body, 'calcUt')`. `getPlanetName` call is tagged `CallCategory.metadata` via `markScope` so it does not pollute `forCard`. Only planets tab passes `codeViewEnabled: true`; all other tabs use the default `false` (button not rendered). Code shown in modal matches the planet (body name, flags). Manual smoke test passes.

### Issue A15: L2 integration test
**Dependencies:** A3, A4, A7, A10
**Acceptance:** `test/integration/trace_pipeline_test.dart` exists and passes. Spins up a real `ProviderContainer`, drives planets provider with a fixed JD + body list, asserts: (1) `setEphePath` entry tagged `context`; (2) one `calcUt` entry per body tagged `calc` with matching `cardKey`; (3) `getPlanetName` entries tagged `metadata` and excluded from `forCard`; (4) `headlineForCard(SE_SUN, 'calcUt')` returns the expected entry. This is the test that proves A3+A4+A10 integrate.

### Issue A11: C emitter tests
**Dependencies:** A7
**Acceptance:** `test/code_view/c_emitter_test.dart` passes.

### Issue A12: Wrapper tests
**Dependencies:** A2, A4
**Acceptance:** `test/code_view/tracing_swiss_eph_test.dart` passes, covers pass-through and scope tagging.

### Issue A13: Flag decompose tests
**Dependencies:** A6
**Acceptance:** `test/code_view/flag_decompose_test.dart` passes.

### Issue A14: Constants map tests
**Dependencies:** A5
**Acceptance:** `test/code_view/constants_map_test.dart` passes.

## Execution Order

**Wave 1 (parallel):** A1, A5, A8
**Wave 2 (parallel, after Wave 1):** A2 (needs A1), A6 (needs A5), A14 (needs A5)
**Wave 3 (parallel, after Wave 2):** A3 (needs A2), A7 (needs A1, A5, A6), A13 (needs A6)
**Wave 4 (parallel, after Wave 3):** A4 (needs A3), A9 (needs A7, A8), A11 (needs A7), A12 (needs A2, will be extended in W5)
**Wave 5:** A10 (needs A3, A4, A7, A9), A12 extension (needs A4), A15 (needs A3, A4, A7, A10 — runs after A10)

Critical path: A1 → A2 → A3 → A4 → A10. That's 5 serial hops; parallelism on the constant-map and modal tracks (A5/A8/A6/A7) absorbs most of the remaining work.

## Post-Merge Cleanup

After all waves merge:
- `grep -rn 'TODO' lib/core/code_view/` — address any deferred decisions.
- Verify `flutter analyze` is clean.
- Regenerate goldens (`flutter test test/goldens/ --update-goldens`) and eyeball every changed PNG.
- Update `doc/swe-dashboard-v2.md` "Phase 1" checklist with completion dates.

## Next Steps

- `/pre-mortem` to stress-test this plan before execution.
- Then `/implement A1` (or `/crank` if bd were available) to start work.
- Phase 2 follow-up plan: ContextBar/FlagBar/per-tab buttons + program-mode emitter + Dart emitter. Out of scope here.
