// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:typed_data';

/// Counterpart: (systematic divergence: web loader seam)
Future<void> initializeWasm([String? modulePath]) =>
    throw UnsupportedError('initializeWasm is web-only');

/// Counterpart: (systematic divergence: web loader seam)
void loadEpheFile(String filename, Uint8List bytes) => throw UnsupportedError(
  'loadEpheFile is web-only; pass ephePath in EphemerisConfig instead',
);
