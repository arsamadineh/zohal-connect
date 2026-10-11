// design/components/connect_control.dart
// Centerpiece Persian letter «ز» connection control for Zohal Connect.
// Features the sharp square dot, angular «ز» body, severed circuit slash line,
// internal energy beam, state transitions, and ambient atmospheric glow.

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
  late AnimationController _laserPulseController;
  late AnimationController _energyBeamController;
  late AnimationController _floatController;
  late AnimationController _shockwaveController;
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();

    // Connection transition: 750 ms cubic ease for slash retraction & illumination
    _connectTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // Laser charging / breathing pulse: 1100 ms alternate loop
    _laserPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Flowing energy beam through the letter spine: 1600 ms continuous loop
    _energyBeamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Subtle gentle float in connected state: 3000 ms alternate loop
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Expanding square shockwave on connection: 800 ms single shot
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Press scale: 90 ms in
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        if (!_laserPulseController.isAnimating) {
          _laserPulseController.repeat(reverse: true);
        }
        if (!_energyBeamController.isAnimating) {
          _energyBeamController.repeat();
        }
        break;

      case ConnectionPhase.connected:
        _laserPulseController.stop();
        _energyBeamController.stop();
        _connectTransitionController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutCubic,
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
        _laserPulseController.stop();
        _energyBeamController.stop();
        _floatController.stop();
        _shockwaveController.stop();
        _connectTransitionController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        break;
    }
  }

  @override
  void dispose() {
    _connectTransitionController.dispose();
    _laserPulseController.dispose();
    _energyBeamController.dispose();
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
            _laserPulseController,
            _energyBeamController,
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
                    laserValue: _laserPulseController.value,
                    energyBeamValue: _energyBeamController.value,
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
  final double laserValue;
  final double energyBeamValue;
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
    required this.laserValue,
    required this.energyBeamValue,
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

    // 1. Ambient Background Glow
    _drawAmbientGlow(
        canvas, canonW, canonH, isConnecting, isConnected, isFailed);

    // 2. Expanding Square Shockwave (Active on transition to connected)
    if (shockwaveValue > 0.0 && shockwaveValue < 1.0) {
      _drawShockwave(canvas, shockwaveValue);
    }

    // 3. Subtle floating vertical offset in connected state
    final double floatDy = isConnected ? -3.5 * floatValue : 0.0;

    // 4. Angular «ز» Body
    _drawGlyphBody(canvas, floatDy, isConnecting, isConnected, isFailed);

    // 5. Internal Flowing Energy Beam (Active during connecting)
    if (isConnecting) {
      _drawEnergyBeam(canvas, floatDy);
    }

    // 6. Square Dot at (160, 72)
    _drawSquareDot(canvas, floatDy, isConnecting, isConnected, isFailed);

    // 7. Crossing Slash Line (The Severed Circuit)
    // Slices away and vanishes in connected state (connectProgress -> 1.0)
    if (connectProgress < 1.0) {
      _drawSlashLine(canvas, floatDy, isConnecting, isFailed);
    }

    // 8. 4 Sharp Stage Indicator Pips at the bottom
    _drawStagePips(canvas, isConnecting, isConnected, isFailed);

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
      glowAlpha = 0.18;
    } else if (isConnecting) {
      glowColor = const Color(0xFF3B82F6);
      glowAlpha = 0.16 + 0.14 * laserValue;
    } else if (isConnected) {
      glowColor = const Color(0xFF10B981);
      glowAlpha = 0.22;
    } else {
      glowColor = textPrimaryColor;
      glowAlpha = 0.05;
    }

    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(160.0, 180.0),
        160.0,
        [
          glowColor.withValues(alpha: glowAlpha),
          glowColor.withValues(alpha: glowAlpha * 0.4),
          Colors.transparent,
        ],
        const [0.0, 0.55, 1.0],
      );

    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, w, h), glowPaint);
  }

  void _drawShockwave(Canvas canvas, double progress) {
    final double shockScale = 0.7 + 1.8 * progress;
    final double shockAlpha = (1.0 - progress).clamp(0.0, 1.0) * 0.85;

    final shockRect = Rect.fromCenter(
      center: const Offset(160.0, 72.0),
      width: 56.0 * shockScale,
      height: 56.0 * shockScale,
    );

    final shockPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
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

    // Modern angular «ز» body polygon
    final bodyPath = Path()
      ..moveTo(142.0, 142.0)
      ..lineTo(176.0, 108.0)
      ..lineTo(226.0, 208.0)
      ..lineTo(134.0, 326.0)
      ..lineTo(98.0, 290.0)
      ..lineTo(182.0, 200.0)
      ..close();

    // Body Fill Gradient
    final Color topColor;
    final Color bottomColor;

    if (isFailed) {
      topColor = errorColor;
      bottomColor = errorColor.withValues(alpha: 0.75);
    } else if (isConnected) {
      topColor = Colors.white;
      bottomColor = const Color(0xFFE2E4E9);
    } else if (isConnecting) {
      final double boost = 0.85 + 0.15 * laserValue;
      topColor = Color.lerp(
        const Color(0xFFDBEAFE),
        Colors.white,
        boost,
      )!;
      bottomColor = const Color(0xFFBFDBFE);
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

    // Subtle edge hairline for crispness
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isConnected
          ? const Color(0xFF10B981).withValues(alpha: 0.40)
          : hairlineColor.withValues(alpha: 0.60);

    canvas.drawPath(bodyPath, strokePaint);

    canvas.restore();
  }

  void _drawEnergyBeam(Canvas canvas, double floatDy) {
    canvas.save();
    canvas.translate(0.0, floatDy);

    // Internal laser energy spine inside «ز»
    final beamPath = Path()
      ..moveTo(160.0, 125.0)
      ..lineTo(202.0, 198.0)
      ..lineTo(118.0, 306.0);

    final metrics = beamPath.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final totalLen = metric.length;
      const segmentLen = 65.0;

      // Stage speed / presence boost
      final double cycleSpeed;
      switch (stage) {
        case ConnectionStage.prepare:
          cycleSpeed = 0.7;
          break;
        case ConnectionStage.findGateway:
          cycleSpeed = 1.0;
          break;
        case ConnectionStage.buildTunnel:
          cycleSpeed = 1.3;
          break;
        case ConnectionStage.verifyPath:
          cycleSpeed = 1.7;
          break;
        case ConnectionStage.none:
          cycleSpeed = 1.0;
          break;
      }

      final double pos = (energyBeamValue * cycleSpeed) % 1.0;
      final double head = pos * (totalLen + segmentLen) - segmentLen / 2.0;
      final double start = (head - segmentLen).clamp(0.0, totalLen);
      final double end = head.clamp(0.0, totalLen);

      if (end > start) {
        final extracted = metric.extractPath(start, end);

        // Soft outer glow of beam
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square
          ..strokeWidth = 10.0
          ..color = const Color(0xFF3B82F6).withValues(alpha: 0.35);
        canvas.drawPath(extracted, glowPaint);

        // Core electric beam
        final corePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square
          ..strokeWidth = 4.5
          ..color = const Color(0xFF60A5FA);
        canvas.drawPath(extracted, corePaint);
      }
    }

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

    // Radiant halo behind dot when connected or connecting
    if (isConnected) {
      final glowRect = Rect.fromCenter(
        center: const Offset(160.0, 72.0),
        width: 84.0,
        height: 84.0,
      );
      final glowPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.35);
      canvas.drawRect(glowRect, glowPaint);
    } else if (isConnecting) {
      final double auraSize = 64.0 + 12.0 * laserValue;
      final glowRect = Rect.fromCenter(
        center: const Offset(160.0, 72.0),
        width: auraSize,
        height: auraSize,
      );
      final glowPaint = Paint()
        ..color = const Color(0xFF60A5FA).withValues(
          alpha: 0.20 + 0.15 * laserValue,
        );
      canvas.drawRect(glowRect, glowPaint);
    }

    // Dot Fill: Sharp square (Zero border radius per Rule R18)
    final Color dotFillColor;
    if (isFailed) {
      dotFillColor = errorColor;
    } else if (isConnected) {
      dotFillColor = Colors.white;
    } else if (isConnecting) {
      dotFillColor = Color.lerp(
        const Color(0xFFE0E7FF),
        Colors.white,
        laserValue,
      )!;
    } else {
      dotFillColor = textPrimaryColor;
    }

    final dotPaint = Paint()
      ..color = dotFillColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(dotRect, dotPaint);

    // Subtle hairline border
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isConnected
          ? const Color(0xFF34D399)
          : hairlineColor.withValues(alpha: 0.70);

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

    // Slash line: cuts at 45° directly through dot center (160, 72)
    // Canonical points: (104, 128) to (216, 16)
    // Slices away towards top-right (+38, -38) and shortens when connectProgress increases
    final double slideProgress = connectProgress;
    final double alpha = (1.0 - slideProgress).clamp(0.0, 1.0);
    final double lengthFactor = (1.0 - slideProgress).clamp(0.0, 1.0);

    final Offset shift = Offset(38.0 * slideProgress, -38.0 * slideProgress);
    const Offset center = Offset(160.0, 72.0);
    const Offset vHalf = Offset(56.0, -56.0); // half-length vector

    final Offset pStart = center + shift - vHalf * lengthFactor;
    final Offset pEnd = center + shift + vHalf * lengthFactor;

    if (isFailed) {
      // Broken circuit slash in error color
      final slashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.square
        ..color = errorColor.withValues(alpha: alpha);
      canvas.drawLine(pStart, pEnd, slashPaint);
    } else if (isConnecting) {
      // Laser pulse charge traveling along the slash line
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0
        ..strokeCap = StrokeCap.square
        ..color = const Color(0xFF3B82F6).withValues(
          alpha: (0.35 + 0.25 * laserValue) * alpha,
        );
      canvas.drawLine(pStart, pEnd, glowPaint);

      // Gradient laser stroke
      final laserPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.square
        ..shader = ui.Gradient.linear(
          pStart,
          pEnd,
          [
            const Color(0xFF60A5FA).withValues(alpha: alpha),
            Colors.white.withValues(alpha: alpha),
            const Color(0xFF93C5FD).withValues(alpha: alpha),
          ],
          [
            (laserValue - 0.25).clamp(0.0, 1.0),
            laserValue.clamp(0.0, 1.0),
            (laserValue + 0.25).clamp(0.0, 1.0),
          ],
        );
      canvas.drawLine(pStart, pEnd, laserPaint);
    } else {
      // Disconnected: Solid sharp line cutting through square dot
      final slashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.square
        ..color = textPrimaryColor.withValues(alpha: alpha);
      canvas.drawLine(pStart, pEnd, slashPaint);
    }

    canvas.restore();
  }

  void _drawStagePips(
    Canvas canvas,
    bool isConnecting,
    bool isConnected,
    bool isFailed,
  ) {
    // 4 sharp horizontal ticks at bottom: (Prepare, FindGateway, BuildTunnel, VerifyPath)
    // Spaced evenly along the baseline at y = 356
    const double pipW = 24.0;
    const double pipH = 3.0;
    const double spacing = 8.0;
    const double totalW = 4 * pipW + 3 * spacing; // 120
    const double startX = 160.0 - totalW / 2.0; // 100.0
    const double y = 356.0;

    for (int i = 0; i < 4; i++) {
      final double x = startX + i * (pipW + spacing);
      final rect = Rect.fromLTWH(x, y, pipW, pipH);

      final Color pipColor;
      if (isFailed) {
        pipColor = errorColor;
      } else if (isConnected) {
        pipColor = const Color(0xFF10B981);
      } else if (isConnecting) {
        bool active = false;
        switch (i) {
          case 0:
            active = stage == ConnectionStage.prepare ||
                stage == ConnectionStage.findGateway ||
                stage == ConnectionStage.buildTunnel ||
                stage == ConnectionStage.verifyPath;
            break;
          case 1:
            active = stage == ConnectionStage.findGateway ||
                stage == ConnectionStage.buildTunnel ||
                stage == ConnectionStage.verifyPath;
            break;
          case 2:
            active = stage == ConnectionStage.buildTunnel ||
                stage == ConnectionStage.verifyPath;
            break;
          case 3:
            active = stage == ConnectionStage.verifyPath;
            break;
        }
        pipColor = active
            ? const Color(0xFF60A5FA)
            : hairlineColor.withValues(alpha: 0.50);
      } else {
        pipColor = cancelConfirmationArmed
            ? accentColor
            : hairlineColor.withValues(alpha: 0.40);
      }

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = pipColor;

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZohalGlyphPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.stage != stage ||
        oldDelegate.connectProgress != connectProgress ||
        oldDelegate.laserValue != laserValue ||
        oldDelegate.energyBeamValue != energyBeamValue ||
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
