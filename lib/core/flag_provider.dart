// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'context_provider.dart';
import 'context_state.dart';
import 'flag_state.dart';
import 'persistence.dart';

/// Global flag bar state provider.
final flagBarProvider = StateNotifierProvider<FlagBarNotifier, FlagBarState>((
  ref,
) {
  final persistence = ref.watch(persistenceProvider);
  final notifier = FlagBarNotifier(persistence);

  // Restore persisted flag state.
  notifier.restoreFromPersistence();

  // Auto-link: update locked flags when context bar changes.
  // Use ref.listen (not ref.watch inside notifier) to avoid infinite loops.
  ref.listen<ContextBarState>(contextBarProvider, (prev, next) {
    notifier.syncLockedFlags(next);
  });

  // Set initial locked flags from current context.
  final ctx = ref.read(contextBarProvider);
  notifier.syncLockedFlags(ctx);

  return notifier;
});

class FlagBarNotifier extends StateNotifier<FlagBarState> {
  FlagBarNotifier(this._persistence) : super(const FlagBarState());

  final PersistenceService _persistence;

  void _save() => _persistence.saveFlagBar(state);

  /// Restore persisted coord group and toggles.
  void restoreFromPersistence() {
    final overrides = _persistence.loadFlagBar();
    if (overrides.isEmpty) return;
    state = state.copyWith(
      coordValue: overrides['coordValue'] as int?,
      toggles: overrides['toggles'] as Set<int>?,
    );
  }

  /// Set the mutually exclusive coordinate group.
  void setCoordGroup(int value) {
    state = state.copyWith(coordValue: value);
    _save();
  }

  /// Toggle a composable flag on/off.
  void toggleFlag(int value) {
    final newToggles = Set<int>.from(state.toggles);
    if (newToggles.contains(value)) {
      newToggles.remove(value);
    } else {
      newToggles.add(value);
    }
    state = state.copyWith(toggles: newToggles);
    _save();
  }

  /// Set a composable flag explicitly on or off.
  void setFlag(int value, bool on) {
    final newToggles = Set<int>.from(state.toggles);
    if (on) {
      newToggles.add(value);
    } else {
      newToggles.remove(value);
    }
    state = state.copyWith(toggles: newToggles);
    _save();
  }

  /// Update locked flags from context bar state.
  /// Called by ref.listen — guard against no-op to avoid rebuild churn.
  void syncLockedFlags(ContextBarState ctx) {
    final newLocked = FlagBarState.lockedFlagsFrom(ctx);
    if (newLocked != state.lockedFlags) {
      state = state.copyWith(lockedFlags: newLocked);
    }
  }
}
