# Calc Session — Design Sketch

Date: 2026-05-05
Status: proposal, not implemented

## Problem

Three lifecycles for one concept ("press Calculate, show results, remember
that we calculated"):

| Tab(s) | Trigger | "Has calculated?" |
|---|---|---|
| planets, houses, phenomena, table_view, differential, nodes_apsides | global `calcTriggerProvider` | `ref.watch(calcTriggerProvider) > 0` |
| ayanamsa, dates, eclipses, heliacal, rise_set, coordinates | own `xxxCalcTriggerProvider` | widget-local `bool _hasCalculated` set in `setState` |
| stars | global trigger + `ref.listenManual` to commit text field | global trigger > 0 |

Two real reasons this split exists:

1. **Input commit ordering.** Tabs with `TextEditingController` must commit
   text → provider before the result provider runs. The global Calculate
   button has no hook for that, so those tabs grew their own buttons +
   triggers.
2. **Tab-scoped staleness.** Pressing global Calculate while on Planets
   should not silently re-run Coordinates with whatever inputs happen to
   be in its providers. Local triggers accidentally solved this.

The widget-local `_hasCalculated` bool is just duplication: every tab can
already derive it from its trigger.

## Proposal: single global `CalcSession`, per-tab activation flags

Two concerns, kept separate inside one Notifier:

| Concern | Scope | Why |
|---|---|---|
| "Recompute against current context" | **Global** | Pressing Calculate must refresh every tab — switching to another tab after a context-bar change must show current-context results. |
| "Show results vs placeholder" | **Per tab** | Some tabs (Stars, Eclipses, Coordinates, Heliacal, Rise/Set, Dates, Ayanamsa) need tab-specific inputs before any result is meaningful. They stay at placeholder until the user activates them. |

### State

```dart
// lib/core/calc_session.dart

class CalcSession {
  const CalcSession({
    this.version = 0,
    this.lastRunAt,
    this.tabsRun = const {},
  });

  /// Bumped on every calculate(). Result providers watch this.
  final int version;

  /// When the most recent Calculate fired.
  final DateTime? lastRunAt;

  /// Tab ids that have been "activated" — their UI should show results
  /// rather than the "Press Calculate" placeholder.
  final Set<String> tabsRun;

  bool tabHasRun(String tabId) => tabsRun.contains(tabId);
}

class CalcSessionNotifier extends Notifier<CalcSession> {
  // Tabs that own TextEditingControllers register a commit callback so
  // flag-bar Calculate can pull text → providers before recalculating.
  // Only mounted tabs are in here.
  final Map<String, VoidCallback> _commits = {};

  @override
  CalcSession build() => const CalcSession();

  void registerCommit(String tabId, VoidCallback cb) => _commits[tabId] = cb;
  void unregisterCommit(String tabId) => _commits.remove(tabId);

  /// Single Calculate path. `activate` lists which tabs flip to "has run".
  /// Flag-bar press passes context-only tabs + active tab. Tab-local
  /// buttons pass just their own tab id.
  void calculate({required Set<String> activate}) {
    for (final c in _commits.values) { c(); }
    state = CalcSession(
      version: state.version + 1,
      lastRunAt: DateTime.now(),
      tabsRun: {...state.tabsRun, ...activate},
    );
  }
}

final calcSessionProvider =
    NotifierProvider<CalcSessionNotifier, CalcSession>(CalcSessionNotifier.new);

/// Current visible tab. Updated by the shell on tab change. Used by the
/// flag bar to include the active tab in `activate`.
final activeTabIdProvider = StateProvider<String>((_) => 'planets');

/// Tabs whose only inputs are the global context bar — flag-bar Calculate
/// activates all of these so switching to any of them after a Calculate
/// shows current-context results.
const kContextOnlyTabs = <String>{
  'planets', 'houses', 'phenomena',
  'table_view', 'differential', 'nodes_apsides',
};
```

### Tab integration

**Result provider** — watches `version` (rebuilds on every Calculate),
gates on `tabHasRun`:

```dart
final planetsResultsProvider = Provider<List<PlanetResult>>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('planets')) return const [];
  // ... existing calc body, uses current ectx + selected bodies
});
```

**Tab UI** (replaces both the `_hasCalculated` getter and the widget-local bool):

```dart
final hasRun = ref.watch(
  calcSessionProvider.select((s) => s.tabHasRun('planets')),
);
return hasRun ? _buildResults() : _buildPlaceholder();
```

**Tabs with text inputs** register a commit callback so flag-bar Calculate
syncs them too:

```dart
@override
void initState() {
  super.initState();
  _commit = () {
    ref.read(starSearchProvider.notifier).state = _searchController.text.trim();
  };
  ref.read(calcSessionProvider.notifier).registerCommit('stars', _commit);
}

@override
void dispose() {
  ref.read(calcSessionProvider.notifier).unregisterCommit('stars');
  super.dispose();
}
```

**Flag-bar Calculate**:

```dart
onPressed: () {
  final activeTab = ref.read(activeTabIdProvider);
  ref.read(calcSessionProvider.notifier).calculate(
    activate: {...kContextOnlyTabs, activeTab},
  );
},
```

The `{...kContextOnlyTabs, activeTab}` set means: every context-only tab
becomes active (so switching to Houses after pressing Calculate on Planets
shows updated Houses), plus whatever input-required tab the user is
currently viewing (so they don't have to also press the tab's own button).

**Tab-local button** (Stars, Coordinates ops, Eclipses search, etc.):

```dart
void _calculate() {
  // Tab-specific commits — fields the global commit callback wouldn't catch
  // (e.g. Coordinates' op-specific subset of fields).
  ref.read(coordOpProvider.notifier).state = CoordOp.azAlt;
  ref.read(coordLongitudeProvider.notifier).state =
      double.tryParse(_lonCtrl.text) ?? 0.0;
  // ...
  ref.read(calcSessionProvider.notifier).calculate(activate: {'coordinates'});
}
```

### Coordinates (option A — one session per tab)

Each of the three op buttons commits its op's fields then calls
`calculate(activate: {'coordinates'})`. Since the tab's `tabHasRun` is one
boolean, pressing any op marks the whole tab "run" — older op results
that share the same providers will recompute on every press.

The minor cost: if the user runs op-1, then op-2, op-1's result still
displays the op-1 last-committed values (because `coordOpProvider` and
its result provider are scoped to the current op selection). Acceptable.

## Why this is better

- **One concept.** "Should this tab show results?" is
  `session.tabHasRun(id)`. No more `_hasCalculated` booleans. No more
  `if (trigger == 0)` guards scattered across providers.
- **Calculate is global, but display is per-tab.** Pressing Calculate
  recomputes everything against current context (so switching tabs after
  a context-bar change shows current-context results), while
  not-yet-engaged tabs stay at placeholder.
- **Input commit is first-class.** No more `ref.listenManual` workaround
  in `stars_tab.dart`; no more "remember to call setState after bumping
  the trigger" in `dates_tab.dart`.
- **Extension point for v2.** When tracing arrives, `CalcSession` grows
  `lastTrace`, `lastError`, `inputsSnapshot` — same pattern, no rewiring.

## What I'm not proposing

- **Not** a per-tab Module with its own Notifier subclass. The session is
  uniform; family keys are enough.
- **Not** removing `EffectiveContext` or merging this with the
  C-globals/SE-execution work. That's a separate (bigger) wave.
- **Not** moving the Calculate button into each tab. The flag bar stays
  the primary entry; tabs that already have local buttons (Coordinates,
  Stars search-then-calc) keep them and call the same `calculate()`.

## Migration order

1. Add `lib/core/calc_session.dart` with the Notifier and `activeTabIdProvider`.
2. Wire `AppShell` to update `activeTabIdProvider` on tab change.
3. Convert flag-bar Calculate to read `activeTabIdProvider` and call
   `calculate()` on the matching session.
4. Convert tabs one at a time. For each tab:
   - Replace `ref.watch(<trigger>)` + `if (trigger == 0)` with `session.hasRun`.
   - Replace `_hasCalculated` getter/bool with `session.hasRun`.
   - For text-input tabs, move commit logic into `registerCommit` instead
     of inline before-bump or `ref.listenManual`.
   - Delete the old per-tab `xxxCalcTriggerProvider`.
5. Delete `calcTriggerProvider` and `lib/core/calc_trigger.dart` once no
   tab references it.

Each tab is a small independent commit. No flag day.

## Open questions

- **Stale-results indicator.** Changing the context bar without pressing
  Calculate leaves visible results displayed for old context. We could
  add `session.contextChangedSinceLastRun` and grey out the cards. Defer
  unless it bites in practice.
- **Tab id source-of-truth.** Tabs are added regularly; a single
  `tab_ids.dart` with `const` strings (matching the constants used by
  `kContextOnlyTabs`) is enough. An enum is more friction than benefit.
- **Should activating a tab via flag-bar mean it stays activated forever?**
  For the lifetime of the app session, yes. Once activated, a tab keeps
  recomputing on every subsequent Calculate. There is no "deactivate"
  path.

## Persistence

`CalcSession` state is **not persisted**. App restart begins with
`version: 0`, `tabsRun: {}`. Every tab shows its placeholder until the
user presses Calculate.

Tab inputs (selected bodies, ayanamsa choice, last star search term,
date ranges, coordinate op selection, etc.) continue to persist via
their existing per-input providers in `lib/core/persistence.dart`. The
session is ephemeral; the inputs survive restart.
