// test/features/about/update_dialog_test.dart
// Comprehensive widget tests for UpdateDialog 7-phase state machine,
// pause/resume/cancel interactions, live speed/ETA, and sharp styling.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/core/persian.dart';
import 'package:zohal/core/updater.dart';
import 'package:zohal/design/components/sharp_button.dart';
import 'package:zohal/features/about/update_dialog.dart';
import 'package:zohal/l10n/strings_fa.dart';

class MockResumableDownloader implements IResumableDownloader {
  final StreamController<DownloadProgress> _controller =
      StreamController<DownloadProgress>.broadcast(sync: true);

  DownloadProgress _progress = DownloadProgress.idle(0);

  bool startCalled = false;
  bool pauseCalled = false;
  bool resumeCalled = false;
  bool cancelCalled = false;

  Completer<File>? startCompleter;
  Completer<File>? resumeCompleter;

  void emit(DownloadProgress progress) {
    _progress = progress;
    _controller.add(progress);
  }

  @override
  Stream<DownloadProgress> get progressStream => _controller.stream;

  @override
  DownloadProgress get currentProgress => _progress;

  @override
  Future<File> start({
    UpdateInfo? info,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
  }) {
    startCalled = true;
    startCompleter = Completer<File>();
    return startCompleter!.future;
  }

  @override
  void pause() {
    pauseCalled = true;
    emit(DownloadProgress(
      bytesReceived: _progress.bytesReceived,
      totalBytes: _progress.totalBytes,
      progressFraction: _progress.progressFraction,
      speedBytesPerSec: 0.0,
      status: DownloadStatus.paused,
    ));
  }

  @override
  Future<File> resume() {
    resumeCalled = true;
    resumeCompleter = Completer<File>();
    emit(DownloadProgress(
      bytesReceived: _progress.bytesReceived,
      totalBytes: _progress.totalBytes,
      progressFraction: _progress.progressFraction,
      speedBytesPerSec: 1024 * 512,
      status: DownloadStatus.downloading,
    ));
    return resumeCompleter!.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
    emit(DownloadProgress(
      bytesReceived: _progress.bytesReceived,
      totalBytes: _progress.totalBytes,
      progressFraction: _progress.progressFraction,
      speedBytesPerSec: 0.0,
      status: DownloadStatus.canceled,
    ));
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  const testInfo = UpdateInfo(
    version: '0.2.0',
    downloadUrl: 'https://example.com/zohal-0.2.0.AppImage',
    filename: 'zohal-0.2.0.AppImage',
    sizeBytes: 25000000,
    releaseNotes: 'ویژگی‌های نسخه جدید:\n- سرعت بالاتر\n- رفع خطای اتصال',
  );

  Widget createTestWidget({
    required MockResumableDownloader mockDownloader,
  }) {
    return MaterialApp(
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  UpdateDialog.show(
                    context,
                    testInfo,
                    downloader: mockDownloader,
                  );
                },
                child: const Text('نمایش دیالوگ'),
              ),
            );
          },
        ),
      ),
    );
  }

  group('UpdateDialog Widget & State Machine Tests', () {
    late MockResumableDownloader mockDownloader;

    setUp(() {
      mockDownloader = MockResumableDownloader();
    });

    tearDown(() {
      mockDownloader.dispose();
    });

    testWidgets(
        'Initial Idle State renders version, size, notes, and sharp buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      // 1. Verify Dialog Title
      expect(find.text(StringsFa.updateAvailableTitle), findsOneWidget);

      // 2. Verify Version formatted with Persian digits in LTR isolate
      final versionText =
          Persian.ltrIsolate(Persian.toPersianDigits(testInfo.version));
      expect(find.textContaining(versionText), findsOneWidget);

      // 3. Verify Formatted Size
      expect(
          find.text(Persian.formatBytes(testInfo.sizeBytes!)), findsOneWidget);

      // 4. Verify Release Notes
      expect(find.textContaining('ویژگی‌های نسخه جدید'), findsOneWidget);

      // 5. Verify Sharp Corners (BorderRadius.zero)
      final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final shape = alertDialog.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, equals(BorderRadius.zero));

      // 6. Verify Action Buttons (Later and Download&Install)
      expect(find.widgetWithText(SharpButton, StringsFa.updateLater),
          findsOneWidget);
      expect(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Later dismisses dialog cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.widgetWithText(SharpButton, StringsFa.updateLater));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
        'Download Progress displays speed, ETA, percentage, and Pause button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      // Tap Download & Install
      await tester.tap(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
      );
      await tester.pump();

      expect(mockDownloader.startCalled, isTrue);

      // Emit active download progress
      mockDownloader.emit(const DownloadProgress(
        bytesReceived: 12500000,
        totalBytes: 25000000,
        progressFraction: 0.5,
        speedBytesPerSec: 1024 * 1024 * 2.5, // 2.5 MB/s
        estimatedTimeRemaining: Duration(seconds: 5),
        status: DownloadStatus.downloading,
      ));
      await tester.pump();

      // Verify downloading indicator and text
      expect(find.text(StringsFa.updateDownloading), findsOneWidget);
      expect(find.textContaining('۵۰٪'), findsOneWidget);
      expect(find.textContaining('سرعت:'), findsOneWidget);
      expect(find.textContaining('۲٫۵ مگابایت/ث'), findsOneWidget);
      expect(find.textContaining('زمان باقی‌مانده:'), findsOneWidget);
      expect(find.textContaining('~۵ ثانیه'), findsOneWidget);

      // Verify buttons switched to Pause and Cancel
      expect(find.widgetWithText(SharpButton, StringsFa.updatePause),
          findsOneWidget);
      expect(
          find.widgetWithText(SharpButton, StringsFa.cancel), findsOneWidget);
    });

    testWidgets(
        'Pause and Resume transitions UI and invokes downloader handles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      // Start download
      await tester.tap(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
      );
      await tester.pump();

      // Emit downloading
      mockDownloader.emit(const DownloadProgress(
        bytesReceived: 10000000,
        totalBytes: 25000000,
        progressFraction: 0.4,
        speedBytesPerSec: 1000000,
        status: DownloadStatus.downloading,
      ));
      await tester.pump();

      // Tap Pause
      await tester.tap(find.widgetWithText(SharpButton, StringsFa.updatePause));
      await tester.pump();

      expect(mockDownloader.pauseCalled, isTrue);

      // UI must reflect paused state
      expect(find.text(StringsFa.updatePaused), findsOneWidget);
      expect(find.widgetWithText(SharpButton, StringsFa.updateResume),
          findsOneWidget);

      // Tap Resume
      await tester
          .tap(find.widgetWithText(SharpButton, StringsFa.updateResume));
      await tester.pump();

      expect(mockDownloader.resumeCalled, isTrue);
    });

    testWidgets('Retrying State displays reconnecting text and retry attempt', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
      );
      await tester.pump();

      mockDownloader.emit(const DownloadProgress(
        bytesReceived: 5000000,
        totalBytes: 25000000,
        progressFraction: 0.2,
        speedBytesPerSec: 0.0,
        status: DownloadStatus.retrying,
        retryAttempt: 2,
        maxRetries: 5,
      ));
      await tester.pump();

      expect(find.textContaining(StringsFa.updateReconnecting), findsOneWidget);
      expect(find.textContaining('۲ از ۵'), findsOneWidget);
      expect(find.widgetWithText(SharpButton, StringsFa.updateRetry),
          findsOneWidget);
      expect(
          find.widgetWithText(SharpButton, StringsFa.cancel), findsOneWidget);
    });

    testWidgets('Verifying State displays verification text',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
      );
      await tester.pump();

      mockDownloader.emit(const DownloadProgress(
        bytesReceived: 25000000,
        totalBytes: 25000000,
        progressFraction: 1.0,
        speedBytesPerSec: 0.0,
        status: DownloadStatus.verifying,
      ));
      await tester.pump();

      expect(find.text(StringsFa.updateVerifying), findsOneWidget);
    });

    testWidgets('Failure State renders error banner and allows Retry', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
      );
      await tester.pump();

      mockDownloader.emit(const DownloadProgress(
        bytesReceived: 5000000,
        totalBytes: 25000000,
        progressFraction: 0.2,
        speedBytesPerSec: 0.0,
        status: DownloadStatus.failed,
        errorMessage: 'خطای شبکه',
      ));
      await tester.pump();

      expect(find.text('خطای شبکه'), findsOneWidget);
      expect(find.widgetWithText(SharpButton, StringsFa.close), findsOneWidget);
      expect(find.widgetWithText(SharpButton, StringsFa.updateRetry),
          findsOneWidget);
    });

    testWidgets(
        'Tapping Cancel in downloading state invokes cancel and dismisses dialog',
        (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(mockDownloader: mockDownloader));
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SharpButton, StringsFa.updateDownloadAndInstall),
      );
      await tester.pump();

      mockDownloader.emit(const DownloadProgress(
        bytesReceived: 5000000,
        totalBytes: 25000000,
        progressFraction: 0.2,
        speedBytesPerSec: 500000,
        status: DownloadStatus.downloading,
      ));
      await tester.pump();

      await tester.tap(find.widgetWithText(SharpButton, StringsFa.cancel));
      await tester.pumpAndSettle();

      expect(mockDownloader.cancelCalled, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
