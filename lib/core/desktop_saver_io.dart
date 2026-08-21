// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Present a native "save as" dialog and write [bytes] to the chosen path.
///
/// Used on Linux, where `file_saver`'s `saveAs` is unimplemented and would
/// otherwise dump silently into the Downloads directory. `file_selector_linux`
/// gives a real GTK save dialog. Returns a human-readable SnackBar status.
Future<String> saveViaDialog(Uint8List bytes, String stem, String ext) async {
  final location = await getSaveLocation(
    suggestedName: '$stem.$ext',
    acceptedTypeGroups: [
      XTypeGroup(label: ext.toUpperCase(), extensions: [ext]),
    ],
  );
  if (location == null) return 'Save cancelled';
  await File(location.path).writeAsBytes(bytes);
  return 'Saved $stem.$ext';
}
