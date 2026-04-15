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
              final total = t > 0 ? partSize + t : sizeHint;
              controller.add(DownloadProgress(partSize + r, total));
            },
          );
          break; // success
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
            throw DownloadFailed(
                'Network error: ${e.type.name}');
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
      // Final tick at 100%.
      final finalSize = File(finalPath).lengthSync();
      controller.add(DownloadProgress(finalSize, finalSize));
    }

    run()
        .then((_) => controller.close())
        .catchError((Object e, StackTrace st) {
      controller.addError(e, st);
      controller.close();
    });

    return controller.stream;
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
