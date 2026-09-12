// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Dataset-agnostic transfer unit for the downloader. Carries only what the
/// download mechanics need (url, where to write, size/hash for verification).
///
/// The ephemeris-file ontology — `BodyFamily`, the Swiss-Ephemeris payload
/// validation policy — stays in `CatalogEntry`, which builds one of these via
/// `toDownloadSpec()`. Non-ephemeris callers (e.g. the city atlas) construct a
/// spec directly and never touch the body catalog.
class DownloadSpec {
  const DownloadSpec({
    required this.url,
    required this.filename,
    this.subdir = '',
    this.sizeBytes,
    this.md5,
    this.sniffEphePayload = false,
    this.minSniffBytes = 16 * 1024,
  });

  final String url;
  final String filename;

  /// Subdirectory relative to the download root (e.g. 'ast0', 'atlas').
  /// Empty = root.
  final String subdir;
  final int? sizeBytes;
  final String? md5;

  /// When [md5] is null, validate the finished payload as a Swiss Ephemeris
  /// file (reject HTML error pages / truncated blobs). Callers with an md5 to
  /// pin — including every atlas release — leave this false and rely on the
  /// hash instead.
  final bool sniffEphePayload;

  /// Floor for the ephe payload sniff (ignored unless [sniffEphePayload]).
  final int minSniffBytes;
}
