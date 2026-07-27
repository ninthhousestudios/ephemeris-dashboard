// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:shared_preferences/shared_preferences.dart';

/// One persisted field of a state class: how to read it off the state, how to
/// put it back, and how it is encoded in [SharedPreferences].
///
/// The point of the indirection is that saving and restoring fold over the
/// *same* list. A field reaches the store and comes back by adding one row to
/// its owner's list — there is no writer, reader and applier to keep in
/// lockstep, and so no fourth place to forget (swe-dashboard/86).
abstract class PrefField<S> {
  const PrefField();

  /// The [SharedPreferences] key. Keys are prefixed per state owner.
  String get key;

  void save(SharedPreferences prefs, S state);

  /// Returns [state] with this field replaced by the stored value, or [state]
  /// unchanged when nothing usable is stored.
  S restore(SharedPreferences prefs, S state);
}

/// A [PrefField] carrying a value of type [T].
///
/// [T] is bound here and hidden behind the [PrefField] supertype, so one list
/// holds fields of mixed types without any of them passing through `dynamic`.
class TypedPrefField<S, T extends Object> extends PrefField<S> {
  const TypedPrefField({
    required this.key,
    required this.getter,
    required this.setter,
    required this.codec,
  });

  @override
  final String key;

  /// Null means "no value": [save] then erases the key rather than leaving the
  /// previous choice behind for the next restore to pick up.
  final T? Function(S state) getter;

  final S Function(S state, T value) setter;

  final PrefCodec<T> codec;

  @override
  void save(SharedPreferences prefs, S state) {
    final value = getter(state);
    if (value == null) {
      prefs.remove(key);
    } else {
      codec.write(prefs, key, value);
    }
  }

  @override
  S restore(SharedPreferences prefs, S state) {
    final value = codec.read(prefs, key);
    return value == null ? state : setter(state, value);
  }
}

/// How a value of type [T] is encoded in [SharedPreferences].
abstract class PrefCodec<T extends Object> {
  const PrefCodec();

  void write(SharedPreferences prefs, String key, T value);

  /// Null when nothing is stored, or when what is stored is no longer usable
  /// (an enum name that has since been renamed, say). The field then leaves the
  /// state alone, so the fallback is whatever the state already holds — the
  /// class default on a fresh launch, rather than a second default written out
  /// beside each read.
  T? read(SharedPreferences prefs, String key);
}

class _DoublePrefCodec extends PrefCodec<double> {
  const _DoublePrefCodec();

  @override
  void write(SharedPreferences prefs, String key, double value) =>
      prefs.setDouble(key, value);

  @override
  double? read(SharedPreferences prefs, String key) => prefs.getDouble(key);
}

class _IntPrefCodec extends PrefCodec<int> {
  const _IntPrefCodec();

  @override
  void write(SharedPreferences prefs, String key, int value) =>
      prefs.setInt(key, value);

  @override
  int? read(SharedPreferences prefs, String key) => prefs.getInt(key);
}

class _BoolPrefCodec extends PrefCodec<bool> {
  const _BoolPrefCodec();

  @override
  void write(SharedPreferences prefs, String key, bool value) =>
      prefs.setBool(key, value);

  @override
  bool? read(SharedPreferences prefs, String key) => prefs.getBool(key);
}

class _StringPrefCodec extends PrefCodec<String> {
  const _StringPrefCodec();

  @override
  void write(SharedPreferences prefs, String key, String value) =>
      prefs.setString(key, value);

  @override
  String? read(SharedPreferences prefs, String key) => prefs.getString(key);
}

/// Stored as the enum's [Enum.name], so the numbering may change freely; a name
/// that no longer resolves reads as absent.
class EnumPrefCodec<E extends Enum> extends PrefCodec<E> {
  const EnumPrefCodec(this.values);

  final List<E> values;

  @override
  void write(SharedPreferences prefs, String key, E value) =>
      prefs.setString(key, value.name);

  @override
  E? read(SharedPreferences prefs, String key) {
    final name = prefs.getString(key);
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// Stored as a list of decimal strings. Entries that no longer parse are
/// dropped rather than read as 0 — a 0 is not a flag value, so it would only
/// sit in the set forever.
class _IntSetPrefCodec extends PrefCodec<Set<int>> {
  const _IntSetPrefCodec();

  @override
  void write(SharedPreferences prefs, String key, Set<int> value) =>
      prefs.setStringList(key, [for (final v in value) v.toString()]);

  @override
  Set<int>? read(SharedPreferences prefs, String key) {
    final stored = prefs.getStringList(key);
    if (stored == null) return null;
    return {for (final s in stored) ?int.tryParse(s)};
  }
}

const doublePref = _DoublePrefCodec();
const intPref = _IntPrefCodec();
const boolPref = _BoolPrefCodec();
const stringPref = _StringPrefCodec();
const intSetPref = _IntSetPrefCodec();
