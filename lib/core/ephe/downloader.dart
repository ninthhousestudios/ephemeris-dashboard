import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog.dart';

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

class EphemerisDownloader {
  EphemerisDownloader(this._dio);
  final Dio _dio;

  /// Download [entry] into [destDir]. Emits progress, resumes partial
  /// downloads via HTTP Range, verifies MD5 (when provided), and retries
  /// network errors up to 3× with exponential backoff.
  Stream<DownloadProgress> download({
    required CatalogEntry entry,
    required String destDir,
    CancelToken? cancel,
    ConfirmLargeDownload? confirmLargeDownload,
  }) async* {
    final partPath = '$destDir/${entry.filename}.part';
    final finalPath = '$destDir/${entry.filename}';

    final size = entry.sizeBytes ?? 0;
    if (size > kLargeDownloadThreshold && confirmLargeDownload != null) {
      final ok = await confirmLargeDownload(size);
      if (!ok) throw const DownloadFailed('Cancelled by user.');
    }

    final controller = StreamController<DownloadProgress>();
    final done = Completer<void>();

    Future<void> attempt() async {
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
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
            // 416 = Range Not Satisfiable; surface as error for handler below.
            validateStatus: (s) => s != null && s >= 200 && s < 400,
          ),
          onReceiveProgress: (r, t) {
            controller.add(DownloadProgress(partSize + r, size > 0 ? size : partSize + t));
          },
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 416) {
          // Server refused range — nuke .part and restart fresh.
          if (partFile.existsSync()) partFile.deleteSync();
          throw const _RetryFromZero();
        }
        rethrow;
      }
    }

    Future<void> run() async {
      var attemptN = 0;
      while (true) {
        try {
          await attempt();
          break;
        } on _RetryFromZero {
          continue;
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) {
            throw const DownloadFailed('Cancelled.');
          }
          final retriable = e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionTimeout;
          attemptN++;
          if (!retriable || attemptN >= 3) {
            throw DownloadFailed('Network error: ${e.message ?? e.type.name}');
          }
          await Future<void>.delayed(
            Duration(seconds: 1 << (attemptN - 1)), // 1s, 2s, 4s
          );
        }
      }

      if (entry.md5 != null) {
        final digest = md5.convert(await File(partPath).readAsBytes());
        if (digest.toString() != entry.md5) {
          File(partPath).deleteSync();
          throw const DownloadFailed('MD5 mismatch.');
        }
      }

      File(partPath).renameSync(finalPath);
    }

    // Run and pipe progress.
    run().then((_) => done.complete()).catchError((Object e, StackTrace st) {
      done.completeError(e, st);
    });

    try {
      await for (final p in controller.stream) {
        yield p;
        if (done.isCompleted) break;
      }
      await done.future;
    } finally {
      await controller.close();
    }
  }
}

class _RetryFromZero implements Exception {
  const _RetryFromZero();
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
