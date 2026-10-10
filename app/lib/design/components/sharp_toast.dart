// design/components/sharp_toast.dart
// Flat toast notification for Zohal Connect. Zero radius, elevation 0, hairline border.

import 'package:flutter/material.dart';

import '../tokens.dart';

class SharpToast {
  SharpToast._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceRaised =
        isDark ? ZohalTokens.darkSurfaceRaised : ZohalTokens.lightSurfaceRaised;
    final hairline =
        isDark ? ZohalTokens.darkHairline : ZohalTokens.lightHairline;
    final textPrimary =
        isDark ? ZohalTokens.darkTextPrimary : ZohalTokens.lightTextPrimary;
    final error = isDark ? ZohalTokens.darkError : ZohalTokens.lightError;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 32.0,
        left: 20.0,
        right: 20.0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: surfaceRaised,
                border: Border.all(
                  color: isError ? error : hairline,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: isError ? error : textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}
