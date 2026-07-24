# Layout test harness

The no-golden-images rule and its rationale live in the root `CLAUDE.md`. This
file is the mechanics.

**`test/layout_invariants_test.dart`** is the load-bearing one. It sweeps all
18 screen-level surfaces x 3 viewports (400x800 mobile, 800x1024 tablet,
1400x900 desktop) x 5 text scales (1.0, 1.15, 1.3, 1.7, 2.0) and asserts no
overflow, plus that each surface still paints text at 2x. Diffs as text, no
binaries, no baselines to regenerate.

`test/support/widget_fixtures.dart` holds the shared surface list and pump
helpers it runs against — add a new screen-level surface there and the sweep
picks it up.

`_knownOverflows` in the invariants test is an itemised defect list
(yojana `swe-dashboard/65`), **checked both ways** — a new overflow fails, and
an entry that stops overflowing also fails and asks you to delete it. It can
only shrink. Never widen it to make a test pass; fix the layout.

`pumpAppWidget(hostInScrollView: true)` reproduces how `AppShell` hosts its
children (its `body` is a `SingleChildScrollView`). Without it, pumping a tab
into a fixed-height Scaffold reports a bottom overflow for any tab taller than
the viewport — a fact about the harness, not the app.

Overflow-collecting tests must restore `FlutterError.onError` **before** any
`expect`. Calling `expect` while it is overridden trips a binding assertion and
flutter_tools then deadlocks on shutdown instead of reporting the failure;
`addTearDown` is too late.
