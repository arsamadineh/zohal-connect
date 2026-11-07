// features/about/update_dialog.dart
// Dialog for in-app update download and installation with byte progress, speed, ETA, and pause/resume handles.
// Complies with ZOHAL_SPEC: sharp corners (R18), Persian UI, no emojis.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/persian.dart';
import '../../core/updater.dart';
import '../../design/components/sharp_button.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final IResumableDownloader? downloader;

  const UpdateDialog({
    super.key,
    required this.info,
    this.downloader,
  });

  static Future<void> show(
    BuildContext context,
    UpdateInfo info, {
    IResumableDownloader? downloader,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(info: info, downloader: downloader),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  late final IResumableDownloader _downloader;
  StreamSubscription<DownloadProgress>? _progressSub;
  DownloadProgress _progress = DownloadProgress.idle(0);
  String? _errorMessage;
  File? _downloadedFile;
  bool _isInstalling = false;

  @override
  void initState() {
    super.initState();
    _downloader = widget.downloader ?? ResumableDownloader(info: widget.info);
    _progress = widget.downloader?.currentProgress ??
        DownloadProgress.idle(widget.info.sizeBytes ?? 0);

    _progressSub = _downloader.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
        if (progress.status == DownloadStatus.failed) {
          _errorMessage = progress.errorMessage ?? StringsFa.updateFailed;
        }
      });

      if (progress.status == DownloadStatus.readyToInstall &&
          _downloadedFile != null) {
        unawaited(_handleInstall(_downloadedFile!));
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _handleStartDownload() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final file = await _downloader.start(
        info: widget.info,
        expectedSha256: widget.info.expectedSha256,
      );
      _downloadedFile = file;
      if (mounted) {
        await _handleInstall(file);
      }
    } catch (e) {
      if (e is DownloadCancelledException ||
          e.toString().contains('DownloadCancelledException')) {
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = e is ChecksumMismatchException ||
                  e.toString().contains('ChecksumMismatchException')
              ? StringsFa.updateVerificationFailed
              : StringsFa.updateFailed;
        });
      }
    }
  }

  void _handlePause() {
    _downloader.pause();
  }

  void _handleResume() {
    setState(() {
      _errorMessage = null;
    });
    unawaited(_downloader.resume().then((file) {
      _downloadedFile = file;
      if (mounted) {
        unawaited(_handleInstall(file));
      }
    }).catchError((dynamic e) {
      if (e is DownloadCancelledException ||
          e.toString().contains('DownloadCancelledException')) {
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = e is ChecksumMismatchException ||
                  e.toString().contains('ChecksumMismatchException')
              ? StringsFa.updateVerificationFailed
              : StringsFa.updateFailed;
        });
      }
    }));
  }

  void _handleCancel() {
    unawaited(_downloader.cancel());
    Navigator.of(context).pop();
  }

  Future<void> _handleInstall(File file) async {
    if (!mounted || _isInstalling) return;
    _isInstalling = true;
    setState(() {
      _progress = DownloadProgress(
        status: DownloadStatus.installing,
        bytesReceived: _progress.bytesReceived,
        totalBytes: _progress.totalBytes,
        progressFraction: 1.0,
        speedBytesPerSec: 0.0,
      );
    });
    await installUpdate(file);
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
            // Version and File Size Header
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

            // Release Notes (Visible when Idle or Error)
            if (_progress.status == DownloadStatus.idle &&
                widget.info.releaseNotes != null &&
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

            // Active Progress & Status View
            if (_progress.status == DownloadStatus.downloading ||
                _progress.status == DownloadStatus.connecting) ...[
              LinearProgressIndicator(
                value: _progress.progressFraction > 0
                    ? _progress.progressFraction
                    : null,
                minHeight: 6.0,
                borderRadius: BorderRadius.zero,
                backgroundColor: hairline,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
              const SizedBox(height: 8.0),
              // Progress Row (Bytes & Percentage)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      StringsFa.updateDownloading,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  if (_progress.totalBytes > 0)
                    Flexible(
                      child: Text(
                        '${Persian.formatPercent((_progress.progressFraction * 100).toInt())} '
                        '(${Persian.formatBytes(_progress.bytesReceived)} از ${Persian.formatBytes(_progress.totalBytes)})',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontFamily: ZohalTokens.fontFamily,
                          fontSize: 12.0,
                          color: textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4.0),
              // Speed & ETA Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${StringsFa.updateSpeed} ${Persian.formatByteRate(_progress.speedBytesPerSec)}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 11.0,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  if (_progress.estimatedTimeRemaining != null)
                    Flexible(
                      child: Text(
                        '${StringsFa.updateEta} ${Persian.formatEta(_progress.estimatedTimeRemaining)}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: ZohalTokens.fontFamily,
                          fontSize: 11.0,
                          color: textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ] else if (_progress.status == DownloadStatus.paused) ...[
              LinearProgressIndicator(
                value: _progress.progressFraction,
                minHeight: 6.0,
                borderRadius: BorderRadius.zero,
                backgroundColor: hairline,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      StringsFa.updatePaused,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Text(
                      '${Persian.formatPercent((_progress.progressFraction * 100).toInt())} '
                      '(${Persian.formatBytes(_progress.bytesReceived)} از ${Persian.formatBytes(_progress.totalBytes)})',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_progress.status == DownloadStatus.retrying) ...[
              LinearProgressIndicator(
                minHeight: 6.0,
                borderRadius: BorderRadius.zero,
                backgroundColor: hairline,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.error),
              ),
              const SizedBox(height: 8.0),
              Text(
                '${StringsFa.updateReconnecting} (${Persian.formatNumber(_progress.retryAttempt)} از ${Persian.formatNumber(_progress.maxRetries)})',
                style: TextStyle(
                  fontSize: 12.0,
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_progress.status == DownloadStatus.verifying) ...[
              LinearProgressIndicator(
                minHeight: 6.0,
                borderRadius: BorderRadius.zero,
                backgroundColor: hairline,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
              const SizedBox(height: 8.0),
              Text(
                StringsFa.updateVerifying,
                style: TextStyle(
                  fontSize: 12.0,
                  color: textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_progress.status == DownloadStatus.installing ||
                _progress.status == DownloadStatus.readyToInstall) ...[
              LinearProgressIndicator(
                minHeight: 6.0,
                borderRadius: BorderRadius.zero,
                backgroundColor: hairline,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
              const SizedBox(height: 8.0),
              Text(
                StringsFa.updateInstalling,
                style: TextStyle(
                  fontSize: 12.0,
                  color: textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Error banner
            if (_errorMessage != null &&
                _progress.status != DownloadStatus.downloading &&
                _progress.status != DownloadStatus.connecting &&
                _progress.status != DownloadStatus.verifying &&
                _progress.status != DownloadStatus.installing) ...[
              const SizedBox(height: 8.0),
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
        if (_progress.status == DownloadStatus.idle &&
            _errorMessage == null) ...[
          SharpButton(
            label: StringsFa.updateLater,
            isOutlined: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8.0),
          SharpButton(
            label: StringsFa.updateDownloadAndInstall,
            onPressed: _handleStartDownload,
          ),
        ] else if (_progress.status == DownloadStatus.downloading ||
            _progress.status == DownloadStatus.connecting) ...[
          SharpButton(
            label: StringsFa.cancel,
            isOutlined: true,
            onPressed: _handleCancel,
          ),
          const SizedBox(width: 8.0),
          SharpButton(
            label: StringsFa.updatePause,
            isOutlined: true,
            onPressed: _handlePause,
          ),
        ] else if (_progress.status == DownloadStatus.paused) ...[
          SharpButton(
            label: StringsFa.cancel,
            isOutlined: true,
            onPressed: _handleCancel,
          ),
          const SizedBox(width: 8.0),
          SharpButton(
            label: StringsFa.updateResume,
            onPressed: _handleResume,
          ),
        ] else if (_progress.status == DownloadStatus.retrying) ...[
          SharpButton(
            label: StringsFa.cancel,
            isOutlined: true,
            onPressed: _handleCancel,
          ),
          const SizedBox(width: 8.0),
          SharpButton(
            label: StringsFa.updateRetry,
            onPressed: _handleResume,
          ),
        ] else if (_progress.status == DownloadStatus.verifying) ...[
          SharpButton(
            label: StringsFa.cancel,
            isOutlined: true,
            onPressed: _handleCancel,
          ),
        ] else if (_progress.status == DownloadStatus.failed ||
            _errorMessage != null) ...[
          SharpButton(
            label: StringsFa.close,
            isOutlined: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8.0),
          SharpButton(
            label: StringsFa.updateRetry,
            onPressed: _progress.status == DownloadStatus.idle
                ? _handleStartDownload
                : _handleResume,
          ),
        ],
      ],
    );
  }
}
