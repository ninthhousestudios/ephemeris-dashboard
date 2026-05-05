# Codebase Architecture Review

Date: 2026-05-05

Skill used: `improve-codebase-architecture`.

Context notes:

- I found no `CONTEXT.md` and no ADR folder, so this review uses vocabulary from `README.md`, `CLAUDE.md`, `doc/2026-03-24-swisseph-dashboard-design.md`, and `doc/swe-dashboard-v2.md`.
- Existing domain terms used here: calculation context, flag bar, context bar, result card, ephemeris source, tab, Swiss Ephemeris call, chart import/export.

## Deepening Opportunities

1. Deepen the calculation execution Module.

   Files: `lib/core/calc_context.dart`, `lib/core/swe_service.dart`, most `lib/tabs/*/*_provider.dart`, especially `lib/tabs/planets/planets_provider.dart` and `lib/tabs/table_view/table_view_provider.dart`.

   Problem: `EffectiveContext.calculate()` claims the Seam for C global setup, but the Interface is shallow: many tab providers call it only to trigger `_applyGlobals()` and then call `SwissEph` directly. For example, `planetsResultsProvider` applies globals at `lib/tabs/planets/planets_provider.dart:133` and calls `swe.calcUt` directly at `lib/tabs/planets/planets_provider.dart:143`; Table View does the same at `lib/tabs/table_view/table_view_provider.dart:87` and `lib/tabs/table_view/table_view_provider.dart:101`. The deletion test says this Module is not deep enough: deleting `calculate()` would mostly move one `_applyGlobals()` call into each provider, while each provider already owns call ordering, flags, errors, and return mapping.

   Solution: Move "run this Swiss Ephemeris calculation under this effective context" behind a deeper calculation execution Module. That Module should own C-global application, call ordering, effective flags, error normalization, and the per-call metadata that v2 needs for tracing. The tabs should describe the calculation they want, not manually coordinate `setSidMode`, `setTopo`, flags, `calcUt`, `revjul`, and error strings.

   Benefits: Locality improves because global-state ordering and trace capture live in one place instead of every provider. Leverage improves because the same Interface can support normal execution, traced execution, test adapters, and eventually generated code. Tests also become more meaningful: the Interface is the test surface, so tests can validate "a planets calculation emits these calls/results/errors under this context" without rebuilding a ProviderContainer for every tab.

2. Deepen the result surface Module before adding the v2 code button.

   Files: `lib/widgets/result_card.dart`, `lib/core/export_service.dart`, `lib/tabs/*/*_tab.dart`, `lib/tabs/*/*_provider.dart`, `lib/layout/app_shell.dart`.

   Problem: Result display, per-card copy, export rows, and future code snippets are related behavior, but their knowledge is spread across tabs. `ResultCard` knows only formatted fields and a dead `onPin` action (`lib/widgets/result_card.dart:21`, `lib/widgets/result_card.dart:130`). Tabs build fields manually (`lib/tabs/planets/planets_tab.dart:274`, `lib/tabs/houses/houses_tab.dart:118`, `lib/tabs/phenomena/phenomena_tab.dart:201`) while providers separately build `ExportRow`s. `ExportService` assumes homogeneous row fields by using the first row as the TSV/CSV header (`lib/core/export_service.dart:27`, `lib/core/export_service.dart:63`), which is fragile for tabs like Houses, Dates, and Nodes/Apsides where rows are not all the same shape.

   Solution: Introduce a deeper result surface Module that represents one displayed calculation result once, with display fields, raw fields, export shape, action availability, and optional trace entry identity. `ResultCard` should render that Module. `ExportService` and the v2 code modal should consume it instead of each tab remapping results independently.

   Benefits: Locality improves because adding "C ..." to result cards no longer requires touching every tab's field construction. Leverage improves because display, copy, export, and code emission reuse the same result identity. Tests improve because each tab can be tested for its result surface shape once, and export/code behavior can be tested generically.

3. Deepen the calculate-session Module.

   Files: `lib/core/calc_trigger.dart`, `lib/widgets/flag_bar/flag_bar.dart`, `lib/tabs/rise_set/rise_set_provider.dart`, `lib/tabs/coordinates/coordinates_provider.dart`, `lib/tabs/dates/dates_tab.dart`, `lib/tabs/heliacal/heliacal_tab.dart`, plus every tab using `_hasCalculated`.

   Problem: The app has more than one calculation lifecycle. Some tabs use the global `calcTriggerProvider` (`lib/core/calc_trigger.dart:3`, `lib/widgets/flag_bar/flag_bar.dart:91`), some use local trigger providers (`lib/tabs/rise_set/rise_set_provider.dart:41`, `lib/tabs/coordinates/coordinates_provider.dart:29`), and some keep `_hasCalculated` as local widget state (`lib/tabs/dates/dates_tab.dart:20`, `lib/tabs/heliacal/heliacal_tab.dart:36`). This is a shallow Interface: callers must know which trigger applies, whether the first calculation happened, whether text controllers need syncing, and whether results should clear on context change.

   Solution: Create a calculation-session Module for each tab category. It should own "not calculated yet", "last successful calculation", "last failed calculation", "current inputs snapshot", and "trace from the last Calculate press". Tabs should ask the session what to render and which actions are enabled. The global flag bar can still exist, but it should issue a session command instead of incrementing a bare integer.

   Benefits: Locality improves because disabled-until-first-calc behavior from v2 becomes one rule rather than a repeated widget convention. Leverage improves because trace storage, export enablement, and stale-result handling become reusable across all tabs. Tests improve because session state can be exercised without pumping whole tabs.

4. Make Swiss Ephemeris global state one real Seam.

   Files: `lib/core/calc_context.dart`, `lib/core/swe_service.dart`, `lib/core/ephe/scanner.dart`, `lib/layout/app_shell.dart`.

   Problem: The code already recognizes the danger of C globals, but the Seam is split. `EffectiveContext` says C globals should only be set there (`lib/core/calc_context.dart:44`), `ephePathApplyProvider` has a deliberate provider side effect that calls `setEphePath` (`lib/core/swe_service.dart:70`), and the ephemeris scanner probes by calling `setEphePath` on its `SwissEph` adapter (`lib/core/ephe/scanner.dart:134`). `AppShell` has to remember to read the side-effect provider at startup (`lib/layout/app_shell.dart:56`). One adapter means a hypothetical seam; here the app has several implicit adapters and no single Interface for global-state mutation.

   Solution: Put Swiss Ephemeris global-state mutation behind a deeper Module that owns the shared `SwissEph` adapter, current ephemeris directory, context globals, scanner/probe instances, and reset/restore behavior. Calculation code should enter through this Module; scanner code should use a separate adapter or a clearly scoped probe path.

   Benefits: Locality improves because future concurrency, tracing, and ephemeris switching bugs concentrate in one Module. Leverage improves because tests can install a fake adapter and assert global-state order. This also reduces the risk that v2 tracing records calculation calls but misses setup calls that happened through another provider side effect.

5. Deepen context hydration and persistence.

   Files: `lib/core/context_provider.dart`, `lib/core/persistence.dart`, `lib/core/flag_provider.dart`, `lib/layout/app_shell.dart`.

   Problem: `ContextBarNotifier` accepts persistence, but `_loadPersisted()` returns `{}` (`lib/core/context_provider.dart:27`), so `AppShell` restores context later in a microtask (`lib/layout/app_shell.dart:58`). `FlagBarNotifier` restores synchronously and then syncs locked flags from the current context (`lib/core/flag_provider.dart:14`, `lib/core/flag_provider.dart:23`). This makes startup ordering part of the Interface: maintainers must know which providers start with defaults and which update after the first frame.

   Solution: Create a context hydration Module that builds the initial context and flags in one pass from persistence, platform ephemeris availability, and the current time. If delayed restoration is truly required, make the delayed state explicit as a loading/hydrating session state instead of a microtask hidden in `AppShell`.

   Benefits: Locality improves because startup policy is not split between core providers and shell UI. Leverage improves because tests can instantiate initial app state directly. It also gives v2 a reliable place to get code-header metadata such as JD, location, ephemeris source, and ayanamsa.

## v2 Design Opinion

The v2 design has the right north star: "accuracy by construction" via tracing actual Swiss Ephemeris calls is much stronger than hand-maintained templates. It also fits this codebase because the existing providers already centralize user-visible calculations enough that a tracing execution Module can become the natural next deep Module.

The largest design risk is tracing at the raw wrapper-call level without first creating a typed call model. `CallEntry.args: List<Object?>` is convenient, but C, Dart, and TOML emitters need more than positional Dart values: they need constant identity, flag composition, pointer/output conventions, setup-call ordering, and sometimes language-specific binding names. If that structure is not captured at execution time, the emitter layer will become a pile of reverse lookups and special cases.

I would keep Phase 1, but I would adjust its internal goal: do not just wrap `SwissEph`; create the minimal calculation execution Module and typed call-entry model needed for `swe_calc_ut` snippets. That lets Phase 1 validate the hardest architectural question without committing to the full plugin system.

I would also delay TOML plugins until C and Dart are stable as first-party emitters. The proposed TOML schema is plausible for simple calls, but Swiss Ephemeris has enough odd functions that a template-only plugin format may become shallow: plugin authors would need to know every quirk that the app already knows. Dogfooding is good, but migrating C and Dart into TOML in Phase 3 may remove useful Dart type checks too early.

Open design pressure to resolve before implementation:

- Card-to-trace mapping should use deterministic trace IDs, not list index, because filtering/reordering cards is already common.
- The trace should include setup calls made through ephemeris/global-state Modules, not only per-tab calculation calls.
- Generated snippets should probably be tied to the result surface Module, not directly to `ResultCard`, so export/copy/code share identity.
- Threading can stay single-calc-at-a-time for now, but that assumption should live in the calculation execution Module and be testable.

Which of these would you like to explore?
