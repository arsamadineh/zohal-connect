// design/motion.dart
// Motion tokens and animations for Zohal Connect per ZOHAL_SPEC Section 12.4.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class ZohalMotion {
  ZohalMotion._();

  // Easing curves
  static const Curve easeStandard = Cubic(0.32, 0.72, 0.0, 1.0);

  // Springs (mass, stiffness, damping coefficient d = 2 * zeta * sqrt(m * k))
  // Snappy: mass 1, stiffness 420, damping ratio 0.9 -> d = 2 * 0.9 * sqrt(420) ≈ 36.89
  static final SpringDescription springSnappy = SpringDescription(
    mass: 1.0,
    stiffness: 420.0,
    damping: 2.0 * 0.9 * math.sqrt(420.0),
  );

  // Gentle: mass 1, stiffness 220, damping ratio 0.85 -> d = 2 * 0.85 * sqrt(220) ≈ 25.21
  static final SpringDescription springGentle = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 2.0 * 0.85 * math.sqrt(220.0),
  );

  // Durations
  static const Duration durationMicro = Duration(milliseconds: 120);
  static const Duration durationStandard = Duration(milliseconds: 280);
  static const Duration durationEmphasized = Duration(milliseconds: 480);
  static const Duration durationSheet = Duration(milliseconds: 420);
  static const Duration durationStagger = Duration(milliseconds: 28);
  static const Duration durationPressIn = Duration(milliseconds: 90);
  static const Duration durationPressOut = Duration(milliseconds: 160);

  // Press Scale
  static const double pressScale = 0.98;

  /// Custom RTL-aware Slide & Fade Page Route
  static Route<T> createPageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: durationStandard,
      reverseTransitionDuration: durationStandard,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: easeStandard);

        // Slide from reading-start (right in RTL, offset (1.0, 0.0) -> (0.0, 0.0) with 24 dp)
        return AnimatedBuilder(
          animation: curved,
          builder: (context, child) {
            final double slideOffset = (1.0 - curved.value) * 24.0;
            return Transform.translate(
              offset: Offset(slideOffset, 0.0),
              child: Opacity(
                opacity: curved.value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}
