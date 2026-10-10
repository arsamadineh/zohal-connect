// design/components/sharp_switch.dart
// Sharp toggle switch for Zohal Connect. Zero border radius, rectangular track and square thumb.

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

class SharpSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SharpSwitch({super.key, required this.value, required this.onChanged});

  @override
  State<SharpSwitch> createState() => _SharpSwitchState();
}

class _SharpSwitchState extends State<SharpSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ZohalMotion.durationMicro,
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(SharpSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onChanged == null) return;
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? ZohalTokens.darkSurface : ZohalTokens.lightSurface;
    final hairline = isDark
        ? ZohalTokens.darkHairline
        : ZohalTokens.lightHairline;
    final textSecondary = isDark
        ? ZohalTokens.darkTextSecondary
        : ZohalTokens.lightTextSecondary;
    final accent = theme.colorScheme.primary;

    const double trackWidth = 44.0;
    const double trackHeight = 24.0;
    const double thumbSize = 16.0;
    const double padding = 3.0;
    const double slideDistance = trackWidth - thumbSize - (padding * 2.0);

    return Semantics(
      toggled: widget.value,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double t = _controller.value;
            final Color trackBg = Color.lerp(surface, accent, t)!;
            final Color trackBorder = Color.lerp(hairline, accent, t)!;
            final Color thumbColor = Color.lerp(textSecondary, surface, t)!;

            return Container(
              width: trackWidth,
              height: trackHeight,
              decoration: BoxDecoration(
                color: trackBg,
                border: Border.all(color: trackBorder, width: 1.0),
                borderRadius: BorderRadius.zero,
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: padding + (slideDistance * t),
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: thumbColor,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
