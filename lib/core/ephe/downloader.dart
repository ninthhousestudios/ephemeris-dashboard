import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog.dart';
import 'validation.dart';

class DownloadProgress {
  const DownloadProgress(this.received, this.total);
  final int received;
  final int total;
  double get fraction => total <= 0 ? 0 : received / total;
}

/// Thrown after retries exhaust or an MD5 verification fails.
class DownloadFailed implements Exception {
  const DownloadFailed(this.message);
  final String message;
  @override
  String toString() => 'DownloadFailed: $message';
}

/// Signature for "confirm large download" callback (user dialog).
/// Must return true to proceed, false to abort.
typedef ConfirmLargeDownload = Future<bool> Function(int sizeBytes);

/// Files above this threshold require explicit user confirmation before
/// any bytes leave the wire.
const int kLargeDownloadThreshold = 500 * 1024 * 1024;

/// Minimum gap between [DownloadProgress] events emitted during an active
/// transfer. Keeps the UI rebuild rate bounded regardless of link speed.
/// The final 100% tick and the initial 0% tick are always emitted.
const int kProgressIntervalMs = 200;

/// Engine used for a given transfer. `curl` is preferred on desktop when
/// available — dart:io's HttpClient consistently trails curl/browsers on
/// bulk binary transfers (smaller default receive buffers, per-chunk
/// async hops on the UI isolate). `dio` is the fallback.
enum _Engine { curl, dio }

class EphemerisDownloader {
  EphemerisDownloader(this._dio);
  final Dio _dio;

  /// Cached result of probing for `curl` on PATH. null = not probed yet.
  bool? _curlAvailable;

  /// Download [entry] into [destDir]. Emits progress, resumes partial
  /// downloads via HTTP Range, verifies MD5 (when provided), and retries
  /// network errors. Uses curl when available; falls back to dio.
  Stream<DownloadProgress> download({
    required CatalogEntry entry,
    required String destDir,
    CancelToken? cancel,
    ConfirmLargeDownload? confirmLargeDownload,
  }) {
    final controller = StreamController<DownloadProgress>();

    Future<void> run() async {
      final partPath = '$destDir/${entry.filename}.part';
      final finalPath = '$destDir/${entry.filename}';

      final sizeHint = entry.sizeBytes ?? 0;
      if (sizeHint > kLargeDownloadThreshold &&
          confirmLargeDownload != null) {
        final ok = await confirmLargeDownload(sizeHint);
        if (!ok) throw const DownloadFailed('Cancelled by user.');
      }

      // Surface a starting-progress tick so the UI doesn't sit at 0
      // with no signal if the server stalls before first bytes.
      controller.add(DownloadProgress(0, sizeHint));

      final engine = await _pickEngine();
      if (engine == _Engine.curl) {
        await _runCurl(
          entry: entry,
          partPath: partPath,
          sizeHint: sizeHint,
          cancel: cancel,
          controller: controller,
        );
      } else {
        await _runDio(
          entry: entry,
          partPath: partPath,
          sizeHint: sizeHint,
          cancel: cancel,
          controller: controller,
        );
      }

      await _finalize(
        entry: entry,
        partPath: partPath,
        finalPath: finalPath,
        controller: controller,
      );
    }

    run()
        .then((_) => controller.close())
        .catchError((Object e, StackTrace st) {
      controller.addError(e, st);
      controller.close();
    });

    return controller.stream;
  }

  Future<_Engine> _pickEngine() async {
    if (kIsWeb) return _Engine.dio;
    _curlAvailable ??= await _probeCurl();
    return _curlAvailable! ? _Engine.curl : _Engine.dio;
  }

  static Future<bool> _probeCurl() async {
    try {
      final r = await Process.run('curl', ['--version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Spawn `curl` and let it stream the response straight to disk.
  /// curl handles Range resume (`-C -`), redirects (`-L`), HTTP errors
  /// (`--fail`), and transient retries (`--retry 3`). We poll the .part
  /// file size for progress — cheaper than parsing curl's stderr.
  Future<void> _runCurl({
    required CatalogEntry entry,
    required String partPath,
    required int sizeHint,
    required CancelToken? cancel,
    required StreamController<DownloadProgress> controller,
  }) async {
    final args = <String>[
      '-C', '-',
      '-L',
      '--fail',
      '--silent',
      '--show-error',
      '--retry', '3',
      '--retry-delay', '1',
      '-o', partPath,
      entry.url,
    ];

    final proc = await Process.start('curl', args);

    var userCancelled = false;
    final cancelSub = cancel?.whenCancel.asStream().listen((_) {
      userCancelled = true;
      proc.kill();
    });

    // Drain stdout (should be empty with --silent) and collect stderr
    // so we can surface a useful message if curl bails.
    final stderrBuf = StringBuffer();
    final stdoutDone = proc.stdout.drain<void>();
    final stderrDone = proc.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuf.write);

    final partFile = File(partPath);
    final progressTimer = Timer.periodic(
      const Duration(milliseconds: kProgressIntervalMs),
      (_) {
        if (!partFile.existsSync()) return;
        final size = partFile.lengthSync();
        if (!controller.isClosed) {
          controller.add(DownloadProgress(size, sizeHint));
        }
      },
    );

    final exitCode = await proc.exitCode;
    progressTimer.cancel();
    await cancelSub?.cancel();
    await stdoutDone;
    await stderrDone;

    if (userCancelled) {
      throw const DownloadFailed('Cancelled.');
    }
    if (exitCode != 0) {
      final msg = stderrBuf.toString().trim();
      throw DownloadFailed(
          'curl exit $exitCode: ${msg.isEmpty ? '(no error output)' : msg}');
    }
  }

  /// Fallback engine: dio. Same Range-resume + retry semantics as curl,
  /// but measurably slower on bulk binary. Used when curl isn't on PATH
  /// (or on web — though the manager screen gates web out earlier).
  Future<void> _runDio({
    required CatalogEntry entry,
    required String partPath,
    required int sizeHint,
    required CancelToken? cancel,
    required StreamController<DownloadProgress> controller,
  }) async {
    // Throttle progress emissions. dio fires onReceiveProgress on every
    // chunk (thousands/sec on a fast link); each emission drives a UI
    // rebuild in the manager screen, which can starve the event loop
    // and cap throughput well below network speed.
    var lastEmitMs = 0;
    var attemptN = 0;

    while (true) {
      final partFile = File(partPath);
      final partSize = partFile.existsSync() ? partFile.lengthSync() : 0;

      final headers = <String, String>{};
      if (partSize > 0) headers['Range'] = 'bytes=$partSize-';

      try {
        await _dio.download(
          entry.url,
          partPath,
          cancelToken: cancel,
          deleteOnError: false,
          // When resuming, append to the existing .part instead of
          // truncating it (dio's default is write-from-zero).
          fileAccessMode: partSize > 0
              ? FileAccessMode.append
              : FileAccessMode.write,
          options: Options(
            headers: headers,
            // Accept 200 (fresh) and 206 (range resume).
            validateStatus: (s) => s != null && s >= 200 && s < 300,
          ),
          onReceiveProgress: (r, t) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            if (nowMs - lastEmitMs < kProgressIntervalMs) return;
            lastEmitMs = nowMs;
            final total = t > 0 ? partSize + t : sizeHint;
            controller.add(DownloadProgress(partSize + r, total));
          },
        );
        return; // success
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          throw const DownloadFailed('Cancelled.');
        }
        final status = e.response?.statusCode;
        if (status == 416) {
          // Server rejected range — nuke .part and try again fresh.
          if (partFile.existsSync()) partFile.deleteSync();
          continue;
        }
        // 4xx (except 416/408) means the catalog URL is wrong or the
        // server rejects us — no amount of retry will help.
        if (status != null && status >= 400 && status < 500 &&
            status != 408) {
          throw DownloadFailed('HTTP $status from ${entry.url}');
        }
        final retriable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionTimeout;
        attemptN++;
        if (!retriable || attemptN >= 3) {
          throw DownloadFailed('Network error: ${e.type.name}');
        }
        await Future<void>.delayed(
          Duration(seconds: 1 << (attemptN - 1)), // 1s, 2s, 4s
        );
      }
    }
  }

  /// Verify MD5 (if the catalog provides one) or sniff for HTML-error-page
  /// payloads, then rename `.part` → final and emit the 100% tick.
  Future<void> _finalize({
    required CatalogEntry entry,
    required String partPath,
    required String finalPath,
    required StreamController<DownloadProgress> controller,
  }) async {
    final partFileHandle = File(partPath);
    if (entry.md5 != null) {
      // Stream the hash so we don't load a multi-GB JPL file into RAM.
      final digest = await md5.bind(partFileHandle.openRead()).last;
      if (digest.toString() != entry.md5) {
        partFileHandle.deleteSync();
        throw const DownloadFailed('MD5 mismatch.');
      }
    } else if (entry.filename.endsWith('.se1') ||
        entry.filename.endsWith('.eph')) {
      // No hash in the catalog — at least sanity-check that we didn't
      // write an HTML error page or a tiny truncated blob to disk.
      final rej = validateEpheFile(partFileHandle);
      if (rej != null) {
        partFileHandle.deleteSync();
        throw DownloadFailed(
            'Downloaded payload rejected: ${describeRejection(rej)}');
      }
    }

    partFileHandle.renameSync(finalPath);
    final finalSize = File(finalPath).lengthSync();
    controller.add(DownloadProgress(finalSize, finalSize));
  }
}

final downloaderProvider = Provider<EphemerisDownloader>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(minutes: 10),
  ));
  ref.onDispose(dio.close);
  return EphemerisDownloader(dio);
});
