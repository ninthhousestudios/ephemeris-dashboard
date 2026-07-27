// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The user-defined ayanamsha list is one store shared by the Ayanamsa tab and
/// the context bar (swe-dashboard/96). Before, each kept its own and an entry
/// defined in one was invisible to the other; these tests pin the pieces that
/// unification rests on — stable ids, the name fallback, id resolution, the
/// stored round trip, and the Context's reconciliation when an entry goes away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swe_dashboard/core/ayanamsa_catalog.dart';
import 'package:swe_dashboard/core/calc_context.dart';
import 'package:swe_dashboard/core/context_provider.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/user_ayanamsa.dart';
import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_provider.dart';
import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_tab.dart';
import 'package:swe_dashboard/theme/app_themes.dart';
import 'package:swe_dashboard/widgets/context_bar/ayanamsa_selector.dart';
import 'package:swe_dashboard/widgets/context_bar/user_ayanamsa_dialog.dart';

import 'support/widget_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserAyanamsaNotifier — arbitrary editable entries', () {
    test('add appends entries with distinct, stable ids', () {
      final n = UserAyanamsaNotifier()
        ..add()
        ..add();
      expect(n.state.length, 2);
      expect(n.state[0].id, isNot(n.state[1].id));
      // Default seed is J2000 so a fresh entry is swetest-comparable, not 0.
      expect(n.state[0].t0, 2451545.0);
    });

    test('add returns the id of the entry it created', () {
      final n = UserAyanamsaNotifier();
      final id = n.add(name: 'Mine', t0: 2440000, value: 23.5, t0IsUt: true);
      final entry = n.state.single;
      expect(entry.id, id);
      expect(entry.name, 'Mine');
      expect(entry.t0, 2440000);
      expect(entry.value, 23.5);
      expect(entry.t0IsUt, isTrue);
    });

    test('update mutates only the matching entry, by id', () {
      final n = UserAyanamsaNotifier()
        ..add()
        ..add();
      final firstId = n.state[0].id;
      final secondId = n.state[1].id;

      n.update(firstId, t0: 2440000, value: 23.5, t0IsUt: true);

      final first = n.state.firstWhere((u) => u.id == firstId);
      final second = n.state.firstWhere((u) => u.id == secondId);
      expect(first.t0, 2440000);
      expect(first.value, 23.5);
      expect(first.t0IsUt, isTrue);
      // Untouched entry keeps its defaults.
      expect(second.t0, 2451545.0);
      expect(second.t0IsUt, isFalse);
    });

    test('partial update leaves unspecified fields intact', () {
      final n = UserAyanamsaNotifier()..add(name: 'Kept');
      final id = n.state[0].id;
      n
        ..update(id, t0IsUt: true)
        ..update(id, value: 24.1); // must not reset t0IsUt or the name
      expect(n.state[0].t0IsUt, isTrue);
      expect(n.state[0].value, 24.1);
      expect(n.state[0].name, 'Kept');
    });

    test('update clears the name when passed null explicitly', () {
      final n = UserAyanamsaNotifier()..add(name: 'Temporary');
      n.update(n.state[0].id, name: null);
      expect(n.state[0].name, isNull);
    });

    test('removeById drops one entry and keeps the rest', () {
      final n = UserAyanamsaNotifier()
        ..add()
        ..add();
      final keep = n.state[1].id;
      n.removeById(n.state[0].id);
      expect(n.state.map((u) => u.id), [keep]);
    });

    test('ids are not reused after removal', () {
      final n = UserAyanamsaNotifier()..add();
      final firstId = n.state[0].id;
      n
        ..removeById(firstId)
        ..add();
      expect(n.state.single.id, isNot(firstId));
    });

    test('ids restored from the store are not handed out again', () {
      final n = UserAyanamsaNotifier(
        initial: const [UserAyanamsa(id: 7), UserAyanamsa(id: 3)],
      );
      final id = n.add();
      expect(id, isNot(7));
      expect(id, isNot(3));
    });

    test('onChanged fires on every mutation, with the new list', () {
      final seen = <List<int>>[];
      final n = UserAyanamsaNotifier(
        onChanged: (entries) => seen.add([for (final u in entries) u.id]),
      );
      final id = n.add();
      n
        ..update(id, value: 1)
        ..removeById(id);
      expect(seen, [
        [id],
        [id],
        <int>[],
      ]);
    });
  });

  group('labels and resolution', () {
    test('an unnamed entry is numbered by position', () {
      expect(userAyanamsaLabel(const UserAyanamsa(id: 9), 0), 'User-defined 1');
      expect(userAyanamsaLabel(const UserAyanamsa(id: 9), 2), 'User-defined 3');
    });

    test('a blank name falls back to the numbered label', () {
      const entry = UserAyanamsa(id: 0, name: '  ');
      expect(userAyanamsaLabel(entry, 0), 'User-defined 1');
    });

    test('a name is used verbatim', () {
      const entry = UserAyanamsa(id: 0, name: 'Josh 1950');
      expect(userAyanamsaLabel(entry, 4), 'Josh 1950');
    });

    test('resolve finds the selected entry, and nothing for a stale id', () {
      const entries = [UserAyanamsa(id: 1), UserAyanamsa(id: 2)];
      expect(resolveUserAyanamsa(entries, 2)?.id, 2);
      expect(resolveUserAyanamsa(entries, 5), isNull);
      expect(resolveUserAyanamsa(entries, null), isNull);
      expect(resolveUserAyanamsa(const [], 1), isNull);
    });

    test('sidMode ORs the jdisut bit only when t0 is UT', () {
      expect(const UserAyanamsa(id: 0).sidMode, ayanamsaUserId);
      expect(
        const UserAyanamsa(id: 0, t0IsUt: true).sidMode,
        ayanamsaUserId | userAyanUtBit,
      );
    });
  });

  group('storage', () {
    Future<SharedPreferences> freshPrefs() {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    test('the list survives save → load, field for field', () async {
      final prefs = await freshPrefs();
      const stored = [
        UserAyanamsa(id: 4, name: 'Named', t0: 2415020.0, value: 22.5),
        UserAyanamsa(id: 5, t0IsUt: true),
      ];

      userAyanamsaListPref.write(prefs, userAyanamsasPrefKey, stored);

      expect(userAyanamsaListPref.read(prefs, userAyanamsasPrefKey), stored);
    });

    test('nothing stored reads as absent, not as an empty list', () async {
      final prefs = await freshPrefs();
      expect(userAyanamsaListPref.read(prefs, userAyanamsasPrefKey), isNull);
    });

    test('unusable stored data reads as absent rather than throwing', () async {
      final prefs = await freshPrefs();
      await prefs.setString(userAyanamsasPrefKey, 'not json at all');
      expect(userAyanamsaListPref.read(prefs, userAyanamsasPrefKey), isNull);
    });

    test('an entry with no usable id is dropped, the rest survive', () async {
      final prefs = await freshPrefs();
      await prefs.setString(
        userAyanamsasPrefKey,
        '[{"id":1,"t0":2451545.0,"value":0.0,"t0IsUt":false},{"name":"orphan"}]',
      );
      final loaded = userAyanamsaListPref.read(prefs, userAyanamsasPrefKey);
      expect(loaded?.map((u) => u.id), [1]);
    });

    test('an entry missing its astronomy is dropped, not defaulted', () async {
      // `toJson` always writes t0 and value, so their absence is drift, not a
      // valid saved entry — defaulting them would make it selectable and
      // computable in a frame the user never chose.
      final prefs = await freshPrefs();
      await prefs.setString(
        userAyanamsasPrefKey,
        '[{"id":1,"value":23.85},{"id":2,"t0":2451545.0},'
        '{"id":3,"t0":"J2000","value":23.85},'
        '{"id":4,"t0":2451545.0,"value":23.85}]',
      );
      final loaded = userAyanamsaListPref.read(prefs, userAyanamsasPrefKey);
      expect(loaded?.map((u) => u.id), [4]);
    });
  });

  group('legacy store migration', () {
    /// A store as a build before swe-dashboard/96 left it: the one user-defined
    /// ayanamsha as scalar Context fields, no list and no selected id.
    Future<SharedPreferences> legacyPrefs({required int ayanamsa}) {
      SharedPreferences.setMockInitialValues({
        'ctx_ayanamsa': ayanamsa,
        'ctx_user_ayan_t0': 2415020.0,
        'ctx_user_ayan_value': 22.5,
        'ctx_user_ayan_t0_is_ut': true,
      });
      return SharedPreferences.getInstance();
    }

    test('the old scalar params become one entry in the list', () async {
      final prefs = await legacyPrefs(ayanamsa: ayanamsaUserId);
      migrateLegacyUserAyanamsa(prefs);

      final entry = userAyanamsaListPref
          .read(prefs, userAyanamsasPrefKey)
          ?.single;
      expect(entry?.t0, 2415020.0);
      expect(entry?.value, 22.5);
      expect(entry?.t0IsUt, isTrue);
    });

    test(
      'a Context that was on user-defined selects the migrated entry',
      () async {
        final prefs = await legacyPrefs(ayanamsa: ayanamsaUserId);
        migrateLegacyUserAyanamsa(prefs);

        final entry = userAyanamsaListPref
            .read(prefs, userAyanamsasPrefKey)
            ?.single;
        expect(prefs.getInt('ctx_user_ayan_id'), entry?.id);
      },
    );

    test('a Context on a built-in mode keeps its selection', () async {
      // The parameters are still carried over — they are the user's work — but
      // nothing about the chart's frame changes.
      final prefs = await legacyPrefs(ayanamsa: 1);
      migrateLegacyUserAyanamsa(prefs);

      expect(
        userAyanamsaListPref.read(prefs, userAyanamsasPrefKey),
        hasLength(1),
      );
      expect(prefs.getInt('ctx_user_ayan_id'), isNull);
      expect(prefs.getInt('ctx_ayanamsa'), 1);
    });

    test('the legacy keys are dropped, so a second run is a no-op', () async {
      final prefs = await legacyPrefs(ayanamsa: ayanamsaUserId);
      migrateLegacyUserAyanamsa(prefs);
      expect(prefs.containsKey('ctx_user_ayan_t0'), isFalse);
      expect(prefs.containsKey('ctx_user_ayan_value'), isFalse);
      expect(prefs.containsKey('ctx_user_ayan_t0_is_ut'), isFalse);

      // Editing the migrated entry away must not resurrect it on next launch.
      userAyanamsaListPref.write(prefs, userAyanamsasPrefKey, const []);
      migrateLegacyUserAyanamsa(prefs);
      expect(userAyanamsaListPref.read(prefs, userAyanamsasPrefKey), isEmpty);
    });

    test('a store already on the list shape is left alone', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const existing = [UserAyanamsa(id: 9, name: 'Mine', value: 24.0)];
      userAyanamsaListPref.write(prefs, userAyanamsasPrefKey, existing);

      migrateLegacyUserAyanamsa(prefs);

      expect(userAyanamsaListPref.read(prefs, userAyanamsasPrefKey), existing);
    });

    test(
      'a store that never had a user-defined ayanamsha stays empty',
      () async {
        SharedPreferences.setMockInitialValues({'ctx_ayanamsa': 1});
        final prefs = await SharedPreferences.getInstance();

        migrateLegacyUserAyanamsa(prefs);

        expect(prefs.containsKey(userAyanamsasPrefKey), isFalse);
      },
    );
  });

  group('ContextBarNotifier reconciliation', () {
    Future<ContextBarNotifier> notifier() async {
      SharedPreferences.setMockInitialValues({});
      final store = PersistenceService(await SharedPreferences.getInstance());
      final n = ContextBarNotifier(SweUtils(EphemerisRunner()), store, true);
      addTearDown(n.dispose);
      return n;
    }

    test('selecting an entry sets both the mode and the id', () async {
      final n = await notifier();
      n.selectUserAyanamsa(3);
      expect(n.state.ayanamsa, ayanamsaUserId);
      expect(n.state.userAyanId, 3);
    });

    test('losing the selected entry falls back to another user one', () async {
      final n = await notifier();
      n
        ..selectUserAyanamsa(3)
        ..reconcileUserAyanamsa([1, 2]);
      expect(n.state.ayanamsa, ayanamsaUserId);
      expect(n.state.userAyanId, 1);
    });

    test('losing the last entry moves off user-defined entirely', () async {
      final n = await notifier();
      n
        ..selectUserAyanamsa(3)
        ..reconcileUserAyanamsa([]);
      expect(n.state.ayanamsa, isNot(ayanamsaUserId));
      expect(n.state.ayanamsa, greaterThanOrEqualTo(0));
    });

    test('a selection that still exists is left alone', () async {
      final n = await notifier();
      n
        ..selectUserAyanamsa(3)
        ..reconcileUserAyanamsa([1, 3]);
      expect(n.state.userAyanId, 3);
    });

    test('a built-in selection is untouched by list changes', () async {
      final n = await notifier();
      n
        ..setAyanamsa(1)
        ..reconcileUserAyanamsa([]);
      expect(n.state.ayanamsa, 1);
    });
  });

  group('cross-surface visibility — one list, two surfaces', () {
    /// One container shared by both surfaces, so what each pump sees is the
    /// other's writes rather than a fixture staged for it.
    Future<ProviderContainer> sharedApp() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
          ...tabOverrides,
          ayanamsaCompareModeProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> pumpInto(
      WidgetTester tester,
      ProviderContainer container,
      Widget child,
    ) async {
      tester.view.physicalSize = kDesktop;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppThemes.dark,
            themeAnimationDuration: Duration.zero,
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('one defined on the tab is offered by the context bar', (
      tester,
    ) async {
      final container = await sharedApp();

      // The tab's own "User-defined" add chip.
      await pumpInto(tester, container, const AyanamsaTab());
      // The chip row scrolls horizontally, so the add chip can sit off-screen.
      final addChip = find.widgetWithText(ActionChip, 'User-defined');
      await tester.ensureVisible(addChip);
      await tester.pumpAndSettle();
      await tester.tap(addChip);
      await tester.pump();
      container
          .read(userAyanamsasProvider.notifier)
          .update(container.read(userAyanamsasProvider).single.id, name: 'Tab');

      // Same container, the context bar's selector: it offers the tab's entry.
      await pumpInto(tester, container, const AyanamsaSelector());
      expect(find.text('Tab', skipOffstage: false), findsOneWidget);
    });

    testWidgets('one defined in the context bar is editable on the tab', (
      tester,
    ) async {
      final container = await sharedApp();

      // The context bar's "Add user-defined…" dialog, driven as the selector
      // drives it.
      await pumpInto(
        tester,
        container,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showUserAyanamsaDialog(context, ref),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name (optional)'),
        'From the context bar',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      // It is the Context's selection...
      final ctx = container.read(contextBarProvider);
      expect(ctx.ayanamsa, ayanamsaUserId);
      expect(ctx.userAyanId, container.read(userAyanamsasProvider).single.id);

      // ...and the tab renders an editor for it, by name.
      await pumpInto(tester, container, const AyanamsaTab());
      expect(find.byTooltip('Remove From the context bar'), findsOneWidget);
    });

    testWidgets('deleting the selected entry on the tab moves the Context', (
      tester,
    ) async {
      final container = await sharedApp();
      final id = container
          .read(userAyanamsasProvider.notifier)
          .add(name: 'Doomed');
      container.read(contextBarProvider.notifier).selectUserAyanamsa(id);

      await pumpInto(tester, container, const AyanamsaTab());
      await tester.tap(find.byTooltip('Remove Doomed'));
      await tester.pump();

      expect(container.read(userAyanamsasProvider), isEmpty);
      expect(
        container.read(contextBarProvider).ayanamsa,
        isNot(ayanamsaUserId),
      );
    });

    test('a restored selection with no entry behind it is reconciled', () async {
      // A store left mid-flight by an older build: the Context says 255 and
      // names an entry, the list does not have it. Nothing edits the list here,
      // so only reconciling at creation catches this.
      SharedPreferences.setMockInitialValues({
        'ctx_ayanamsa': ayanamsaUserId,
        'ctx_user_ayan_id': 7,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(contextBarProvider).ayanamsa,
        isNot(ayanamsaUserId),
      );
      // And the derived context never hands the engine 255 with no parameters.
      expect(
        container.read(effectiveContextProvider).ayanamsa,
        isNot(ayanamsaUserId),
      );
    });
  });

  test('the Ayanamsa catalog still carries the user-defined pseudo-mode', () {
    // The context bar renders user entries in its place, but the id is still
    // what the engine is configured with, and the tab still labels rows by it.
    expect(ayanamsaName(ayanamsaUserId), 'User-defined');
  });
}
