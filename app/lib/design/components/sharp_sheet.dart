// design/components/sharp_sheet.dart
// Sharp modal bottom sheet for Zohal Connect. Zero border radius, 24x2 dp rectangular grabber.

import 'package:flutter/material.dart';

import '../tokens.dart';

class SharpSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const SharpSheet({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceRaised = isDark
        ? ZohalTokens.darkSurfaceRaised
        : ZohalTokens.lightSurfaceRaised;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: surfaceRaised,
      elevation: 0.0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) =>
          SharpSheet(title: title, trailing: trailing, child: child),
    );
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

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? ZohalTokens.darkSurfaceRaised
            : ZohalTokens.lightSurfaceRaised,
        border: Border(top: BorderSide(color: hairline, width: 1.0)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12.0),
          // 24 x 2 dp rectangular grabber
          Container(
            width: 24.0,
            height: 2.0,
            color: textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 16.0),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
                IconButton(
                  icon: const Icon(Icons.close_sharp, size: 20.0),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'بستن',
                ),
              ],
            ),
          ),
          Container(
            height: 1.0,
            color: hairline,
            margin: const EdgeInsets.only(top: 12.0),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
