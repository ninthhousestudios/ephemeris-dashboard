# PRD: Deep-Module Refactor

Vocabulary follows `CONTEXT.md`. Honors `docs/adr/0001-reactive-results.md`.

## Problem Statement

The Ephemeris Dashboard works, but it was vibe-coded: the same tab shape was
hand-copied ~14 times, so there is almost no leverage anywhere. Changing how a
calculation works means editing it in 14 places, and the health analysis confirms
it — every tab co-changes with every other tab at 66–100% with no static dependency
between them. Nothing in the calculation path is testable without booting the native
Swiss Ephemeris binary, because the tracer wraps the concrete FFI type instead of an
interface. The code-emission pipeline is held together by stringly-typed contracts
maintained in three places and is already silently dropping calls (`swe_sidtime`).
Chart parsing is duplicated against a separate, better library (`charts_dart`) that
has the bug fixes and the real TOML spec but cannot run on web. And the app is
documented as having an explicit Calculate button that does not match its actual
reactive behavior. The result is a codebase that is hard to navigate, hard to test,
and hard to extend — the opposite of "agentically engineered."

## Solution

Refactor the dashboard into a small set of **deep modules** — simple, stable
interfaces with rich, isolated internals — without changing what the app does for
its users (except removing the vestigial Calculate button in favor of the reactive
behavior users already prefer). Concretely: introduce an **Ephemeris** interface seam
so every **Calculation** becomes testable behind a fake; extract a **Calculation
kernel** so each tab shrinks to a compute lambda and the copy-paste coupling
collapses; make a single **Symbol Catalog** the source of truth for the **Emitters**
and call recording; adopt **charts_dart** as the one chart library (split into a
web-safe byte core); let each tab self-describe via a **Tab registry**; and extract a
reusable **DateTimeInput** from the oversized context bar. The app stays shippable at
every step, guarded by the existing golden tests plus the new unit tests the seams
make possible.

## User Stories

1. As the maintainer, I want each tab to express only its own calculation logic, so
   that changing the shared calculation path is a one-place edit, not a 14-place one.
2. As the maintainer, I want the tab co-change coupling to disappear, so that editing
   one tab does not implicitly risk every other tab.
3. As an AI agent working in this codebase, I want one **Calculation kernel** to read
   instead of 14 near-identical provider preambles, so that I can understand the
   calculation path from a single module.
4. As the maintainer, I want an **Ephemeris** interface with a fake adapter, so that I
   can unit-test any tab's **Result** without loading the native Swiss Ephemeris
   binary.
5. As the maintainer, I want the production **Ephemeris** adapter to keep recording
   the **Call Trace**, so that the "show me the code" feature is preserved through the
   refactor.
6. As the maintainer, I want a single **Symbol Catalog** mapping Swiss Ephemeris
   constants and functions to their per-**Code Target** renderings, so that adding a
   function or constant is one edit instead of six parallel-map edits.
7. As the maintainer, I want the **Emitters** and the call recording to derive from
   the **Symbol Catalog**, so that a traced call cannot be silently dropped by an
   emitter (the `swe_sidtime` class of bug becomes structurally impossible).
8. As a user, I want the emitted C and Dart code to match exactly what was computed,
   so that I can trust the code as a faithful recipe for the **Result**.
9. As a user, I want **Results** to update live whenever I change the **Context**, so
   that the displayed values are never out of sync with my selected options.
10. As a user, I want no Calculate button and no "stale" indicator, so that the
    interface is simpler and the values are always current (ADR-0001).
11. As a user, I want the dashboard to show meaningful **Results** immediately on
    launch, so that I see live values for "now" without having to trigger anything.
12. As the maintainer, I want each recompute to remain synchronous, so that the
    **Applied Globals** cannot drift across await points.
13. As a user, I want to load a **Chart** from any supported file format and have it
    set the **Context's** **Moment** and **Location**, so that I can quickly enter
    time and place from existing chart files.
14. As a user, I want chart loading to recompute everything from the **Ephemeris**, so
    that stored positions in a file never override the dashboard's own values.
15. As a user on the web build, I want chart loading to work, so that I am not limited
    to desktop for importing charts.
16. As the maintainer, I want **charts_dart** to be the single source of truth for
    chart formats, so that the chtk/jhd bug fixes and the **Open Astrology Chart** TOML
    spec live in one library instead of two diverging copies.
17. As the maintainer, I want **charts_dart** split into a pure byte-based core and a
    thin `dart:io` file wrapper, so that the dashboard can depend on the core on web
    while the CLI keeps file convenience.
18. As the maintainer, I want round-trip tests for every chart format, so that a
    parsing regression is caught immediately instead of in the field.
19. As the maintainer, I want each tab to self-describe via a **Tab registry**
    descriptor, so that adding a tab is one descriptor instead of edits scattered
    across the shell.
20. As the maintainer, I want the shell to stop importing every tab widget and
    provider, so that the shell is no longer a god-importer.
21. As the maintainer, I want a forgotten format toggle to be a compile-time or
    registry error, not a silent no-op, so that wiring mistakes surface immediately.
22. As the maintainer, I want a reusable **DateTimeInput** module, so that the context
    bar and the dates/differential tabs share one **Moment** editor instead of three
    copies.
23. As the maintainer, I want **Moment** civil↔JD conversion unit-tested, so that the
    JD-is-canonical rule is verified and date-sync bugs are caught.
24. As the maintainer, I want the **Locked Flags** computed by one pure function of the
    **Context**, so that the lock-set is a single source of truth instead of two maps
    that must agree.
25. As a user, I want the context bar to behave identically after its decomposition,
    so that the refactor is invisible to me except where intended.
26. As the maintainer, I want the app to stay shippable at every step, so that the
    refactor never requires a long non-functional window.
27. As the maintainer, I want the golden tests to keep passing across the refactor, so
    that UI regressions are caught automatically.
28. As the maintainer, I want `CONTEXT.md` vocabulary used in code and tests, so that
    names match the domain model and the codebase stays navigable.

## Implementation Decisions

- **Reactive projection (ADR-0001).** **Results** are a pure function of the
  **Context** and **Flags**, recomputed on change. The Calculate button, the
  activation gate, and the `NotRun` state are removed. The **Context** defaults to a
  sensible **Moment** ("now") and last-used **Location**. Each recompute stays
  synchronous to protect the **Applied Globals**.
- **① Ephemeris seam.** Define an `Ephemeris` interface whose surface is the union of
  what tabs call and what the recorder traces. The production adapter wraps the Swiss
  Ephemeris FFI object and records the **Call Trace**; a fake adapter backs tests. The
  conditional-import split for native/web stays; the fake is the third adapter.
- **② Calculation kernel.** A single entry point projects the **Context** + **Flags**
  into one **Result** per tab: it owns the wiring (context/globals/runner/tag),
  injects a configured **Ephemeris**, and handles `SweException` uniformly via a
  `CalcOutcome = Ok | SweError` envelope. Tabs provide a compute lambda and a result
  type; tabs with richer error needs (e.g. dates' per-field errors) embed that in
  their result type. The shallow "effective context" merge is folded away.
- **③ charts_dart adoption.** Split `charts_dart` into a pure byte-based core
  (`readBytes`/`encodeBytes`, no `dart:io`) plus a thin `dart:io` file wrapper for its
  CLI. The dashboard depends on the core (path/git dependency) and deletes its in-tree
  chart-format parsers. The **Open Astrology Chart** TOML spec is the contract, not
  redesigned. Cross-repo work.
- **④ Symbol Catalog + Emitters.** One typed catalog maps Swiss Ephemeris functions
  and constants to their per-**Code Target** renderings. The **Emitters** and the call
  recording derive from it. Coverage is enforced so a traced call without an emitter
  rendering is a test failure, not a silent fallthrough. The two **Code Targets** (C,
  Dart) stay.
- **⑤ Tab registry.** Each tab exposes a plain-Dart `TabDescriptor` (label, icon,
  content builder, optional format-provider + export wiring). The shell iterates the
  registry. No codegen (project rule).
- **⑥ DateTimeInput.** Extract the **Moment** editor (controller set + civil↔JD
  parsing + the precise-time picker) into one module reused by the context bar and the
  dates/differential tabs. Split the context bar's mobile/desktop layouts into shared
  field widgets composed twice rather than rebuilt twice.
- **Kept as-is (already deep):** `ResultCard`, the ephemeris-file download/scan
  subsystem, `AppliedGlobals.fromContext`.
- **Sequencing:** ① first (foundation) → ② and ④ in parallel → ⑤ and ⑥. ③ runs on an
  independent track anytime.

## Testing Decisions

- **What makes a good test here:** it exercises a module through its **interface** and
  asserts external behavior — a **Result** value, an emitted code string, a round-trip
  equality — never an implementation detail. The **Ephemeris** fake is the key
  enabler: tests script ephemeris responses and assert the **Result**, with no native
  binary.
- **① Ephemeris:** test the fake adapter and that the production adapter records the
  expected **Call Trace**. Prior art: the existing tracing/runner tests.
- **② Calculation kernel:** test the reactive projection (Context change → new
  Result), the `SweError` path, and a representative tab's compute via the fake
  **Ephemeris**.
- **④ Symbol Catalog + Emitters:** test catalog completeness, emitter output for each
  **Code Target**, and trace↔emitter coverage (every traceable function has a
  rendering). Prior art: the existing emitter and symbol-catalog tests.
- **③ charts_dart:** per-format round-trip tests (write → `readBytes` → assert fields)
  in the charts_dart repo, where zero parser tests currently exist. The byte seam
  makes these mock-free.
- **⑥ DateTimeInput:** **Moment** civil↔JD conversion and field parsing, including the
  Gregorian/Julian boundary.
- **Pure functions:** **Locked Flags** (pure function of **Context**), `AppliedGlobals`
  derivation.
- **⑤ Tab registry:** light test that every tab has a descriptor and the registry is
  complete.
- **Golden tests** continue to guard the UI across the whole refactor.

## Out of Scope

- New calculation features, new tabs, or new chart formats.
- New **Code Targets** (e.g. Python) — the catalog makes them easier later, but none
  are added here.
- Reverse-engineering closed chart formats (`.SFcht`, etc.) — see charts_dart docs.
- Rewriting the app from scratch — explicitly rejected; this is an incremental,
  always-shippable refactor.
- Theming, responsive-zoom, and the ephemeris-file download/scan subsystem, except
  where a module boundary touches them.

## Further Notes

- The refactor is the work; behavior parity (minus the Calculate button) is the
  guardrail. Golden tests + the new unit tests verify every step.
- charts_dart changes land in a separate repo and must keep its CLI working.
- This PRD supersedes the "explicit Calculate button" decision in CLAUDE.md; that doc
  should be updated when ② lands.
