// design/components/sharp_row.dart
// Grouped 56 dp row for Zohal Connect. Flat surface, zero radius, hairline separator.

import 'package:flutter/material.dart';

import '../tokens.dart';

class SharpRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const SharpRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            constraints: const BoxConstraints(minHeight: ZohalTokens.rowHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16.0)],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: ZohalTokens.fontFamily,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2.0),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: ZohalTokens.fontFamily,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12.0),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
        if (showDivider) Container(height: 1.0, color: hairline),
      ],
    );
  }
}
