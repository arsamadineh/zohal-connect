// features/logs/logs_screen.dart
// Logs screen for Zohal Connect according to ZOHAL_SPEC Section 13.5.
// Real-time log list from in-memory ring buffer with filtering and diagnostic export.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logger.dart';
import '../../core/persian.dart';
import '../../design/components/sharp_button.dart';
import '../../design/components/sharp_toast.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool _filterErrorsOnly = false;

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
    final errorColor = isDark ? ZohalTokens.darkError : ZohalTokens.lightError;
    final accent = theme.colorScheme.primary;

    final entries = ZohalLogger().getEntries(
      minLevel: _filterErrorsOnly ? LogLevel.error : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          StringsFa.logs,
          style: TextStyle(
            fontFamily: ZohalTokens.fontFamily,
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_sharp, size: 20.0),
            tooltip: StringsFa.settingsCopyAll,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ZohalLogger().exportAll()));
              SharpToast.show(context, StringsFa.toastCopied);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: hairline, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: hairline, width: 1.0)),
              ),
              child: Row(
                children: [
                  SharpButton(
                    label: StringsFa.logsFilterAll,
                    isOutlined: _filterErrorsOnly,
                    height: 36.0,
                    onPressed: () {
                      setState(() => _filterErrorsOnly = false);
                    },
                  ),
                  const SizedBox(width: 8.0),
                  SharpButton(
                    label: StringsFa.logsFilterErrors,
                    isOutlined: !_filterErrorsOnly,
                    height: 36.0,
                    onPressed: () {
                      setState(() => _filterErrorsOnly = true);
                    },
                  ),
                ],
              ),
            ),

            // Log entries list
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        StringsFa.logsEmpty,
                        style: TextStyle(
                          fontFamily: ZohalTokens.fontFamily,
                          fontSize: 14.0,
                          color: textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          Container(height: 1.0, color: hairline),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isError = entry.level == LogLevel.error;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.formattedTime,
                                style: TextStyle(
                                  fontFamily: ZohalTokens.fontFamily,
                                  fontSize: 12.0,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 1.0,
                                ),
                                decoration: BoxDecoration(
                                  color: isError
                                      ? errorColor.withOpacity(0.15)
                                      : textSecondary.withOpacity(0.15),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Text(
                                  Persian.ltrIsolate(entry.levelLabel),
                                  style: TextStyle(
                                    fontFamily: ZohalTokens.fontFamily,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: isError ? errorColor : textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  entry.message,
                                  style: TextStyle(
                                    fontFamily: ZohalTokens.fontFamily,
                                    fontSize: 13.0,
                                    color: isError ? errorColor : textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
