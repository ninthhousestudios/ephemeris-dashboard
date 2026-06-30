# SWE Dashboard v2 — Code View Feature

**Date:** 2026-04-12
**Status:** Design draft
**Scope:** v2 feature addition — surface executable source code for every calculation the app performs, in multiple languages, with guaranteed accuracy.

## Motivation

The Swiss Ephemeris C API is the canonical reference; swisseph.dart is a thin FFI wrapper. Users of this dashboard are often developers, researchers, or students who want to take a calculation they see on screen and reproduce it in their own code — in C, Dart, Python, or whatever binding they use.

This feature makes every calculation in the dashboard directly copyable as runnable source code.

## Core Principles

1. **Accuracy by construction.** Displayed code is not generated from templates describing what we *think* the app does. It is generated from a trace of the actual Swiss Ephemeris calls the app made. If the app called `swe_set_topo(...)` then `swe_calc_ut(...)`, that is exactly what the code shows.
2. **Contextual slices.** The same trace is rendered differently depending on where the "code" button is clicked. A button on a result card shows the one line responsible for that card. A button on the tab shows a complete runnable program.
3. **Pluggable languages.** C and Dart are bundled first-party. Other languages (Python, JS, Rust, Go, …) are added via TOML plugin files, without recompiling.

## User-Facing Surface

### Entry Points

A "C ⋯" button appears on:

- Each **ResultCard** — emits the single call that produced the card's values.
- The **ContextBar** — emits the context setup calls (`swe_set_topo`, `swe_set_sid_mode`, date/time conversion helpers).
- The **FlagBar** / ephemeris options section — emits the ephemeris-source setup calls (`swe_set_ephe_path`, `swe_set_jpl_file`, etc.).
- Each **Tab** — emits a complete, standalone program reproducing every card on the tab.

The button is **disabled until the first calculation has been run**. Before that, no trace exists; a placeholder template would undermine the accuracy guarantee.

The button label is `C` with a small `⋯` affordance; tapping `⋯` opens a language picker menu populated by the installed plugins. `C` alone is the default shortcut.

**Relation to existing Pin button:** The `onPin` callback exists in `ResultCard` but is never wired in code. The pin button slot is repurposed for the "C ⋯" control. Pinning, as described in the v1 spec, is dropped.

### Display

A **modal dialog**, not an inline expansion. Reasons:

- Generated programs can be 50+ lines; an inline expansion would destabilize the zoom-sensitive card/tab layout.
- Syntax-independent plain monospace text is all we render; no syntax highlighting in v2.

Modal contains:

- Scrollable code area (both directions).
- Resizable window.
- Copy-to-clipboard button.
- Language label in the title bar.

### Code Header

Every emitted code block begins with a comment block:

```
// Generated from swe_dashboard
// JD (UT): 2460412.5
// Date/Time: 2026-04-12 00:00 UT
// Location: 51.5074°N, 0.1278°W, 0m
// Ephemeris: Swiss Ephemeris (SEFLG_SWIEPH)
// Ayanamsa: Lahiri (SE_SIDM_LAHIRI)
```

The exact fields vary by slice (a card-level snippet does not need the full context block).

## Call Tracing

### Mechanism

A `TracingSwissEph` wrapper sits around the `SwissEph` instance exposed by `sweProvider`. It forwards every method call to the real instance, and records each call into a `CallTrace`.

```dart
enum CallCategory { context, flags, calc, teardown }

class CallEntry {
  final String name;          // e.g. "swe_calc_ut"
  final List<Object?> args;   // ordered positional args as Dart values
  final Object? result;       // return value (for display as // returns: comment)
  final CallCategory category;
}

class CallTrace {
  final List<CallEntry> entries;
  final EffectiveContext context;  // for header metadata
  final DateTime capturedAt;
}
```

The trace is tagged by category so each "C ⋯" button can filter:

| Button location | Category filter |
|---|---|
| ContextBar | `context` |
| FlagBar / ephemeris options | `flags` |
| ResultCard | the specific `calc` entry that produced the card |
| Tab | all categories (`context` + `flags` + `calc[]` + `teardown`) |

### Lifecycle

- Trace is cleared at the start of each Calculate-button press.
- Each tab's Riverpod notifier holds the trace from the most recent calc.
- Cards identify their trace entry via an ID passed through when the calc runs (index or deterministic key).
- If a trace entry is missing when a button is clicked (shouldn't happen given the disabled-until-first-calc rule), the modal displays an error explaining state.

### Why Not Templates

Templates are tempting — they're simple. But they drift. If swisseph.dart changes which underlying call it makes for `calc_ut2` vs `calc_ut`, or adds a new pre-call setup, templates silently become wrong. Call-tracing mirrors reality by construction.

## Code Emission

### Emitter Interface

```dart
enum EmitMode { snippet, section, program }

abstract class CodeEmitter {
  String get languageId;         // "c", "dart", "python"
  String get displayName;        // "C (Swiss Ephemeris)"
  String get fileExtension;      // "c"
  String emit(CallTrace trace, EmitMode mode, EmitFilter filter);
}
```

`EmitFilter` selects which entries to render (single entry, category subset, or all).

### Bundled Emitters

- **C** — first-party, canonical. Matches `swephexp.h` exactly.
- **Dart** — first-party, matches what swisseph.dart actually does (since that is what the app calls).

### Plugin Emitters

TOML files describe additional languages. Minimum viable plugin schema:

```toml
[plugin]
id = "python"
display = "Python (pyswisseph)"
extension = "py"

[preamble]
snippet_import = "import swisseph as swe"
program_header = """
import swisseph as swe

def main():
"""
program_footer = """
if __name__ == '__main__':
    main()
"""

[constants]
SE_SUN         = "swe.SUN"
SE_MOON        = "swe.MOON"
SEFLG_SWIEPH   = "swe.FLG_SWIEPH"
SEFLG_SIDEREAL = "swe.FLG_SIDEREAL"
# ... one entry per SwissEph constant the app uses

[calls.swe_calc_ut]
template = "swe.calc_ut({jd}, {args[0]}, {args[1]})"

[calls.swe_set_topo]
template = "swe.set_topo({args[0]}, {args[1]}, {args[2]})"

[calls.swe_set_sid_mode]
template = "swe.set_sid_mode({args[0]}, {args[1]}, {args[2]})"

# ... one entry per supported SwissEph function
```

Placeholder substitution is simple: `{args[N]}`, `{jd}`, named fields from the trace entry. Constants referenced in args are looked up in `[constants]` before substitution.

### Missing Function Handling

If the trace includes a `swe_xxx` call that a plugin does not declare in `[calls]`, the emitter inserts:

```
// TODO: <language> binding missing for swe_xxx
```

and continues. This keeps plugins useful even when incomplete.

### Plugin Discovery and Loading

- **Bundled:** TOMLs in `assets/plugins/` loaded via `rootBundle`.
- **User:** TOMLs in `<platform-config-dir>/swe_dashboard/plugins/` (resolved via `path_provider`).
- User plugins override bundled plugins if the `id` matches.
- Loaded at app startup.

### Plugin Error Handling

- Malformed TOML → plugin skipped, single toast notification on app startup listing skipped plugins.
- Missing required fields (`id`, `display`) → same behavior.
- No modal, no stacktrace; we fail soft and keep the app usable.

## Implementation Phases

### Phase 1 — Minimum Viable

- `TracingSwissEph` wrapper recording calls.
- Per-card "C" button only (no `⋯`, no language picker).
- C emitter only, hardcoded in Dart (no TOML loading yet).
- Snippet mode only (the one `swe_calc_ut` line).
- Modal with plain text and copy button.

This validates the tracing approach end-to-end with the smallest surface.

### Phase 2 — Full Slice Coverage

- ContextBar, FlagBar, and per-tab "C" buttons.
- Section and program emit modes in the C emitter.
- Dart emitter added (bundled, still hardcoded).

### Phase 3 — TOML Plugins

- TOML loader, schema, constants table.
- Migrate C and Dart from hardcoded to TOML (dogfood the plugin format).
- Plugin discovery from both bundled assets and user config dir.
- Language picker `⋯` menu.

### Phase 4 — Polish

- Resize modal with persisted size.
- Richer `// returns:` annotations on each call.
- Optional: save-as file button for program mode.

## Open Questions

1. **Deterministic card-to-trace mapping.** Most tabs generate cards programmatically (e.g., one per selected planet). The card needs a stable key that matches its trace entry. Per-tab notifiers already have this implicitly via list index; confirm this holds for tabs that filter or reorder cards.
2. **Constant naming in C emitter.** C uses raw `#define` names (`SE_SUN`, `SEFLG_SWIEPH`). The trace records Dart enum values; we need a reverse-lookup table. Feasible but tedious — roughly 200 constants.
3. **Threading.** Swiss Ephemeris C globals (ephe path, sid mode, topo) are process-global. If the app ever computes in parallel, traces could interleave. Current app is single-calc-at-a-time; document this assumption.

## Non-Goals

- Executing generated code. The modal displays code; it does not run it.
- Syntax highlighting. Plain monospace only in v2.
- Full Python/JS/Rust bindings shipped first-party. Those are plugin territory.
- Round-tripping — importing code back into the app.
