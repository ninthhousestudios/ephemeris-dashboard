// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ephemeris/runner.dart';
import 'swe_utils.dart';

/// SweUtils backed by the runner's rs.Ephemeris — for untraced utility calls.
/// Resolves the engine lazily per call so it tracks engine rebuilds.
///
/// Ephemeris Source staging (where the `.se1` files come from) lives in
/// `core/ephe/bootstrap.dart`, not here.
final sweProvider = Provider<SweUtils>((ref) {
  return SweUtils(ref.watch(ephemerisRunnerProvider));
});
