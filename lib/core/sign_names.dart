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
///   * [humanDesign]   — the Human Design gate/line/color/tone/base subdivision
///     of the ecliptic. Not a 12-sign relabelling at all: gate 1 is anchored to
///     13°15′ of Scorpio (longitude 223°15′ within the frame), so it is valid in
///     every ecliptic frame — sidereal shifts the longitudes but the gate
///     boundaries shift with them. Renders a multi-line In-Sign Longitude field
///     rather than a single sign name (see [humanDesignPlacement], [inSignField]).
///   * [userDefined]  — one of the user's named 12-name sets ([UserSignSet]).
enum SignScheme {
  none('None'),
  zodiac('Zodiac'),
  aditya('Aditya'),
  trueSidereal('True Sidereal'),
  humanDesign('Human Design'),
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

// ── Human Design subdivision ──────────────────────────────────────────
//
// Ported from libaditya's YiLongitude (hd/longitude.py, hd/constants.py). The
// ecliptic is divided into 64 gates in a fixed wheel order starting at
// [_hdGateOne]; each gate splits into 6 lines, each line into 6 colors, each
// color into 6 tones, each tone into 5 bases. Gate 1 is anchored at 13°15′ of
// Scorpio — longitude 223°15′ within the frame — so the scheme works in any
// ecliptic frame (sidereal shifts every longitude, but the gate boundaries move
// with it); see [effectiveSchemeFor].

/// The in-frame ecliptic longitude of the start of Human Design gate 1: 223°15′
/// (13°15′ of Scorpio).
const double _hdGateOne = 223 + 1 / 4;

/// Angular sizes of each subdivision, in degrees. `gate = 360/64`; each level
/// below divides the one above (lines/6, colors/6, tones/6, bases/5).
const double _hdGate = 360 / 64;
const double _hdLine = _hdGate / 6;
const double _hdColor = _hdLine / 6;
const double _hdTone = _hdColor / 6;
const double _hdBase = _hdTone / 5;

/// The 64 gates in wheel order along the ecliptic, gate 1 first at [_hdGateOne].
const List<int> _hdWheel = [
  1, 43, 14, 34, 9, 5, 26, 11, 10, 58, 38, 54, 61, 60, 41, 19, //
  13, 49, 30, 55, 37, 63, 22, 36, 25, 17, 21, 51, 42, 3, 27, 24, //
  2, 23, 8, 20, 16, 35, 45, 12, 15, 52, 39, 53, 62, 56, 31, 33, //
  7, 4, 29, 59, 40, 64, 47, 6, 46, 18, 48, 57, 32, 50, 28, 44, //
];

/// A Human Design placement: the gate/line/color/tone/base a longitude falls in
/// (each 1-based), plus, for each level, the longitude *into* that subdivision
/// and how far through it that is as a percentage. Mirrors the `*_in_longitude`
/// / `*_elapsed` accessors of libaditya's HDLongitude.
typedef HumanDesignPlacement = ({
  int gate,
  int line,
  int color,
  int tone,
  int base,
  double gateInLon,
  double lineInLon,
  double colorInLon,
  double toneInLon,
  double baseInLon,
  double gateElapsed,
  double lineElapsed,
  double colorElapsed,
  double toneElapsed,
  double baseElapsed,
});

/// The Human Design placement of [lon]. Wrap-safe for any finite [lon].
HumanDesignPlacement humanDesignPlacement(double lon) {
  final dist = _norm360(lon - _hdGateOne);

  // Total whole bases from gate 1, decomposed level by level (base 1–5; line,
  // color, tone 1–6) exactly as YiLongitude.init_gate does with divmod.
  final totalBases = (dist / _hdBase).floor();
  final tones = totalBases ~/ 5;
  final base = totalBases % 5 + 1;
  final colors = tones ~/ 6;
  final tone = tones % 6 + 1;
  final lines = colors ~/ 6;
  final color = colors % 6 + 1;
  final gatesFrom = lines ~/ 6;
  final line = lines % 6 + 1;
  final gate = _hdWheel[gatesFrom];

  final gateInLon = _norm360(lon - (_hdGateOne + _hdGate * gatesFrom));
  final lineInLon = gateInLon - _hdLine * (line - 1);
  final colorInLon = lineInLon - _hdColor * (color - 1);
  final toneInLon = colorInLon - _hdTone * (tone - 1);
  final baseInLon = toneInLon - _hdBase * (base - 1);

  return (
    gate: gate,
    line: line,
    color: color,
    tone: tone,
    base: base,
    gateInLon: gateInLon,
    lineInLon: lineInLon,
    colorInLon: colorInLon,
    toneInLon: toneInLon,
    baseInLon: baseInLon,
    gateElapsed: gateInLon / _hdGate * 100,
    lineElapsed: lineInLon / _hdLine * 100,
    colorElapsed: colorInLon / _hdColor * 100,
    toneElapsed: toneInLon / _hdTone * 100,
    baseElapsed: baseInLon / _hdBase * 100,
  );
}

/// The multi-line In-Sign Longitude value for the Human Design scheme: one line
/// per level (gate, line, color, tone, base), each formatted as
/// `IN_LONGITUDE LEVEL N; ELAPSED% elapsed`. [fmt] governs the angle rendering
/// like every other In-Sign Longitude value.
String humanDesignInSign(double lon, DisplayFormat fmt) {
  final p = humanDesignPlacement(lon);
  String pct(double v) => '${v.toStringAsFixed(2)}%';
  return [
    '${formatAngle(p.gateInLon, fmt)} gate ${p.gate}; ${pct(p.gateElapsed)} elapsed',
    '${formatAngle(p.lineInLon, fmt)} line ${p.line}; ${pct(p.lineElapsed)} elapsed',
    '${formatAngle(p.colorInLon, fmt)} color ${p.color}; ${pct(p.colorElapsed)} elapsed',
    '${formatAngle(p.toneInLon, fmt)} tone ${p.tone}; ${pct(p.toneElapsed)} elapsed',
    '${formatAngle(p.baseInLon, fmt)} base ${p.base}; ${pct(p.baseElapsed)} elapsed',
  ].join('\n');
}

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
    case SignScheme.humanDesign:
      // Human Design has no single sign name or in-sign value — it renders a
      // multi-line field ([humanDesignInSign]). [inSignField] handles it before
      // reaching here, so this primitive (and the unused [signNameFor]) yield
      // nothing for it.
      return null;
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
  // Human Design's field is multi-line; its most-significant in-sign value is
  // the longitude into the gate (`lon mod 30` would be meaningless here).
  if (scheme == SignScheme.humanDesign && lon.isFinite) {
    return humanDesignPlacement(lon).gateInLon;
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
  // Human Design is not a single named sign: its value is a multi-line
  // gate/line/color/tone/base breakdown under the one "In-Sign Longitude" label.
  if (scheme == SignScheme.humanDesign) {
    return ('In-Sign Longitude', humanDesignInSign(lon, fmt));
  }
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
    // Human Design anchors gate 1 to 13°15′ of Scorpio (longitude 223°15′ within
    // the frame). Sidereal shifts every longitude by the ayanamsha, but the gate
    // boundaries shift with them, so it stays valid in every ecliptic frame.
    case SignScheme.humanDesign:
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

  /// Collapse a built-in scheme the Context no longer supports — Aditya once the
  /// zodiac turns sidereal, True Sidereal once its frame is left — down to its
  /// [effectiveSchemeFor] fallback, so the selector stops showing (greyed) a
  /// mode that cannot render. userDefined is unaffected (valid in every frame).
  void reconcileScheme(ContextBarState ctx) {
    final effective = effectiveSchemeFor(state, ctx);
    if (effective != state.scheme) {
      _emit(SignNameSelection(scheme: effective));
    }
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

      // Also collapse a scheme the Context stops supporting (Aditya⇒sidereal,
      // True Sidereal⇒out of frame) so a stale, un-renderable mode does not sit
      // selected in the dropdown.
      notifier.reconcileScheme(ref.read(contextBarProvider));
      ref.listen<ContextBarState>(
        contextBarProvider,
        (_, ctx) => notifier.reconcileScheme(ctx),
      );

      return notifier;
    });
