// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
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

    test('vertical is one row per (step, body), JD and date leading', () {
      final rows = seriesToExportRows(
        table,
        SeriesLayout.vertical,
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

      // Vertically the same hole is an absent row, not an empty one.
      final vertical = seriesToExportRows(
        sparse,
        SeriesLayout.vertical,
        momentLabel: label,
      );
      expect(vertical.map((r) => r.header), ['Sun', 'Sun', 'Chiron']);
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
      expect(
        ExportService.toTsv(
          seriesToExportRows(
            errorFirst,
            SeriesLayout.vertical,
            momentLabel: label,
          ),
        ).split('\n').first,
        'Name\tJD\tDate\tLongitude\tLatitude\tError',
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
        expect(
          rows.single.fields.map((f) => f.$1),
          isNot(contains(anyOf('Latitude', 'Sun Latitude'))),
        );
      }
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
        'Name\tJD\tDate\tLongitude\tLatitude\tError',
      );
      expect(ExportService.toTsv(vertical).split('\n').length, 4);
      expect(
        ExportService.toCsv(horizontal).split('\n').first,
        'Name,JD,Date,Sun Longitude,Sun Latitude,Moon Longitude,Moon Latitude,'
        'Error',
      );
      expect(ExportService.toJson(horizontal), contains('"Sun Longitude"'));
      expect(
        ExportService.toColonSeparated(vertical),
        startsWith('Sun\nJD: 2451545.00000000\n'),
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
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
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
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
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
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
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

      await pump(
        tester,
        SeriesView(
          tabId: 'planets',
          steps: steps,
          momentLabel: (m) => m.ut.toStringAsFixed(1),
        ),
        size: const Size(1400, 900),
      );

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

    testWidgets('SeriesView export menu offers both layouts', (tester) async {
      final steps = [
        _ok(1.0, [
          _row('Sun', [('Longitude', '10')]),
        ]),
      ];

      await pump(
        tester,
        SeriesView(
          tabId: 'planets',
          steps: steps,
          momentLabel: (m) => m.ut.toStringAsFixed(1),
        ),
        size: const Size(1400, 900),
      );

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      expect(find.text(SeriesLayout.vertical.label), findsOneWidget);
      expect(find.text(SeriesLayout.horizontal.label), findsOneWidget);
      expect(find.text('Copy as TSV'), findsOneWidget);

      // Choosing a layout leaves the menu open so a format can follow.
      await tester.tap(find.text(SeriesLayout.horizontal.label));
      await tester.pumpAndSettle();
      expect(find.text('Copy as TSV'), findsOneWidget);
    });
  });
}
