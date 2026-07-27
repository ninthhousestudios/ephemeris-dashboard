// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayanamsa_catalog.dart';
import 'persistence.dart';
import 'pref_field.dart';

/// One user-defined ayanamsha (SE_SIDM_USER, 255).
///
/// There is a single list of these for the whole app: the Ayanamsa tab edits
/// them, and the context bar's Ayanamsa dropdown selects one of them to drive
/// chart calculations on every other tab. Defining one from either place adds
/// to the same list (swe-dashboard/96) — before, the tab and the context bar
/// each kept their own, and an entry made in one was invisible to the other.
class UserAyanamsa {
  const UserAyanamsa({
    required this.id,
    this.name,
    this.t0 = 2451545.0, // J2000
    this.value = 0.0,
    this.t0IsUt = false,
  });

  final int id;

  /// Optional user label. Null (or blank) falls back to "User-defined N",
  /// numbered by position — see [userAyanamsaLabel].
  final String? name;

  final double t0; // reference Julian Day
  final double value; // ayanamsha at t0, degrees
  final bool t0IsUt; // SE_SIDBIT_USER_UT (jdisut)

  /// The sid_mode this entry calculates under, with the `jdisut` bit ORed in.
  int get sidMode => t0IsUt ? (ayanamsaUserId | userAyanUtBit) : ayanamsaUserId;

  UserAyanamsa copyWith({
    Object? name = _sentinel,
    double? t0,
    double? value,
    bool? t0IsUt,
  }) => UserAyanamsa(
    id: id,
    name: identical(name, _sentinel) ? this.name : name as String?,
    t0: t0 ?? this.t0,
    value: value ?? this.value,
    t0IsUt: t0IsUt ?? this.t0IsUt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    't0': t0,
    'value': value,
    't0IsUt': t0IsUt,
  };

  /// Null when the stored shape is no longer usable, so one bad entry is
  /// dropped rather than taking the whole list down with it.
  ///
  /// `t0` and `value` are required, not defaulted: [toJson] always writes both,
  /// so their absence means corruption or schema drift rather than a valid
  /// saved entry. Substituting J2000 and 0° there would hand the engine a
  /// selectable entry that computes in a frame the user never chose.
  static UserAyanamsa? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! int) return null;
    final t0 = json['t0'];
    final value = json['value'];
    if (t0 is! num || !t0.isFinite) return null;
    if (value is! num || !value.isFinite) return null;
    final name = json['name'];
    return UserAyanamsa(
      id: id,
      name: name is String ? name : null,
      t0: t0.toDouble(),
      value: value.toDouble(),
      t0IsUt: json['t0IsUt'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAyanamsa &&
          id == other.id &&
          name == other.name &&
          t0 == other.t0 &&
          value == other.value &&
          t0IsUt == other.t0IsUt;

  @override
  int get hashCode => Object.hash(id, name, t0, value, t0IsUt);
}

const Object _sentinel = Object();

/// Display label for [entry] at [index] in the list: its name if it has a
/// non-blank one, else "User-defined N" numbered from 1 by position.
String userAyanamsaLabel(UserAyanamsa entry, int index) {
  final name = entry.name?.trim();
  return (name == null || name.isEmpty) ? 'User-defined ${index + 1}' : name;
}

/// The entry [id] selects, or null when it selects none.
///
/// Deliberately not a "nearest match" fallback: a dangling id is reconciled at
/// the point of removal ([ContextBarNotifier.reconcileUserAyanamsa]), so a null
/// here means the Context genuinely has no user-defined ayanamsha selected.
UserAyanamsa? resolveUserAyanamsa(List<UserAyanamsa> entries, int? id) {
  for (final entry in entries) {
    if (entry.id == id) return entry;
  }
  return null;
}

/// Stored as one JSON array under a single key. A list, unlike the scalar
/// Context fields, has no [PrefField] shape to fold over — but it still goes
/// through a [PrefCodec] so unusable stored data reads as absent, not as a
/// throw on launch.
class UserAyanamsaListPrefCodec extends PrefCodec<List<UserAyanamsa>> {
  const UserAyanamsaListPrefCodec();

  @override
  void write(SharedPreferences prefs, String key, List<UserAyanamsa> value) =>
      prefs.setString(key, jsonEncode([for (final u in value) u.toJson()]));

  @override
  List<UserAyanamsa>? read(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null; // Not JSON at all: treat as nothing stored.
    }
    if (decoded is! List) return null;
    return [for (final e in decoded) ?UserAyanamsa.fromJson(e)];
  }
}

const userAyanamsaListPref = UserAyanamsaListPrefCodec();
const userAyanamsasPrefKey = 'user_ayanamsas';

/// Pref keys written by builds before swe-dashboard/96, when the Context
/// carried one user-defined ayanamsha's parameters as scalars of its own.
const _legacyT0Key = 'ctx_user_ayan_t0';
const _legacyValueKey = 'ctx_user_ayan_value';
const _legacyT0IsUtKey = 'ctx_user_ayan_t0_is_ut';
const _ayanamsaKey = 'ctx_ayanamsa';
const _userAyanIdKey = 'ctx_user_ayan_id';

/// Fold a pre-swe-dashboard/96 store into the list shape, in place.
///
/// Those builds stored the single user-defined ayanamsha as three scalar
/// Context fields. Nothing reads those keys any more, so without this the
/// user's ayanamsha is simply gone — and worse, a Context that still says
/// `ayanamsa == 255` restores selecting a user-defined entry that does not
/// exist. The parameters become one entry, and the selection follows only if
/// the old Context was actually on 255.
///
/// Runs against storage before any provider reads it (from `main`), so the
/// list and the Context both come up already migrated and neither has to know
/// the old shape. Idempotent: the legacy keys are dropped, and a store that
/// already has [userAyanamsasPrefKey] is left alone.
void migrateLegacyUserAyanamsa(SharedPreferences prefs) {
  if (prefs.containsKey(userAyanamsasPrefKey)) return;
  final t0 = prefs.getDouble(_legacyT0Key);
  final value = prefs.getDouble(_legacyValueKey);
  if (t0 == null && value == null) return;

  const migrated = 0;
  userAyanamsaListPref.write(prefs, userAyanamsasPrefKey, [
    UserAyanamsa(
      id: migrated,
      t0: t0 ?? const UserAyanamsa(id: migrated).t0,
      value: value ?? 0.0,
      t0IsUt: prefs.getBool(_legacyT0IsUtKey) ?? false,
    ),
  ]);
  if (prefs.getInt(_ayanamsaKey) == ayanamsaUserId) {
    prefs.setInt(_userAyanIdKey, migrated);
  }
  prefs
    ..remove(_legacyT0Key)
    ..remove(_legacyValueKey)
    ..remove(_legacyT0IsUtKey);
}

/// The app-wide list of user-defined ayanamshas.
///
/// [onChanged] fires after every mutation: the provider uses it to persist the
/// list. Left null in tests, which exercise the notifier on its own.
class UserAyanamsaNotifier extends StateNotifier<List<UserAyanamsa>> {
  UserAyanamsaNotifier({List<UserAyanamsa> initial = const [], this.onChanged})
    : _nextId = initial.fold(0, (m, u) => u.id >= m ? u.id + 1 : m),
      super(initial);

  final void Function(List<UserAyanamsa> entries)? onChanged;

  int _nextId;

  void _emit(List<UserAyanamsa> next) {
    state = next;
    onChanged?.call(next);
  }

  /// Append an entry and return its id, so a caller that also selects it (the
  /// context bar's "Add user-defined…") does not have to guess which one it is.
  int add({String? name, double? t0, double? value, bool t0IsUt = false}) {
    final id = _nextId++;
    _emit([
      ...state,
      UserAyanamsa(
        id: id,
        name: name,
        t0: t0 ?? const UserAyanamsa(id: 0).t0,
        value: value ?? 0.0,
        t0IsUt: t0IsUt,
      ),
    ]);
    return id;
  }

  void removeById(int id) {
    _emit(state.where((u) => u.id != id).toList());
  }

  void update(
    int id, {
    Object? name = _sentinel,
    double? t0,
    double? value,
    bool? t0IsUt,
  }) {
    _emit([
      for (final u in state)
        if (u.id == id)
          u.copyWith(name: name, t0: t0, value: value, t0IsUt: t0IsUt)
        else
          u,
    ]);
  }
}

/// User-defined ayanamshas, shared by the Ayanamsa tab and the context bar.
///
/// Owns the entries and nothing else. Keeping the Context's selection from
/// dangling when an entry goes away is `contextBarProvider`'s job, done by
/// listening to this provider: the Context is what holds the id, and this file
/// importing `context_provider.dart` to push at it put a plain core data list
/// inside the context/engine import cycle (swe-dashboard/97).
final userAyanamsasProvider =
    StateNotifierProvider<UserAyanamsaNotifier, List<UserAyanamsa>>((ref) {
      final persistence = ref.watch(persistenceProvider);
      return UserAyanamsaNotifier(
        initial:
            persistence.loadValue(userAyanamsaListPref, userAyanamsasPrefKey) ??
            const [],
        onChanged: (entries) => persistence.saveValue(
          userAyanamsaListPref,
          userAyanamsasPrefKey,
          entries,
        ),
      );
    });
