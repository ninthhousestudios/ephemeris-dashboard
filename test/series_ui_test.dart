// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/calculation/run_tab_calc.dart';
import 'package:swe_dashboard/core/calculation/series_export.dart';
import 'package:swe_dashboard/core/calculation/series_settings.dart';
import 'package:swe_dashboard/core/calculation/series_settings_provider.dart';
import 'package:swe_dashboard/core/calculation/series_spec.dart';
import 'package:swe_dashboard/core/calculation/series_table.dart';
import 'package:swe_dashboard/core/export_service.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/widgets/quantity_picker.dart';
import 'package:swe_dashboard/widgets/series_bar.dart';
import 'package:swe_dashboard/widgets/series_grid.dart';
import 'package:swe_dashboard/widgets/series_view.dart';

import 'support/widget_fixtures.dart';

Moment _moment(double ut) => Moment(ut: ut, deltaT: 0);

SeriesStep _ok(double ut, List<ExportRow> rows) =>
    (_moment(ut), CalcOk<List<ExportRow>>(rows));

SeriesStep _err(double ut, String message) =>
    (_moment(ut), CalcError<List<ExportRow>>(message));

ExportRow _row(String header, List<(String, String)> fields) =>
    ExportRow(header: header, fields: fields);

void main() {
  group('buildSeriesTable', () {
    test('columns are (header, label) pairs in step-0 order', () {
      final table = buildSeriesTable([
        _ok(1.0, [
          _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
          _row('Moon', [('Longitude', '20'), ('Latitude', '5')]),
        ]),
      ]);

      expect(table.columns.map((c) => c.title), [
        'Sun Longitude',
        'Sun Latitude',
        'Moon Longitude',
        'Moon Latitude',
      ]);
      expect(
        table.rows.single.values[const SeriesColumn('Moon', 'Latitude')],
        '5',
      );
    });

    test(
      'a column appearing only in a later step is appended, not inserted',
      () {
        final table = buildSeriesTable([
          _ok(1.0, [
            _row('Sun', [('Longitude', '10')]),
          ]),
          _ok(2.0, [
            _row('Sun', [('Longitude', '11')]),
            _row('Chiron', [('Longitude', '99')]),
          ]),
        ]);

        expect(table.columns.map((c) => c.title), [
          'Sun Longitude',
          'Chiron Longitude',
        ]);
        // The step that lacks the column has a hole, not a shift.
        expect(
          table.rows.first.values[const SeriesColumn('Chiron', 'Longitude')],
          isNull,
        );
      },
    );

    test('an errored step is a row, and contributes no columns', () {
      final table = buildSeriesTable([
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
        _err(2.0, 'jd 2 out of range'),
        _ok(3.0, [
          _row('Sun', [('Longitude', '12')]),
        ]),
      ]);

      expect(table.columns.map((c) => c.title), ['Sun Longitude']);
      expect(table.rows.length, 3);
      expect(table.rows[1].isError, isTrue);
      expect(table.rows[1].error, 'jd 2 out of range');
      expect(table.rows[1].moment.ut, 2.0);
      expect(table.hasErrors, isTrue);
    });

    test('hidden labels drop the quantity for every header', () {
      final table = buildSeriesTable(
        [
          _ok(1.0, [
            _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
            _row('Moon', [('Longitude', '20'), ('Latitude', '5')]),
          ]),
        ],
        hiddenLabels: {'Latitude'},
      );

      expect(table.columns.map((c) => c.title), [
        'Sun Longitude',
        'Moon Longitude',
      ]);
    });

    test('empty input is an empty table', () {
      final table = buildSeriesTable(const []);
      expect(table.isEmpty, isTrue);
      expect(table.hasErrors, isFalse);
    });
  });

  group('seriesToExportRows', () {
    final table = buildSeriesTable([
      _ok(2451545.0, [
        _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
        _row('Moon', [('Longitude', '20'), ('Latitude', '5')]),
      ]),
      _err(2451546.0, 'out of range'),
    ]);

    String label(Moment m) => 'day ${m.ut.toStringAsFixed(0)}';

    test('vertical is the transpose: a row per quantity, the steps across', () {
      final rows = seriesToExportRows(
        table,
        SeriesLayout.vertical,
        momentLabel: label,
      );

      // The (body, quantity) pair stays one label; the steps are the columns.
      expect(rows.map((r) => r.header), [
        'JD',
        'Sun Longitude',
        'Sun Latitude',
        'Moon Longitude',
        'Moon Latitude',
        'Error',
      ]);
      expect(rows[1].fields, [
        ('day 2451545', '10'),
        // The failed step is a blank cell in every quantity's row.
        ('day 2451546', ''),
      ]);
      // The Moment is a column here, so full-precision time is its own row
      // rather than a field leading each one.
      expect(rows[0].fields.first, ('day 2451545', '2451545.00000000'));
      // And the error is a row along the bottom, one cell per step.
      expect(rows.last.fields, [
        ('day 2451545', ''),
        ('day 2451546', 'out of range'),
      ]);
    });

    test('long is one row per (step, body), JD and date leading', () {
      final rows = seriesToExportRows(
        table,
        SeriesLayout.long,
        momentLabel: label,
      );

      expect(rows.map((r) => r.header), ['Sun', 'Moon', '']);
      expect(rows[0].fields, [
        ('JD', '2451545.00000000'),
        ('Date', 'day 2451545'),
        ('Longitude', '10'),
        ('Latitude', '0'),
      ]);
      expect(rows[1].fields.last, ('Latitude', '5'));
      // The errored step is one row carrying the message, not one per body,
      // padded to the quantity schema so the message stays the last column.
      expect(rows[2].fields, [
        ('JD', '2451546.00000000'),
        ('Date', 'day 2451546'),
        ('Longitude', ''),
        ('Latitude', ''),
        ('Error', 'out of range'),
      ]);
    });

    test('long stays tidy: one label per quantity, whatever the body', () {
      // The point of the shape — every row has the same schema, so it loads
      // as a dataframe without reshaping.
      final rows = seriesToExportRows(
        table,
        SeriesLayout.long,
        momentLabel: label,
      );
      expect(
        ExportService.toCsv(rows).split('\n').first,
        'Name,JD,Date,Longitude,Latitude,Error',
      );
    });

    test('two steps that format alike still get a column each', () {
      final rows = seriesToExportRows(
        table,
        SeriesLayout.vertical,
        // A step finer than the label's resolution: both Moments read alike.
        momentLabel: (_) => 'noon',
      );

      expect(rows[1].fields.map((f) => f.$1), ['noon', 'noon (2)']);
    });

    test('horizontal is one row per step in grid column order', () {
      final rows = seriesToExportRows(
        table,
        SeriesLayout.horizontal,
        momentLabel: label,
      );

      expect(rows.length, 2);
      expect(rows[0].header, 'day 2451545');
      expect(rows[0].fields, [
        ('JD', '2451545.00000000'),
        ('Date', 'day 2451545'),
        ('Sun Longitude', '10'),
        ('Sun Latitude', '0'),
        ('Moon Longitude', '20'),
        ('Moon Latitude', '5'),
      ]);
      // An errored step keeps the full column shape, message last.
      expect(rows[1].fields, [
        ('JD', '2451546.00000000'),
        ('Date', 'day 2451546'),
        ('Sun Longitude', ''),
        ('Sun Latitude', ''),
        ('Moon Longitude', ''),
        ('Moon Latitude', ''),
        ('Error', 'out of range'),
      ]);
    });

    test('a body missing from a step is a hole, not a shifted column', () {
      final sparse = buildSeriesTable([
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
        _ok(2.0, [
          _row('Sun', [('Longitude', '11')]),
          _row('Chiron', [('Longitude', '99')]),
        ]),
      ]);

      final horizontal = seriesToExportRows(
        sparse,
        SeriesLayout.horizontal,
        momentLabel: label,
      );
      expect(horizontal[0].fields.last, ('Chiron Longitude', ''));

      // Transposed, the same hole is an empty cell in Chiron's row — the step
      // it is missing from is a column, and columns do not move.
      final vertical = seriesToExportRows(
        sparse,
        SeriesLayout.vertical,
        momentLabel: label,
      );
      expect(vertical.map((r) => r.header), [
        'JD',
        'Sun Longitude',
        'Chiron Longitude',
      ]);
      expect(vertical.last.fields, [('day 1', ''), ('day 2', '99')]);
    });

    test('an errored first step does not reorder the exported columns', () {
      // ExportService derives its columns from first appearance across rows,
      // so a bare error row at step 0 would put Error ahead of every quantity
      // and make the schema depend on which step failed.
      final errorFirst = buildSeriesTable([
        _err(1.0, 'out of range'),
        _ok(2.0, [
          _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
        ]),
      ]);

      expect(
        ExportService.toTsv(
          seriesToExportRows(
            errorFirst,
            SeriesLayout.horizontal,
            momentLabel: label,
          ),
        ).split('\n').first,
        'Name\tJD\tDate\tSun Longitude\tSun Latitude\tError',
      );
      // Transposed there is nothing to reorder: every row carries every step,
      // so the columns are the steps in series order whatever failed.
      expect(
        ExportService.toTsv(
          seriesToExportRows(
            errorFirst,
            SeriesLayout.vertical,
            momentLabel: label,
          ),
        ).split('\n').first,
        'Name\tday 1\tday 2',
      );
    });

    test('hidden quantities stay out of both layouts', () {
      final hidden = buildSeriesTable(
        [
          _ok(1.0, [
            _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
          ]),
        ],
        hiddenLabels: {'Latitude'},
      );

      for (final layout in SeriesLayout.values) {
        final rows = seriesToExportRows(hidden, layout, momentLabel: label);
        // The quantity names a row in one layout and a column in the other,
        // so a hidden one must be absent from both.
        expect([
          ...rows.map((r) => r.header),
          ...rows.expand((r) => r.fields).map((f) => f.$1),
        ], isNot(contains(anyOf('Latitude', 'Sun Latitude'))));
      }
    });

    test('the filename stem carries the start Moment', () {
      expect(
        seriesFilenameStem('planets', [
          _ok(2451545.0, const []),
          _ok(2451546.0, const []),
        ]),
        'swe_planets_series_2451545.0000',
      );
      // Two series from different Contexts are distinguishable.
      expect(
        seriesFilenameStem('planets', [_ok(2451545.0, const [])]),
        isNot(seriesFilenameStem('planets', [_ok(2460000.0, const [])])),
      );
      // Nothing to name it after beats naming a file NaN.
      expect(seriesFilenameStem('planets', const []), 'swe_planets_series');
      expect(
        seriesFilenameStem('planets', [_ok(double.nan, const [])]),
        'swe_planets_series',
      );
    });

    test('the formats consume both layouts', () {
      final vertical = seriesToExportRows(
        table,
        SeriesLayout.vertical,
        momentLabel: label,
      );
      final horizontal = seriesToExportRows(
        table,
        SeriesLayout.horizontal,
        momentLabel: label,
      );

      expect(
        ExportService.toTsv(vertical).split('\n').first,
        'Name\tday 2451545\tday 2451546',
      );
      // Header + JD, four quantities, Error.
      expect(ExportService.toTsv(vertical).split('\n').length, 7);
      expect(
        ExportService.toCsv(horizontal).split('\n').first,
        'Name,JD,Date,Sun Longitude,Sun Latitude,Moon Longitude,Moon Latitude,'
        'Error',
      );
      expect(ExportService.toJson(horizontal), contains('"Sun Longitude"'));
      expect(
        ExportService.toColonSeparated(vertical),
        startsWith('JD\nday 2451545: 2451545.00000000\n'),
      );
    });
  });

  group('seriesFieldLabels', () {
    test('deduplicates across rows, preserving order', () {
      final labels = seriesFieldLabels([
        _ok(1.0, [
          _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
          _row('Moon', [('Longitude', '20'), ('Latitude', '5')]),
        ]),
      ]);
      expect(labels, ['Longitude', 'Latitude']);
    });

    test('falls through an errored first step to the first that computed', () {
      final labels = seriesFieldLabels([
        _err(1.0, 'boom'),
        _ok(2.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
      ]);
      expect(labels, ['Longitude']);
    });

    test('is empty when nothing computed', () {
      expect(seriesFieldLabels([_err(1.0, 'boom')]), isEmpty);
    });
  });

  group('StepUnit.snapStepValue', () {
    test('leaves an acceptable value alone', () {
      expect(StepUnit.days.snapStepValue(2.5), 2.5);
      expect(StepUnit.months.snapStepValue(-3), -3);
    });

    test('rounds a fractional value for a calendar unit', () {
      expect(StepUnit.months.snapStepValue(2.4), 2.0);
      expect(StepUnit.years.snapStepValue(-1.6), -2.0);
    });

    test('falls back to ±1 where no rounding helps', () {
      expect(StepUnit.days.snapStepValue(0), 1.0);
      expect(StepUnit.months.snapStepValue(0.4), 1.0);
      expect(StepUnit.days.snapStepValue(double.nan), 1.0);
      expect(StepUnit.days.snapStepValue(double.negativeInfinity), -1.0);
    });
  });

  group('SeriesSettingsNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
        ],
      );
      addTearDown(container.dispose);
    });

    SeriesSettings read(String tab) =>
        container.read(seriesSettingsProvider(tab));
    SeriesSettingsNotifier notifier(String tab) =>
        container.read(seriesSettingsProvider(tab).notifier);

    test('defaults to series mode off', () {
      expect(read('planets').enabled, isFalse);
      expect(read('planets').stepUnit, StepUnit.days);
      expect(read('planets').rowCount, 30);
    });

    test('settings are per tab', () {
      notifier('planets').setEnabled(true);
      expect(read('planets').enabled, isTrue);
      expect(read('houses').enabled, isFalse);
    });

    test('rejects a step value the unit cannot use, keeping the old one', () {
      expect(notifier('planets').setStepValue(0), isFalse);
      expect(notifier('planets').setStepValue(double.nan), isFalse);
      expect(read('planets').stepValue, 1.0);
      expect(notifier('planets').setStepValue(-2), isTrue);
      expect(read('planets').stepValue, -2.0);
    });

    test('switching to a calendar unit snaps the step value', () {
      notifier('planets').setStepValue(2.4);
      expect(notifier('planets').setStepUnit(StepUnit.months), 2.0);
      expect(read('planets').stepValue, 2.0);
      expect(read('planets').stepUnit, StepUnit.months);
    });

    test('row count above the hard cap is stored, and capped at compute', () {
      expect(notifier('planets').setRowCount(0), isFalse);
      expect(notifier('planets').setRowCount(5000), isTrue);
      expect(read('planets').rowCount, 5000);
      expect(
        read('planets').specFrom(_moment(2451545.0)).effectiveRowCount,
        seriesHardRowCap,
      );
    });

    test('quantities default visible; hiding is what is persisted', () async {
      expect(read('planets').showsLabel('Latitude'), isTrue);
      notifier('planets').setLabelVisible('Latitude', false);
      expect(read('planets').showsLabel('Latitude'), isFalse);

      // A fresh container over the same prefs sees the same settings.
      final prefs = await SharedPreferences.getInstance();
      final reopened = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
        ],
      );
      addTearDown(reopened.dispose);
      expect(
        reopened.read(seriesSettingsProvider('planets')).showsLabel('Latitude'),
        isFalse,
      );
      expect(
        reopened.read(seriesSettingsProvider('houses')).showsLabel('Latitude'),
        isTrue,
      );
    });

    test('export layout defaults vertical and persists per tab', () async {
      expect(read('planets').layout, SeriesLayout.vertical);
      notifier('planets').setLayout(SeriesLayout.horizontal);

      final prefs = await SharedPreferences.getInstance();
      final reopened = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
        ],
      );
      addTearDown(reopened.dispose);
      expect(
        reopened.read(seriesSettingsProvider('planets')).layout,
        SeriesLayout.horizontal,
      );
      expect(
        reopened.read(seriesSettingsProvider('houses')).layout,
        SeriesLayout.vertical,
      );
    });

    test('a layout name from another build falls back, it does not throw', () {
      SharedPreferences.setMockInitialValues({
        'series_planets_export_layout': 'diagonal',
      });
      expect(SeriesLayout.byName('diagonal'), SeriesLayout.vertical);
      expect(SeriesLayout.byName(null), SeriesLayout.vertical);
      expect(SeriesLayout.byName('horizontal'), SeriesLayout.horizontal);
    });
  });

  // The gate every tab's series provider is now one line of: which settings
  // fields drive a recompute, and what a disabled series subscribes to.
  group('seriesSteps', () {
    late ProviderContainer container;
    late Provider<List<(Moment, CalcOutcome<double>)>> stepsProvider;
    late int factoryCalls;
    late int computeCalls;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      factoryCalls = 0;
      computeCalls = 0;
      stepsProvider = Provider<List<(Moment, CalcOutcome<double>)>>(
        (ref) => seriesSteps(
          ref,
          'planets',
          compute: () {
            factoryCalls++;
            return (eph, moment) {
              computeCalls++;
              return moment.ut;
            };
          },
        ),
      );
      container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
        ],
      );
      addTearDown(container.dispose);
      // Held alive: an unlistened Provider is disposed between reads, and then
      // every read recomputes, which is the thing under test here.
      container.listen(stepsProvider, (_, _) {});
    });

    SeriesSettingsNotifier notifier() =>
        container.read(seriesSettingsProvider('planets').notifier);

    test('series mode off runs no compute, and builds none', () {
      expect(container.read(stepsProvider), isEmpty);
      expect(
        factoryCalls,
        0,
        reason:
            'a disabled series must not even build the compute, which is what '
            'subscribes to the tab selections',
      );
    });

    test('a step edit made while off notifies no one', () {
      // The gate returns a *canonical* empty list, so re-evaluating a
      // switched-off series yields a value equal to the last one and Riverpod
      // holds its listeners. A fresh `[]` would rebuild the tab instead.
      var notifications = 0;
      container.listen(stepsProvider, (_, _) => notifications++);
      final first = container.read(stepsProvider);

      notifier().setStepValue(3);

      expect(identical(container.read(stepsProvider), first), isTrue);
      expect(notifications, 0);
    });

    test('enabled runs the compute once per row, at stepping Moments', () {
      notifier()
        ..setEnabled(true)
        ..setRowCount(3);

      final steps = container.read(stepsProvider);

      expect(steps, hasLength(3));
      expect(computeCalls, 3);
      final uts = steps.map((s) => (s.$2 as CalcOk<double>).value).toList();
      expect(uts[1] - uts[0], closeTo(1.0, 1e-9));
      expect(uts[2] - uts[1], closeTo(1.0, 1e-9));
    });

    test('a display-only settings edit does not recompute the series', () {
      notifier()
        ..setEnabled(true)
        ..setRowCount(2);
      final first = container.read(stepsProvider);
      final callsAfterFirst = factoryCalls;

      notifier()
        ..setLabelVisible('Longitude', false)
        ..setLayout(SeriesLayout.horizontal);

      expect(identical(container.read(stepsProvider), first), isTrue);
      expect(factoryCalls, callsAfterFirst);
      expect(computeCalls, 2);
    });

    test('an edit to the shape of the series does recompute it', () {
      notifier()
        ..setEnabled(true)
        ..setRowCount(2);
      container.read(stepsProvider);

      notifier().setRowCount(4);
      expect(container.read(stepsProvider), hasLength(4));

      notifier().setStepUnit(StepUnit.months);
      final monthly = container.read(stepsProvider);
      expect(
        (monthly[1].$2 as CalcOk<double>).value -
            (monthly[0].$2 as CalcOk<double>).value,
        greaterThan(27.0),
      );

      notifier().setEnabled(false);
      expect(container.read(stepsProvider), isEmpty);
    });
  });

  group('widgets', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      Widget child, {
      Size size = const Size(400, 800),
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: child,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('SeriesBar shows step controls only in series mode', (
      tester,
    ) async {
      final container = await pump(tester, const SeriesBar(tabId: 'planets'));

      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Rows'), findsNothing);

      await tester.tap(find.text('Series'));
      await tester.pump();

      expect(find.text('Rows '), findsOneWidget);
      expect(find.text('Days'), findsOneWidget);
      expect(container.read(seriesSettingsProvider('planets')).enabled, isTrue);
    });

    testWidgets('SeriesBar step unit chips snap the step value field', (
      tester,
    ) async {
      final container = await pump(
        tester,
        const SeriesBar(tabId: 'planets'),
        size: const Size(1400, 900),
      );
      container.read(seriesSettingsProvider('planets').notifier)
        ..setEnabled(true)
        ..setStepValue(2.4);
      await tester.pump();

      await tester.tap(find.text('Months'));
      await tester.pump();

      expect(container.read(seriesSettingsProvider('planets')).stepValue, 2.0);
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    });

    testWidgets('SeriesBar warns above the soft row cap', (tester) async {
      final container = await pump(
        tester,
        const SeriesBar(tabId: 'planets'),
        size: const Size(1400, 900),
      );
      container.read(seriesSettingsProvider('planets').notifier)
        ..setEnabled(true)
        ..setRowCount(seriesSoftRowCap + 1);
      await tester.pump();

      expect(find.textContaining('comfort limit'), findsOneWidget);
    });

    testWidgets('SeriesBar survives extreme text scale at mobile width', (
      tester,
    ) async {
      final container = await pump(
        tester,
        const SeriesBar(tabId: 'planets'),
        textScale: 3.0,
      );
      container
          .read(seriesSettingsProvider('planets').notifier)
          .setEnabled(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('SeriesGrid renders an error row without shifting columns', (
      tester,
    ) async {
      final table = buildSeriesTable([
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
        _err(2.0, 'out of range'),
      ]);

      await tester.pump(Duration.zero);
      await pump(
        tester,
        SeriesGrid(
          table: table,
          momentLabel: (m) => m.ut.toStringAsFixed(1),
          momentColumnTitle: 'UT',
          layout: SeriesLayout.horizontal,
        ),
        size: const Size(1400, 900),
      );

      expect(find.text('UT'), findsOneWidget);
      expect(find.text('Sun Longitude'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('out of range'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SeriesView picker hides a quantity across all bodies', (
      tester,
    ) async {
      final steps = [
        _ok(1.0, [
          _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
          _row('Moon', [('Longitude', '20'), ('Latitude', '5')]),
        ]),
      ];

      final container = await pump(
        tester,
        SeriesView(tabId: 'planets', steps: steps),
        size: const Size(1400, 900),
      );
      // Horizontal, so the headings carry the body name and the chip label is
      // not itself a heading.
      container
          .read(seriesSettingsProvider('planets').notifier)
          .setLayout(SeriesLayout.horizontal);
      await tester.pump();

      expect(find.byType(QuantityPicker), findsOneWidget);
      expect(find.text('Sun Latitude'), findsOneWidget);
      expect(find.text('Moon Latitude'), findsOneWidget);

      // The chip and the column heading share the label text, so tap the chip.
      await tester.tap(find.widgetWithText(FilterChip, 'Latitude'));
      await tester.pump();

      expect(find.text('Sun Latitude'), findsNothing);
      expect(find.text('Moon Latitude'), findsNothing);
      expect(find.text('Sun Longitude'), findsOneWidget);
    });

    testWidgets('the chosen layout is the one the grid renders', (
      tester,
    ) async {
      final steps = [
        _ok(1.0, [
          _row('Sun', [('Longitude', '10'), ('Latitude', '0')]),
          _row('Moon', [('Longitude', '20'), ('Latitude', '5')]),
        ]),
      ];

      final container = await pump(
        tester,
        SeriesView(tabId: 'planets', steps: steps),
        size: const Size(1400, 900),
      );

      // Vertical is the default and is the transpose: the (body, quantity)
      // pair is a row label, and the steps are the columns.
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Sun Longitude'), findsOneWidget);
      expect(find.text('Moon Latitude'), findsOneWidget);
      // One step, so one step column and no Moment column heading.
      expect(find.text('Date/Time (UT1)'), findsNothing);

      container
          .read(seriesSettingsProvider('planets').notifier)
          .setLayout(SeriesLayout.horizontal);
      await tester.pump();

      // Horizontal puts the same pairs back along the top, with the Moment
      // leading each row.
      expect(find.text('Name'), findsNothing);
      expect(find.text('Date/Time (UT1)'), findsOneWidget);
      expect(find.text('Sun Longitude'), findsOneWidget);
      expect(find.text('Moon Latitude'), findsOneWidget);

      container
          .read(seriesSettingsProvider('planets').notifier)
          .setLayout(SeriesLayout.long);
      await tester.pump();

      // Long splits the pair over both axes: the body names a row, the
      // quantity a column, and the Moment leads as it does horizontally.
      expect(find.text('Date/Time (UT1)'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Moon'), findsOneWidget);
      expect(find.text('Sun Longitude'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a transposed grid puts the steps across and errors along the '
        'bottom', (tester) async {
      final table = buildSeriesTable([
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
          _row('Moon', [('Longitude', '20')]),
        ]),
        _err(2.0, 'out of range'),
      ]);

      await pump(
        tester,
        SeriesGrid(
          table: table,
          momentLabel: (m) => m.ut.toStringAsFixed(1),
          momentColumnTitle: 'UT',
          layout: SeriesLayout.vertical,
        ),
        size: const Size(1400, 900),
      );

      // Steps are the column headings; the Moment column title has no place.
      expect(find.text('1.0'), findsOneWidget);
      expect(find.text('2.0'), findsOneWidget);
      expect(find.text('UT'), findsNothing);

      // A row per (body, quantity), values in the step's column.
      expect(find.text('Sun Longitude'), findsOneWidget);
      expect(find.text('Moon Longitude'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // The failed step is a dashed column — one cell per quantity row — and
      // its message sits in the Error row along the bottom.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('out of range'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SeriesView export menu offers every layout', (tester) async {
      final steps = [
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
      ];

      await pump(
        tester,
        SeriesView(tabId: 'planets', steps: steps),
        size: const Size(1400, 900),
      );

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      for (final layout in SeriesLayout.values) {
        expect(find.text(layout.label), findsOneWidget);
      }
      expect(find.text('Copy as TSV'), findsOneWidget);

      // Choosing a layout leaves the menu open so a format can follow.
      await tester.tap(find.text(SeriesLayout.horizontal.label));
      await tester.pumpAndSettle();
      expect(find.text('Copy as TSV'), findsOneWidget);
    });

    testWidgets('the chosen layout is the one that reaches the clipboard', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final steps = [
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
      ];

      final container = await pump(
        tester,
        SeriesView(tabId: 'planets', steps: steps),
        size: const Size(1400, 900),
      );

      // Default layout is vertical: the one step is the only column, and
      // 'Sun Longitude' names a row.
      await tester.tap(find.byIcon(Icons.file_download));
      await tester.pumpAndSettle();
      expect(copied, contains('\nSun Longitude\t10'));

      // Selecting horizontal transposes it: the Moment is the row identifier
      // and the column carries the body name.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SeriesLayout.horizontal.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy as TSV'));
      await tester.pumpAndSettle();
      expect(copied, startsWith('Name\tJD\tDate\tSun Longitude\n'));

      // The choice went to the settings, not to widget state.
      expect(
        container.read(seriesSettingsProvider('planets')).layout,
        SeriesLayout.horizontal,
      );
    });

    testWidgets('a persisted layout is the one the export button starts on', (
      tester,
    ) async {
      final steps = [
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
      ];

      final container = await pump(
        tester,
        SeriesView(tabId: 'planets', steps: steps),
        size: const Size(1400, 900),
      );
      container
          .read(seriesSettingsProvider('planets').notifier)
          .setLayout(SeriesLayout.horizontal);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      final radio = tester.widget<RadioMenuButton<int>>(
        find.ancestor(
          of: find.text(SeriesLayout.horizontal.label),
          matching: find.byType(RadioMenuButton<int>),
        ),
      );
      expect(radio.groupValue, radio.value);
    });
  });
}
