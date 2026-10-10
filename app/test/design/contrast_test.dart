// test/design/contrast_test.dart
// Unit tests verifying WCAG AA contrast ratio (>= 4.5:1) for design tokens.

import 'package:flutter/material.dart';
import 'package:test/test.dart';

import '../../lib/design/tokens.dart';

void main() {
  group('Design Tokens Contrast (WCAG AA >= 4.5:1)', () {
    test('Dark theme text primary vs surface has >= 4.5:1 contrast', () {
      final ratio = ZohalTokens.contrastRatio(
        ZohalTokens.darkTextPrimary,
        ZohalTokens.darkSurface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'Dark textPrimary contrast ratio: $ratio',
      );
    });

    test('Light theme text primary vs surface has >= 4.5:1 contrast', () {
      final ratio = ZohalTokens.contrastRatio(
        ZohalTokens.lightTextPrimary,
        ZohalTokens.lightSurface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'Light textPrimary contrast ratio: $ratio',
      );
    });

    test('Dark theme error vs surface has >= 4.5:1 contrast', () {
      final ratio = ZohalTokens.contrastRatio(
        ZohalTokens.darkError,
        ZohalTokens.darkSurface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'Dark error contrast ratio: $ratio',
      );
    });

    test('Light theme error vs surface has >= 4.5:1 contrast', () {
      final ratio = ZohalTokens.contrastRatio(
        ZohalTokens.lightError,
        ZohalTokens.lightSurface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'Light error contrast ratio: $ratio',
      );
    });

    test(
      'Resolved system accent in dark mode guarantees >= 4.5:1 contrast',
      () {
        // Test with arbitrary system accent (e.g. low-contrast teal)
        const lowContrastAccent = Color(0xFF1E3A3A);
        final resolved = ZohalTokens.resolveAccent(lowContrastAccent, true);
        final ratio = ZohalTokens.contrastRatio(
          resolved,
          ZohalTokens.darkSurface,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Resolved dark accent contrast ratio: $ratio',
        );
      },
    );

    test(
      'Resolved system accent in light mode guarantees >= 4.5:1 contrast',
      () {
        // Test with arbitrary high-lightness system accent (e.g. pastel yellow)
        const pastelAccent = Color(0xFFFFF176);
        final resolved = ZohalTokens.resolveAccent(pastelAccent, false);
        final ratio = ZohalTokens.contrastRatio(
          resolved,
          ZohalTokens.lightSurface,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Resolved light accent contrast ratio: $ratio',
        );
      },
    );
  });
}
