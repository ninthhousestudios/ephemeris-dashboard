# Codex Suggestions for SWE Dashboard v2

Date: 2026-05-05

Source design: `doc/swe-dashboard-v2.md`

## Summary

The v2 direction is sound: generate code from the calls the app actually made, not from hand-maintained guesses about those calls. That accuracy goal should drive the implementation architecture.

My main suggestion is to treat v2 as a calculation-execution refactor first and a code-modal feature second. If tracing is bolted onto the current per-tab providers, the trace will work for Phase 1 but become fragile as soon as context setup, flags, tab-level programs, plugins, and non-`calcUt` functions are added.

## Recommended Shape

Build these Modules in this order:

1. `CalculationRunner`

   A core Module that owns:

   - Applying `EffectiveContext` to Swiss Ephemeris C globals.
   - Executing one calculation command or a batch of commands.
   - Recording all setup and calculation calls into a trace.
   - Normalizing Swiss Ephemeris errors.
   - Returning typed domain results to tab providers.

   This should replace the current pattern where each provider calls `ectx.calculate(...)` only to apply globals and then calls `SwissEph` directly.

2. Typed trace model

   Avoid a long-term trace shape of only:

   ```dart
   List<Object?> args
   ```

   That is too weak for emitters. A useful trace entry should preserve semantic information:

   - Function name, for example `swe_calc_ut`.
   - Typed arguments, including constant identity where known.
   - Effective flags as both integer value and symbolic parts.
   - Context setup calls and their reason.
   - Return values and return flag.
   - Stable trace ID.
   - Category: context, flags, calc, teardown.

   The trace should be emitter-neutral but not untyped.

3. Result surface model

   Add a Module that represents one displayed result once. It should hold:

   - Card title/subtitle.
   - Display fields.
   - Raw fields.
   - Export fields.
   - Optional trace ID.
   - Available actions, including copy/export/code.

   Then `ResultCard`, export, and v2 code actions can consume the same result identity. This avoids adding code-button wiring separately across every tab.

4. Code modal and C snippet emitter

   Once the runner and trace model exist, implement the smallest visible feature:

   - Per-card code button.
   - C only.
   - `swe_calc_ut` only.
   - Snippet mode only.
   - Plain text modal with copy.

   This validates the architecture without taking on plugins, full programs, or every Swiss Ephemeris function at once.

## Suggested Phase Plan

### Phase 0: Traceable planets path

Before user-facing UI, convert only the Planets tab path enough to prove the architecture:

- Add `CalculationRunner`.
- Route `planetsResultsProvider` through it.
- Capture context setup plus each `calcUt`.
- Attach deterministic trace IDs to `PlanetResult`.
- Add tests for call order and trace contents using a fake adapter if practical.

Done means: the Planets tab still renders the same values, but a test can assert the trace contains `setSidMode`, `setTopo`, `setJplFile`, and `calcUt` when applicable.

### Phase 1: Per-card C snippets

Implement the visible MVP from the v2 doc:

- Repurpose the unused `ResultCard.onPin` slot into a code action.
- Disable the action until the result has a trace ID.
- Show a modal with a C snippet for the selected trace entry.
- Include minimal header metadata: JD, date/time, location if relevant, ephemeris source, ayanamsa if relevant.

Do not add TOML, language picker, or tab-level programs in this phase.

### Phase 2: Shared result surface

Move repeated field/export/card construction behind a result surface Module for the highest-traffic tabs:

- Planets.
- Houses.
- Stars.
- Phenomena.
- Table View if feasible, though its row shape is different.

Done means: code actions, copy, and export are driven by the same result identity rather than parallel per-tab mappings.

### Phase 3: Full C emitter coverage

Expand first-party C emission across tabs:

- ContextBar section.
- FlagBar section.
- Per-tab complete program mode.
- More Swiss Ephemeris functions beyond `swe_calc_ut`.

This phase should force the trace model to represent odd call shapes. Keep it in Dart while the model is still evolving.

### Phase 4: Dart emitter

Add first-party Dart emission after C stabilizes:

- Emit code matching `swisseph.dart`, not the C names.
- Reuse the same trace model.
- Keep constants and flag decomposition centralized.

This phase proves whether the trace model is genuinely language-neutral.

### Phase 5: Plugin schema

Only introduce TOML plugins after C and Dart are stable. The TOML format should be designed from real emitter needs, not guessed upfront.

Start with plugins for simple bindings. If a language needs logic that templates cannot express, prefer an explicit unsupported-call marker over making the TOML schema too powerful too early.

## Trace ID Guidance

Do not map cards to traces by list index. Use deterministic IDs.

Examples:

- `planets:calc_ut:body=0`
- `stars:fixstar2_ut:term=Aldebaran`
- `houses:cusp:system=P:index=1`
- `phenomena:pheno_ut:body=4`

IDs should be generated where the calculation command is created, not in the widget. Widgets should receive an already-attached trace ID.

## Constant and Flag Handling

This is likely the most tedious part of v2. Do it once.

Create a Swiss Ephemeris symbol catalog Module that knows:

- Body constants: `SE_SUN`, `SE_MOON`, etc.
- Flag constants: `SEFLG_SWIEPH`, `SEFLG_SPEED`, etc.
- Sidereal mode constants.
- Eclipse flags and rise/set flags where needed.
- Dart names and C names separately.

The trace should carry symbolic identity when possible, with integer fallback when unknown.

Emitters should not reverse-engineer constants from raw integers independently.

## Swiss Ephemeris Global State

The current code mutates Swiss Ephemeris global state in more than one place:

- `EffectiveContext._applyGlobals`.
- `ephePathApplyProvider`.
- Ephemeris scanner probes.

For v2, tracing needs to see the setup calls that affected the calculation. Put calculation-time global setup behind `CalculationRunner`, and make scanner/probe behavior clearly separate so trace output does not accidentally include background validation calls.

Document the single-calc-at-a-time assumption in the runner. If parallel calculation is later added, the runner is the right place to serialize access or provide isolated adapters.

## Emitter Guidance

Keep emitters deterministic and boring.

Recommended emitter Interface:

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

Use `TraceSlice` rather than raw filters in the emitter. Filtering belongs near the trace/result selection layer; emission should receive the exact slice it is supposed to render.

Missing functions should include a clear TODO, but first-party C/Dart emitters should generally fail tests when a supported app call has no emitter case.

## UI Guidance

The v2 modal should stay intentionally plain:

- Monospace text.
- Horizontal and vertical scroll.
- Copy button.
- Language label.
- No syntax highlighting in the first implementation.

For the card action, prefer an icon-plus-short-label or compact text action that fits the existing `ResultCard` action row. Since the pin feature is dropped, remove pin wording from comments and tests when replacing it.

## Testing Suggestions

Add focused tests at the Module level before relying on golden tests:

- `CalculationRunner` applies setup calls before calc calls.
- Context setup calls are present only when relevant.
- Trace IDs remain stable when selected bodies reorder.
- C emitter renders symbolic constants for known bodies/flags.
- Unknown constants fall back predictably.
- Missing plugin call templates produce TODO output.
- Result surface export does not assume every row has identical fields.

Golden tests are still useful for modal layout and card action placement, but they should not be the primary verification for trace correctness.

## Main Risks

1. Weak trace entries

   If trace entries only contain raw Dart positional args, emitters will accumulate language-specific reverse lookup logic.

2. Trace capture outside the real execution path

   If the app keeps calling `SwissEph` directly from providers, the trace can drift from reality.

3. Plugin schema too early

   TOML plugins are attractive, but the schema should follow proven first-party emitters.

4. Result identity spread across widgets

   If trace IDs are attached in `ResultCard`, tab-level program output and export/code consistency will be harder.

5. Hidden C global state

   If setup calls happen through provider side effects, generated code may omit required context.

## Recommended First Commit

The first implementation commit should not contain the modal. It should contain:

- `CalculationRunner`.
- Typed trace records for context setup and `calcUt`.
- Planets tab routed through the runner.
- Stable trace IDs on `PlanetResult`.
- Unit tests for trace order and contents.

After that commit, the UI work becomes straightforward and less likely to distort the architecture.
