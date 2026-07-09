// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

/// Why a candidate ephemeris file was rejected by [validateEpheFile].
enum EpheFileRejection { missing, tooSmall, looksLikeHtml }

/// Cheap sanity check for a file on disk that claims to be a Swiss
/// Ephemeris (.se1) or JPL (.eph) binary. Catches the two failure modes
/// we actually see in the wild:
///
/// 1. Truncated transfers — anything below [minBytes] can't be a real
///    SE/JPL file (real ones are hundreds of KB to multiple GB).
/// 2. HTML error pages served with HTTP 200 — GitHub's raw.* CDN does
///    this on rate-limit, and some S3-backed mirrors return XML error
///    bodies. We detect by sniffing the first bytes.
///
/// Returns null when the file looks plausible, otherwise a reason.
EpheFileRejection? validateEpheFile(File file, {int minBytes = 16 * 1024}) {
  if (!file.existsSync()) return EpheFileRejection.missing;
  final len = file.lengthSync();
  if (len < minBytes) return EpheFileRejection.tooSmall;

  final raf = file.openSync();
  try {
    final head = raf.readSync(16);
    final asText = String.fromCharCodes(head).toLowerCase().trimLeft();
    if (asText.startsWith('<!doc') ||
        asText.startsWith('<html') ||
        asText.startsWith('<?xml') ||
        (asText.isNotEmpty && asText.codeUnitAt(0) == 0x3c /* '<' */ )) {
      return EpheFileRejection.looksLikeHtml;
    }
  } finally {
    raf.closeSync();
  }
  return null;
}

String describeRejection(EpheFileRejection r) => switch (r) {
  EpheFileRejection.missing => 'file missing',
  EpheFileRejection.tooSmall => 'file too small to be a real ephemeris',
  EpheFileRejection.looksLikeHtml =>
    'file looks like an HTML/XML error page, not an ephemeris binary',
};
