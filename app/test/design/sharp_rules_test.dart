// test/design/sharp_rules_test.dart
// Unit tests enforcing Rule R18: Sharp corners only, zero border radius everywhere.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/design/theme.dart';

void main() {
  group('Shape Lock: Zero Border Radius', () {
    test('Dark theme enforces zero border radius in components', () {
      final theme = ZohalTheme.createTheme(isDark: true);

      // Card theme shape
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, equals(BorderRadius.zero));

      // Dialog theme shape
      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(dialogShape.borderRadius, equals(BorderRadius.zero));

      // Bottom sheet shape
      final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(sheetShape.borderRadius, equals(BorderRadius.zero));

      // Button theme shapes
      final elevatedShape = theme.elevatedButtonTheme.style?.shape?.resolve(
        {},
      ) as RoundedRectangleBorder;
      expect(elevatedShape.borderRadius, equals(BorderRadius.zero));

      final outlinedShape = theme.outlinedButtonTheme.style?.shape?.resolve(
        {},
      ) as RoundedRectangleBorder;
      expect(outlinedShape.borderRadius, equals(BorderRadius.zero));
    });

    test('Light theme enforces zero border radius in components', () {
      final theme = ZohalTheme.createTheme(isDark: false);

      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, equals(BorderRadius.zero));

      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(dialogShape.borderRadius, equals(BorderRadius.zero));

      final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(sheetShape.borderRadius, equals(BorderRadius.zero));
    });
  });
}
