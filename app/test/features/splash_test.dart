// test/features/splash_test.dart
// Verification tests for instant launch, splash frame 1 rendering, and transitions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/app.dart';
import 'package:zohal/design/components/brand_logo.dart';
import 'package:zohal/design/tokens.dart';
import 'package:zohal/features/connect/main_screen.dart';
import 'package:zohal/features/onboarding/onboarding_screen.dart';
import 'package:zohal/features/splash/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup & Splash Screen Verification (R1)', () {
    testWidgets('Warm up test framework and localization delegates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: ZohalApp(),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Frame 1 renders BrandLogo(size: 72.0) immediately during async loading',
      (WidgetTester tester) async {
        final completer = Completer<bool>();

        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingCompletedProvider
                  .overrideWith((ref) => completer.future),
            ],
            child: const ZohalApp(),
          ),
        );

        stopwatch.stop();

        // Verify cold start frame 1 timing is well under 250ms SLA
        expect(stopwatch.elapsedMilliseconds, lessThan(250));

        // Verify SplashScreen and BrandLogo are rendered immediately
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(BrandLogo), findsOneWidget);
        final logo = tester.widget<BrandLogo>(find.byType(BrandLogo));
        expect(logo.size, equals(72.0));

        // Verify BrandLogo is centered
        final centerFinder = find.ancestor(
          of: find.byType(BrandLogo),
          matching: find.byType(Center),
        );
        expect(centerFinder, findsOneWidget);

        // Verify neither MainScreen nor OnboardingScreen is present during splash
        expect(find.byType(MainScreen), findsNothing);
        expect(find.byType(OnboardingScreen), findsNothing);

        // Verify no generic loading spinner
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Clean up pending completer and allow deferred updater timer to settle
        completer.complete(true);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Transitions smoothly from Splash to MainScreen when onboarding is completed',
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

        // Verify splash state
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(BrandLogo), findsOneWidget);
        expect(find.byType(MainScreen), findsNothing);

        // Complete async resolution for existing user
        completer.complete(true);
        await tester.pumpAndSettle();

        // Verify transition to MainScreen
        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(OnboardingScreen), findsNothing);

        // Allow deferred updater 3s timer to fire
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Transitions smoothly from Splash to OnboardingScreen on first launch',
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

        // Verify splash state
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(BrandLogo), findsOneWidget);

        // Complete async resolution for new user
        completer.complete(false);
        await tester.pumpAndSettle();

        // Verify transition to OnboardingScreen
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(MainScreen), findsNothing);
      },
    );

    testWidgets(
      'Gracefully falls back to MainScreen on preference error',
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

        // Simulate storage failure
        completer.completeError(Exception('SharedPreferences I/O error'));
        await tester.pumpAndSettle();

        // Verify graceful fallback to MainScreen without crashing
        expect(find.byType(MainScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Allow deferred updater 3s timer to fire
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Enforces RTL directionality and dark surface aesthetics during splash',
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

        // Verify RTL directionality
        final directionality = Directionality.of(
          tester.element(find.byType(BrandLogo)),
        );
        expect(directionality, equals(TextDirection.rtl));

        // Verify background color of SplashScreen scaffold
        final splashScaffold = tester.widget<Scaffold>(
          find.descendant(
            of: find.byType(SplashScreen),
            matching: find.byType(Scaffold),
          ),
        );
        expect(splashScaffold.backgroundColor, equals(const Color(0xFF0A0D14)));

        // Clean up
        completer.complete(true);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'BrandLogo renders untinted in Dark mode',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: BrandLogo(size: 72.0),
            ),
          ),
        );
        final darkImage = tester.widget<Image>(find.byType(Image));
        expect(darkImage.color, isNull);
        expect(darkImage.width, equals(72.0));
        expect(darkImage.height, equals(72.0));
      },
    );

    testWidgets(
      'BrandLogo renders lightTextPrimary in Light mode',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            themeMode: ThemeMode.light,
            home: const Scaffold(
              body: BrandLogo(size: 72.0),
            ),
          ),
        );
        final lightImage = tester.widget<Image>(find.byType(Image));
        expect(lightImage.color, equals(ZohalTokens.lightTextPrimary));
        expect(lightImage.colorBlendMode, equals(BlendMode.srcIn));
        expect(lightImage.width, equals(72.0));
        expect(lightImage.height, equals(72.0));
      },
    );

    testWidgets(
      'SplashScreen maintains dark contrast context even in Light parent MaterialApp',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            themeMode: ThemeMode.light,
            home: const SplashScreen(),
          ),
        );
        final splashImage = tester.widget<Image>(find.byType(Image));
        expect(splashImage.color, isNull);
        expect(splashImage.width, equals(72.0));
        expect(splashImage.height, equals(72.0));
      },
    );
  });
}
