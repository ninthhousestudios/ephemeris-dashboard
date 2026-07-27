// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephe/catalog.dart';
import 'package:swe_dashboard/core/ephe/downloader.dart';
import 'package:swe_dashboard/core/ephe/types.dart';

/// Serve [payload] on a free local port, optionally honouring Range
/// requests. Returns (url, cleanup).
Future<(String url, Future<void> Function())> _serve(
  List<int> payload, {
  bool honorRange = true,
  int? mangleAt,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(() async {
    await for (final req in server) {
      final rangeHdr = req.headers.value('range');
      final bytes = Uint8List.fromList(payload);
      List<int> body = bytes;
      int status = 200;
      if (honorRange && rangeHdr != null && rangeHdr.startsWith('bytes=')) {
        final from = int.parse(
          rangeHdr.substring('bytes='.length).split('-').first,
        );
        body = bytes.sublist(from);
        status = 206;
        req.response.headers.add(
          'Content-Range',
          'bytes $from-${bytes.length - 1}/${bytes.length}',
        );
      }
      if (mangleAt != null && body.length > mangleAt) {
        body = [...body]..[mangleAt] ^= 0xFF;
      }
      req.response.statusCode = status;
      req.response.headers.contentLength = body.length;
      req.response.add(body);
      await req.response.close();
    }
  }());
  final url = 'http://${server.address.host}:${server.port}/payload.bin';
  return (url, () async => server.close(force: true));
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ephe_dl_test_');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('downloads a small file end-to-end and emits progress', () async {
    final payload = List<int>.generate(4096, (i) => i & 0xFF);
    final (url, stop) = await _serve(payload);
    addTearDown(stop);

    final dl = EphemerisDownloader(Dio());
    final entry = CatalogEntry(
      filename: 'payload.bin',
      family: BodyFamily.unknown,
      url: url,
      sizeBytes: payload.length,
    );
    final events = <DownloadProgress>[];
    await for (final p in dl.download(entry: entry, destDir: tmp.path)) {
      events.add(p);
    }
    final out = File('${tmp.path}/payload.bin');
    expect(out.existsSync(), isTrue);
    expect(out.lengthSync(), payload.length);
    expect(events, isNotEmpty);
    // Last event reflects completion.
    expect(events.last.received, payload.length);
  });

  test('verifies MD5 and fails on mismatch', () async {
    final payload = List<int>.generate(2048, (i) => i & 0xFF);
    // Serve mangled bytes so the MD5 won't match the catalog's claim.
    final (url, stop) = await _serve(payload, mangleAt: 0);
    addTearDown(stop);

    final expectedMd5 = md5.convert(payload).toString();
    final dl = EphemerisDownloader(Dio());
    final entry = CatalogEntry(
      filename: 'payload.bin',
      family: BodyFamily.unknown,
      url: url,
      sizeBytes: payload.length,
      md5: expectedMd5,
    );

    await expectLater(() async {
      await for (final _ in dl.download(entry: entry, destDir: tmp.path)) {}
    }, throwsA(isA<DownloadFailed>()));
    // On MD5 failure, the .part file must be cleaned up.
    expect(File('${tmp.path}/payload.bin.part').existsSync(), isFalse);
    expect(File('${tmp.path}/payload.bin').existsSync(), isFalse);
  });

  test('resumes from an existing .part via Range', () async {
    final payload = List<int>.generate(8192, (i) => i & 0xFF);
    final (url, stop) = await _serve(payload);
    addTearDown(stop);

    // Pre-seed a half-complete .part file.
    final halfway = payload.length ~/ 2;
    File(
      '${tmp.path}/payload.bin.part',
    ).writeAsBytesSync(payload.sublist(0, halfway));

    final dl = EphemerisDownloader(Dio());
    final entry = CatalogEntry(
      filename: 'payload.bin',
      family: BodyFamily.unknown,
      url: url,
      sizeBytes: payload.length,
    );
    await for (final _ in dl.download(entry: entry, destDir: tmp.path)) {}

    final out = File('${tmp.path}/payload.bin');
    expect(out.existsSync(), isTrue);
    expect(out.readAsBytesSync(), payload);
  });

  test('large-download callback can cancel before any bytes move', () async {
    final dl = EphemerisDownloader(Dio());
    const entry = CatalogEntry(
      filename: 'huge.eph',
      family: BodyFamily.jpl,
      url: 'http://127.0.0.1:1/nope', // should never be hit
      sizeBytes: kLargeDownloadThreshold + 1,
    );
    await expectLater(() async {
      await for (final _ in dl.download(
        entry: entry,
        destDir: tmp.path,
        confirmLargeDownload: (_) async => false,
      )) {}
    }, throwsA(isA<DownloadFailed>()));
    expect(File('${tmp.path}/huge.eph.part').existsSync(), isFalse);
  });
}
