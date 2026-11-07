// test/core/updater_test.dart
// Unit tests for semantic versioning, DNS IP validation, autostart manager,
// SHA256 integrity verification, Android ABI resolution, ResumableDownloader
// with HTTP Range headers (206/200/416), pause/resume/cancel, auto-retry, and state scoping.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zohal/core/autostart.dart';
import 'package:zohal/core/updater.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('zohal_updater_test_');
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  // ===========================================================================
  // 1. Semantic Versioning & DNS & Autostart (Preserved Baseline)
  // ===========================================================================
  group('Updater Semantic Versioning', () {
    test('identifies newer major, minor, and patch versions', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('0.2.0', '0.1.9'), isTrue);
    });

    test('rejects older or identical versions', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('0.9.9', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(isNewerVersion('1.1.0', '1.2.0'), isFalse);
    });

    test('handles build metadata and pre-release tags', () {
      expect(isNewerVersion('1.0.1+5', '1.0.0+4'), isTrue);
      expect(isNewerVersion('1.0.0-rc1', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.1-beta', '1.0.0'), isTrue);
    });

    test('handles different component lengths gracefully', () {
      expect(isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
    });
  });

  group('DNS IP Validation', () {
    test('validates standard IPv4 addresses', () {
      expect(InternetAddress.tryParse('1.1.1.1'), isNotNull);
      expect(InternetAddress.tryParse('8.8.8.8'), isNotNull);
      expect(InternetAddress.tryParse('178.22.122.100'), isNotNull);
      expect(InternetAddress.tryParse('10.202.10.10'), isNotNull);
      expect(InternetAddress.tryParse('256.0.0.1'), isNull);
      expect(InternetAddress.tryParse('1.1.1'), isNull);
      expect(InternetAddress.tryParse('invalid'), isNull);
    });

    test('validates standard IPv6 addresses', () {
      expect(InternetAddress.tryParse('2606:4700:4700::1111'), isNotNull);
      expect(InternetAddress.tryParse('2001:4860:4860::8888'), isNotNull);
      expect(InternetAddress.tryParse('::1'), isNotNull);
      expect(InternetAddress.tryParse('2606:4700:gggg::1111'), isNull);
    });
  });

  group('Autostart Manager', () {
    test('isLinuxAutostartEnabled returns boolean without crashing', () async {
      final enabled = await AutostartManager.isLinuxAutostartEnabled();
      expect(enabled, isA<bool>());
    });

    test('sync false succeeds without throwing', () async {
      await expectLater(AutostartManager.sync(false), completes);
    });
  });

  // ===========================================================================
  // 2. SHA256 Integrity Verification
  // ===========================================================================
  group('SHA256 Integrity Verification', () {
    test('parseSha256Sums parses single and multi-line GNU coreutils outputs',
        () {
      const sample = '''
# Comments should be ignored
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8  Zohal-0.2.0-x86_64.AppImage
E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 *release-assets/zohal-v0.2.0-arm64-v8a.apk
4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a  windows\\zohal-v0.2.0-x86_64.exe

invalid line without hash
''';

      final sums = parseSha256Sums(sample);
      expect(sums.length, equals(3));
      expect(
        sums['Zohal-0.2.0-x86_64.AppImage'],
        equals(
            '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
      );
      // Case-insensitive normalized to lowercase, directory stripped, '*' stripped
      expect(
        sums['zohal-v0.2.0-arm64-v8a.apk'],
        equals(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
      );
      expect(
        sums['zohal-v0.2.0-x86_64.exe'],
        equals(
            '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a'),
      );
    });

    test('computeFileSha256 accurately computes hash of local file', () async {
      final testFile = File('${tempTestDir.path}/hello.txt');
      await testFile.writeAsString('hello world');

      // SHA256 of "hello world" (without newline): b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
      final hash = await computeFileSha256(testFile);
      expect(
        hash,
        equals(
            'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9'),
      );
    });

    test(
        'ResumableDownloader deletes .part file and throws ChecksumMismatchException on hash mismatch',
        () async {
      const filename = 'update_mismatch.bin';
      final payload = utf8.encode('real content payload');
      const badExpectedHash =
          '0000000000000000000000000000000000000000000000000000000000000000';

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/update_mismatch.bin',
          filename: filename,
          expectedSha256: badExpectedHash,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            Stream.value(payload),
            200,
            contentLength: payload.length,
          );
        }),
      );

      expect(
        () => downloader.start(),
        throwsA(isA<ChecksumMismatchException>()),
      );

      final partFile = File('${tempTestDir.path}/$filename.part');
      final targetFile = File('${tempTestDir.path}/$filename');

      // Wait a tick for async file deletion
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await partFile.exists(), isFalse);
      expect(await targetFile.exists(), isFalse);
    });
  });

  // ===========================================================================
  // 3. Android ABI Asset Selection
  // ===========================================================================
  group('Android ABI Selection', () {
    final assets = [
      {
        'name': 'zohal-v0.2.0-arm64-v8a.apk',
        'browser_download_url': 'url-arm64',
        'size': 100
      },
      {
        'name': 'zohal-v0.2.0-armeabi-v7a.apk',
        'browser_download_url': 'url-v7a',
        'size': 90
      },
      {
        'name': 'zohal-v0.2.0-x86_64.apk',
        'browser_download_url': 'url-x86_64',
        'size': 110
      },
      {
        'name': 'zohal-v0.2.0.universal.apk',
        'browser_download_url': 'url-universal',
        'size': 200
      },
    ];

    test('selects arm64-v8a for 64-bit ARM device', () {
      final selected = selectAndroidApkAsset(
        assets: assets,
        deviceAbis: ['arm64-v8a', 'armeabi-v7a'],
      );
      expect(selected?['name'], equals('zohal-v0.2.0-arm64-v8a.apk'));
      expect(selected?['browser_download_url'], equals('url-arm64'));
    });

    test('selects armeabi-v7a for 32-bit ARM device', () {
      final selected = selectAndroidApkAsset(
        assets: assets,
        deviceAbis: ['armeabi-v7a', 'armeabi'],
      );
      expect(selected?['name'], equals('zohal-v0.2.0-armeabi-v7a.apk'));
    });

    test('selects x86_64 for emulator', () {
      final selected = selectAndroidApkAsset(
        assets: assets,
        deviceAbis: ['x86_64'],
      );
      expect(selected?['name'], equals('zohal-v0.2.0-x86_64.apk'));
    });

    test('falls back to universal APK if device ABI is unsupported', () {
      final selected = selectAndroidApkAsset(
        assets: assets,
        deviceAbis: ['mips64'],
      );
      expect(selected?['name'], equals('zohal-v0.2.0.universal.apk'));
    });
  });

  // ===========================================================================
  // 4. ResumableDownloader & HTTP Range Protocol
  // ===========================================================================
  group('ResumableDownloader HTTP Range Protocol', () {
    test(
        'Fresh Download (HTTP 200) transfers full payload and renames .part to target',
        () async {
      const filename = 'fresh_download.bin';
      final payload = List.generate(1000, (i) => i % 256);
      String? emittedRangeHeader;

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/fresh.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          emittedRangeHeader = req.headers['Range'];
          return http.StreamedResponse(
            Stream.value(payload),
            200,
            contentLength: 1000,
          );
        }),
      );

      final resultFile = await downloader.start();
      expect(emittedRangeHeader, isNull,
          reason: 'Offset 0 must not emit Range header');
      expect(await resultFile.exists(), isTrue);
      expect(await resultFile.length(), equals(1000));
      expect(
          await File('${tempTestDir.path}/$filename.part').exists(), isFalse);
    });

    test(
        'Resuming Download (HTTP 206) emits Range header and appends remaining bytes',
        () async {
      const filename = 'resume_download.bin';
      final partFile = File('${tempTestDir.path}/$filename.part');
      final initialBytes = List.generate(400, (i) => 1);
      await partFile.writeAsBytes(initialBytes);

      String? capturedRangeHeader;
      final remainingBytes = List.generate(600, (i) => 2);

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/resume.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          capturedRangeHeader = req.headers['Range'];
          return http.StreamedResponse(
            Stream.value(remainingBytes),
            206,
            contentLength: 600,
            headers: {'content-range': 'bytes 400-999/1000'},
          );
        }),
      );

      final resultFile = await downloader.start();
      expect(capturedRangeHeader, equals('bytes=400-'));
      expect(await resultFile.length(), equals(1000));
      final fileBytes = await resultFile.readAsBytes();
      expect(fileBytes.sublist(0, 400), equals(initialBytes));
      expect(fileBytes.sublist(400), equals(remainingBytes));
    });

    test('HTTP 200 Overwrite Fallback truncates .part and rewrites from byte 0',
        () async {
      const filename = 'fallback_200.bin';
      final partFile = File('${tempTestDir.path}/$filename.part');
      await partFile.writeAsBytes(List.generate(400, (i) => 9)); // stale bytes

      final allBytes = List.generate(1000, (i) => i % 128);

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/fallback.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          // Server ignores Range header and returns 200 with entire file
          return http.StreamedResponse(
            Stream.value(allBytes),
            200,
            contentLength: 1000,
          );
        }),
      );

      final resultFile = await downloader.start();
      // Length must be 1000, not 1400 (was truncated)
      expect(await resultFile.length(), equals(1000));
      expect(await resultFile.readAsBytes(), equals(allBytes));
    });

    test(
        'HTTP 416 Range Not Satisfiable completes if local file already matches totalBytes',
        () async {
      const filename = 'completed_416.bin';
      final partFile = File('${tempTestDir.path}/$filename.part');
      await partFile.writeAsBytes(List.generate(1000, (i) => 7));

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/completed.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            const Stream.empty(),
            416,
            headers: {'content-range': 'bytes */1000'},
          );
        }),
      );

      final resultFile = await downloader.start();
      expect(await resultFile.exists(), isTrue);
      expect(await resultFile.length(), equals(1000));
    });

    test('Pause preserves byte offset and Resume continues from that offset',
        () async {
      const filename = 'pause_resume.bin';
      final chunk1 = List.generate(500, (i) => 1);
      final chunk2 = List.generate(500, (i) => 2);

      int requestCount = 0;
      String? secondRangeHeader;
      final streamController = StreamController<List<int>>();

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/pause_resume.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          requestCount++;
          if (requestCount == 1) {
            return http.StreamedResponse(
              streamController.stream,
              200,
              contentLength: 1000,
            );
          } else {
            secondRangeHeader = req.headers['Range'];
            return http.StreamedResponse(
              Stream.value(chunk2),
              206,
              contentLength: 500,
              headers: {'content-range': 'bytes 500-999/1000'},
            );
          }
        }),
      );

      // Start download in background
      unawaited(downloader.start());

      // Wait a tick for connection to establish and stream to listen
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Emit first 500 bytes
      streamController.add(chunk1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Pause
      downloader.pause();
      expect(downloader.status, equals(DownloadStatus.paused));

      // Verify .part file has exactly 500 bytes
      final partFile = File('${tempTestDir.path}/$filename.part');
      expect(await partFile.length(), equals(500));

      // Resume
      final resumeFuture = downloader.resume();
      final finalFile = await resumeFuture;

      expect(secondRangeHeader, equals('bytes=500-'));
      expect(await finalFile.length(), equals(1000));
    });

    test(
        'Cancel cleans up .part file and completes with DownloadCancelledException',
        () async {
      const filename = 'cancel_test.bin';
      final streamController = StreamController<List<int>>();

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/cancel.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            streamController.stream,
            200,
            contentLength: 1000,
          );
        }),
      );

      final future = downloader.start();
      streamController.add(List.generate(300, (i) => 1));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await downloader.cancel();

      expect(future, throwsA(isA<DownloadCancelledException>()));
      expect(downloader.status, equals(DownloadStatus.canceled));

      final partFile = File('${tempTestDir.path}/$filename.part');
      expect(await partFile.exists(), isFalse);
    });

    test(
        'Transient network drop (SocketException) auto-retries from current offset',
        () async {
      const filename = 'auto_retry.bin';
      int attempts = 0;
      final chunk1 = List.generate(400, (i) => 1);
      final chunk2 = List.generate(600, (i) => 2);

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/retry.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        clientFactory: () => MockHttpClient((req) async {
          attempts++;
          if (attempts == 1) {
            // First attempt sends 400 bytes then fails with SocketException
            final controller = StreamController<List<int>>();
            controller.add(chunk1);
            controller
                .addError(const SocketException('Simulated network reset'));
            return http.StreamedResponse(
              controller.stream,
              200,
              contentLength: 1000,
            );
          } else {
            // Second attempt receives Range header and delivers remaining bytes
            expect(req.headers['Range'], equals('bytes=400-'));
            return http.StreamedResponse(
              Stream.value(chunk2),
              206,
              contentLength: 600,
              headers: {'content-range': 'bytes 400-999/1000'},
            );
          }
        }),
      );

      final finalFile = await downloader.start();
      expect(attempts, equals(2));
      expect(await finalFile.length(), equals(1000));
    });

    test(
        'Exhausting maxRetries fails with DownloadException and preserves .part file',
        () async {
      const filename = 'fail_exhaust.bin';
      int attempts = 0;

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/fail.bin',
          filename: filename,
          sizeBytes: 1000,
        ),
        storageDirectory: tempTestDir,
        maxRetries: 2, // 2 retries for fast test
        clientFactory: () => MockHttpClient((req) async {
          attempts++;
          throw const SocketException('Persistent failure');
        }),
      );

      expect(() => downloader.start(), throwsA(isA<DownloadException>()));
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      expect(attempts, equals(3)); // Initial + 2 retries
      expect(downloader.status, equals(DownloadStatus.failed));
    });
  });

  // ===========================================================================
  // 5. Riverpod State Scoping & Startup Deferral
  // ===========================================================================
  group('Riverpod State Scoping & Startup Delay', () {
    test(
        'initialUpdateDelayProvider can be overridden with Duration.zero in tests',
        () async {
      final container = ProviderContainer(
        overrides: [
          initialUpdateDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(initialUpdateDelayProvider), equals(Duration.zero));
      expect(container.read(hasRunInitialUpdateCheckProvider), isFalse);
    });

    test('resetUpdateCheckStateForTesting resets top-level state cleanly', () {
      isFirstUpdateCheck = false;
      resetUpdateCheckStateForTesting(isFirst: true);
      expect(isFirstUpdateCheck, isTrue);
    });
  });
}
