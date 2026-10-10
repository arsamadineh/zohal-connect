// design/components/sharp_button.dart
// Sharp rectangular button for Zohal Connect. Zero border radius, elevation 0, spring press.

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

class SharpButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isDestructive;
  final Widget? icon;
  final double? width;
  final double height;

  const SharpButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isOutlined = false,
    this.isDestructive = false,
    this.icon,
    this.width,
    this.height = 48.0,
  });

  @override
  State<SharpButton> createState() => _SharpButtonState();
}

class _SharpButtonState extends State<SharpButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ZohalMotion.durationPressIn,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    _pressController.reverse();
    widget.onPressed!();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? ZohalTokens.darkSurface : ZohalTokens.lightSurface;
    final hairline =
        isDark ? ZohalTokens.darkHairline : ZohalTokens.lightHairline;
    final textPrimary =
        isDark ? ZohalTokens.darkTextPrimary : ZohalTokens.lightTextPrimary;
    final error = isDark ? ZohalTokens.darkError : ZohalTokens.lightError;
    final accent = theme.colorScheme.primary;

    final Color bgColor;
    final Color textColor;
    final Border? border;

    if (widget.isOutlined) {
      bgColor = Colors.transparent;
      textColor = widget.isDestructive ? error : textPrimary;
      border = Border.all(
        color: widget.isDestructive ? error : hairline,
        width: 1.0,
      );
    } else {
      bgColor = widget.isDestructive ? error : accent;
      textColor = ZohalTokens.contrastRatio(bgColor, surface) >= 4.5
          ? surface
          : textPrimary;
      border = null;
    }

    final effectiveTextColor = widget.onPressed == null
        ? textColor.withValues(alpha: 0.4)
        : textColor;

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _pressController,
          builder: (context, child) {
            final double scale =
                1.0 - (1.0 - ZohalMotion.pressScale) * _pressController.value;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: widget.width,
                height: widget.height,
                constraints: const BoxConstraints(minWidth: 88.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: border,
                  borderRadius: BorderRadius.zero,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8.0),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500,
                        color: effectiveTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
