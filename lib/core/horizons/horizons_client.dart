// The Horizons seam: HTTP lives here only, mirroring the SIMBAD/downloader
// discipline (dio behind a Provider, a pure query function, a typed result).
// Tabs and widgets reach Horizons through this file, never package:dio.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'horizons_request.dart';
import 'horizons_response.dart';

/// Execute [request] and parse the JSON envelope into the [HorizonsResponse]
/// taxonomy. Throws [HorizonsException] only on transport failure; a problem
/// Horizons reports comes back as [HorizonsApiError]. Non-2xx responses are not
/// thrown — their bodies carry the diagnostic Horizons wants shown.
Future<HorizonsResponse> queryHorizons(HorizonsRequest request, Dio dio) async {
  final Response<String> resp;
  try {
    resp = await dio.get<String>(
      request.requestUrl(),
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );
  } on DioException catch (e) {
    throw HorizonsException('Network error: ${e.message ?? e}');
  }
  return parseHorizonsBody(resp.data ?? '', httpStatus: resp.statusCode ?? 0);
}

/// Parse a Horizons JSON envelope body into the response taxonomy. Pure — no
/// network — so it is directly testable against captured responses.
HorizonsResponse parseHorizonsBody(String body, {required int httpStatus}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    // format=json should always yield JSON; a non-JSON body means a server-side
    // failure (e.g. an HTML 500 page).
    return HorizonsApiError(
      message: 'Horizons returned a non-JSON response (HTTP $httpStatus).',
      httpStatus: httpStatus,
      rawText: body.isEmpty ? null : body,
    );
  }
  if (decoded is! Map<String, Object?>) {
    return HorizonsApiError(
      message: 'Unrecognized Horizons response shape.',
      httpStatus: httpStatus,
      rawText: body.isEmpty ? null : body,
    );
  }

  final result = decoded['result'];
  final resultText = result is String ? result : null;

  // Explicit error / validation message wins over any partial result.
  final error = decoded['error'];
  if (error is String && error.isNotEmpty) {
    return HorizonsApiError(
      message: error,
      httpStatus: httpStatus,
      rawText: resultText,
    );
  }
  final message = decoded['message'];
  if (message is String && message.isNotEmpty && httpStatus >= 400) {
    return HorizonsApiError(
      message: message,
      httpStatus: httpStatus,
      rawText: resultText,
    );
  }

  // SPK: base64 binary segment.
  final spk = decoded['spk'];
  if (spk is String && spk.isNotEmpty) {
    final Uint8List bytes;
    try {
      bytes = base64.decode(spk);
    } on FormatException {
      return HorizonsApiError(
        message: 'Horizons returned an SPK payload that could not be decoded.',
        httpStatus: httpStatus,
      );
    }
    final fileId = decoded['spk_file_id'];
    return HorizonsSpk(
      bytes: bytes,
      suggestedFilename: fileId is String ? '$fileId.bsp' : null,
    );
  }

  if (resultText == null) {
    return HorizonsApiError(
      message: 'Horizons response contained no result (HTTP $httpStatus).',
      httpStatus: httpStatus,
    );
  }

  if (isDisambiguation(resultText)) {
    return HorizonsDisambiguation(
      candidates: parseCandidates(resultText),
      rawText: resultText,
    );
  }

  return HorizonsTable(
    rawText: resultText,
    signature: _signatureSource(decoded),
  );
}

String? _signatureSource(Map<String, Object?> json) {
  final sig = json['signature'];
  if (sig is Map<String, Object?>) {
    final source = sig['source'];
    if (source is String) return source;
  }
  return null;
}

/// True when a `result` text is a non-unique-target list rather than an
/// ephemeris. Covers the small-body index table and the major-body match list.
bool isDisambiguation(String result) {
  return result.contains('To SELECT, enter record #') ||
      result.contains('Multiple major-bodies match') ||
      result.contains('Matching small-bodies') ||
      result.contains('Small-body Index Search Results');
}

/// Best-effort parse of a disambiguation list into candidates: lines that begin
/// with an integer record id, the remainder taken as the name. The raw text is
/// always retained on [HorizonsDisambiguation] for lines this misses.
List<TargetCandidate> parseCandidates(String result) {
  final candidates = <TargetCandidate>[];
  final rowPattern = RegExp(r'^\s*(-?\d+)\s+(\S.*)$');
  for (final line in const LineSplitter().convert(result)) {
    if (line.contains('Record #') || line.contains('----')) continue;
    final match = rowPattern.firstMatch(line);
    if (match == null) continue;
    final recordId = match.group(1);
    final name = match.group(2);
    if (recordId == null || name == null) continue;
    candidates.add(TargetCandidate(recordId: recordId, name: name.trim()));
  }
  return candidates;
}

/// Dedicated Dio for Horizons — its own timeouts, since ephemeris tables can be
/// large and slow. Separate from the SIMBAD and downloader clients.
final horizonsDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Stable cache key for a request: a hash of its normalized query string, so
/// two requests that differ only in parameter order collide correctly.
String horizonsCacheKey(HorizonsRequest request) {
  final params = request.toQueryParameters();
  final keys = params.keys.toList()..sort();
  final normalized = keys.map((k) => '$k=${params[k]}').join('&');
  return sha256.convert(utf8.encode(normalized)).toString();
}

/// In-memory response cache keyed by [horizonsCacheKey]. Re-running an identical
/// query returns the stored response with no network round-trip.
class HorizonsCache {
  final Map<String, HorizonsResponse> _entries = {};

  HorizonsResponse? get(HorizonsRequest request) =>
      _entries[horizonsCacheKey(request)];

  void put(HorizonsRequest request, HorizonsResponse response) =>
      _entries[horizonsCacheKey(request)] = response;
}

final horizonsCacheProvider = Provider<HorizonsCache>((ref) => HorizonsCache());
