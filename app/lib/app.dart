// app.dart
// Root Application widget for Zohal Connect according to ZOHAL_SPEC Section 14.9.
// RTL enforcement, fa_IR locale, Material 3 sharp theme, dynamic light/dark.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bridge.dart';
import 'design/theme.dart';
import 'features/connect/main_screen.dart';
import 'l10n/strings_fa.dart';

class ZohalApp extends ConsumerWidget {
  const ZohalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemAccent = ref.watch(systemAccentProvider);

    return MaterialApp(
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
      home: const MainScreen(),
    );
  }
}
