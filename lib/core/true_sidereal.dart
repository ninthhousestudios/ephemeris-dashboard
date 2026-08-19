// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayanamsa_catalog.dart';
import 'calc_context.dart';
import 'context_provider.dart';
import 'context_state.dart';
import 'ephemeris/runner.dart';
import 'flag_provider.dart';
import 'persistence.dart';
import 'pref_field.dart';
import 'swe_constants.dart';

/// The True Sidereal zodiac: 13 constellations of *unequal* width, their
/// boundaries computed at runtime from the ecliptic longitudes of edge
/// ("boundary") stars at the chart date — so they precess with the stars.
///
/// This is Chimenti's Midpoint Method (see
/// `../../../arjuna/arrow/docs/true-sidereal-method.md`), ported from Arrow's
/// `calc/lib/src/zodiac/`. Where the equal-sign schemes in `sign_names.dart`
/// are pure `lon mod 30` relabellings, this one needs the engine: it reads 26
/// boundary stars each recompute. A body's constellation and its numeric
/// sidereal longitude therefore will *not* line up with `lon / 30` — that is
/// correct, not a bug.
///
/// A "set" is a full boundary-star assignment (which catalog star is each
/// constellation's first/last edge) plus editable constellation names; the app
/// keeps a persisted list and one active id, mirroring `UserSignSet` /
/// `UserAyanamsa`. The default set is Chimenti's 26 stars.

const Object _sentinel = Object();

/// One constellation in a [TrueSiderealSet]: an editable display [name] and the
/// two edge stars that bound it. [firstStar]/[lastStar] are search terms for
/// [Ephemeris.fixstar2Ut] — a common name (`Mesarthim`) or a leading-comma
/// Bayer/Flamsteed designation (`,gamAri`, `,62Sgr`).
///
/// "First" is the lower-ecliptic-longitude edge, "last" the higher; a
/// constellation's start boundary is the midpoint of the previous
/// constellation's [lastStar] and this one's [firstStar].
class TrueSiderealConstellation {
  const TrueSiderealConstellation({
    required this.name,
    required this.firstStar,
    required this.lastStar,
  });

  final String name;
  final String firstStar;
  final String lastStar;

  TrueSiderealConstellation copyWith({
    String? name,
    String? firstStar,
    String? lastStar,
  }) => TrueSiderealConstellation(
    name: name ?? this.name,
    firstStar: firstStar ?? this.firstStar,
    lastStar: lastStar ?? this.lastStar,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'first': firstStar,
    'last': lastStar,
  };

  static TrueSiderealConstellation? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final first = json['first'];
    final last = json['last'];
    if (name is! String || first is! String || last is! String) return null;
    return TrueSiderealConstellation(
      name: name,
      firstStar: first,
      lastStar: last,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrueSiderealConstellation &&
          name == other.name &&
          firstStar == other.firstStar &&
          lastStar == other.lastStar;

  @override
  int get hashCode => Object.hash(name, firstStar, lastStar);
}

/// One user-defined True Sidereal set: an optional [name] plus exactly 13
/// [constellations] in ecliptic order (Aries first, Ophiuchus between Scorpius
/// and Sagittarius, Pisces last). Mirrors [UserSignSet] — a single app-wide
/// list, each entry an id + label + payload.
class TrueSiderealSet {
  const TrueSiderealSet({
    required this.id,
    this.name,
    required this.constellations,
  });

  final int id;

  /// Optional user label. Null (or blank) falls back to "True Sidereal set N",
  /// numbered by position — see [trueSiderealSetLabel].
  final String? name;

  /// Exactly 13 constellations, in ecliptic order.
  final List<TrueSiderealConstellation> constellations;

  TrueSiderealSet copyWith({
    Object? name = _sentinel,
    List<TrueSiderealConstellation>? constellations,
  }) => TrueSiderealSet(
    id: id,
    name: identical(name, _sentinel) ? this.name : name as String?,
    constellations: constellations ?? this.constellations,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'constellations': [for (final c in constellations) c.toJson()],
  };

  /// Null when the stored shape is unusable, so one bad entry is dropped rather
  /// than taking the whole list down. [constellations] must be exactly 13.
  static TrueSiderealSet? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! int) return null;
    final raw = json['constellations'];
    if (raw is! List || raw.length != 13) return null;
    final constellations = <TrueSiderealConstellation>[];
    for (final c in raw) {
      final parsed = TrueSiderealConstellation.fromJson(c);
      if (parsed == null) return null;
      constellations.add(parsed);
    }
    final name = json['name'];
    return TrueSiderealSet(
      id: id,
      name: name is String ? name : null,
      constellations: constellations,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrueSiderealSet &&
          id == other.id &&
          name == other.name &&
          _listEq(constellations, other.constellations);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(constellations));
}

bool _listEq(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Display label for [entry] at [index]: its name if non-blank, else
/// "True Sidereal set N" numbered from 1 by position.
String trueSiderealSetLabel(TrueSiderealSet entry, int index) {
  final name = entry.name?.trim();
  return (name == null || name.isEmpty)
      ? 'True Sidereal set ${index + 1}'
      : name;
}

/// The entry [id] selects, falling back to the first set (so there is always an
/// active set while any exist), or null when the list is empty.
TrueSiderealSet? resolveTrueSiderealSet(List<TrueSiderealSet> sets, int? id) {
  for (final s in sets) {
    if (s.id == id) return s;
  }
  return sets.isEmpty ? null : sets.first;
}

// ── The Chimenti default (26 stars) ───────────────────────────────────

/// Chimenti's 13 edge-star pairs, keyed by constellation name, as leading-comma
/// Bayer/Flamsteed designations resolvable against `sefstars.txt`. The values
/// (star identities) are facts from the Midpoint Method paper — see the doc.
///
/// Note 62 Sagittarii (`,62Sgr`) and Algedi α² Cap (`,alf02Cap`), the two edges
/// feeding the Sagittarius→Capricornus boundary, which are the ones easy to get
/// wrong. Both are present in this app's bundled catalog.
const _chimentiConstellations = <TrueSiderealConstellation>[
  TrueSiderealConstellation(
    name: 'Aries',
    firstStar: ',gamAri', // Mesarthim
    lastStar: ',delAri', // Botein
  ),
  TrueSiderealConstellation(
    name: 'Taurus',
    firstStar: ',omiTau', // Omicron Tauri
    lastStar: ',zetTau', // Tianguan
  ),
  TrueSiderealConstellation(
    name: 'Gemini',
    firstStar: ',1Gem', // 1 Geminorum
    lastStar: ',kapGem', // Kappa Geminorum
  ),
  TrueSiderealConstellation(
    name: 'Cancer',
    firstStar: ',chiCnc', // Chi Cancri
    lastStar: ',alfCnc', // Acubens
  ),
  TrueSiderealConstellation(
    name: 'Leo',
    firstStar: ',kapLeo', // Al Minliar / Kappa Leonis
    lastStar: ',betLeo', // Denebola
  ),
  TrueSiderealConstellation(
    name: 'Virgo',
    firstStar: ',nu.Vir', // Nu Virginis
    lastStar: ',mu.Vir', // Rijl al Awwa / Mu Virginis
  ),
  TrueSiderealConstellation(
    name: 'Libra',
    firstStar: ',alf02Lib', // Zubenelgenubi
    lastStar: ',48Lib', // 48 Librae
  ),
  TrueSiderealConstellation(
    name: 'Scorpius',
    firstStar: ',delSco', // Dschubba
    lastStar: ',tauSco', // Paikauhale
  ),
  TrueSiderealConstellation(
    name: 'Ophiuchus',
    firstStar: ',etaOph', // Sabik
    lastStar: ',45Oph', // 45 Ophiuchi
  ),
  TrueSiderealConstellation(
    name: 'Sagittarius',
    firstStar: ',gamSgr', // Alnasl / Nash
    lastStar: ',62Sgr', // 62 Sagittarii
  ),
  TrueSiderealConstellation(
    name: 'Capricornus',
    firstStar: ',alf02Cap', // Algedi (α² Cap)
    lastStar: ',delCap', // Deneb Algedi
  ),
  TrueSiderealConstellation(
    name: 'Aquarius',
    firstStar: ',iotAqr', // Iota Aquarii
    lastStar: ',phiAqr', // Phi Aquarii
  ),
  TrueSiderealConstellation(
    name: 'Pisces',
    firstStar: ',gamPsc', // Gamma Piscium
    lastStar: ',alfPsc', // Alrescha
  ),
];

/// A fresh Chimenti default set with the given [id].
TrueSiderealSet defaultTrueSiderealSet({int id = 0}) => TrueSiderealSet(
  id: id,
  name: 'Chimenti',
  constellations: _chimentiConstellations,
);

// ── Pure binning (midpoint method) ────────────────────────────────────

double _norm360(double lon) {
  final n = lon % 360;
  return n < 0 ? n + 360 : n;
}

/// A boundary star named by a set could not be resolved / fed a longitude when
/// building the binning. Carries the offending [starName] so the UI can name it.
class MissingBoundaryStarException implements Exception {
  const MissingBoundaryStarException(this.starName);
  final String starName;

  @override
  String toString() => 'Boundary star not found: $starName';
}

/// The 13 constellation boundaries for one chart, resolved from boundary-star
/// longitudes. Immutable and pure — no engine handle.
///
/// [boundaries] `[i]` is the *start* ecliptic longitude of constellation
/// [names]`[i]`, in `[0, 360)`, ecliptic order. The span of constellation `i`
/// runs to `boundaries[(i+1) % 13]`, wrapping once (Pisces→Aries) across 0°.
class TrueSiderealBinning {
  const TrueSiderealBinning._(this.names, this.boundaries);

  final List<String> names;
  final List<double> boundaries;

  /// The placement of [lon]: the constellation containing it and the degrees
  /// from that constellation's start boundary (`>= 0`, `< its width`).
  ({String name, double inSign}) placementAt(double lon) {
    final l = _norm360(lon);
    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i];
      final end = boundaries[(i + 1) % boundaries.length];
      final contains = start < end
          ? (l >= start && l < end)
          : (l >= start || l < end); // wraps 0°
      if (contains) {
        return (name: names[i], inSign: (l - start + 360) % 360);
      }
    }
    // Coverage is a full partition of the circle, so this is unreachable unless
    // boundaries degenerate; fall back to the first constellation rather than
    // throw from a display path.
    return (name: names.first, inSign: (l - boundaries.first + 360) % 360);
  }

  /// Build a binning from a [set] and a map of boundary-star search term to its
  /// ecliptic longitude (in the same sidereal frame the bodies are rendered).
  ///
  /// Throws [MissingBoundaryStarException] when a needed star is absent from
  /// [starLongitudes] or its longitude is non-finite.
  static TrueSiderealBinning build(
    TrueSiderealSet set,
    Map<String, double> starLongitudes,
  ) {
    double lonOf(String star) {
      final lon = starLongitudes[star];
      if (lon == null || !lon.isFinite) {
        throw MissingBoundaryStarException(star);
      }
      return _norm360(lon);
    }

    final cons = set.constellations;
    final n = cons.length;

    // midpoints[i] = start of constellation (i+1): midpoint of constellation
    // i's last star and constellation (i+1)'s first star, wrap-safe. The last
    // entry (Pisces→Aries) is the start of Aries.
    final rotated = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final lastLon = lonOf(cons[i].lastStar);
      final firstLon = lonOf(cons[(i + 1) % n].firstStar);
      final gap = (firstLon - lastLon + 360) % 360;
      final midpoint = (lastLon + gap / 2) % 360;
      // This midpoint starts constellation (i+1); the Pisces→Aries one (i=n-1)
      // starts constellation 0.
      rotated[(i + 1) % n] = midpoint;
    }

    return TrueSiderealBinning._([for (final c in cons) c.name], rotated);
  }
}

// ── Persistence ───────────────────────────────────────────────────────

/// The set list, stored as one JSON array (like [UserSignSet]).
class TrueSiderealSetListPrefCodec extends PrefCodec<List<TrueSiderealSet>> {
  const TrueSiderealSetListPrefCodec();

  @override
  void write(
    SharedPreferences prefs,
    String key,
    List<TrueSiderealSet> value,
  ) => prefs.setString(key, jsonEncode([for (final s in value) s.toJson()]));

  @override
  List<TrueSiderealSet>? read(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! List) return null;
    return [for (final e in decoded) ?TrueSiderealSet.fromJson(e)];
  }
}

const trueSiderealSetListPref = TrueSiderealSetListPrefCodec();
const trueSiderealSetsPrefKey = 'true_sidereal_sets';
const activeTrueSiderealSetIdPrefKey = 'active_true_sidereal_set_id';

// ── Notifiers + providers ─────────────────────────────────────────────

/// The app-wide list of True Sidereal sets. [onChanged] fires after every
/// mutation so the provider can persist; left null in tests. Mirrors
/// [UserSignSetNotifier].
class TrueSiderealSetNotifier extends StateNotifier<List<TrueSiderealSet>> {
  TrueSiderealSetNotifier({
    List<TrueSiderealSet> initial = const [],
    this.onChanged,
  }) : _nextId = initial.fold(0, (m, s) => s.id >= m ? s.id + 1 : m),
       super(initial);

  final void Function(List<TrueSiderealSet> entries)? onChanged;

  int _nextId;

  void _emit(List<TrueSiderealSet> next) {
    state = next;
    onChanged?.call(next);
  }

  /// Append a set and return its id, so a caller that also selects it does not
  /// have to guess which one it is.
  int add({
    String? name,
    required List<TrueSiderealConstellation> constellations,
  }) {
    final id = _nextId++;
    _emit([
      ...state,
      TrueSiderealSet(id: id, name: name, constellations: constellations),
    ]);
    return id;
  }

  void removeById(int id) => _emit(state.where((s) => s.id != id).toList());

  void update(
    int id, {
    Object? name = _sentinel,
    List<TrueSiderealConstellation>? constellations,
  }) {
    _emit([
      for (final s in state)
        if (s.id == id)
          s.copyWith(name: name, constellations: constellations)
        else
          s,
    ]);
  }
}

/// True Sidereal sets, shared app-wide. Seeded with the Chimenti default so
/// there is always at least one set (and one to fall back to). Owns the entries;
/// the active id reconciles against this list.
final userTrueSiderealSetsProvider =
    StateNotifierProvider<TrueSiderealSetNotifier, List<TrueSiderealSet>>((
      ref,
    ) {
      final persistence = ref.watch(persistenceProvider);
      final stored = persistence.loadValue(
        trueSiderealSetListPref,
        trueSiderealSetsPrefKey,
      );
      return TrueSiderealSetNotifier(
        initial: (stored == null || stored.isEmpty)
            ? [defaultTrueSiderealSet()]
            : stored,
        onChanged: (entries) => persistence.saveValue(
          trueSiderealSetListPref,
          trueSiderealSetsPrefKey,
          entries,
        ),
      );
    });

/// Which True Sidereal set is active, by id. Null resolves to the first set
/// (see [resolveTrueSiderealSet]). Persisted.
class ActiveTrueSiderealSetNotifier extends StateNotifier<int?> {
  ActiveTrueSiderealSetNotifier({int? initial, this.onChanged})
    : super(initial);

  final void Function(int? id)? onChanged;

  void select(int id) {
    state = id;
    onChanged?.call(id);
  }

  /// The active set was removed: drop to null so [resolveTrueSiderealSet] falls
  /// back to the first remaining set rather than dangling a dead id.
  void reconcile(List<int> setIds) {
    if (state == null) return;
    if (setIds.contains(state)) return;
    state = null;
    onChanged?.call(null);
  }
}

final activeTrueSiderealSetIdProvider =
    StateNotifierProvider<ActiveTrueSiderealSetNotifier, int?>((ref) {
      final persistence = ref.watch(persistenceProvider);
      final notifier = ActiveTrueSiderealSetNotifier(
        initial: persistence.loadValue(intPref, activeTrueSiderealSetIdPrefKey),
        // Only a real id is written; a reconcile-to-null leaves the stale id in
        // the store, which resolveTrueSiderealSet harmlessly falls back from.
        onChanged: (id) {
          if (id != null) {
            persistence.saveValue(intPref, activeTrueSiderealSetIdPrefKey, id);
          }
        },
      );

      void reconcile(List<TrueSiderealSet> sets) =>
          notifier.reconcile([for (final s in sets) s.id]);
      reconcile(ref.read(userTrueSiderealSetsProvider));
      ref.listen<List<TrueSiderealSet>>(
        userTrueSiderealSetsProvider,
        (_, sets) => reconcile(sets),
      );

      return notifier;
    });

/// The resolved active set — the entry the id selects, or the first set.
final activeTrueSiderealSetProvider = Provider<TrueSiderealSet?>((ref) {
  final sets = ref.watch(userTrueSiderealSetsProvider);
  final id = ref.watch(activeTrueSiderealSetIdProvider);
  return resolveTrueSiderealSet(sets, id);
});

/// The binning for the current Context, or a graceful error, or neither.
///
/// `binning` is null and `error` null when the Context is not in the True
/// Sidereal frame (the only frame the mode renders in — see
/// `effectiveSchemeFor`). `error` is a human message when a boundary star could
/// not be resolved. Both fields are never non-null together.
typedef TrueSiderealBinningState = ({
  TrueSiderealBinning? binning,
  String? error,
});

/// Computes the [TrueSiderealBinning] at the Context Moment by reading each
/// boundary star's ecliptic longitude in the active sidereal frame.
///
/// Gated on the True Sidereal frame (Zodiac: Sidereal + Ayanamsa: True
/// Sidereal), so it does the 26 engine calls only when they could matter. Uses
/// the Context Moment; in a series the boundaries precess between steps, but
/// that drift is sub-degree over ordinary spans and the card/copy/export of the
/// Context Moment itself is exact.
final trueSiderealBinningProvider = Provider<TrueSiderealBinningState>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final active =
      ctx.zodiacRef == ZodiacRef.sidereal &&
      ctx.ayanamsa == ayanamsaTrueSiderealId;
  if (!active) return (binning: null, error: null);

  final set = ref.watch(activeTrueSiderealSetProvider);
  if (set == null) return (binning: null, error: null);

  final runner = ref.watch(ephemerisRunnerProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final jdUt = ref.watch(effectiveContextProvider.select((c) => c.jdUt));
  // Ecliptic longitude in the active sidereal frame: strip any XYZ/equatorial
  // coordinate toggle (the binning is longitude-only; the in-sign line does not
  // render under those coordinates anyway).
  final iflag = ref.watch(flagBarProvider).iflag & ~seFlgXyz & ~seFlgEquatorial;

  try {
    runner.apply(globals);
    final lons = <String, double>{};
    // Every unique edge star, fetched once.
    final wanted = <String>{
      for (final c in set.constellations) ...[c.firstStar, c.lastStar],
    };
    for (final star in wanted) {
      final term = star.trim();
      final double lon;
      try {
        final r = runner.eph.fixstar2Ut(term, jdUt, iflag);
        lon = r.longitude;
      } on SweException {
        return (binning: null, error: 'Boundary star not found: $star');
      }
      if (!lon.isFinite) {
        return (binning: null, error: 'Boundary star not found: $star');
      }
      lons[star] = lon;
    }
    return (binning: TrueSiderealBinning.build(set, lons), error: null);
  } on MissingBoundaryStarException catch (e) {
    return (binning: null, error: 'Boundary star not found: ${e.starName}');
  } on SweException catch (e) {
    return (binning: null, error: e.message);
  }
});
