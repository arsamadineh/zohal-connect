// test/challenger/m2_2_checksum_install_stress_test.dart
// Adversarial Challenger 2 Test Suite for Milestone 2 (R2):
// 1. Bit-flip attacks & SHA256 checksum integrity verification
// 2. Malformed SHA256SUMS.txt (empty, whitespace, CRLF, corrupt, multi-entry)
// 3. Rapid UI button toggling (Pause -> Resume -> Pause -> Cancel race conditions)
// 4. Installation failure modes & platform fallback edge cases

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zohal/core/updater.dart';
import 'package:zohal/design/components/sharp_button.dart';
import 'package:zohal/features/about/update_dialog.dart';
import 'package:zohal/l10n/strings_fa.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

class _TestMockDownloader implements IResumableDownloader {
  final StreamController<DownloadProgress> _controller =
      StreamController<DownloadProgress>.broadcast(sync: true);

  DownloadProgress _progress = DownloadProgress.idle(100000);
  int pauseCalls = 0;
  int resumeCalls = 0;
  int cancelCalls = 0;

  @override
  Stream<DownloadProgress> get progressStream => _controller.stream;

  @override
  DownloadProgress get currentProgress => _progress;

  @override
  Future<File> start({
    UpdateInfo? info,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
  }) async {
    _progress = const DownloadProgress(
      bytesReceived: 10000,
      totalBytes: 100000,
      progressFraction: 0.1,
      speedBytesPerSec: 1024 * 100,
      status: DownloadStatus.downloading,
    );
    _controller.add(_progress);
    return Completer<File>().future;
  }

  @override
  void pause() {
    pauseCalls++;
    _progress = DownloadProgress(
      bytesReceived: _progress.bytesReceived,
      totalBytes: _progress.totalBytes,
      progressFraction: _progress.progressFraction,
      speedBytesPerSec: 0.0,
      status: DownloadStatus.paused,
    );
    _controller.add(_progress);
  }

  @override
  Future<File> resume() async {
    resumeCalls++;
    _progress = DownloadProgress(
      bytesReceived: _progress.bytesReceived,
      totalBytes: _progress.totalBytes,
      progressFraction: _progress.progressFraction,
      speedBytesPerSec: 1024 * 100,
      status: DownloadStatus.downloading,
    );
    _controller.add(_progress);
    return Completer<File>().future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _progress = DownloadProgress(
      bytesReceived: _progress.bytesReceived,
      totalBytes: _progress.totalBytes,
      progressFraction: _progress.progressFraction,
      speedBytesPerSec: 0.0,
      status: DownloadStatus.canceled,
    );
    _controller.add(_progress);
  }
}

Widget createTestDialogWidget({
  required UpdateInfo info,
  IResumableDownloader? downloader,
}) {
  return MaterialApp(
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              UpdateDialog.show(context, info, downloader: downloader);
            },
            child: const Text('نمایش دیالوگ'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zohal_challenger_m2_2_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  Uint8List generatePayload(int size) {
    final data = Uint8List(size);
    for (int i = 0; i < size; i++) {
      data[i] = (i * 37 + 13) & 0xFF;
    }
    return data;
  }

  // ===========================================================================
  // 1. Bit-Flip Attacks & Checksum Integrity Verification
  // ===========================================================================
  group('1. Bit-Flip Attacks & SHA256 Integrity Verification', () {
    test('Bit-flip attack at byte 0 (MSB) purges .part and prevents replacement', () async {
      const filename = 'zohal-bitflip-byte0.AppImage';
      final validPayload = generatePayload(10000);
      final expectedSha256 = sha256.convert(validPayload).toString();

      // Inject flipped MSB at byte 0
      final corruptedPayload = Uint8List.fromList(validPayload);
      corruptedPayload[0] ^= 0x80;

      final partFile = File('${tempDir.path}/$filename.part');
      final targetFile = File('${tempDir.path}/$filename');

      final downloader = ResumableDownloader(
        info: UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/$filename',
          filename: filename,
          sizeBytes: validPayload.length,
          expectedSha256: expectedSha256,
        ),
        storageDirectory: tempDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            Stream.value(corruptedPayload),
            200,
            contentLength: corruptedPayload.length,
          );
        }),
      );

      // Verify that ChecksumMismatchException is thrown
      expect(
        downloader.start(),
        throwsA(isA<ChecksumMismatchException>()),
      );

      // Allow completion handler to finish
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert .part file is unconditionally deleted
      expect(await partFile.exists(), isFalse,
          reason: 'Corrupted .part file must be deleted immediately');

      // Assert target file was NEVER created
      expect(await targetFile.exists(), isFalse,
          reason: 'Target file must not be created or replaced on checksum failure');

      expect(downloader.status, equals(DownloadStatus.failed));
    });

    test('Bit-flip attack at the final byte (LSB) purges .part and fails gracefully', () async {
      const filename = 'zohal-bitflip-lastbyte.AppImage';
      final validPayload = generatePayload(8192);
      final expectedSha256 = sha256.convert(validPayload).toString();

      // Inject flipped LSB at the last byte
      final corruptedPayload = Uint8List.fromList(validPayload);
      corruptedPayload[corruptedPayload.length - 1] ^= 0x01;

      final partFile = File('${tempDir.path}/$filename.part');
      final targetFile = File('${tempDir.path}/$filename');

      final downloader = ResumableDownloader(
        info: UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/$filename',
          filename: filename,
          sizeBytes: validPayload.length,
          expectedSha256: expectedSha256,
        ),
        storageDirectory: tempDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            Stream.value(corruptedPayload),
            200,
            contentLength: corruptedPayload.length,
          );
        }),
      );

      expect(
        downloader.start(),
        throwsA(isA<ChecksumMismatchException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(await partFile.exists(), isFalse);
      expect(await targetFile.exists(), isFalse);
      expect(downloader.status, equals(DownloadStatus.failed));
    });

    test('Pre-existing valid target installation is preserved when download is corrupt', () async {
      const filename = 'zohal-preserve-target.AppImage';
      final oldPayload = utf8.encode('existing installed version 0.1.15');
      final targetFile = File('${tempDir.path}/$filename');
      await targetFile.writeAsBytes(oldPayload);

      final newPayload = generatePayload(5000);
      final corruptedNewPayload = Uint8List.fromList(newPayload);
      corruptedNewPayload[100] ^= 0xFF; // Invert all 8 bits at byte 100

      final downloader = ResumableDownloader(
        info: UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/$filename',
          filename: filename,
          sizeBytes: newPayload.length,
          expectedSha256: sha256.convert(newPayload).toString(),
        ),
        storageDirectory: tempDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            Stream.value(corruptedNewPayload),
            200,
            contentLength: corruptedNewPayload.length,
          );
        }),
      );

      expect(downloader.start(), throwsA(isA<ChecksumMismatchException>()));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Crucial: target file must still exist and retain old content
      expect(await targetFile.exists(), isTrue);
      expect(await targetFile.readAsBytes(), equals(oldPayload));

      final partFile = File('${tempDir.path}/$filename.part');
      expect(await partFile.exists(), isFalse);
    });

    test('Bit-flip injected into pre-existing .part file triggers mismatch on resumption', () async {
      const filename = 'zohal-corrupt-part.AppImage';
      const totalSize = 10000;
      final fullPayload = generatePayload(totalSize);
      final expectedSha256 = sha256.convert(fullPayload).toString();

      // Write 4000 bytes to .part, but with a bit flipped at byte 500
      final initialBytes = Uint8List.fromList(fullPayload.sublist(0, 4000));
      initialBytes[500] ^= 0x40; // bit-flip
      final partFile = File('${tempDir.path}/$filename.part');
      await partFile.writeAsBytes(initialBytes);

      final remainingBytes = fullPayload.sublist(4000);

      final downloader = ResumableDownloader(
        info: UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/$filename',
          filename: filename,
          sizeBytes: totalSize,
          expectedSha256: expectedSha256,
        ),
        storageDirectory: tempDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            Stream.value(remainingBytes),
            206,
            contentLength: remainingBytes.length,
            headers: {'content-range': 'bytes 4000-9999/10000'},
          );
        }),
      );

      expect(downloader.start(), throwsA(isA<ChecksumMismatchException>()));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(await partFile.exists(), isFalse);
      expect(downloader.status, equals(DownloadStatus.failed));
    });

    test('Case-insensitive SHA256 matching succeeds with uppercase hex', () async {
      const filename = 'zohal-case-insensitive.AppImage';
      final payload = generatePayload(2048);
      // Uppercase hash
      final expectedSha256 = sha256.convert(payload).toString().toUpperCase();

      final downloader = ResumableDownloader(
        info: UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/$filename',
          filename: filename,
          sizeBytes: payload.length,
          expectedSha256: expectedSha256,
        ),
        storageDirectory: tempDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(
            Stream.value(payload),
            200,
            contentLength: payload.length,
          );
        }),
      );

      final resultFile = await downloader.start();
      expect(await resultFile.exists(), isTrue);
      expect(downloader.status, equals(DownloadStatus.readyToInstall));
    });
  });

  // ===========================================================================
  // 2. Malformed SHA256SUMS.txt Parsing & Error Handling
  // ===========================================================================
  group('2. Malformed SHA256SUMS.txt Parsing & Robustness', () {
    test('handles empty and whitespace-only SHA256SUMS.txt', () {
      expect(parseSha256Sums(''), isEmpty);
      expect(parseSha256Sums('   \n\t  \r\n   '), isEmpty);
    });

    test('handles Windows CRLF line endings and trailing spaces', () {
      const raw =
          "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9  app.AppImage\r\n"
          "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8 *app.apk\r\n";
      final map = parseSha256Sums(raw);
      expect(map.length, equals(2));
      expect(map['app.AppImage'],
          equals('b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9'));
      expect(map['app.apk'],
          equals('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'));
    });

    test('ignores comments, short hashes, long hashes, non-hex chars, and missing filenames', () {
      const malformedText = '''
# Top level comment
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8  valid.AppImage
# Another comment
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d   short_63_chars.AppImage
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d899 long_66_chars.AppImage
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542g8  non_hex_char_g.AppImage
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8  *
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8
not a hash at all
   5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8   *indented_valid.apk   
''';
      final map = parseSha256Sums(malformedText);
      expect(map.length, equals(2));
      expect(map.containsKey('valid.AppImage'), isTrue);
      expect(map.containsKey('indented_valid.apk'), isTrue);
      expect(map.containsKey('short_63_chars.AppImage'), isFalse);
      expect(map.containsKey('long_66_chars.AppImage'), isFalse);
      expect(map.containsKey('non_hex_char_g.AppImage'), isFalse);
    });

    test('strips Linux and Windows directory prefixes from filenames', () {
      const pathsText = '''
b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9  ./build/outputs/linux/zohal.AppImage
5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8 *artifacts\\windows\\zohal.exe
''';
      final map = parseSha256Sums(pathsText);
      expect(map['zohal.AppImage'],
          equals('b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9'));
      expect(map['zohal.exe'],
          equals('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'));
    });

    test('parses filenames containing internal spaces properly', () {
      const spaceText =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 *Zohal Connect Setup 0.2.0.AppImage\n';
      final map = parseSha256Sums(spaceText);
      expect(map['Zohal Connect Setup 0.2.0.AppImage'],
          equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    });
  });

  // ===========================================================================
  // 3. Rapid UI Button Toggling & Concurrency Stress Testing
  // ===========================================================================
  group('3. Rapid UI Button Toggling & Concurrency Stress', () {
    testWidgets('Rapid Pause -> Resume -> Pause -> Cancel clicks do not throw or corrupt UI', (
      WidgetTester tester,
    ) async {
      final mockDownloader = _TestMockDownloader();
      const testInfo = UpdateInfo(
        version: '0.2.0',
        downloadUrl: 'https://example.com/rapid_toggle.bin',
        filename: 'rapid_toggle.bin',
        sizeBytes: 100000,
      );

      await tester.pumpWidget(createTestDialogWidget(
        info: testInfo,
        downloader: mockDownloader,
      ));

      // Open dialog
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      // Click Download
      await tester.tap(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
      );
      await tester.pump();

      // 1. Pause
      await tester.tap(find.widgetWithText(SharpButton, StringsFa.updatePause));
      await tester.pump();
      expect(mockDownloader.pauseCalls, equals(1));
      expect(find.widgetWithText(SharpButton, StringsFa.updateResume), findsOneWidget);

      // 2. Resume
      await tester.tap(find.widgetWithText(SharpButton, StringsFa.updateResume));
      await tester.pump();
      expect(mockDownloader.resumeCalls, equals(1));
      expect(find.widgetWithText(SharpButton, StringsFa.updatePause), findsOneWidget);

      // 3. Pause again
      await tester.tap(find.widgetWithText(SharpButton, StringsFa.updatePause));
      await tester.pump();
      expect(mockDownloader.pauseCalls, equals(2));

      // 4. Cancel
      await tester.tap(find.widgetWithText(SharpButton, StringsFa.cancel));
      await tester.pumpAndSettle();
      expect(mockDownloader.cancelCalls, equals(1));

      // Verify no unhandled exception was thrown to Flutter framework
      expect(tester.takeException(), isNull);

      // Verify dialog was dismissed
      expect(find.byType(AlertDialog), findsNothing);
    });

    test('Rapid consecutive pause() calls are idempotent', () async {
      final streamController = StreamController<List<int>>();
      addTearDown(streamController.close);

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/idempotent.bin',
          filename: 'idempotent.bin',
          sizeBytes: 10000,
        ),
        storageDirectory: tempDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(streamController.stream, 200);
        }),
      );

      final future = downloader.start();
      unawaited(future.catchError((_) => File('')));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Call pause 5 times rapidly
      downloader.pause();
      downloader.pause();
      downloader.pause();
      downloader.pause();
      downloader.pause();

      expect(downloader.status, equals(DownloadStatus.paused));
      await downloader.cancel();
    });

    test('Probing concurrent start() calls reveals un-guarded async window in start()', () async {
      final streamController = StreamController<List<int>>();
      addTearDown(streamController.close);

      final downloader = ResumableDownloader(
        info: const UpdateInfo(
          version: '0.2.0',
          downloadUrl: 'https://example.com/concurrent.bin',
          filename: 'concurrent.bin',
          sizeBytes: 10000,
        ),
        storageDirectory: tempDir,
        clientFactory: () => MockHttpClient((req) async {
          return http.StreamedResponse(streamController.stream, 200);
        }),
      );

      // Call 1
      final f1 = downloader.start();
      unawaited(f1.catchError((_) => File('')));

      // Synchronous Call 2 (before event loop runs _runDownloadLoop)
      final f2 = downloader.start();
      unawaited(f2.catchError((_) => File('')));

      // Because _status is only set to connecting inside _runDownloadLoop,
      // synchronous double-call creates two distinct futures and two competing loops:
      expect(identical(f1, f2), isFalse,
          reason: 'Synchronous start() calls before event loop yield are not deduped');

      // Let event loop run to establish connecting state
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await downloader.cancel();
    });
  });

  // ===========================================================================
  // 4. Installation Edge Cases & Android ABI Matching
  // ===========================================================================
  group('4. Installation & Platform Edge Cases', () {
    test('Android ABI selector handles empty, universal, and mismatched device ABIs', () {
      final assets = [
        {
          'name': 'zohal-0.2.0-universal.apk',
          'browser_download_url': 'https://example.com/universal.apk',
          'size': 25000000,
        },
        {
          'name': 'zohal-0.2.0-arm64-v8a.apk',
          'browser_download_url': 'https://example.com/arm64.apk',
          'size': 20000000,
        },
        {
          'name': 'zohal-0.2.0-armeabi-v7a.apk',
          'browser_download_url': 'https://example.com/armv7.apk',
          'size': 18000000,
        },
      ];

      // 1. Matches arm64-v8a device
      final arm64Match = selectAndroidApkAsset(
        assets: assets,
        deviceAbis: ['arm64-v8a', 'armeabi-v7a'],
      );
      expect(arm64Match?['name'], equals('zohal-0.2.0-arm64-v8a.apk'));

      // 2. Matches 32-bit armeabi-v7a device
      final armv7Match = selectAndroidApkAsset(
        assets: assets,
        deviceAbis: ['armeabi-v7a'],
      );
      expect(armv7Match?['name'], equals('zohal-0.2.0-armeabi-v7a.apk'));

      // 3. Falls back to universal for unrecognized ABI (e.g. mips or riscv64)
      final fallbackMatch = selectAndroidApkAsset(
        assets: assets,
        deviceAbis: ['riscv64'],
      );
      expect(fallbackMatch?['name'], equals('zohal-0.2.0-universal.apk'));

      // 4. Returns null if asset list has no APKs
      final emptyMatch = selectAndroidApkAsset(
        assets: [
          {'name': 'zohal.AppImage', 'browser_download_url': 'https://example.com/app'},
        ],
        deviceAbis: ['arm64-v8a'],
      );
      expect(emptyMatch, isNull);
    });
  });
}
