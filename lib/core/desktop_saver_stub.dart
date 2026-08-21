// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:typed_data';

/// Web stub: the native save dialog relies on `dart:io`, which does not exist
/// on the web. This is never called there — [saveViaDialog] is guarded behind a
/// `!kIsWeb && Linux` check — but the symbol must exist for the conditional
/// import to compile.
Future<String> saveViaDialog(Uint8List bytes, String stem, String ext) async =>
    throw UnsupportedError('Native save dialog unavailable on this platform');
