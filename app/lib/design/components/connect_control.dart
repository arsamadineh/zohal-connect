// design/components/connect_control.dart
// Centerpiece Persian letter «ز» connection control for Zohal Connect.
// Minimalist, high-framerate geometric Saturn/Zayn circuit control adhering
// strictly to Rule R18 (sharp corners, zero border radius) and Rule R14/R15.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/engine_state.dart';
import '../../l10n/strings_fa.dart';
import '../motion.dart';
import '../tokens.dart';

class ConnectControl extends StatefulWidget {
  final ConnectionPhase phase;
  final ConnectionStage stage;
  final VoidCallback onTap;
  final bool cancelConfirmationArmed;

  const ConnectControl({
    super.key,
    required this.phase,
    required this.stage,
    required this.onTap,
    this.cancelConfirmationArmed = false,
  });

  @override
  State<ConnectControl> createState() => _ConnectControlState();
}

class _ConnectControlState extends State<ConnectControl>
    with TickerProviderStateMixin {
  late AnimationController _connectTransitionController;
  late AnimationController _pulseController;
  late AnimationController _reticleController;
  late AnimationController _floatController;
  late AnimationController _shockwaveController;
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();

    // Circuit engagement / retraction transition: 600 ms cubic ease
    _connectTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Subtle breathing luminosity pulse: 1400 ms alternate loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Geometric targeting reticle scanning loop: 1800 ms
    _reticleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Connected state gentle levitation: 3200 ms alternate loop
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Single-shot geometric square shockwave on connect: 650 ms
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Press scale response
    _pressController = AnimationController(
      vsync: this,
      duration: ZohalMotion.durationPressIn,
    );

    _updateAnimations(oldPhase: null);
  }

  @override
  void didUpdateWidget(ConnectControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase || oldWidget.stage != widget.stage) {
      _updateAnimations(oldPhase: oldWidget.phase);
    }
  }

  void _updateAnimations({ConnectionPhase? oldPhase}) {
    switch (widget.phase) {
      case ConnectionPhase.connecting:
      case ConnectionPhase.reconnecting:
      case ConnectionPhase.preparing:
        _floatController.stop();
        _connectTransitionController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
        if (!_reticleController.isAnimating) {
          _reticleController.repeat();
        }
        break;

      case ConnectionPhase.connected:
        _pulseController.stop();
        _reticleController.stop();
        _connectTransitionController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
        if (oldPhase != ConnectionPhase.connected) {
          _shockwaveController.forward(from: 0.0);
        }
        if (!_floatController.isAnimating) {
          _floatController.repeat(reverse: true);
        }
        break;

      case ConnectionPhase.idle:
      case ConnectionPhase.disconnecting:
      case ConnectionPhase.failed:
        _pulseController.stop();
        _reticleController.stop();
        _floatController.stop();
        _shockwaveController.stop();
        _connectTransitionController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
        break;
    }
  }

  @override
  void dispose() {
    _connectTransitionController.dispose();
    _pulseController.dispose();
    _reticleController.dispose();
    _floatController.dispose();
    _shockwaveController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  String _getSemanticsLabel() {
    switch (widget.phase) {
      case ConnectionPhase.idle:
        return StringsFa.stateIdle;
      case ConnectionPhase.preparing:
        return StringsFa.statePreparing;
      case ConnectionPhase.connecting:
        return StringsFa.stateConnecting;
      case ConnectionPhase.connected:
        return StringsFa.stateConnected;
      case ConnectionPhase.reconnecting:
        return StringsFa.stateReconnecting;
      case ConnectionPhase.disconnecting:
        return StringsFa.stateDisconnecting;
      case ConnectionPhase.failed:
        return StringsFa.stateFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? ZohalTokens.darkHairline : ZohalTokens.lightHairline;
    final textPrimary =
        isDark ? ZohalTokens.darkTextPrimary : ZohalTokens.lightTextPrimary;
    final textSecondary =
        isDark ? ZohalTokens.darkTextSecondary : ZohalTokens.lightTextSecondary;
    final accent = theme.colorScheme.primary;
    final error = isDark ? ZohalTokens.darkError : ZohalTokens.lightError;

    return Semantics(
      button: true,
      label: _getSemanticsLabel(),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _connectTransitionController,
            _pulseController,
            _reticleController,
            _floatController,
            _shockwaveController,
            _pressController,
          ]),
          builder: (context, child) {
            final double scale =
                1.0 - (1.0 - ZohalMotion.pressScale) * _pressController.value;

            return Transform.scale(
              scale: scale,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(176.0, 176.0),
                  painter: _ZohalGlyphPainter(
                    phase: widget.phase,
                    stage: widget.stage,
                    connectProgress: _connectTransitionController.value,
                    pulseValue: _pulseController.value,
                    reticleValue: _reticleController.value,
                    floatValue: _floatController.value,
                    shockwaveValue: _shockwaveController.value,
                    hairlineColor: hairline,
                    textPrimaryColor: textPrimary,
                    textSecondaryColor: textSecondary,
                    accentColor: accent,
                    errorColor: error,
                    cancelConfirmationArmed: widget.cancelConfirmationArmed,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ZohalGlyphPainter extends CustomPainter {
  final ConnectionPhase phase;
  final ConnectionStage stage;
  final double connectProgress;
  final double pulseValue;
  final double reticleValue;
  final double floatValue;
  final double shockwaveValue;
  final Color hairlineColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color accentColor;
  final Color errorColor;
  final bool cancelConfirmationArmed;

  _ZohalGlyphPainter({
    required this.phase,
    required this.stage,
    required this.connectProgress,
    required this.pulseValue,
    required this.reticleValue,
    required this.floatValue,
    required this.shockwaveValue,
    required this.hairlineColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.accentColor,
    required this.errorColor,
    required this.cancelConfirmationArmed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Canonical coordinate space: 320 x 380
    const double canonW = 320.0;
    const double canonH = 380.0;

    final double scale = math.min(size.width / canonW, size.height / canonH);
    final double dx = (size.width - canonW * scale) / 2.0;
    final double dy = (size.height - canonH * scale) / 2.0;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final bool isConnecting = phase == ConnectionPhase.connecting ||
        phase == ConnectionPhase.reconnecting ||
        phase == ConnectionPhase.preparing;
    final bool isConnected = phase == ConnectionPhase.connected;
    final bool isFailed = phase == ConnectionPhase.failed;

    // 1. Ambient Background Glow (Subtle & theme-aligned, no garish bleed)
    _drawAmbientGlow(
        canvas, canonW, canonH, isConnecting, isConnected, isFailed);

    // 2. Expanding Square Shockwave (Active on transition to connected)
    if (shockwaveValue > 0.0 && shockwaveValue < 1.0) {
      _drawShockwave(canvas, shockwaveValue);
    }

    // 3. Subtle floating vertical offset in connected state
    final double floatDy = isConnected ? -3.0 * floatValue : 0.0;

    // 4. Angular «ز» Body
    _drawGlyphBody(canvas, floatDy, isConnecting, isConnected, isFailed);

    // 5. Square Dot & Precision Reticle at (160, 72)
    _drawSquareDot(canvas, floatDy, isConnecting, isConnected, isFailed);

    // 6. Crossing Slash Line (Severed circuit that heals on connect)
    if (connectProgress < 1.0) {
      _drawSlashLine(canvas, floatDy, isConnecting, isFailed);
    }

    canvas.restore();
  }

  void _drawAmbientGlow(
    Canvas canvas,
    double w,
    double h,
    bool isConnecting,
    bool isConnected,
    bool isFailed,
  ) {
    final Color glowColor;
    final double glowAlpha;

    if (isFailed) {
      glowColor = errorColor;
      glowAlpha = 0.12;
    } else if (isConnected) {
      glowColor = const Color(0xFF10B981);
      glowAlpha = 0.14;
    } else if (isConnecting) {
      glowColor = accentColor;
      glowAlpha = 0.08 + 0.08 * pulseValue;
    } else {
      glowColor = textPrimaryColor;
      glowAlpha = 0.03;
    }

    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(160.0, 190.0),
        150.0,
        [
          glowColor.withValues(alpha: glowAlpha),
          glowColor.withValues(alpha: glowAlpha * 0.3),
          Colors.transparent,
        ],
        const [0.0, 0.6, 1.0],
      );

    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, w, h), glowPaint);
  }

  void _drawShockwave(Canvas canvas, double progress) {
    // Sharp square expanding shockwave (Rule R18: sharp corners only)
    final double shockScale = 0.8 + 1.6 * progress;
    final double shockAlpha = (1.0 - progress).clamp(0.0, 1.0) * 0.7;

    final shockRect = Rect.fromCenter(
      center: const Offset(160.0, 72.0),
      width: 56.0 * shockScale,
      height: 56.0 * shockScale,
    );

    final shockPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF10B981).withValues(alpha: shockAlpha);

    canvas.drawRect(shockRect, shockPaint);
  }

  void _drawGlyphBody(
    Canvas canvas,
    double floatDy,
    bool isConnecting,
    bool isConnected,
    bool isFailed,
  ) {
    canvas.save();
    canvas.translate(0.0, floatDy);

    // Crisp angular «ز» body polygon
    final bodyPath = Path()
      ..moveTo(142.0, 142.0)
      ..lineTo(176.0, 108.0)
      ..lineTo(226.0, 208.0)
      ..lineTo(134.0, 326.0)
      ..lineTo(98.0, 290.0)
      ..lineTo(182.0, 200.0)
      ..close();

    final Color topColor;
    final Color bottomColor;

    if (isFailed) {
      topColor = errorColor;
      bottomColor = errorColor.withValues(alpha: 0.75);
    } else if (isConnected) {
      topColor = Colors.white;
      bottomColor = const Color(0xFFD1FAE5);
    } else if (isConnecting) {
      final double boost = 0.75 + 0.25 * pulseValue;
      topColor = Color.lerp(textPrimaryColor, accentColor, boost)!;
      bottomColor = Color.lerp(textSecondaryColor, accentColor, boost * 0.7)!;
    } else {
      topColor = textPrimaryColor;
      bottomColor = textSecondaryColor.withValues(alpha: 0.85);
    }

    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(142.0, 108.0),
        const Offset(182.0, 326.0),
        [topColor, bottomColor],
      );

    canvas.drawPath(bodyPath, bodyPaint);

    // Razor-sharp 1px edge stroke
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isConnected
          ? const Color(0xFF10B981).withValues(alpha: 0.45)
          : isConnecting
              ? accentColor.withValues(alpha: 0.5)
              : hairlineColor.withValues(alpha: 0.6);

    canvas.drawPath(bodyPath, strokePaint);

    canvas.restore();
  }

  void _drawSquareDot(
    Canvas canvas,
    double floatDy,
    bool isConnecting,
    bool isConnected,
    bool isFailed,
  ) {
    canvas.save();
    canvas.translate(0.0, floatDy);

    // Dot geometry: Rect(132, 44, 56, 56), center at (160, 72)
    const dotRect = Rect.fromLTWH(132.0, 44.0, 56.0, 56.0);

    // Precision Aerospace Reticle Brackets (during connecting)
    if (isConnecting) {
      // Micro-pulse breathing aperture
      final double d = 3.0 + 3.0 * math.sin(reticleValue * 2 * math.pi);
      const double bracketLen = 10.0;
      final reticlePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accentColor.withValues(alpha: 0.65 + 0.35 * pulseValue);

      // Top-Left L-bracket
      final tl = Path()
        ..moveTo(126.0 - d, 44.0 + bracketLen)
        ..lineTo(126.0 - d, 38.0 - d)
        ..lineTo(132.0 - d + bracketLen, 38.0 - d);
      canvas.drawPath(tl, reticlePaint);

      // Top-Right L-bracket
      final tr = Path()
        ..moveTo(188.0 + d + bracketLen, 44.0 + bracketLen)
        ..lineTo(194.0 + d, 38.0 - d)
        ..lineTo(194.0 + d - bracketLen, 38.0 - d);
      canvas.drawPath(tr, reticlePaint);

      // Bottom-Left L-bracket
      final bl = Path()
        ..moveTo(126.0 - d, 100.0 - bracketLen)
        ..lineTo(126.0 - d, 106.0 + d)
        ..lineTo(132.0 - d + bracketLen, 106.0 + d);
      canvas.drawPath(bl, reticlePaint);

      // Bottom-Right L-bracket
      final br = Path()
        ..moveTo(188.0 + d + bracketLen, 100.0 - bracketLen)
        ..lineTo(194.0 + d, 106.0 + d)
        ..lineTo(194.0 + d - bracketLen, 106.0 + d);
      canvas.drawPath(br, reticlePaint);
    }

    // Dot Fill: Sharp square (Zero border radius per Rule R18)
    final Color dotFillColor;
    if (isFailed) {
      dotFillColor = errorColor;
    } else if (isConnected) {
      dotFillColor = Colors.white;
    } else if (isConnecting) {
      dotFillColor = Color.lerp(
        textPrimaryColor,
        Colors.white,
        0.5 + 0.5 * pulseValue,
      )!;
    } else {
      dotFillColor = textPrimaryColor;
    }

    final dotPaint = Paint()
      ..color = dotFillColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(dotRect, dotPaint);

    // Subtle sharp perimeter outline
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isConnected
          ? const Color(0xFF34D399)
          : isConnecting
              ? accentColor.withValues(alpha: 0.8)
              : hairlineColor.withValues(alpha: 0.7);

    canvas.drawRect(dotRect, strokePaint);

    canvas.restore();
  }

  void _drawSlashLine(
    Canvas canvas,
    double floatDy,
    bool isConnecting,
    bool isFailed,
  ) {
    canvas.save();
    canvas.translate(0.0, floatDy);

    // Slash line: cuts at 45 deg directly through dot center (160, 72)
    // Slices away smoothly towards top-right (+38, -38) and retracts
    final double slideProgress = connectProgress;
    final double alpha = (1.0 - slideProgress).clamp(0.0, 1.0);
    final double lengthFactor = (1.0 - slideProgress).clamp(0.0, 1.0);

    final Offset shift = Offset(38.0 * slideProgress, -38.0 * slideProgress);
    const Offset center = Offset(160.0, 72.0);
    const Offset vHalf = Offset(56.0, -56.0); // half-length vector

    final Offset pStart = center + shift - vHalf * lengthFactor;
    final Offset pEnd = center + shift + vHalf * lengthFactor;

    final Color slashColor;
    if (isFailed) {
      slashColor = errorColor.withValues(alpha: alpha);
    } else if (isConnecting) {
      // Crisp pulse in accent color
      final double blend = 0.5 + 0.5 * pulseValue;
      slashColor = Color.lerp(textPrimaryColor, accentColor, blend)!
          .withValues(alpha: alpha);
    } else {
      slashColor = textPrimaryColor.withValues(alpha: alpha);
    }

    final slashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.square
      ..color = slashColor;

    canvas.drawLine(pStart, pEnd, slashPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ZohalGlyphPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.stage != stage ||
        oldDelegate.connectProgress != connectProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.reticleValue != reticleValue ||
        oldDelegate.floatValue != floatValue ||
        oldDelegate.shockwaveValue != shockwaveValue ||
        oldDelegate.hairlineColor != hairlineColor ||
        oldDelegate.textPrimaryColor != textPrimaryColor ||
        oldDelegate.textSecondaryColor != textSecondaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.errorColor != errorColor ||
        oldDelegate.cancelConfirmationArmed != cancelConfirmationArmed;
  }
}
