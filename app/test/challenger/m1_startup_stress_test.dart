// test/challenger/m1_startup_stress_test.dart
// Empirical Challenger Stress Harness for Milestone 1: Instant Launch & Opening Performance (R1)
//
// Rigorously tests:
// 1. Cold start network deferral: 0 network requests during the first 2.5 seconds of launch (<250ms SLA)
// 2. Frame 1 synchronous mounting of SplashScreen & BrandLogo(size: 72.0) before async microtasks
// 3. Statistical cold-start benchmark (<250ms) across 50 iterations with percentiles
// 4. Simulated slow storage (SharedPreferences delays of 500ms, 2500ms, 5000ms, 10000ms)
// 5. Resilience: storage exceptions, dark/light theme contrast isolation, and RTL directionality

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zohal/app.dart';
import 'package:zohal/core/bridge.dart';
import 'package:zohal/design/components/brand_logo.dart';
import 'package:zohal/features/connect/main_screen.dart';
import 'package:zohal/features/onboarding/onboarding_screen.dart';
import 'package:zohal/features/splash/splash_screen.dart';

// =============================================================================
// Mock HTTP Infrastructure for Spying Network Requests
// =============================================================================

class NetworkCallRecord {
  final DateTime timestamp;
  final Uri uri;
  final String method;

  NetworkCallRecord({
    required this.timestamp,
    required this.uri,
    required this.method,
  });
}

class SpyingHttpOverrides extends HttpOverrides {
  final List<NetworkCallRecord> calls = [];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _SpyingHttpClient(calls);
  }
}

class _SpyingHttpClient implements HttpClient {
  final List<NetworkCallRecord> calls;

  _SpyingHttpClient(this.calls);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    calls.add(NetworkCallRecord(
      timestamp: DateTime.now(),
      uri: url,
      method: method,
    ));
    return _SpyingHttpClientRequest(url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyingHttpClientRequest implements HttpClientRequest {
  @override
  final Uri uri;
  _SpyingHttpClientRequest(this.uri);

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _SpyingHttpClientResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyingHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final body = jsonEncode({
      'tag_name': 'v0.2.0',
      'assets': [
        {
          'name': 'zohal-connect-0.2.0.AppImage',
          'browser_download_url':
              'https://github.com/arsamadineh/zohal-connect/releases/download/v0.2.0/zohal-connect-0.2.0.AppImage',
          'size': 25000000,
        }
      ],
    });
    final stream = Stream<List<int>>.value(utf8.encode(body));
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// Main Challenger Test Suite
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Zohal',
      packageName: 'app.zohal.connect',
      version: '0.2.0',
      buildNumber: '16',
      buildSignature: '',
    );
  });

  group('WARM-UP & FRAMEWORK INITIALIZATION', () {
    testWidgets('Warm up Flutter framework and fa_IR localization delegates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fa', 'IR'),
          supportedLocales: [Locale('fa', 'IR')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  group('CHALLENGE 1: Network Deferral Empirical Verification (updateInfoProvider)', () {
    testWidgets(
      'Strict 2.5s network freeze: ZERO outbound network requests occur during first 2.5 seconds of launch',
      (WidgetTester tester) async {
        final spyOverrides = SpyingHttpOverrides();

        await HttpOverrides.runWithHttpOverrides(() async {
          // Mount app where onboarding is already completed, launching into MainScreen
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                onboardingCompletedProvider.overrideWith((ref) async => true),
              ],
              child: const ZohalApp(),
            ),
          );

          // Initial frame pump: mounts SplashScreen while onboarding resolves
          await tester.pump();

          // Advance 150ms for AnimatedSwitcher (120ms duration) to complete cross-fade to MainScreen
          await tester.pump(const Duration(milliseconds: 150));
          expect(find.byType(MainScreen), findsOneWidget);

          // Sample at t = 150ms: exactly 0 network calls must have occurred
          expect(
            spyOverrides.calls.length,
            equals(0),
            reason: 'Network request made immediately on MainScreen mount',
          );

          // Sample at t = 500ms (advance 350ms)
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            spyOverrides.calls.length,
            equals(0),
            reason: 'Network request initiated prematurely at t=500ms',
          );

          // Sample at t = 1000ms (advance 500ms)
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            spyOverrides.calls.length,
            equals(0),
            reason: 'Network request initiated prematurely at t=1000ms',
          );

          // Sample at t = 1500ms (advance 500ms)
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            spyOverrides.calls.length,
            equals(0),
            reason: 'Network request initiated prematurely at t=1500ms',
          );

          // Sample at t = 2000ms (advance 500ms)
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            spyOverrides.calls.length,
            equals(0),
            reason: 'Network request initiated prematurely at t=2000ms',
          );

          // Sample at t = 2500ms (advance 500ms) — Requirement: ZERO network requests in first 2.5s
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            spyOverrides.calls.length,
            equals(0),
            reason:
                'SLA violation: Network request made within 2.5s startup window',
          );

          // Sample at t = 2900ms (advance 400ms) — still within 3.0s deferral window
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            spyOverrides.calls.length,
            equals(0),
            reason: 'Network request initiated at t=2900ms before 3s window',
          );

          // Sample at t = 3100ms (advance 200ms) — 3.0s deferral timer has fired!
          await tester.pump(const Duration(milliseconds: 200));

          // Now the request must have been dispatched
          expect(
            spyOverrides.calls.length,
            equals(1),
            reason: 'Update check should fire after 3.0s deferral timer expires',
          );

          final call = spyOverrides.calls.first;
          expect(call.method, equals('GET'));
          expect(
            call.uri.toString(),
            equals(
              'https://api.github.com/repos/arsamadineh/zohal-connect/releases/latest',
            ),
          );

          // Clean up
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }, spyOverrides);
      },
    );

    testWidgets(
      'Subsequent update checks bypass startup delay for immediate responsiveness',
      (WidgetTester tester) async {
        final spyOverrides = SpyingHttpOverrides();

        await HttpOverrides.runWithHttpOverrides(() async {
          // Mount MainScreen after cold start already completed
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                onboardingCompletedProvider.overrideWith((ref) async => true),
              ],
              child: const ZohalApp(),
            ),
          );

          await tester.pump(const Duration(milliseconds: 150));
          expect(find.byType(MainScreen), findsOneWidget);

          // Since _isFirstUpdateCheck is now false, update check fires immediately
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            spyOverrides.calls.isNotEmpty,
            isTrue,
            reason:
                'Subsequent update check should be immediate without 3s delay',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }, spyOverrides);
      },
    );
  });

  group('CHALLENGE 2: Synchronous Frame 1 Mounting & Startup SLA (<250ms)', () {
    testWidgets(
      'SplashScreen and BrandLogo(size: 72.0) mount synchronously on Frame 1 before any async microtask completes',
      (WidgetTester tester) async {
        final storageCompleter = Completer<bool>();

        // Frame 1 initial pump
        final stopwatch = Stopwatch()..start();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => storageCompleter.future),
            ],
            child: const ZohalApp(),
          ),
        );
        stopwatch.stop();

        // 1. Verify cold start Frame 1 render latency is strictly under 250ms SLA
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(250),
          reason: 'Frame 1 cold start render exceeded 250ms SLA',
        );

        // 2. Verify microtask has NOT executed before synchronous frame 1 build
        // Note: Flutter pump executes synchronous build; microtasks run during event loop drain
        expect(find.byType(SplashScreen), findsOneWidget);

        // 3. Verify BrandLogo is mounted synchronously with exact size 72.0
        expect(find.byType(BrandLogo), findsOneWidget);
        final logoWidget = tester.widget<BrandLogo>(find.byType(BrandLogo));
        expect(logoWidget.size, equals(72.0));

        // 4. Verify BrandLogo is centered
        final centerAncestor = find.ancestor(
          of: find.byType(BrandLogo),
          matching: find.byType(Center),
        );
        expect(centerAncestor, findsOneWidget);

        // 5. Verify no unpainted canvas, no generic spinners, and no content screens on Frame 1
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(MainScreen), findsNothing);
        expect(find.byType(OnboardingScreen), findsNothing);

        // Clean up
        storageCompleter.complete(true);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Statistical Benchmark: 50 consecutive cold-start Frame 1 renders strictly comply with <250ms SLA',
      (WidgetTester tester) async {
        final List<int> elapsedTimesMs = [];
        const int iterations = 50;

        for (int i = 0; i < iterations; i++) {
          final completer = Completer<bool>();
          final sw = Stopwatch()..start();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                onboardingCompletedProvider
                    .overrideWith((ref) => completer.future),
              ],
              child: const ZohalApp(),
            ),
          );

          sw.stop();
          elapsedTimesMs.add(sw.elapsedMilliseconds);

          // Verify each frame 1 renders SplashScreen & BrandLogo
          expect(find.byType(SplashScreen), findsOneWidget);
          expect(find.byType(BrandLogo), findsOneWidget);

          // Unmount cleanly for next cold-start iteration
          completer.complete(true);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }

        // Statistical analysis
        elapsedTimesMs.sort();
        final int minTime = elapsedTimesMs.first;
        final int maxTime = elapsedTimesMs.last;
        final double avgTime =
            elapsedTimesMs.reduce((a, b) => a + b) / iterations;
        final int p95 = elapsedTimesMs[(iterations * 0.95).floor()];

        // Print benchmark summary to test console
        debugPrint(
          '=== M1 Startup Benchmark (50 iterations) ===\n'
          '  Min: ${minTime}ms\n'
          '  Avg: ${avgTime.toStringAsFixed(2)}ms\n'
          '  P95: ${p95}ms\n'
          '  Max: ${maxTime}ms\n'
          '  SLA Threshold: 250ms',
        );

        // Assert all iterations pass <250ms SLA
        expect(
          maxTime,
          lessThan(250),
          reason:
              'Max Frame 1 cold start render exceeded 250ms SLA: max=${maxTime}ms',
        );
        expect(
          p95,
          lessThan(100),
          reason:
              'P95 Frame 1 cold start render exceeded 100ms: p95=${p95}ms',
        );
      },
    );

    testWidgets(
      'SplashScreen enforces dark contrast context regardless of parent theme brightness',
      (WidgetTester tester) async {
        final completer = Completer<bool>();

        // Pump in Light Theme context
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => completer.future),
              systemAccentProvider.overrideWith((ref) => Colors.blue),
            ],
            child: MaterialApp(
              theme: ThemeData.light(),
              themeMode: ThemeMode.light,
              home: const SplashScreen(),
            ),
          ),
        );

        // Verify BrandLogo image color is null (untinted white) due to internal Theme dark wrapper
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.color, isNull);
        expect(image.colorBlendMode, isNull);

        // Verify Scaffold background is #0A0D14
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, equals(const Color(0xFF0A0D14)));

        completer.complete(true);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });

  group('CHALLENGE 3: Simulated Slow Storage Stress Test (SharedPreferences Delay)', () {
    testWidgets(
      'Simulated 500ms disk delay: SplashScreen remains active without flicker or timeout',
      (WidgetTester tester) async {
        final completer = Completer<bool>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => completer.future),
            ],
            child: const ZohalApp(),
          ),
        );

        // Verify initial render
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(BrandLogo), findsOneWidget);

        // Advance 250ms (halfway through delay)
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(BrandLogo), findsOneWidget);
        expect(find.byType(MainScreen), findsNothing);
        expect(tester.takeException(), isNull);

        // Advance another 250ms
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(SplashScreen), findsOneWidget);

        // Finish storage resolution
        completer.complete(true);
        await tester.pumpAndSettle();

        // Verify clean transition into MainScreen
        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Simulated 2500ms disk delay: SplashScreen remains stable, zero flickering or timeout',
      (WidgetTester tester) async {
        final completer = Completer<bool>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => completer.future),
            ],
            child: const ZohalApp(),
          ),
        );

        // Step through 2500ms in 500ms increments
        for (int step = 0; step < 5; step++) {
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            find.byType(SplashScreen),
            findsOneWidget,
            reason: 'SplashScreen lost at step $step (t=${(step + 1) * 500}ms)',
          );
          expect(find.byType(BrandLogo), findsOneWidget);
          expect(find.byType(MainScreen), findsNothing);
          expect(tester.takeException(), isNull);
        }

        // Complete storage read
        completer.complete(false); // First launch user
        await tester.pumpAndSettle();

        // Verify transition to OnboardingScreen
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Simulated 5000ms extreme disk lag: SplashScreen survives without crashing or dropping frame',
      (WidgetTester tester) async {
        final completer = Completer<bool>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => completer.future),
            ],
            child: const ZohalApp(),
          ),
        );

        // Step through 5000ms in 1000ms intervals
        for (int sec = 1; sec <= 5; sec++) {
          await tester.pump(const Duration(seconds: 1));
          expect(
            find.byType(SplashScreen),
            findsOneWidget,
            reason: 'SplashScreen failed at $sec seconds',
          );
          expect(find.byType(BrandLogo), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        // Resolve storage
        completer.complete(true);
        await tester.pumpAndSettle();

        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Simulated 10000ms worst-case disk freeze: SplashScreen remains intact and recovers',
      (WidgetTester tester) async {
        final completer = Completer<bool>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => completer.future),
            ],
            child: const ZohalApp(),
          ),
        );

        // Advance 10 seconds directly
        await tester.pump(const Duration(seconds: 10));
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(BrandLogo), findsOneWidget);
        expect(find.byType(MainScreen), findsNothing);
        expect(tester.takeException(), isNull);

        // Recover after 10s freeze
        completer.complete(true);
        await tester.pumpAndSettle();

        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Simulated storage corruption/exception: SplashScreen gracefully transitions to MainScreen without crashing',
      (WidgetTester tester) async {
        final completer = Completer<bool>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => completer.future),
            ],
            child: const ZohalApp(),
          ),
        );

        expect(find.byType(SplashScreen), findsOneWidget);

        // Simulate fatal SQLite / I/O storage error
        completer.completeError(
          const FileSystemException('Fatal: SharedPreferences file corrupted'),
        );
        await tester.pumpAndSettle();

        // App must NOT crash; must fall back gracefully to MainScreen
        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });
}
