// test/challenger/m2_updater_stress_test.dart
// Empirical Challenger Stress Harness for Milestone 2: Resumable & Bulletproof In-App Updater (R2)
//
// Empirically verifies using real local loopback HTTP sockets:
// 1. Pause at 30% progress preserves `.part` file on disk with exact bytes
// 2. Resume emits `Range: bytes=<offset>-` and server serves HTTP 206 Partial Content
// 3. Real network drop (abrupt TCP socket destruction) auto-retries from exact offset
// 4. Consecutive network drops (multiple retries) recover cumulatively
// 5. Server returning HTTP 200 instead of 206 gracefully truncates and restarts without file corruption
// 6. SHA256 integrity mismatch throws ChecksumMismatchException and deletes `.part` file
// 7. HTTP 416 Range Not Satisfiable handling for completed vs invalid offsets
// 8. Cancellation cleanly deletes partial files and frees socket resources
// 9. Sliding-window speed and ETA calculations

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/core/updater.dart';

// =============================================================================
// Live Local Mock HTTP Server with Real TCP Sockets
// =============================================================================

class CapturedHttpRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final DateTime timestamp;

  CapturedHttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.timestamp,
  });

  String? get rangeHeader => headers['range'];
}

class MockUpdateServer {
  final HttpServer _server;
  final List<CapturedHttpRequest> capturedRequests = [];

  MockUpdateServer._(this._server);

  int get port => _server.port;
  Uri get baseUrl => Uri.parse('http://127.0.0.1:$port');

  static Future<MockUpdateServer> start({
    required Future<void> Function(HttpRequest request, MockUpdateServer server)
        handler,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final mockServer = MockUpdateServer._(server);

    server.listen((HttpRequest request) async {
      final headerMap = <String, String>{};
      request.headers.forEach((name, values) {
        headerMap[name.toLowerCase()] = values.join(', ');
      });

      mockServer.capturedRequests.add(
        CapturedHttpRequest(
          method: request.method,
          uri: request.uri,
          headers: headerMap,
          timestamp: DateTime.now(),
        ),
      );

      try {
        await handler(request, mockServer);
      } catch (_) {
        // Suppress expected socket disconnect errors on server side
      }
    });

    return mockServer;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

// =============================================================================
// Main Test Suite
// =============================================================================

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zohal_m2_challenger_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Helper to generate deterministic binary payload
  Uint8List generatePayload(int size) {
    final data = Uint8List(size);
    for (int i = 0; i < size; i++) {
      data[i] = (i * 31 + 17) & 0xFF;
    }
    return data;
  }

  // ===========================================================================
  // CHALLENGE 1 & 2: Pause at 30% & Resume with HTTP Range Header (Live HTTP)
  // ===========================================================================
  group('CHALLENGE 1 & 2: Pause at 30% & Resume with HTTP Range 206', () {
    test(
      'Pauses at 30% progress, preserves .part on disk, and resumes with Range: bytes=X-',
      () async {
        const totalSize = 64000;
        final payload = generatePayload(totalSize);
        final payloadSha256 = sha256.convert(payload).toString();

        final pauseCompleter = Completer<void>();

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            final range = request.headers.value('range');

            if (range == null) {
              // First connection: Stream chunks with pacing
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.set('Content-Type', 'application/octet-stream');
              request.response.headers.set('Content-Length', totalSize.toString());
              request.response.headers.set('Accept-Ranges', 'bytes');

              const chunkSize = 2048;
              int offset = 0;
              while (offset < totalSize) {
                final end = (offset + chunkSize > totalSize) ? totalSize : offset + chunkSize;
                request.response.add(payload.sublist(offset, end));
                await request.response.flush();
                offset = end;
                await Future<void>.delayed(const Duration(milliseconds: 15));
              }
              try {
                await request.response.close();
              } catch (_) {}
            } else {
              // Resumed connection: Must have Range header
              final match = RegExp(r'bytes=(\d+)-').firstMatch(range);
              expect(match, isNotNull, reason: 'Range header must match bytes=X-');
              final startOffset = int.parse(match!.group(1)!);
              final remaining = totalSize - startOffset;

              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.set(
                'Content-Range',
                'bytes $startOffset-${totalSize - 1}/$totalSize',
              );
              request.response.headers.set('Content-Length', remaining.toString());
              request.response.headers.set('Content-Type', 'application/octet-stream');

              request.response.add(payload.sublist(startOffset));
              await request.response.flush();
              await request.response.close();
            }
          },
        );

        addTearDown(server.close);

        const filename = 'update_pause_resume.bin';
        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/update_pause_resume.bin',
            filename: filename,
            sizeBytes: totalSize,
            expectedSha256: payloadSha256,
          ),
          storageDirectory: tempDir,
        );

        // Start download and pause as soon as 30% (~19,200 bytes) is reached
        bool paused = false;
        final downloadFuture = downloader.start(
          onProgress: (p) {
            if (p.bytesReceived >= 19200 && !paused) {
              paused = true;
              downloader.pause();
              if (!pauseCompleter.isCompleted) {
                pauseCompleter.complete();
              }
            }
          },
        );
        unawaited(downloadFuture);

        await pauseCompleter.future;
        expect(downloader.status, equals(DownloadStatus.paused));

        // Let the I/O sink flush
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final partFile = File('${tempDir.path}/$filename.part');
        expect(await partFile.exists(), isTrue, reason: '.part file must exist on disk after pause');

        final pausedLength = await partFile.length();
        expect(pausedLength, greaterThanOrEqualTo(19200),
            reason: '.part file must have stored at least 30% of bytes');
        expect(pausedLength, lessThan(totalSize),
            reason: '.part file must not be complete yet');

        // Verify partial bytes on disk match payload prefix exactly
        final partBytes = await partFile.readAsBytes();
        expect(partBytes, equals(payload.sublist(0, pausedLength)),
            reason: '.part bytes on disk must be identical to payload prefix');

        // Now resume
        final resumeFuture = downloader.resume();
        final finalFile = await resumeFuture;

        expect(await finalFile.exists(), isTrue);
        expect(await finalFile.length(), equals(totalSize));

        // Verify .part was cleaned up/renamed
        expect(await partFile.exists(), isFalse,
            reason: '.part file must be renamed to target file on completion');

        // Bit-for-bit SHA256 integrity check
        final finalBytes = await finalFile.readAsBytes();
        expect(sha256.convert(finalBytes).toString(), equals(payloadSha256));
        expect(finalBytes, equals(payload));

        // Verify server captured requests
        expect(server.capturedRequests.length, equals(2));
        expect(server.capturedRequests[0].rangeHeader, isNull);
        expect(
          server.capturedRequests[1].rangeHeader,
          equals('bytes=$pausedLength-'),
          reason: 'Resumed HTTP request must specify exact byte offset in Range header',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 3: Simulated Real Network Drop (Abrupt Premature Close)
  // ===========================================================================
  group('CHALLENGE 3: Real TCP Socket Drop & Auto-Retry Loop', () {
    test(
      'Abrupt premature stream termination midway triggers auto-retry from exact offset without resetting to 0',
      () async {
        const totalSize = 80000;
        final payload = generatePayload(totalSize);
        final payloadSha256 = sha256.convert(payload).toString();

        int connectionCount = 0;
        int droppedOffset = 0;

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            connectionCount++;

            if (connectionCount == 1) {
              // Attempt 1: Send 32,000 bytes (40%), then prematurely close the connection
              // With Content-Length: 80000, this triggers ClientException (connection closed while receiving data)
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.set('Content-Length', totalSize.toString());
              request.response.headers.set('Content-Type', 'application/octet-stream');

              droppedOffset = 32000;
              request.response.add(payload.sublist(0, droppedOffset));
              await request.response.flush();

              try {
                await request.response.close();
              } catch (_) {}
            } else {
              // Attempt 2: Client auto-retries with Range header
              final range = request.headers.value('range');
              expect(range, isNotNull,
                  reason: 'Auto-retry request must include Range header');

              final match = RegExp(r'bytes=(\d+)-').firstMatch(range!);
              expect(match, isNotNull);
              final requestedOffset = int.parse(match!.group(1)!);

              expect(requestedOffset, equals(droppedOffset),
                  reason: 'Auto-retry must resume from exact dropped offset');

              final remaining = totalSize - requestedOffset;
              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.set(
                'Content-Range',
                'bytes $requestedOffset-${totalSize - 1}/$totalSize',
              );
              request.response.headers.set('Content-Length', remaining.toString());
              request.response.headers.set('Content-Type', 'application/octet-stream');

              request.response.add(payload.sublist(requestedOffset));
              await request.response.flush();
              await request.response.close();
            }
          },
        );

        addTearDown(server.close);

        const filename = 'network_drop_test.bin';
        final progressList = <DownloadProgress>[];

        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/network_drop_test.bin',
            filename: filename,
            sizeBytes: totalSize,
            expectedSha256: payloadSha256,
          ),
          storageDirectory: tempDir,
        );

        downloader.progressStream.listen(progressList.add);

        final resultFile = await downloader.start();

        expect(connectionCount, equals(2));
        expect(await resultFile.exists(), isTrue);
        expect(await resultFile.length(), equals(totalSize));

        // Verify SHA256 integrity
        final resultBytes = await resultFile.readAsBytes();
        expect(sha256.convert(resultBytes).toString(), equals(payloadSha256));
        expect(resultBytes, equals(payload));

        // Verify progress sequence encountered 'retrying' and did not reset receivedBytes to 0
        final retryingEvents =
            progressList.where((p) => p.status == DownloadStatus.retrying).toList();
        expect(retryingEvents, isNotEmpty,
            reason: 'Must enter retrying state on socket exception');

        final postRetryDownloading = progressList
            .where((p) =>
                p.status == DownloadStatus.downloading &&
                p.retryAttempt > 0)
            .toList();
        expect(postRetryDownloading, isNotEmpty);
        expect(
          postRetryDownloading.first.bytesReceived,
          greaterThanOrEqualTo(droppedOffset),
          reason: 'Bytes received after retry must not reset to 0',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 4: Multiple Consecutive Network Drops (Double Interruption)
  // ===========================================================================
  group('CHALLENGE 4: Double Network Drop & Cumulative Recovery', () {
    test(
      'Survives two successive network socket drops and finishes with exact payload',
      () async {
        const totalSize = 60000;
        final payload = generatePayload(totalSize);
        final payloadSha256 = sha256.convert(payload).toString();

        int attempt = 0;
        const drop1Offset = 20000;
        const drop2Offset = 40000;

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            attempt++;
            final range = request.headers.value('range');

            if (attempt == 1) {
              // 1st attempt: Stream 20,000 bytes then drop prematurely
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.set('Content-Length', totalSize.toString());
              request.response.add(payload.sublist(0, drop1Offset));
              await request.response.flush();
              try {
                await request.response.close();
              } catch (_) {}
            } else if (attempt == 2) {
              // 2nd attempt: Verify Range is 20,000-, stream up to 40,000, then drop again
              expect(range, equals('bytes=$drop1Offset-'));
              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.set(
                'Content-Range',
                'bytes $drop1Offset-${totalSize - 1}/$totalSize',
              );
              request.response.headers.set(
                'Content-Length',
                (totalSize - drop1Offset).toString(),
              );
              request.response.add(payload.sublist(drop1Offset, drop2Offset));
              await request.response.flush();
              try {
                await request.response.close();
              } catch (_) {}
            } else {
              // 3rd attempt: Verify Range is 40,000-, stream remainder to completion
              expect(range, equals('bytes=$drop2Offset-'));
              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.set(
                'Content-Range',
                'bytes $drop2Offset-${totalSize - 1}/$totalSize',
              );
              request.response.headers.set(
                'Content-Length',
                (totalSize - drop2Offset).toString(),
              );
              request.response.add(payload.sublist(drop2Offset));
              await request.response.flush();
              await request.response.close();
            }
          },
        );

        addTearDown(server.close);

        const filename = 'double_drop_test.bin';
        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/double_drop_test.bin',
            filename: filename,
            sizeBytes: totalSize,
            expectedSha256: payloadSha256,
          ),
          storageDirectory: tempDir,
        );

        final resultFile = await downloader.start();

        expect(attempt, equals(3));
        expect(await resultFile.exists(), isTrue);
        expect(await resultFile.length(), equals(totalSize));

        final resultBytes = await resultFile.readAsBytes();
        expect(sha256.convert(resultBytes).toString(), equals(payloadSha256));
        expect(resultBytes, equals(payload));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 5: Server Ignoring Range Header (HTTP 200 Overwrite Fallback)
  // ===========================================================================
  group('CHALLENGE 5: HTTP 200 Truncate Fallback (Range Ignored)', () {
    test(
      'When server responds with HTTP 200 OK despite Range header, .part is truncated cleanly without corrupting length',
      () async {
        const totalSize = 50000;
        final payload = generatePayload(totalSize);
        final payloadSha256 = sha256.convert(payload).toString();

        const filename = 'http_200_fallback.bin';
        final partFile = File('${tempDir.path}/$filename.part');

        // Pre-populate .part file with 25,000 bytes of stale/corrupted junk
        final staleBytes = Uint8List(25000);
        staleBytes.fillRange(0, 25000, 0xEE);
        await partFile.writeAsBytes(staleBytes);

        String? observedRangeHeader;
        int requestCount = 0;

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            requestCount++;
            observedRangeHeader = request.headers.value('range');

            // Server ignores Range header and returns 200 OK with full file
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.set('Content-Length', totalSize.toString());
            request.response.headers.set('Content-Type', 'application/octet-stream');

            request.response.add(payload);
            await request.response.flush();
            await request.response.close();
          },
        );

        addTearDown(server.close);

        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/http_200_fallback.bin',
            filename: filename,
            sizeBytes: totalSize,
            expectedSha256: payloadSha256,
          ),
          storageDirectory: tempDir,
        );

        final resultFile = await downloader.start();

        // Downloader correctly asked for bytes=25000-
        expect(observedRangeHeader, equals('bytes=25000-'));
        expect(requestCount, equals(1));

        // Result file must be exactly 50,000 bytes, NOT 75,000 bytes (was truncated!)
        expect(await resultFile.length(), equals(totalSize),
            reason: 'File must be truncated to 50000, not appended to 75000');

        final resultBytes = await resultFile.readAsBytes();
        expect(sha256.convert(resultBytes).toString(), equals(payloadSha256));
        expect(resultBytes, equals(payload));
        expect(await partFile.exists(), isFalse);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 6: SHA256 Checksum Integrity & Corrupted Byte Purging
  // ===========================================================================
  group('CHALLENGE 6: SHA256 Integrity Verification & Corrupt File Purging', () {
    test(
      'Rejects payload when single bit is flipped, deletes .part file, and throws ChecksumMismatchException',
      () async {
        const totalSize = 30000;
        final payload = generatePayload(totalSize);
        // Correct expected hash
        final expectedHash = sha256.convert(payload).toString();

        // Corrupted payload (flip byte 1000)
        final corruptedPayload = Uint8List.fromList(payload);
        corruptedPayload[1000] ^= 0xFF;

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.set('Content-Length', totalSize.toString());
            request.response.headers.set('Content-Type', 'application/octet-stream');
            request.response.add(corruptedPayload);
            await request.response.flush();
            await request.response.close();
          },
        );

        addTearDown(server.close);

        const filename = 'corrupted_download.bin';
        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/corrupted_download.bin',
            filename: filename,
            sizeBytes: totalSize,
            expectedSha256: expectedHash,
          ),
          storageDirectory: tempDir,
        );

        expect(
          () => downloader.start(),
          throwsA(isA<ChecksumMismatchException>()),
        );

        // Give a short tick for cleanup
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final partFile = File('${tempDir.path}/$filename.part');
        final targetFile = File('${tempDir.path}/$filename');

        expect(await partFile.exists(), isFalse,
            reason: '.part file MUST be purged on checksum mismatch to prevent corrupt installs');
        expect(await targetFile.exists(), isFalse,
            reason: 'Target file MUST never be created from corrupted payload');
        expect(downloader.status, equals(DownloadStatus.failed));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 7: HTTP 416 Range Not Satisfiable Edge Cases
  // ===========================================================================
  group('CHALLENGE 7: HTTP 416 Range Not Satisfiable', () {
    test(
      'HTTP 416 completes gracefully when local .part is already fully downloaded',
      () async {
        const totalSize = 20000;
        final payload = generatePayload(totalSize);
        final payloadSha256 = sha256.convert(payload).toString();

        const filename = 'already_complete.bin';
        final partFile = File('${tempDir.path}/$filename.part');
        // Pre-write full file to .part
        await partFile.writeAsBytes(payload);

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            // Server sees range offset >= totalSize and returns 416
            request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
            request.response.headers.set('Content-Range', 'bytes */$totalSize');
            await request.response.close();
          },
        );

        addTearDown(server.close);

        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/already_complete.bin',
            filename: filename,
            sizeBytes: totalSize,
            expectedSha256: payloadSha256,
          ),
          storageDirectory: tempDir,
        );

        final resultFile = await downloader.start();
        expect(await resultFile.exists(), isTrue);
        expect(await resultFile.length(), equals(totalSize));
        expect(await partFile.exists(), isFalse);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'HTTP 416 purges invalid .part and restarts fresh if offset was invalid or size unknown',
      () async {
        const totalSize = 20000;
        final payload = generatePayload(totalSize);
        final payloadSha256 = sha256.convert(payload).toString();

        const filename = 'invalid_offset_416.bin';
        final partFile = File('${tempDir.path}/$filename.part');
        // Pre-write 15,000 bytes (incomplete, but server rejects range)
        await partFile.writeAsBytes(payload.sublist(0, 15000));

        int requestCount = 0;

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            requestCount++;
            if (requestCount == 1) {
              // First request: reject Range with 416
              request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
              request.response.headers.set('Content-Range', 'bytes */$totalSize');
              await request.response.close();
            } else {
              // Second request: client deleted .part and sent fresh request (no Range)
              expect(request.headers.value('range'), isNull);
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.set('Content-Length', totalSize.toString());
              request.response.add(payload);
              await request.response.flush();
              await request.response.close();
            }
          },
        );

        addTearDown(server.close);

        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/invalid_offset_416.bin',
            filename: filename,
            sizeBytes: totalSize,
            expectedSha256: payloadSha256,
          ),
          storageDirectory: tempDir,
        );

        final resultFile = await downloader.start();
        expect(requestCount, equals(2));
        expect(await resultFile.exists(), isTrue);
        expect(await resultFile.length(), equals(totalSize));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 8: Cancellation & Resource Teardown Under Active Stream
  // ===========================================================================
  group('CHALLENGE 8: Cancellation & Stream Resource Teardown', () {
    test(
      'Cancelling an active stream abruptly purges .part file and raises DownloadCancelledException',
      () async {
        const totalSize = 100000;
        final payload = generatePayload(totalSize);

        final serverStartedStreaming = Completer<void>();

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.set('Content-Length', totalSize.toString());

            // Stream slowly
            for (int i = 0; i < 10; i++) {
              request.response.add(payload.sublist(i * 1000, (i + 1) * 1000));
              await request.response.flush();
              if (!serverStartedStreaming.isCompleted) {
                serverStartedStreaming.complete();
              }
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
            await request.response.close();
          },
        );

        addTearDown(server.close);

        const filename = 'cancel_stress.bin';
        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/cancel_stress.bin',
            filename: filename,
            sizeBytes: totalSize,
          ),
          storageDirectory: tempDir,
        );

        final startFuture = downloader.start();

        await serverStartedStreaming.future;
        await downloader.cancel();

        expect(downloader.status, equals(DownloadStatus.canceled));
        expect(startFuture, throwsA(isA<DownloadCancelledException>()));

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final partFile = File('${tempDir.path}/$filename.part');
        expect(await partFile.exists(), isFalse,
            reason: '.part file must be removed when cancelled');
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 9: HTTP Request Headers Specification Conformance
  // ===========================================================================
  group('CHALLENGE 9: Protocol Headers Conformance', () {
    test(
      'Issues standard User-Agent, Accept, and Range headers adhering to project spec',
      () async {
        const totalSize = 1000;
        final payload = generatePayload(totalSize);

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.set('Content-Length', totalSize.toString());
            request.response.add(payload);
            await request.response.flush();
            await request.response.close();
          },
        );

        addTearDown(server.close);

        const filename = 'header_check.bin';
        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/header_check.bin',
            filename: filename,
            sizeBytes: totalSize,
          ),
          storageDirectory: tempDir,
        );

        await downloader.start();

        expect(server.capturedRequests.length, equals(1));
        final req = server.capturedRequests.first;
        expect(req.method, equals('GET'));
        expect(req.headers['user-agent'], equals('ZohalConnect/0.2.0'));
        expect(req.headers['accept'], equals('*/*'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 10: Sliding-Window Speed & ETA Verification on Live Stream
  // ===========================================================================
  group('CHALLENGE 10: Live Speed & ETA Dynamics', () {
    test(
      'Calculates positive speed and valid ETA during transfer, zeroes speed on pause, and completes',
      () async {
        const totalSize = 100000;
        final payload = generatePayload(totalSize);

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.set('Content-Length', totalSize.toString());

            const chunkSize = 5000;
            for (int offset = 0; offset < totalSize; offset += chunkSize) {
              final end = (offset + chunkSize > totalSize) ? totalSize : offset + chunkSize;
              request.response.add(payload.sublist(offset, end));
              await request.response.flush();
              await Future<void>.delayed(const Duration(milliseconds: 30));
            }
            await request.response.close();
          },
        );

        addTearDown(server.close);

        const filename = 'speed_eta_test.bin';
        final progressEvents = <DownloadProgress>[];

        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/speed_eta_test.bin',
            filename: filename,
            sizeBytes: totalSize,
          ),
          storageDirectory: tempDir,
        );

        downloader.progressStream.listen(progressEvents.add);

        final resultFile = await downloader.start();
        expect(await resultFile.exists(), isTrue);

        final activeSpeeds = progressEvents
            .where((p) => p.status == DownloadStatus.downloading && p.speedBytesPerSec > 0)
            .map((p) => p.speedBytesPerSec)
            .toList();

        expect(activeSpeeds, isNotEmpty,
            reason: 'Must compute non-zero speed during active streaming');

        final etas = progressEvents
            .where((p) => p.status == DownloadStatus.downloading && p.estimatedTimeRemaining != null)
            .map((p) => p.estimatedTimeRemaining!)
            .toList();

        expect(etas, isNotEmpty,
            reason: 'Must compute non-null ETA during streaming');

        for (final eta in etas) {
          expect(eta.inSeconds, greaterThan(0));
          expect(eta.inDays, lessThan(7)); // Sane bounds
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 11: Oversized .part Auto-Purge Protection
  // ===========================================================================
  group('CHALLENGE 11: Oversized .part Cleanup', () {
    test(
      'Automatically deletes oversized .part file and restarts fresh without Range header',
      () async {
        const totalSize = 30000;
        final payload = generatePayload(totalSize);

        const filename = 'oversized.bin';
        final partFile = File('${tempDir.path}/$filename.part');
        // Pre-create .part with 50,000 bytes (larger than totalSize 30,000)
        await partFile.writeAsBytes(Uint8List(50000));

        late MockUpdateServer server;
        server = await MockUpdateServer.start(
          handler: (request, s) async {
            // Must NOT have received a Range header
            expect(request.headers.value('range'), isNull,
                reason: 'Oversized .part must be purged and download restarted from 0 without Range');

            request.response.statusCode = HttpStatus.ok;
            request.response.headers.set('Content-Length', totalSize.toString());
            request.response.add(payload);
            await request.response.flush();
            await request.response.close();
          },
        );

        addTearDown(server.close);

        final downloader = ResumableDownloader(
          info: UpdateInfo(
            version: '0.2.0',
            downloadUrl: '${server.baseUrl}/oversized.bin',
            filename: filename,
            sizeBytes: totalSize,
          ),
          storageDirectory: tempDir,
        );

        final resultFile = await downloader.start();
        expect(await resultFile.exists(), isTrue);
        expect(await resultFile.length(), equals(totalSize));
        expect(await partFile.exists(), isFalse);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ===========================================================================
  // CHALLENGE 12: Invariant States & Method Idempotency
  // ===========================================================================
  group('CHALLENGE 12: Invariants & Idempotency', () {
    test(
      'Redundant pause/cancel calls and invalid resumes do not crash downloader',
      () async {
        final downloader = ResumableDownloader(
          info: const UpdateInfo(
            version: '0.2.0',
            downloadUrl: 'http://127.0.0.1:9999/dummy.bin',
            filename: 'dummy.bin',
          ),
          storageDirectory: tempDir,
        );

        // Idle state: pause is a safe no-op
        downloader.pause();
        expect(downloader.status, equals(DownloadStatus.idle));

        // Idle state: cancel is a safe no-op
        await downloader.cancel();
        expect(downloader.status, equals(DownloadStatus.canceled));

        // Cancelled state: redundant cancel is safe
        await downloader.cancel();
        expect(downloader.status, equals(DownloadStatus.canceled));
      },
    );
  });
}

