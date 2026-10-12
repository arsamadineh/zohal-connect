// app.dart
// Root Application widget for Zohal Connect according to ZOHAL_SPEC Section 14.9.
// RTL enforcement, fa_IR locale, Material 3 sharp theme, dynamic light/dark.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/bridge.dart';
import 'core/tray_service.dart';
import 'design/theme.dart';
import 'features/connect/main_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'l10n/strings_fa.dart';

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  } catch (_) {
    return true;
  }
});

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class ZohalApp extends ConsumerStatefulWidget {
  const ZohalApp({super.key});

  @override
  ConsumerState<ZohalApp> createState() => _ZohalAppState();
}

class _ZohalAppState extends ConsumerState<ZohalApp> {
  @override
  void initState() {
    super.initState();
    ref.read(trayServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    final systemAccent = ref.watch(systemAccentProvider);
    final onboarding = ref.watch(onboardingCompletedProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: StringsFa.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ZohalTheme.createTheme(isDark: false, systemAccent: systemAccent),
      darkTheme: ZohalTheme.createTheme(
        isDark: true,
        systemAccent: systemAccent,
      ),
      themeMode: ThemeMode.system, // Auto follow system light/dark per Rule
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: onboarding.when(
        data: (completed) =>
            completed ? const MainScreen() : const OnboardingScreen(),
        loading: () => const Scaffold(body: SizedBox.shrink()),
        error: (_, __) => const MainScreen(),
      ),
    );
  }
}
