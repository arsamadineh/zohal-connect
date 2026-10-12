// features/about/update_dialog.dart
// Dialog for in-app update download and installation with byte progress.
// Complies with ZOHAL_SPEC: sharp corners (R18), Persian UI, no emojis.
import 'package:flutter/material.dart';

import '../../core/persian.dart';
import '../../core/updater.dart';
import '../../design/components/sharp_button.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _isInstalling = false;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.info.sizeBytes ?? 0;
      _errorMessage = null;
    });

    try {
      final downloadedFile = await downloadUpdate(
        widget.info,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _isInstalling = true;
      });

      await installUpdate(downloadedFile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
          _errorMessage = StringsFa.updateFailed;
        });
      }
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

    final versionFormatted =
        Persian.ltrIsolate(Persian.toPersianDigits(widget.info.version));

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: theme.scaffoldBackgroundColor,
      title: Text(
        StringsFa.updateAvailableTitle,
        style: TextStyle(
          fontFamily: ZohalTokens.fontFamily,
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      content: SizedBox(
        width: 420.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${StringsFa.aboutVersion} $versionFormatted',
                  style: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                if (widget.info.sizeBytes != null &&
                    widget.info.sizeBytes! > 0) ...[
                  const Spacer(),
                  Text(
                    Persian.formatBytes(widget.info.sizeBytes!),
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 13.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12.0),
            if (widget.info.releaseNotes != null &&
                widget.info.releaseNotes!.trim().isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 140.0),
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  border: Border.all(color: hairline),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.releaseNotes!.trim(),
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 12.0,
                      height: 1.5,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
            ],
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 6.0,
                borderRadius: BorderRadius.zero,
                backgroundColor: hairline,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    StringsFa.updateDownloading,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                  if (_totalBytes > 0)
                    Text(
                      '${Persian.toPersianDigits((_progress * 100).toInt().toString())}٪ '
                      '(${Persian.formatBytes(_receivedBytes)} از ${Persian.formatBytes(_totalBytes)})',
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                ],
              ),
            ] else if (_isInstalling) ...[
              LinearProgressIndicator(
                minHeight: 6.0,
                borderRadius: BorderRadius.zero,
                backgroundColor: hairline,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                StringsFa.updateInstalling,
                style: TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 12.0,
                  color: textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8.0),
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 12.0,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading && !_isInstalling) ...[
          SharpButton(
            label: StringsFa.updateLater,
            isOutlined: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8.0),
          SharpButton(
            label: _errorMessage != null
                ? StringsFa.updateRetry
                : StringsFa.updateDownloadAndInstall,
            onPressed: _startDownloadAndInstall,
          ),
        ],
      ],
    );
  }
}
