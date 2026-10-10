// design/theme.dart
// Material 3 theme overrides for Zohal Connect according to ZOHAL_SPEC Section 12.2 & 12.3.
// Enforces zero border radius, hairline borders, no shadows, and Vazirmatn typography.

import 'package:flutter/material.dart';

import 'tokens.dart';

class ZohalTheme {
  ZohalTheme._();

  static const OutlinedBorder zeroBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.zero,
  );

  static ThemeData createTheme({required bool isDark, Color? systemAccent}) {
    final surface = isDark ? ZohalTokens.darkSurface : ZohalTokens.lightSurface;
    final surfaceRaised =
        isDark ? ZohalTokens.darkSurfaceRaised : ZohalTokens.lightSurfaceRaised;
    final hairline =
        isDark ? ZohalTokens.darkHairline : ZohalTokens.lightHairline;
    final textPrimary =
        isDark ? ZohalTokens.darkTextPrimary : ZohalTokens.lightTextPrimary;
    final textSecondary =
        isDark ? ZohalTokens.darkTextSecondary : ZohalTokens.lightTextSecondary;
    final error = isDark ? ZohalTokens.darkError : ZohalTokens.lightError;
    final accent = ZohalTokens.resolveAccent(systemAccent, isDark);

    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: ZohalTokens.fontFamily,
        fontSize: 40.0,
        height: 48.0 / 40.0,
        fontWeight: FontWeight.w300,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: ZohalTokens.fontFamily,
        fontSize: 22.0,
        height: 32.0 / 22.0,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: ZohalTokens.fontFamily,
        fontSize: 16.0,
        height: 28.0 / 16.0,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: ZohalTokens.fontFamily,
        fontSize: 15.0,
        height: 26.0 / 15.0,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: ZohalTokens.fontFamily,
        fontSize: 13.0,
        height: 22.0 / 13.0,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: ZohalTokens.fontFamily,
        fontSize: 12.0,
        height: 20.0 / 12.0,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: ZohalTokens.fontFamily,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      cardColor: surfaceRaised,
      dividerColor: hairline,
      splashFactory: NoSplash.splashFactory,
      highlightColor: textPrimary.withValues(alpha: 0.08),
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: ZohalTokens.contrastRatio(surface, accent) >= 4.5
            ? surface
            : textPrimary,
        secondary: accent,
        onSecondary: surface,
        error: error,
        onError: surface,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceRaised,
        onSurfaceVariant: textSecondary,
        outline: hairline,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0.0,
        margin: EdgeInsets.zero,
        shape: zeroBorder,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        elevation: 0.0,
        shape: zeroBorder,
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        elevation: 0.0,
        shape: zeroBorder,
        modalBackgroundColor: surfaceRaised,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0.0,
          shape: zeroBorder,
          backgroundColor: accent,
          foregroundColor: surface,
          textStyle: textTheme.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0.0,
          shape: zeroBorder,
          side: BorderSide(color: hairline, width: 1.0),
          foregroundColor: textPrimary,
          textStyle: textTheme.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: zeroBorder,
          foregroundColor: accent,
          textStyle: textTheme.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: hairline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: hairline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accent, width: 1.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: error, width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}
