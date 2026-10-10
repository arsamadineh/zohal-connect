// design/components/connect_control.dart
// Centerpiece Saturn connect control for Zohal Connect per ZOHAL_SPEC Section 12.5.
// Planet square with thin ring band drawn in two halves for 3D depth, 4 stage ticks.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
  late AnimationController _orbitController;
  late AnimationController _fillController;
  late AnimationController _pressController;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // Orbit controller: 0.4 turns per second -> 2.5 seconds per turn
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Planet fill growth: 480 ms emphasized
    _fillController = AnimationController(
      vsync: this,
      duration: ZohalMotion.durationEmphasized,
    );

    // Press scale: 90 ms in
    _pressController = AnimationController(
      vsync: this,
      duration: ZohalMotion.durationPressIn,
    );

    _updateAnimations();
  }

  @override
  void didUpdateWidget(ConnectControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase || oldWidget.stage != widget.stage) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    switch (widget.phase) {
      case ConnectionPhase.connecting:
      case ConnectionPhase.reconnecting:
      case ConnectionPhase.preparing:
        if (!_orbitController.isAnimating) {
          _orbitController.repeat();
        }
        _fillController.animateTo(0.0, duration: ZohalMotion.durationMicro);
        break;
      case ConnectionPhase.connected:
        _orbitController.stop();
        _fillController.forward();
        break;
      case ConnectionPhase.idle:
      case ConnectionPhase.disconnecting:
      case ConnectionPhase.failed:
        _orbitController.stop();
        _fillController.reverse();
        break;
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _fillController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
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
    final hairline = isDark
        ? ZohalTokens.darkHairline
        : ZohalTokens.lightHairline;
    final textPrimary = isDark
        ? ZohalTokens.darkTextPrimary
        : ZohalTokens.lightTextPrimary;
    final textSecondary = isDark
        ? ZohalTokens.darkTextSecondary
        : ZohalTokens.lightTextSecondary;
    final accent = theme.colorScheme.primary;
    final error = isDark ? ZohalTokens.darkError : ZohalTokens.lightError;

    return Semantics(
      button: true,
      label: _getSemanticsLabel(),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _orbitController,
            _fillController,
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
                  painter: _ConnectControlPainter(
                    phase: widget.phase,
                    stage: widget.stage,
                    fillProgress: _fillController.value,
                    orbitValue: _orbitController.value,
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

class _ConnectControlPainter extends CustomPainter {
  final ConnectionPhase phase;
  final ConnectionStage stage;
  final double fillProgress;
  final double orbitValue;
  final Color hairlineColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color accentColor;
  final Color errorColor;
  final bool cancelConfirmationArmed;

  _ConnectControlPainter({
    required this.phase,
    required this.stage,
    required this.fillProgress,
    required this.orbitValue,
    required this.hairlineColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.accentColor,
    required this.errorColor,
    required this.cancelConfirmationArmed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    const double frameSide = 176.0;
    const double planetSide = 72.0;
    const double ringLength = 232.0;
    const double ringThickness = 2.0;

    // 1. Draw outer frame (176 x 176)
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = cancelConfirmationArmed ? accentColor : hairlineColor;

    final frameRect = Rect.fromCenter(
      center: center,
      width: frameSide,
      height: frameSide,
    );
    canvas.drawRect(frameRect, framePaint);

    // Determine current ring angle (radians)
    double theta;
    if (phase == ConnectionPhase.connecting ||
        phase == ConnectionPhase.reconnecting ||
        phase == ConnectionPhase.preparing) {
      theta = orbitValue * 2.0 * math.pi;
    } else if (phase == ConnectionPhase.connected) {
      theta = -20.0 * math.pi / 180.0;
    } else if (phase == ConnectionPhase.failed) {
      theta = 0.0;
    } else {
      theta = -20.0 * math.pi / 180.0;
    }

    // Determine ring color
    final Color ringColor;
    if (phase == ConnectionPhase.connecting ||
        phase == ConnectionPhase.reconnecting ||
        phase == ConnectionPhase.preparing ||
        phase == ConnectionPhase.connected) {
      ringColor = accentColor;
    } else if (phase == ConnectionPhase.failed) {
      ringColor = errorColor;
    } else {
      ringColor = textPrimaryColor.withOpacity(0.70);
    }

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill;

    // 2. Ring UPPER HALF (y < center.y) drawn BEFORE planet (behind)
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, center.y));
    _drawRotatedRing(
      canvas,
      center,
      ringLength,
      ringThickness,
      theta,
      ringPaint,
    );
    canvas.restore();

    // 3. Draw Planet Square (side = 72)
    final planetRect = Rect.fromCenter(
      center: center,
      width: planetSide,
      height: planetSide,
    );

    // Planet Fill (Connected)
    if (fillProgress > 0.0) {
      final fillSide = planetSide * fillProgress;
      final fillRect = Rect.fromCenter(
        center: center,
        width: fillSide,
        height: fillSide,
      );
      final fillPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(fillRect, fillPaint);
    }

    // Planet Stroke
    final planetStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (phase == ConnectionPhase.connecting ||
        phase == ConnectionPhase.reconnecting ||
        phase == ConnectionPhase.preparing) {
      planetStrokePaint.color = accentColor;
    } else if (phase == ConnectionPhase.connected) {
      planetStrokePaint.color = accentColor;
    } else if (phase == ConnectionPhase.failed) {
      planetStrokePaint.color = errorColor;
    } else {
      planetStrokePaint.color = textSecondaryColor;
    }

    canvas.drawRect(planetRect, planetStrokePaint);

    // 4. Ring LOWER HALF (y >= center.y) drawn AFTER planet (in front)
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, center.y, size.width, size.height));
    _drawRotatedRing(
      canvas,
      center,
      ringLength,
      ringThickness,
      theta,
      ringPaint,
    );
    canvas.restore();

    // 5. Draw 4 Stage Ticks (12 x 2 dp, centered on each side, outside frame)
    _drawStageTicks(canvas, center, frameSide);
  }

  void _drawRotatedRing(
    Canvas canvas,
    Offset center,
    double length,
    double thickness,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: length,
      height: thickness,
    );
    canvas.drawRect(ringRect, paint);
    canvas.restore();
  }

  void _drawStageTicks(Canvas canvas, Offset center, double side) {
    const double tickLength = 12.0;
    const double tickThickness = 2.0;
    const double offsetDist = side / 2.0 + 4.0; // just outside the frame

    final isConnecting =
        phase == ConnectionPhase.connecting ||
        phase == ConnectionPhase.reconnecting ||
        phase == ConnectionPhase.preparing;
    final isFailed = phase == ConnectionPhase.failed;

    // Tick indices:
    // 0: Top (Prepare)
    // 1: Right (FindGateway)
    // 2: Bottom (BuildTunnel)
    // 3: Left (VerifyPath)
    for (int i = 0; i < 4; i++) {
      Color tickColor;
      if (isFailed) {
        tickColor = errorColor;
      } else if (isConnecting) {
        bool active = false;
        switch (i) {
          case 0:
            active =
                stage == ConnectionStage.prepare ||
                stage == ConnectionStage.findGateway ||
                stage == ConnectionStage.buildTunnel ||
                stage == ConnectionStage.verifyPath;
            break;
          case 1:
            active =
                stage == ConnectionStage.findGateway ||
                stage == ConnectionStage.buildTunnel ||
                stage == ConnectionStage.verifyPath;
            break;
          case 2:
            active =
                stage == ConnectionStage.buildTunnel ||
                stage == ConnectionStage.verifyPath;
            break;
          case 3:
            active = stage == ConnectionStage.verifyPath;
            break;
        }
        tickColor = active ? accentColor : hairlineColor;
      } else if (phase == ConnectionPhase.connected) {
        tickColor = accentColor;
      } else {
        tickColor = Colors.transparent;
      }

      if (tickColor == Colors.transparent) continue;

      final tickPaint = Paint()
        ..color = tickColor
        ..style = PaintingStyle.fill;

      switch (i) {
        case 0: // Top
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(center.dx, center.dy - offsetDist),
              width: tickLength,
              height: tickThickness,
            ),
            tickPaint,
          );
          break;
        case 1: // Right
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(center.dx + offsetDist, center.dy),
              width: tickThickness,
              height: tickLength,
            ),
            tickPaint,
          );
          break;
        case 2: // Bottom
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(center.dx, center.dy + offsetDist),
              width: tickLength,
              height: tickThickness,
            ),
            tickPaint,
          );
          break;
        case 3: // Left
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(center.dx - offsetDist, center.dy),
              width: tickThickness,
              height: tickLength,
            ),
            tickPaint,
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectControlPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.stage != stage ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.orbitValue != orbitValue ||
        oldDelegate.cancelConfirmationArmed != cancelConfirmationArmed ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.hairlineColor != hairlineColor;
  }
}
