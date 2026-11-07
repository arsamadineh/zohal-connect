// features/splash/splash_screen.dart
// Instant, brand-aligned splash screen for Zohal Connect rendered on Frame 1.
// Strictly adheres to R1: <250ms render, zero blocking IO, high-contrast BrandLogo.

import 'package:flutter/material.dart';

import '../../design/components/brand_logo.dart';

class SplashScreen extends StatelessWidget {
  /// Custom background color matching brand identity (#0A0D14).
  static const Color brandBackground = Color(0xFF0A0D14);

  final Color backgroundColor;
  final double logoSize;

  const SplashScreen({
    super.key,
    this.backgroundColor = brandBackground,
    this.logoSize = 72.0,
  });

  @override
  Widget build(BuildContext context) {
    // Enforce dark theme context so BrandLogo renders with white/untinted
    // asset colors against the dark background, even if the OS is in Light Mode.
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: BrandLogo(size: logoSize),
        ),
      ),
    );
  }
}
