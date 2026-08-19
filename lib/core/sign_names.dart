// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayanamsa_catalog.dart';
import 'context_provider.dart';
import 'context_state.dart';
import 'display_format.dart';
import 'persistence.dart';
import 'pref_field.dart';
import 'swe_constants.dart';
import 'true_sidereal.dart';

/// How the 12 equal 30° signs are named when a longitude is rendered.
///
/// A pure *display* concern, sibling to [DisplayFormat]/[OutputClock]: it
/// relabels the division of an ecliptic longitude into a named sign plus the
/// in-sign degrees, and never touches the Context or a computation flag. All
/// equal-sign math is `lon mod 30`; no engine call is involved.
///
///   * [none]         — no sign name rendered.
///   * [zodiac]       — Aries…Pisces; valid in every frame (the fallback).
///   * [aditya]       — the 12 Aditya deities; tropical-only (see
///     [effectiveSchemeFor]).
///   * [trueSidereal] — passive display mode selectable only under a True
///     Sidereal Context; rendering is deferred to swe-dashboard/102, so it
///     produces no line here.
///   * [userDefined]  — one of the user's named 12-name sets ([UserSignSet]).
enum SignScheme {
  none('None'),
  zodiac('Zodiac'),
  aditya('Aditya'),
  trueSidereal('True Sidereal'),
  userDefined('User-defined');

  const SignScheme(this.label);
  final String label;

  /// Resolve by [Enum.name], falling back to [zodiac] for a value written by a
  /// build that has since renamed or removed the scheme.
  static SignScheme byName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return SignScheme.zodiac;
  }
}

/// The 12 tropical/sidereal signs, indexed by `floor(lon / 30)`.
const List<String> zodiacNames = [
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

/// The 12 Aditya deities, relabelling the same equal 30° tropical signs:
/// Aryama 0–30° … Dhata 330–360°. Indexed by `floor(lon / 30)`, like
/// [zodiacNames]. Gated tropical-only in [effectiveSchemeFor].
const List<String> adityaNames = [
  'Aryama',
  'Mitra',
  'Varuna',
  'Indra',
  'Vivasvan',
  'Tvashta',
  'Vishnu',
  'Amshu',
  'Bhaga',
  'Pusha',
  'Parjanya',
  'Dhata',
];

const Object _sentinel = Object();

/// One user-defined set of 12 sign names.
///
/// Mirrors [UserAyanamsa]: a single app-wide list, each entry an id + optional
/// label + the 12 names. Equal 30° divisions — the names are the only thing
/// that varies from the zodiac.
class UserSignSet {
  const UserSignSet({required this.id, this.name, required this.names});

  final int id;

  /// Optional user label. Null (or blank) falls back to "Sign set N", numbered
  /// by position — see [userSignSetLabel].
  final String? name;

  /// Exactly 12 names, index 0 = the 0–30° sign.
  final List<String> names;

  UserSignSet copyWith({Object? name = _sentinel, List<String>? names}) =>
      UserSignSet(
        id: id,
        name: identical(name, _sentinel) ? this.name : name as String?,
        names: names ?? this.names,
      );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'names': names};

  /// Null when the stored shape is unusable, so one bad entry is dropped rather
  /// than taking the whole list down. [names] must be exactly 12 strings.
  static UserSignSet? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! int) return null;
    final rawNames = json['names'];
    if (rawNames is! List || rawNames.length != 12) return null;
    final names = <String>[];
    for (final n in rawNames) {
      if (n is! String) return null;
      names.add(n);
    }
    final name = json['name'];
    return UserSignSet(
      id: id,
      name: name is String ? name : null,
      names: names,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSignSet &&
          id == other.id &&
          name == other.name &&
          _listEq(names, other.names);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(names));
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Display label for [entry] at [index]: its name if non-blank, else
/// "Sign set N" numbered from 1 by position.
String userSignSetLabel(UserSignSet entry, int index) {
  final name = entry.name?.trim();
  return (name == null || name.isEmpty) ? 'Sign set ${index + 1}' : name;
}

/// The entry [id] selects, or null when none matches.
UserSignSet? resolveUserSignSet(List<UserSignSet> sets, int? id) {
  for (final s in sets) {
    if (s.id == id) return s;
  }
  return null;
}

/// The global sign-name selection: a [SignScheme] plus, when it is
/// [SignScheme.userDefined], which [UserSignSet] by id. Persisted.
class SignNameSelection {
  const SignNameSelection({this.scheme = SignScheme.zodiac, this.userSetId});

  final SignScheme scheme;

  /// Which user set is selected, meaningful only when [scheme] is
  /// [SignScheme.userDefined].
  final int? userSetId;

  Map<String, Object?> toJson() => {
    'scheme': scheme.name,
    'userSetId': userSetId,
  };

  static SignNameSelection? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['userSetId'];
    return SignNameSelection(
      scheme: SignScheme.byName(json['scheme'] as String?),
      userSetId: id is int ? id : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignNameSelection &&
          scheme == other.scheme &&
          userSetId == other.userSetId;

  @override
  int get hashCode => Object.hash(scheme, userSetId);
}

// ── Pure sign math ────────────────────────────────────────────────────

double _norm360(double lon) {
  final n = lon % 360;
  return n < 0 ? n + 360 : n;
}

/// The sign index `floor(lon / 30)` in `[0, 12)`, wrap-safe for any [lon].
int signIndex(double lon) => (_norm360(lon) ~/ 30) % 12;

/// The longitude within its sign, in `[0, 30)`.
double inSignLongitude(double lon) => _norm360(lon) % 30;

/// The named-sign placement of [lon]: the sign/constellation name and the
/// longitude within it. Null when the scheme renders no name ([SignScheme.none])
/// or when a [SignScheme.trueSidereal] selection has no [binning] available (out
/// of the True Sidereal frame, or a boundary star failed to resolve).
///
/// The single primitive behind [signNameFor], [inSignLongitudeFor] and
/// [inSignField], so the rendered name, its in-sign degrees and their raw value
/// can never disagree. For the equal-sign schemes the in-sign value is
/// `lon mod 30`; for True Sidereal it is the degrees from the constellation's
/// (unequal) start boundary.
({String name, double inSign})? signPlacement(
  double lon,
  SignScheme scheme,
  UserSignSet? set,
  TrueSiderealBinning? binning,
) {
  final i = signIndex(lon);
  switch (scheme) {
    case SignScheme.none:
      return null;
    case SignScheme.zodiac:
      return (name: zodiacNames[i], inSign: inSignLongitude(lon));
    case SignScheme.aditya:
      return (name: adityaNames[i], inSign: inSignLongitude(lon));
    case SignScheme.userDefined:
      final names = set?.names;
      final name = (names != null && names.length == 12)
          ? names[i]
          : zodiacNames[i];
      return (name: name, inSign: inSignLongitude(lon));
    case SignScheme.trueSidereal:
      if (binning == null || !lon.isFinite) return null;
      final p = binning.placementAt(lon);
      return (name: p.name, inSign: p.inSign);
  }
}

/// The sign name for [lon] under [scheme], or null when no name renders — see
/// [signPlacement].
String? signNameFor(
  double lon,
  SignScheme scheme,
  UserSignSet? set,
  TrueSiderealBinning? binning,
) => signPlacement(lon, scheme, set, binning)?.name;

/// The in-sign longitude to store as a field's raw value: `lon mod 30` for the
/// equal-sign schemes, or the degrees into the (unequal) constellation for True
/// Sidereal. Falls back to `lon mod 30` when no True Sidereal binning is
/// available, matching what [inSignField] renders.
double inSignLongitudeFor(
  double lon,
  SignScheme scheme,
  TrueSiderealBinning? binning,
) {
  if (scheme == SignScheme.trueSidereal && binning != null && lon.isFinite) {
    return binning.placementAt(lon).inSign;
  }
  return inSignLongitude(lon);
}

/// The `(label, formatted value)` for the In-Sign Longitude line, or null when
/// it should not render: the scheme is off, the coordinate is not ecliptic
/// (equatorial RA/Dec or cartesian XYZ), or [lon] is non-finite.
///
/// The single insertion primitive: card builders wrap the tuple in a
/// `ResultField` (with [inSignLongitude] as the raw value), export builders
/// splice the tuple straight in. Keeping it a plain tuple keeps this core file
/// free of any widget dependency.
(String, String)? inSignField(
  double lon,
  int coordValue,
  SignScheme scheme,
  UserSignSet? set,
  DisplayFormat fmt,
  TrueSiderealBinning? binning,
) {
  if ((coordValue & seFlgEquatorial) != 0 || (coordValue & seFlgXyz) != 0) {
    return null;
  }
  if (!lon.isFinite) return null;
  final p = signPlacement(lon, scheme, set, binning);
  if (p == null) return null;
  return ('In-Sign Longitude', '${formatAngle(p.inSign, fmt)} ${p.name}');
}

/// The scheme that actually renders under [ctx], reconciling a selection the
/// Context no longer supports down to [SignScheme.zodiac] (valid in every
/// frame). Pure function of the Context — no remembered per-frame state.
///
///   * [SignScheme.aditya] needs a tropical zodiac.
///   * [SignScheme.trueSidereal] needs a sidereal zodiac on the True Sidereal
///     ayanamsha ([ayanamsaTrueSiderealId]); it is otherwise unreachable. Its
///     runtime binning comes from [trueSiderealBinningProvider].
SignScheme effectiveSchemeFor(SignNameSelection sel, ContextBarState ctx) {
  switch (sel.scheme) {
    case SignScheme.none:
    case SignScheme.zodiac:
    case SignScheme.userDefined:
      return sel.scheme;
    case SignScheme.aditya:
      return ctx.zodiacRef == ZodiacRef.tropical
          ? SignScheme.aditya
          : SignScheme.zodiac;
    case SignScheme.trueSidereal:
      final ok =
          ctx.zodiacRef == ZodiacRef.sidereal &&
          ctx.ayanamsa == ayanamsaTrueSiderealId;
      return ok ? SignScheme.trueSidereal : SignScheme.zodiac;
  }
}

/// The scheme + resolved user set + True Sidereal binning to render with for
/// the current Context.
typedef ResolvedSignNames = ({
  SignScheme scheme,
  UserSignSet? set,
  TrueSiderealBinning? binning,
});

/// The one thing tabs watch: the effective [SignScheme] (reconciled against the
/// Context), the resolved [UserSignSet] for [SignScheme.userDefined], and the
/// runtime [TrueSiderealBinning] for [SignScheme.trueSidereal] (null when a
/// boundary star failed — cards then render no in-sign line and the selector
/// surfaces the error).
final resolvedSignNamesProvider = Provider<ResolvedSignNames>((ref) {
  final sel = ref.watch(signNameSelectionProvider);
  final ctx = ref.watch(contextBarProvider);
  final scheme = effectiveSchemeFor(sel, ctx);
  final set = scheme == SignScheme.userDefined
      ? resolveUserSignSet(ref.watch(userSignSetsProvider), sel.userSetId)
      : null;
  final binning = scheme == SignScheme.trueSidereal
      ? ref.watch(trueSiderealBinningProvider).binning
      : null;
  return (scheme: scheme, set: set, binning: binning);
});

// ── Persistence ───────────────────────────────────────────────────────

/// The user-set list, stored as one JSON array (like [UserAyanamsa]).
class UserSignSetListPrefCodec extends PrefCodec<List<UserSignSet>> {
  const UserSignSetListPrefCodec();

  @override
  void write(SharedPreferences prefs, String key, List<UserSignSet> value) =>
      prefs.setString(key, jsonEncode([for (final s in value) s.toJson()]));

  @override
  List<UserSignSet>? read(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! List) return null;
    return [for (final e in decoded) ?UserSignSet.fromJson(e)];
  }
}

/// The selection, stored as a single JSON object.
class SignNameSelectionPrefCodec extends PrefCodec<SignNameSelection> {
  const SignNameSelectionPrefCodec();

  @override
  void write(SharedPreferences prefs, String key, SignNameSelection value) =>
      prefs.setString(key, jsonEncode(value.toJson()));

  @override
  SignNameSelection? read(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    return SignNameSelection.fromJson(decoded);
  }
}

const userSignSetListPref = UserSignSetListPrefCodec();
const userSignSetsPrefKey = 'user_sign_sets';
const signNameSelectionPref = SignNameSelectionPrefCodec();
const signNameSelectionPrefKey = 'sign_name_selection';

// ── Notifiers + providers ─────────────────────────────────────────────

/// The app-wide list of user-defined sign-name sets. [onChanged] fires after
/// every mutation, so the provider can persist; left null in tests.
class UserSignSetNotifier extends StateNotifier<List<UserSignSet>> {
  UserSignSetNotifier({List<UserSignSet> initial = const [], this.onChanged})
    : _nextId = initial.fold(0, (m, s) => s.id >= m ? s.id + 1 : m),
      super(initial);

  final void Function(List<UserSignSet> entries)? onChanged;

  int _nextId;

  void _emit(List<UserSignSet> next) {
    state = next;
    onChanged?.call(next);
  }

  /// Append a set and return its id, so a caller that also selects it does not
  /// have to guess which one it is.
  int add({String? name, required List<String> names}) {
    final id = _nextId++;
    _emit([...state, UserSignSet(id: id, name: name, names: names)]);
    return id;
  }

  void removeById(int id) {
    _emit(state.where((s) => s.id != id).toList());
  }

  void update(int id, {Object? name = _sentinel, List<String>? names}) {
    _emit([
      for (final s in state)
        if (s.id == id) s.copyWith(name: name, names: names) else s,
    ]);
  }
}

/// User-defined sign-name sets, shared app-wide. Owns the entries; the
/// selection reconciles against this list from [signNameSelectionProvider].
final userSignSetsProvider =
    StateNotifierProvider<UserSignSetNotifier, List<UserSignSet>>((ref) {
      final persistence = ref.watch(persistenceProvider);
      return UserSignSetNotifier(
        initial:
            persistence.loadValue(userSignSetListPref, userSignSetsPrefKey) ??
            const [],
        onChanged: (entries) => persistence.saveValue(
          userSignSetListPref,
          userSignSetsPrefKey,
          entries,
        ),
      );
    });

/// The global sign-name selection. Persisted, and reconciled to Zodiac when the
/// selected user set is removed.
class SignNameSelectionNotifier extends StateNotifier<SignNameSelection> {
  SignNameSelectionNotifier({
    required SignNameSelection initial,
    this.onChanged,
  }) : super(initial);

  final void Function(SignNameSelection selection)? onChanged;

  void _emit(SignNameSelection next) {
    state = next;
    onChanged?.call(next);
  }

  void selectScheme(SignScheme scheme) =>
      _emit(SignNameSelection(scheme: scheme));

  void selectUserSet(int id) =>
      _emit(SignNameSelection(scheme: SignScheme.userDefined, userSetId: id));

  /// The selected user set was removed: fall back to Zodiac (a name mode valid
  /// in every frame), rather than dangle a selection with no set behind it.
  void reconcile(List<int> setIds) {
    if (state.scheme != SignScheme.userDefined) return;
    if (setIds.contains(state.userSetId)) return;
    _emit(const SignNameSelection(scheme: SignScheme.zodiac));
  }
}

final signNameSelectionProvider =
    StateNotifierProvider<SignNameSelectionNotifier, SignNameSelection>((ref) {
      final persistence = ref.watch(persistenceProvider);
      final notifier = SignNameSelectionNotifier(
        initial:
            persistence.loadValue(
              signNameSelectionPref,
              signNameSelectionPrefKey,
            ) ??
            const SignNameSelection(),
        onChanged: (selection) => persistence.saveValue(
          signNameSelectionPref,
          signNameSelectionPrefKey,
          selection,
        ),
      );

      // Mirror the Context/ayanamsa reconcile: the selection holds an id into a
      // list it does not own, so a removed set moves the selection back to
      // Zodiac instead of dangling it.
      void reconcile(List<UserSignSet> sets) =>
          notifier.reconcile([for (final s in sets) s.id]);
      reconcile(ref.read(userSignSetsProvider));
      ref.listen<List<UserSignSet>>(
        userSignSetsProvider,
        (_, sets) => reconcile(sets),
      );

      return notifier;
    });
