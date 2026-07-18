// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph_rs/swisseph_rs.dart' show initializeWasm;

/// Initialize ephemeris path stub — not used on web.
Future<String?> initNativeEphePath() =>
    throw UnsupportedError('Not available on web');

/// Load the swisseph_rs WASM module for web.
Future<void> initWasm() => initializeWasm('swisseph_ffi.js');
