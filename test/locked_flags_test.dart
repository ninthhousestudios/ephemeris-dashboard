// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/flag_state.dart';
import 'package:swe_dashboard/core/swe_constants.dart';

ContextBarState _ctx(EqRef eqRef) => ContextBarState(
  dateTime: DateTime.utc(2000),
  utcOffset: 0,
  jdUt: 0,
  eqRef: eqRef,
);

void main() {
  group('FlagBarState.lockedFlagsFrom — equinox reference', () {
    test('true equinox of date locks no equinox flag', () {
      final locked = FlagBarState.lockedFlagsFrom(
        _ctx(EqRef.trueEquinoxOfDate),
      );
      expect(locked & seFlgNoNut, 0);
      expect(locked & seFlgJ2000, 0);
    });

    test('mean equinox of date locks NONUT (not J2000)', () {
      final locked = FlagBarState.lockedFlagsFrom(
        _ctx(EqRef.meanEquinoxOfDate),
      );
      expect(locked & seFlgNoNut, seFlgNoNut);
      expect(locked & seFlgJ2000, 0);
    });

    test('mean equinox J2000 locks J2000 (not NONUT)', () {
      final locked = FlagBarState.lockedFlagsFrom(_ctx(EqRef.meanEquinoxJ2000));
      expect(locked & seFlgJ2000, seFlgJ2000);
      expect(locked & seFlgNoNut, 0);
    });
  });
}
