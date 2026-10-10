// design/tokens.dart
// Design tokens for Zohal Connect according to ZOHAL_SPEC Section 12.3.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class ZohalTokens {
  ZohalTokens._();

  // Dark Theme Colors
  static const Color darkSurface = Color(0xFF0E0F10);
  static const Color darkSurfaceRaised = Color(0xFF151618);
  static const Color darkHairline = Color(0xFF2A2C2F);
  static const Color darkTextPrimary = Color(0xFFECEDEE);
  static const Color darkTextSecondary = Color(0xFF9A9DA1);
  static const Color darkScrim = Color(0x8C000000); // 55% black
  static const Color darkError = Color(0xFFE0735F);

  // Light Theme Colors
  static const Color lightSurface = Color(0xFFF4F4F2);
  static const Color lightSurfaceRaised = Color(0xFFFBFBFA);
  static const Color lightHairline = Color(0xFFD9DAD6);
  static const Color lightTextPrimary = Color(0xFF161718);
  static const Color lightTextSecondary = Color(0xFF6A6D70);
  static const Color lightScrim = Color(0x59000000); // 35% black
  static const Color lightError = Color(0xFFB3412F);

  // Spacing & Grid
  static const double gridUnit = 4.0;
  static const double paddingMobile = 20.0;
  static const double paddingDesktop = 24.0;
  static const double rowHeight = 56.0;
  static const double minTouchTarget = 48.0;
  static const double contentMaxWidth = 420.0;
  static const double hairlineThickness = 1.0;

  // Typography - Font family
  static const String fontFamily = 'Vazirmatn';

  // Contrast calculation helpers (WCAG AA: 4.5:1 for normal text)
  static double calculateLuminance(Color color) {
    double r = color.r;
    double g = color.g;
    double b = color.b;

    r = (r <= 0.03928)
        ? r / 12.92
        : math.pow((r + 0.055) / 1.055, 2.4).toDouble();
    g = (g <= 0.03928)
        ? g / 12.92
        : math.pow((g + 0.055) / 1.055, 2.4).toDouble();
    b = (b <= 0.03928)
        ? b / 12.92
        : math.pow((b + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double contrastRatio(Color fg, Color bg) {
    final double l1 = calculateLuminance(fg);
    final double l2 = calculateLuminance(bg);
    final double brightest = math.max(l1, l2);
    final double darkest = math.min(l1, l2);
    return (brightest + 0.05) / (darkest + 0.05);
  }

  /// Adjusts accent color to guarantee at least 4.5:1 contrast against surface.
  /// If provided accent is null or cannot reach contrast, falls back to textPrimary.
  static Color resolveAccent(Color? systemAccent, bool isDark) {
    final surface = isDark ? darkSurface : lightSurface;
    final fallback = isDark ? darkTextPrimary : lightTextPrimary;

    if (systemAccent == null) return fallback;

    final double ratio = contrastRatio(systemAccent, surface);
    if (ratio >= 4.5) return systemAccent;

    // Adjust brightness iteratively
    HSLColor hsl = HSLColor.fromColor(systemAccent);
    for (int step = 0; step < 20; step++) {
      if (isDark) {
        // Lighten in dark mode to increase contrast against dark surface
        hsl = hsl.withLightness(math.min(1.0, hsl.lightness + 0.05));
      } else {
        // Darken in light mode to increase contrast against light surface
        hsl = hsl.withLightness(math.max(0.0, hsl.lightness - 0.05));
      }
      if (contrastRatio(hsl.toColor(), surface) >= 4.5) {
        return hsl.toColor();
      }
    }
    return fallback;
  }
}
