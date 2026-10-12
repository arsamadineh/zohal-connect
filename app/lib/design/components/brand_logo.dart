// design/components/brand_logo.dart
// Responsive brand logo component adapting seamlessly to dark and light modes.

import 'package:flutter/material.dart';

import '../tokens.dart';

class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({
    super.key,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: isDark ? null : ZohalTokens.lightTextPrimary,
      colorBlendMode: isDark ? null : BlendMode.srcIn,
    );
  }
}
