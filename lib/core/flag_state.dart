// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'swe_constants.dart';

import 'context_state.dart';

/// Immutable state for the flag bar.
///
/// Combines a mutually exclusive coordinate group selection with
/// a set of composable toggle flags. Also tracks auto-locked flags
/// driven by context bar settings (origin, zodiac, ephemeris source).
class FlagBarState {
  const FlagBarState({
    this.coordValue = 0,
    this.toggles = const {},
    this.lockedFlags = 0,
  });

  /// Active coordinate group value (0 = ecliptic, or one SEFLG_* constant).
  final int coordValue;

  /// Set of active composable toggle flag values.
  final Set<int> toggles;

  /// Flags auto-locked by context bar (origin, zodiac, ephemeris source).
  /// These are OR'd into the final iflag but cannot be toggled by the user.
  final int lockedFlags;

  /// Computed iflag for swe_calc_ut calls.
  int get iflag {
    int result = coordValue | lockedFlags;
    for (final t in toggles) {
      result |= t;
    }
    return result;
  }

  /// Hex display of the composed flag.
  String get hexDisplay => '0x${iflag.toRadixString(16).toUpperCase()}';

  FlagBarState copyWith({
    int? coordValue,
    Set<int>? toggles,
    int? lockedFlags,
  }) {
    return FlagBarState(
      coordValue: coordValue ?? this.coordValue,
      toggles: toggles ?? this.toggles,
      lockedFlags: lockedFlags ?? this.lockedFlags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlagBarState &&
          coordValue == other.coordValue &&
          toggles.length == other.toggles.length &&
          toggles.containsAll(other.toggles) &&
          lockedFlags == other.lockedFlags;

  @override
  int get hashCode => Object.hash(
    coordValue,
    Object.hashAll(toggles.toList()..sort()),
    lockedFlags,
  );

  /// Compute locked flags from context bar state.
  static int lockedFlagsFrom(ContextBarState ctx) {
    int locked = 0;

    // Zodiac reference
    if (ctx.zodiacRef == ZodiacRef.sidereal) {
      locked |= seFlgSidereal;
    }

    // Origin
    switch (ctx.origin) {
      case Origin.topocentric:
        locked |= seFlgTopoCtr;
      case Origin.heliocentric:
        locked |= seFlgHelCtr;
      case Origin.barycentric:
        locked |= seFlgBaryCtr;
      case Origin.geocentric:
        break;
    }

    // Equinox reference
    if (ctx.eqRef == EqRef.meanEquinox) {
      locked |= seFlgJ2000;
    }

    // Ephemeris source
    switch (ctx.epheSource) {
      case EpheSource.swissEph:
        locked |= seFlgSwiEph;
      case EpheSource.jpl:
        locked |= seFlgJplEph;
      case EpheSource.moshier:
        locked |= seFlgMosEph;
    }

    return locked;
  }
}
