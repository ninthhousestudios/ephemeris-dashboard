// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// Tab state for JPL Horizons: the editable draft plus the last Run outcome.
// Request/response, not reactive projection (ADR-0003) — nothing fetches until
// run() is called.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/horizons/horizons_client.dart';
import '../../core/horizons/horizons_response.dart';
import 'horizons_draft.dart';

class HorizonsTabState {
  const HorizonsTabState({
    required this.draft,
    this.result,
    this.running = false,
    this.transportError,
  });

  final HorizonsDraft draft;

  /// The last server-answered response (may itself be a [HorizonsApiError]).
  final HorizonsResponse? result;

  /// True while a Run is in flight.
  final bool running;

  /// Set only when the fetch could not reach Horizons at all (transport death).
  final String? transportError;

  HorizonsTabState copyWith({
    HorizonsDraft? draft,
    HorizonsResponse? result,
    bool? running,
    String? transportError,
    bool clearResult = false,
    bool clearTransportError = false,
  }) {
    return HorizonsTabState(
      draft: draft ?? this.draft,
      result: clearResult ? null : (result ?? this.result),
      running: running ?? this.running,
      transportError: clearTransportError
          ? null
          : (transportError ?? this.transportError),
    );
  }
}

class HorizonsTabNotifier extends StateNotifier<HorizonsTabState> {
  HorizonsTabNotifier(this._ref)
    : super(const HorizonsTabState(draft: HorizonsDraft()));

  final Ref _ref;

  void updateDraft(HorizonsDraft Function(HorizonsDraft) transform) {
    state = state.copyWith(draft: transform(state.draft));
  }

  /// Pre-fill the draft from the current app Context (Moment + location).
  void loadFromContext() {
    final ctx = _ref.read(contextBarProvider);
    state = state.copyWith(draft: state.draft.loadedFrom(ctx));
  }

  /// Build the request from the draft and fetch. Served from cache on an
  /// identical repeat. Only transport failure sets [HorizonsTabState.transportError];
  /// a problem Horizons reports arrives as a [HorizonsApiError] result.
  Future<void> run() async {
    final request = state.draft.build();
    final cache = _ref.read(horizonsCacheProvider);

    final cached = cache.get(request);
    if (cached != null) {
      state = state.copyWith(
        result: cached,
        running: false,
        clearTransportError: true,
      );
      return;
    }

    state = state.copyWith(
      running: true,
      clearResult: true,
      clearTransportError: true,
    );
    try {
      final response = await queryHorizons(
        request,
        _ref.read(horizonsDioProvider),
      );
      cache.put(request, response);
      state = state.copyWith(result: response, running: false);
    } on HorizonsException catch (e) {
      state = state.copyWith(running: false, transportError: e.message);
    }
  }
}

final horizonsTabProvider =
    StateNotifierProvider<HorizonsTabNotifier, HorizonsTabState>(
      (ref) => HorizonsTabNotifier(ref),
    );
