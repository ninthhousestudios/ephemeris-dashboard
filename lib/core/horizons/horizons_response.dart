// The result taxonomy. A query the server *answered* (any readable HTTP
// response) yields a [HorizonsResponse]; a transport failure throws
// [HorizonsException]. Disambiguation and SPK are ordinary outcomes, not
// errors, so they are variants rather than thrown.
//
// TYPES-FIRST SKELETON — data model + signatures only. Bodies land after review.

import 'dart:typed_data';

/// Outcome of a Horizons query the server responded to.
sealed class HorizonsResponse {
  const HorizonsResponse();
}

/// A successful ephemeris. [rawText] is always present — it is the view/export
/// surface; [parsed] is populated once the parsing slice lands.
class HorizonsTable extends HorizonsResponse {
  const HorizonsTable({required this.rawText, this.signature, this.parsed});

  final String rawText;
  final String? signature;
  final ParsedEphemeris? parsed;
}

/// Non-unique COMMAND: Horizons returned candidate bodies. Re-query with a
/// chosen candidate's [TargetCandidate.recordId] suffixed with ';'.
class HorizonsDisambiguation extends HorizonsResponse {
  const HorizonsDisambiguation({
    required this.candidates,
    required this.rawText,
  });

  final List<TargetCandidate> candidates;
  final String rawText;
}

/// EPHEM_TYPE=SPK: the decoded binary .bsp segment, ready to save.
class HorizonsSpk extends HorizonsResponse {
  const HorizonsSpk({required this.bytes, this.suggestedFilename});

  final Uint8List bytes;
  final String? suggestedFilename;
}

/// Horizons reported a problem (bad parameter, empty result, HTTP 4xx/5xx with
/// an error body). Surfaced in the result pane, not thrown, so the query is
/// visible and fixable.
class HorizonsApiError extends HorizonsResponse {
  const HorizonsApiError({
    required this.message,
    this.httpStatus,
    this.rawText,
  });

  final String message;
  final int? httpStatus;
  final String? rawText;
}

/// One row of a disambiguation list.
class TargetCandidate {
  const TargetCandidate({
    required this.recordId,
    required this.name,
    this.detail,
  });

  final String recordId;
  final String name;
  final String? detail;
}

/// Structured ephemeris table parsed from CSV output. Exact shape firms up in
/// the parsing slice; columns + string rows are the minimum for a table view
/// and CSV export.
class ParsedEphemeris {
  const ParsedEphemeris({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;
}

/// Transport-level failure — no readable HTTP response (DNS, timeout, offline).
class HorizonsException implements Exception {
  const HorizonsException(this.message);

  final String message;

  @override
  String toString() => 'HorizonsException: $message';
}
