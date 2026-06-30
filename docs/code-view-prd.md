# Code View — Product Requirements Document

**Date:** 2026-05-06
**Status:** Approved
**Feature:** Surface executable source code for every calculation the app performs
**Predecessors:** `doc/swe-dashboard-v2.md` (design draft), `doc/codex-v2-suggestions.md` (architecture review), `doc/ephemeris-runner-design.md` (implemented)

## Problem

Users of this dashboard — developers, researchers, students — see astronomical values on screen and want to reproduce them in their own code. Today they have to reverse-engineer which Swiss Ephemeris calls produced a given number, look up the correct flags, constants, and setup sequence, and hope they got it right.

## Solution

Every calculation result in the dashboard becomes directly copyable as runnable source code. The code is generated from a trace of the actual Swiss Ephemeris calls the app made — not from templates describing what we think it did. If the app called `swe_set_topo(...)` then `swe_calc_ut(...)`, that is exactly what the code shows.

## Starting Point

The architecture is already partway there:

- **EphemerisRunner** (`lib/core/ephemeris/runner.dart`) is the single chokepoint for all ephemeris-touching calls. Every tab provider calls `runner.run(globals, (eph) => eph.method(...))`. Pure utilities (getPlanetName, houseName, fixstar2Mag) bypass the runner since they don't touch C globals.
- **AppliedGlobals** is a value type with equality checking — the runner skips re-applying when nothing changed.
- **EffectiveContext** is a pure value type merging context bar + flag bar state.
- **CalcSession** tracks which tabs have run and gates the calculate button.
- **swisseph.dart** is currently at 0.4.4. Upgrade to 0.4.7 happens before Code View work begins.

The trace seam was explicitly reserved during the EphemerisRunner implementation but not built. This PRD picks up from there.

## Design Decisions

Resolved during domain grilling session (2026-05-06):

1. **TracingSwissEph strategy:** `implements SwissEph` with explicit forwarding for all ~70 methods. No `noSuchMethod` — compile-safe across swisseph.dart upgrades. Traced methods record + forward; untraced methods just forward.

2. **Trace ID generation:** providers set a tab context tag (e.g. `"planets"`), individual entry IDs auto-derived from `{tabId}:{functionName}:{discriminatingArgs}`. Providers don't name each call explicitly.

3. **Trace storage:** one global `CallTrace` per calculate-button press, attached to CalcSession. All UI buttons filter into the same trace. Last calc wins — no history.

4. **Symbol catalog:** structured class with `bodyName(int)`, `flagDecompose(int)`, `sidModeName(int)` methods. Map literal inside, not a type hierarchy. Consumes constants already defined in swisseph.dart's `constants.dart`.

5. **Error handling:** show code for errored calls with `// Error: <message>` comment. TracingSwissEph records calls in try/finally, then rethrows. Code button is not disabled on errored cards.

6. **Section emit framing:** sections are "paste into your existing program" blocks. Header comment sets that expectation.

7. **C program emit style:** reuse `xx[6]`/`serr[256]` buffers across calls, `printf` results after each call.

## Design

### Tracing Layer

A `TracingSwissEph` wrapper sits between EphemerisRunner and the real SwissEph instance. It `implements SwissEph` with explicit forwarding for every method (~70 total). Traced methods (~15-20) record a `CallEntry` then forward; the remaining ~50 utility methods forward without recording.

```
EphemerisRunner
  ├── _apply(globals)  →  records context/flag setup calls
  └── run(globals, body)
        └── body(tracingEph)  →  records calc calls via wrapper
```

The runner owns global-state application in `_apply()`. For tracing, `_apply()` also records which setup calls it made (setEphePath, setSidMode, setTopo, setJplFile). The body closure receives a TracingSwissEph instead of the raw SwissEph, so calc calls are recorded transparently.

Provider code does not change — the closure signature stays `T Function(SwissEph eph)` because TracingSwissEph implements SwissEph.

Calls that throw are still recorded (try/finally pattern). The trace entry includes the error. This supports showing code for errored calculations.

### Trace Model

```dart
enum CallCategory { context, flags, calc, teardown }

class CallEntry {
  final String functionName;       // "swe_calc_ut", "swe_houses"
  final Map<String, Object?> args; // named: {jdUt: 2460412.5, body: 0, iflag: 258}
  final Object? result;
  final int? returnFlag;
  final String? errorMessage;      // non-null if the call threw
  final CallCategory category;
  final String traceId;            // "planets:calc_ut:body=0"
}

class CallTrace {
  final List<CallEntry> entries;
  final EffectiveContext context;
  final DateTime capturedAt;
}

class TraceSlice {
  final List<CallEntry> entries;   // filtered subset
  final EffectiveContext context;
}
```

Key design choices:
- **Named args, not positional** — emitters look up `args['body']` not `args[0]`. Survives signature changes.
- **Symbolic constants preserved** — body 0 is stored alongside identity `SE_SUN`. Flag 258 is stored alongside decomposition `SEFLG_SWIEPH | SEFLG_SPEED`. Emitters consume symbols directly.
- **Deterministic trace IDs** — auto-derived from tab context tag + function name + discriminating args. Provider sets the tab tag; the trace entry composes the full ID. Examples: `planets:calc_ut:body=0`, `houses:houses:system=80`, `stars:fixstar2_ut:term=Aldebaran`.
- **One global trace per calculate press** — attached to CalcSession. Cleared on each new calculate. All UI buttons (card, context bar, flag bar, tab) filter the same trace.

### Swiss Ephemeris Symbol Catalog

A structured class with three lookup methods:

- `String bodyName(int body)` → `"SE_SUN"`, `"SE_MOON"`, etc.
- `List<String> flagDecompose(int flags)` → `["SEFLG_SWIEPH", "SEFLG_SPEED"]`
- `String sidModeName(int mode)` → `"SE_SIDM_LAHIRI"`
- `String? houseSysName(int hsys)` → `"Placidus"` (house systems use char codes, not C #defines)

Internally a map literal mapping int → C name string. ~200 entries sourced from swisseph.dart's `constants.dart`. Flag decomposition iterates known flag bits and collects matches.

### Trace Lifecycle

- Trace is cleared at the start of each Calculate-button press.
- One global trace is built during the calculate pass — setup calls from the runner, then calc calls from each active tab's provider.
- Cards identify their trace entry via the deterministic trace ID.
- Code button is disabled until the first calculation has run (enforced by CalcSession).

### Code Emission

```dart
abstract class CodeEmitter {
  String get languageId;
  String get displayName;
  String get fileExtension;

  String emitSnippet(TraceSlice slice);
  String emitSection(TraceSlice slice);
  String emitProgram(CallTrace trace);
}
```

`TraceSlice` is a filtered view of a CallTrace — the exact entries the emitter should render. Filtering (by card, by category, by tab) happens before the emitter sees it. Emitters are deterministic — they don't decide what to include, only how to format it.

**First-party emitters:**
- **C** — canonical. Matches `swephexp.h` function signatures and `#define` constant names.
- **Dart** — matches `swisseph.dart` method names and Dart constant names.

**Plugin emitters (future):** TOML-based. Designed after C and Dart stabilize the emitter interface.

### C Emitter Output Style

**Snippet** (single card):
```c
// Generated by SWE Dashboard
// JD (UT): 2460412.5
double xx[6];
char serr[256];
int rc = swe_calc_ut(2460412.5, SE_SUN, SEFLG_SWIEPH | SEFLG_SPEED, xx, serr);
// returns: lon=21.832, lat=0.000, dist=1.001
```

**Section** (context bar — paste into your existing program):
```c
// Context setup — paste into your program before calculation calls
swe_set_ephe_path("/path/to/ephe");
swe_set_sid_mode(SE_SIDM_LAHIRI, 0, 0);
swe_set_topo(0.1278, 51.5074, 0);
```

**Program** (full tab — compile and run):
```c
#include "swephexp.h"
#include <stdio.h>

int main() {
    double xx[6];
    char serr[256];
    int rc;

    swe_set_ephe_path("/path/to/ephe");
    swe_set_topo(0.1278, 51.5074, 0);

    rc = swe_calc_ut(2460412.5, SE_SUN, SEFLG_SWIEPH | SEFLG_SPEED, xx, serr);
    printf("Sun: lon=%f lat=%f dist=%f\n", xx[0], xx[1], xx[2]);

    rc = swe_calc_ut(2460412.5, SE_MOON, SEFLG_SWIEPH | SEFLG_SPEED, xx, serr);
    printf("Moon: lon=%f lat=%f dist=%f\n", xx[0], xx[1], xx[2]);

    swe_close();
    return 0;
}
```

Reuse `xx`/`serr` buffers across calls. Print results after each call. Errored calls include `// Error: <message>` instead of printf.

### Code Header

Every emitted block begins with a metadata comment. Fields vary by slice level:

- **Program/section:** JD, date/time, location, ephemeris source, ayanamsa (if sidereal)
- **Snippet:** only fields relevant to that specific call

### UI Surface

**Entry points — a code action button appears on:**

| Location | Slice content | Emit mode |
|---|---|---|
| ResultCard | Single calc call that produced the card | snippet |
| ContextBar | Context setup calls (setTopo, setSidMode, date/time) | section |
| FlagBar | Flag/ephemeris setup calls (setEphePath, setJplFile) | section |
| Tab header | Complete standalone program for every card on the tab | program |

The button label is the current language ID (e.g. `C`) with a `⋯` affordance for the language picker (added in Phase 2). Button is disabled until first calculation.

The unused `ResultCard.onPin` slot is repurposed for the code action. Pin feature is dropped.

**Display — modal dialog:**
- Scrollable code area (both axes)
- Copy-to-clipboard button
- Language label in title bar
- Monospace text, no syntax highlighting
- No resizing in initial implementation

### SwissEph Methods to Trace

Based on current tab providers:

| Method | Used by |
|---|---|
| `calcUt` | planets, coordinates, phenomena, nodes/apsides, planetocentric, differential, table_view, math |
| `houses` | houses |
| `fixstar2Ut` | stars |
| `riseTransTrueHor` | rise/set |
| `heliacalUt` | heliacal |
| `solEclipseWhenLoc` / `solEclipseHow` / `lunEclipseWhen` / `lunEclipseHow` | eclipses |
| `gauquelinSector` | crossings (if applicable) |
| `nodesApsUt` | nodes/apsides |
| `phenoUt` | phenomena |
| `sidTime` / `sidTime0` | houses (sidereal time display) |

Context setup calls traced automatically by the runner:
- `setEphePath`
- `setSidMode`
- `setTopo`
- `setJplFile`

Pure utilities NOT traced: `getPlanetName`, `houseName`, `fixstar2Mag`, `degnorm`, `revjul`, `julday`, `cotrans`, `refrac`, `deltat`, `splitDeg`, `degMidp`, `radNorm`, `radMidp`, `dayOfWeek`, `version`.

## Phases

### Pre-Phase: swisseph.dart Upgrade

Upgrade from 0.4.4 to 0.4.7. Test new bundled `sefstars.txt` with Stars tab. Run golden tests. Separate branch/commit before Code View work begins.

### Phase 0 — Trace Infrastructure

Build the tracing layer with no user-facing UI. Prove it works by routing the Planets tab through it.

**Deliverables:**
- Swiss Ephemeris symbol catalog (body constants, flag constants, sidereal modes, house systems)
- `CallEntry`, `CallTrace`, `TraceSlice` model classes
- `TracingSwissEph` with explicit forwarding for all SwissEph methods; traced methods for `calcUt` and context setup calls
- EphemerisRunner modified to record setup calls and pass TracingSwissEph to closures
- Global trace storage attached to CalcSession
- Tab context tagging in planets provider; auto-derived trace IDs
- Unit tests: trace contains correct setup calls + calc calls in correct order, trace IDs are deterministic, symbol catalog round-trips, errored calls are recorded

**Done means:** Planets tab renders identical values, but a test can assert the trace contains `setSidMode`, `setTopo`, `setJplFile`, and `calcUt` entries with symbolic constants.

### Phase 1 — Per-Card C Snippets (MVP)

The smallest visible feature. Validates the full pipeline from trace → emit → display.

**Deliverables:**
- C emitter: snippet mode only, covering `swe_calc_ut` and context setup functions
- Code action button on ResultCard (repurpose pin slot)
- Button disabled until CalcSession indicates the tab has run
- Modal dialog: monospace text, copy button, language label
- Minimal header metadata (JD, date/time, location if topocentric, ephemeris source, ayanamsa if sidereal)

**Done means:** User clicks Calculate on Planets tab, clicks the code button on Sun's card, sees a correct C snippet with symbolic constants and a `// returns:` annotation.

### Phase 2 — Full Slice Coverage

Expand tracing across all tabs and add section/program emit modes.

**Deliverables:**
- TracingSwissEph traced methods expanded to cover full method table
- Trace IDs for all tab providers (houses, stars, rise/set, heliacal, eclipses, etc.)
- ContextBar code button (section mode)
- FlagBar code button (section mode)
- Tab-level code button (program mode)
- C emitter handles all traced methods in all three emit modes
- Dart emitter added (matching swisseph.dart API)
- Language picker `⋯` menu (C and Dart)

**Done means:** User can get a complete runnable C or Dart program for any tab.

### Phase 3 — TOML Plugin System

Only after first-party C and Dart emitters have stabilized the interface.

**Deliverables:**
- TOML plugin schema (designed from real emitter needs)
- Plugin loader: bundled assets + user config directory
- Constant mapping table in TOML
- Function call templates with placeholder substitution
- Missing-function fallback (`// TODO: <lang> binding missing for swe_xxx`)
- Plugin error handling (malformed → skip + toast, no crash)

**Done means:** A third-party contributor can add Python/JS/Rust support by writing a TOML file, without recompiling.

### Phase 4 — Polish

- Resizable modal with persisted size
- Richer `// returns:` annotations on each call
- Save-as-file button for program mode
- Optional: syntax highlighting if a lightweight solution exists

## Risks

1. **Single-calc-at-a-time assumption.** Swiss Ephemeris C globals are process-global. The runner serializes access implicitly (Flutter is single-threaded for UI). Document this assumption in the runner. If isolate-based parallel calc is ever added, the runner is where serialization or per-isolate adapters would go.

2. **Trace drift.** If any provider bypasses the runner and calls SwissEph directly, the trace misses those calls. Stars provider already does this for `fixstar2Mag` (magnitude lookup) — acceptable since it's a catalog query, not a JD-dependent calculation. Enforce via code review that new ephemeris-touching calls go through the runner.

3. **Plugin schema too early.** TOML plugins are attractive but the schema should follow proven first-party emitters. Phase 3 is intentionally last.

## Non-Goals

- Executing generated code — the modal displays code, it does not run it
- Syntax highlighting in phases 0–3
- Round-tripping — importing code back into the app
- Full third-party language bindings shipped first-party (plugin territory)
- Result surface model refactor — valuable but orthogonal; can happen independently
