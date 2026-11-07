// core/updater.dart
// Automatic and manual update checker, resumable downloader, and installer for Zohal Connect.
// Queries GitHub Releases API directly with zero telemetry and zero tracking pings (R11).
// Features HTTP Range resumption, SHA256 integrity verification, and atomic replacement (R2).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tray_manager/tray_manager.dart';

import 'logger.dart';
import 'single_instance.dart';
import 'vpn_channel.dart';

// =============================================================================
// Update Information Model
// =============================================================================

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String filename;
  final int? sizeBytes;
  final String? releaseNotes;
  final String? expectedSha256;
  final String? sha256SumsUrl;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.filename,
    this.sizeBytes,
    this.releaseNotes,
    this.expectedSha256,
    this.sha256SumsUrl,
  });

  /// Alias for expectedSha256 to support both naming styles
  String? get sha256 => expectedSha256;
}

// =============================================================================
// Startup Deferral & Provider State Scoping
// =============================================================================

/// Configurable startup delay for the initial update check.
/// Defaults to 3 seconds in production to avoid contention on startup frame 1 (<250ms).
/// Can be overridden to Duration.zero in tests via ProviderScope.
final initialUpdateDelayProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 3);
});

/// Riverpod-scoped state tracking whether the initial deferred check has fired.
/// Bound to ProviderContainer lifecycle so each test container gets isolated state.
final hasRunInitialUpdateCheckProvider = StateProvider<bool>((ref) => false);

/// Top-level backing flag for legacy tests with explicit reset capability.
@visibleForTesting
bool isFirstUpdateCheck = true;

/// Explicit reset helper for tests to guarantee clean isolation.
@visibleForTesting
void resetUpdateCheckStateForTesting({bool isFirst = true}) {
  isFirstUpdateCheck = isFirst;
}

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  final hasRunScoped = ref.read(hasRunInitialUpdateCheckProvider);
  if (!hasRunScoped && isFirstUpdateCheck) {
    isFirstUpdateCheck = false;
    unawaited(
      Future.microtask(() {
        try {
          ref.read(hasRunInitialUpdateCheckProvider.notifier).state = true;
        } catch (_) {}
      }),
    );
    final delay = ref.watch(initialUpdateDelayProvider);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
  return fetchLatestUpdate();
});

// =============================================================================
// SHA256 Integrity Verification Helpers
// =============================================================================

class ChecksumMismatchException implements Exception {
  final String expected;
  final String actual;
  const ChecksumMismatchException({
    required this.expected,
    required this.actual,
  });

  @override
  String toString() =>
      'ChecksumMismatchException: expected $expected, got $actual';
}

/// Parses standard GNU sha256sum output into a map of filename -> lowercase 64-hex hash.
Map<String, String> parseSha256Sums(String text) {
  final Map<String, String> checksums = {};
  final lines = const LineSplitter().convert(text);
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    // Matches: 64 hex characters + whitespace + optional '*' (binary flag) + filename
    final match = RegExp(r'^([A-Fa-f0-9]{64})\s+[\*]?(.*)$').firstMatch(line);
    if (match != null) {
      final hash = match.group(1)!.toLowerCase();
      var filename = match.group(2)!.trim();
      if (filename.contains('/')) {
        filename = filename.split('/').last;
      }
      if (filename.contains(r'\')) {
        filename = filename.split(r'\').last;
      }
      if (filename.isNotEmpty) {
        checksums[filename] = hash;
      }
    }
  }
  return checksums;
}

/// Computes SHA256 digest of a local file in a memory-bounded stream (~64 KB chunks).
Future<String> computeFileSha256(File file) async {
  final stream = file.openRead();
  final digest = await sha256.bind(stream).first;
  return digest.toString().toLowerCase();
}

// =============================================================================
// Android ABI Resolution
// =============================================================================

/// Queries native Android Build.SUPPORTED_ABIS via platform channel.
Future<List<String>> getAndroidSupportedAbis() async {
  if (!Platform.isAndroid) return const [];
  try {
    const channel = MethodChannel('app.zohal.connect/vpn');
    final list = await channel.invokeMethod<List<dynamic>>('getSupportedAbis');
    if (list != null) {
      return list.map((e) => e.toString()).toList();
    }
  } catch (_) {}
  return const [];
}

/// Selects the best APK asset matching device supported ABIs in priority order.
Map<String, dynamic>? selectAndroidApkAsset({
  required List<dynamic> assets,
  required List<String> deviceAbis,
}) {
  final apkAssets = assets.whereType<Map<String, dynamic>>().where((asset) {
    final name = (asset['name'] as String? ?? '').toLowerCase();
    return name.endsWith('.apk') && asset['browser_download_url'] != null;
  }).toList();

  if (apkAssets.isEmpty) return null;

  // 1. Match against device supported ABIs in priority order
  for (final rawAbi in deviceAbis) {
    final abi = rawAbi.toLowerCase().trim();
    if (abi.isEmpty) continue;

    for (final asset in apkAssets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains(abi) ||
          (abi == 'arm64-v8a' &&
              (name.contains('arm64') || name.contains('aarch64'))) ||
          (abi == 'armeabi-v7a' &&
              (name.contains('armv7') || name.contains('v7a'))) ||
          (abi == 'x86_64' &&
              (name.contains('x64') || name.contains('amd64')))) {
        return asset;
      }
    }
  }

  // 2. Look for universal / fat APK
  for (final asset in apkAssets) {
    final name = (asset['name'] as String? ?? '').toLowerCase();
    if (name.contains('universal') || name.contains('fat')) {
      return asset;
    }
    final hasArch = name.contains('arm') ||
        name.contains('v8a') ||
        name.contains('v7a') ||
        name.contains('x86') ||
        name.contains('aarch');
    if (!hasArch) {
      return asset;
    }
  }

  // 3. Fallback: first APK
  return apkAssets.first;
}

// =============================================================================
// GitHub Release Fetching
// =============================================================================

Future<UpdateInfo?> fetchLatestUpdate({
  bool force = false,
  http.Client Function()? clientFactory,
}) async {
  if (!Platform.isLinux &&
      !Platform.isWindows &&
      !Platform.isMacOS &&
      !Platform.isAndroid) {
    return null;
  }

  final client = clientFactory != null ? clientFactory() : http.Client();
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final response = await client.get(
      Uri.parse(
        'https://api.github.com/repos/arsamadineh/zohal-connect/releases/latest',
      ),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'ZohalConnect/$currentVersion',
      },
    ).timeout(const Duration(seconds: 7));

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = json['tag_name'] as String? ?? '';
    final remoteVersion = tagName.replaceAll(RegExp(r'^[vV]'), '').trim();

    if (remoteVersion.isEmpty) return null;

    if (force || isNewerVersion(remoteVersion, currentVersion)) {
      final assets = json['assets'] as List<dynamic>? ?? [];
      String downloadUrl = json['html_url'] as String? ??
          'https://github.com/arsamadineh/zohal-connect/releases';
      String filename = '';
      int? sizeBytes;
      String? sha256SumsUrl;

      // First pass: locate SHA256SUMS.txt if present
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name == 'sha256sums.txt' || name == 'sha256sums') {
            sha256SumsUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      // Fetch and parse SHA256SUMS.txt if available
      Map<String, String> checksumMap = {};
      if (sha256SumsUrl != null) {
        try {
          final sumsRes = await client.get(
            Uri.parse(sha256SumsUrl),
            headers: {'User-Agent': 'ZohalConnect/$currentVersion'},
          ).timeout(const Duration(seconds: 5));
          if (sumsRes.statusCode == 200) {
            checksumMap = parseSha256Sums(sumsRes.body);
          }
        } catch (e) {
          ZohalLogger().debug('Failed to fetch SHA256SUMS.txt: $e');
        }
      }

      // Second pass: locate package asset according to platform & ABI
      if (Platform.isAndroid) {
        final deviceAbis = await getAndroidSupportedAbis();
        final selected = selectAndroidApkAsset(
          assets: assets,
          deviceAbis: deviceAbis,
        );
        if (selected != null) {
          downloadUrl = selected['browser_download_url'] as String? ?? downloadUrl;
          filename = selected['name'] as String? ?? '';
          sizeBytes = selected['size'] as int?;
        }
      } else {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            final rawName = asset['name'] as String? ?? '';
            final url = asset['browser_download_url'] as String?;
            final size = asset['size'] as int?;

            if (url != null) {
              if (Platform.isLinux && name.endsWith('.appimage')) {
                downloadUrl = url;
                filename = rawName;
                sizeBytes = size;
                break;
              } else if (Platform.isWindows && name.endsWith('.exe')) {
                downloadUrl = url;
                filename = rawName;
                sizeBytes = size;
                break;
              }
            }
          }
        }
      }

      if (filename.isEmpty) {
        if (Platform.isLinux) {
          filename = 'zohal-connect-$remoteVersion.AppImage';
        } else if (Platform.isAndroid) {
          filename = 'zohal-connect-$remoteVersion.apk';
        } else if (Platform.isWindows) {
          filename = 'zohal-connect-$remoteVersion.exe';
        } else {
          filename = 'zohal-connect-$remoteVersion';
        }
      }

      final expectedSha256 = checksumMap[filename];
      final body = json['body'] as String?;

      return UpdateInfo(
        version: remoteVersion,
        downloadUrl: downloadUrl,
        filename: filename,
        sizeBytes: sizeBytes,
        releaseNotes: body,
        expectedSha256: expectedSha256,
        sha256SumsUrl: sha256SumsUrl,
      );
    }
  } catch (e) {
    ZohalLogger().debug('Update check failed (safe fallback): $e');
  } finally {
    client.close();
  }

  return null;
}

// =============================================================================
// Resumable Downloader State & Interface
// =============================================================================

enum DownloadStatus {
  idle,
  connecting,
  downloading,
  paused,
  retrying,
  verifying,
  readyToInstall,
  installing,
  completed,
  failed,
  canceled,
}

class DownloadProgress {
  final int bytesReceived;
  final int totalBytes;
  final double progressFraction;
  final double speedBytesPerSec;
  final Duration? estimatedTimeRemaining;
  final DownloadStatus status;
  final int retryAttempt;
  final int maxRetries;
  final String? errorMessage;

  const DownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
    required this.progressFraction,
    this.speedBytesPerSec = 0.0,
    this.estimatedTimeRemaining,
    required this.status,
    this.retryAttempt = 0,
    this.maxRetries = 5,
    this.errorMessage,
  });

  /// Alias for backward compatibility
  int get receivedBytes => bytesReceived;

  bool get isPaused => status == DownloadStatus.paused;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isCompleted =>
      status == DownloadStatus.completed || status == DownloadStatus.readyToInstall;
  bool get isRetrying => status == DownloadStatus.retrying;
  bool get isVerifying => status == DownloadStatus.verifying;
  bool get isInstalling => status == DownloadStatus.installing;
  bool get isFailed => status == DownloadStatus.failed;

  factory DownloadProgress.idle(int totalBytes) => DownloadProgress(
        bytesReceived: 0,
        totalBytes: totalBytes,
        progressFraction: 0.0,
        speedBytesPerSec: 0.0,
        status: DownloadStatus.idle,
      );
}

class DownloadCancelledException implements Exception {
  final String message;
  DownloadCancelledException([this.message = 'Download cancelled by user']);
  @override
  String toString() => message;
}

class DownloadException implements Exception {
  final String message;
  final dynamic cause;
  DownloadException(this.message, [this.cause]);
  @override
  String toString() => cause != null ? '$message: $cause' : message;
}

abstract class IResumableDownloader {
  Stream<DownloadProgress> get progressStream;
  DownloadProgress get currentProgress;

  Future<File> start({
    UpdateInfo? info,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
  });

  void pause();
  Future<File> resume();
  Future<void> cancel();
}

class _ByteSample {
  final int timestampMs;
  final int bytes;
  const _ByteSample(this.timestampMs, this.bytes);
}

// =============================================================================
// ResumableDownloader Implementation
// =============================================================================

class ResumableDownloader implements IResumableDownloader {
  final UpdateInfo? info;
  final Directory? storageDirectory;
  final http.Client Function()? clientFactory;
  final Future<bool> Function(File partFile)? integrityVerifier;
  final int maxRetries;

  ResumableDownloader({
    this.info,
    this.storageDirectory,
    this.clientFactory,
    this.integrityVerifier,
    this.maxRetries = 5,
  }) {
    _currentProgress = DownloadProgress.idle(info?.sizeBytes ?? 0);
  }

  final StreamController<DownloadProgress> _progressStreamController =
      StreamController<DownloadProgress>.broadcast(sync: true);

  @override
  Stream<DownloadProgress> get progressStream =>
      _progressStreamController.stream;

  DownloadProgress _currentProgress = DownloadProgress.idle(0);

  @override
  DownloadProgress get currentProgress => _currentProgress;

  DownloadStatus _status = DownloadStatus.idle;
  DownloadStatus get status => _status;

  UpdateInfo? _activeInfo;
  String? _expectedSha256;

  int _receivedBytes = 0;
  int _totalBytes = 0;
  int _retryCount = 0;

  bool _isPaused = false;
  bool _isCancelled = false;

  http.Client? _activeClient;
  StreamSubscription<List<int>>? _streamSubscription;
  Completer<void>? _activeChunkCompleter;
  IOSink? _activeSink;
  Completer<File>? _activeCompleter;
  void Function(DownloadProgress)? _progressCallback;

  final List<_ByteSample> _speedSamples = [];
  static const int _windowDurationMs = 2000;
  static const int _minDurationMs = 250;

  Directory get _dir =>
      storageDirectory ??
      Directory('${Directory.systemTemp.path}/zohal_update');

  File get targetFile => File('${_dir.path}/${_activeInfo!.filename}');
  File get partFile => File('${_dir.path}/${_activeInfo!.filename}.part');

  @override
  Future<File> start({
    UpdateInfo? info,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
  }) async {
    _activeInfo = info ?? this.info;
    if (_activeInfo == null) {
      throw ArgumentError('UpdateInfo must be provided to start download');
    }
    _expectedSha256 = expectedSha256 ?? _activeInfo!.expectedSha256;

    if (_status == DownloadStatus.downloading ||
        _status == DownloadStatus.connecting) {
      return _activeCompleter?.future ??
          Future.error(StateError('Download already in progress'));
    }

    _progressCallback = onProgress;
    _isPaused = false;
    _isCancelled = false;
    _retryCount = 0;
    _speedSamples.clear();

    _activeCompleter = Completer<File>();
    unawaited(_runDownloadLoop());
    return _activeCompleter!.future;
  }

  @override
  void pause() {
    if (_status != DownloadStatus.downloading &&
        _status != DownloadStatus.connecting &&
        _status != DownloadStatus.retrying) {
      return;
    }

    _isPaused = true;
    _status = DownloadStatus.paused;
    _tearDownCurrentStream();
    _emitProgress(DownloadStatus.paused);
  }

  @override
  Future<File> resume() async {
    if (_status != DownloadStatus.paused &&
        _status != DownloadStatus.failed &&
        _status != DownloadStatus.idle) {
      return _activeCompleter?.future ??
          Future.error(StateError('Cannot resume when in state $_status'));
    }

    _isPaused = false;
    _isCancelled = false;
    _speedSamples.clear();
    _activeCompleter = Completer<File>();
    unawaited(_runDownloadLoop());
    return _activeCompleter!.future;
  }

  @override
  Future<void> cancel() async {
    _isCancelled = true;
    _status = DownloadStatus.canceled;
    _tearDownCurrentStream();

    if (_activeInfo != null && await partFile.exists()) {
      try {
        await partFile.delete();
      } catch (_) {}
    }

    _emitProgress(DownloadStatus.canceled);
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.completeError(DownloadCancelledException());
    }
  }

  void _tearDownCurrentStream() {
    if (_activeChunkCompleter != null && !_activeChunkCompleter!.isCompleted) {
      _activeChunkCompleter!.complete();
      _activeChunkCompleter = null;
    }
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _activeClient?.close();
    _activeClient = null;
    try {
      _activeSink?.flush();
      _activeSink?.close();
    } catch (_) {}
    _activeSink = null;
  }

  Future<void> _runDownloadLoop() async {
    while (!_isPaused && !_isCancelled) {
      try {
        if (!await _dir.exists()) {
          await _dir.create(recursive: true);
        }

        int offset = 0;
        if (await partFile.exists()) {
          offset = await partFile.length();
          if (_activeInfo!.sizeBytes != null &&
              offset > _activeInfo!.sizeBytes!) {
            await partFile.delete();
            offset = 0;
          }
        }
        _receivedBytes = offset;
        _totalBytes = _activeInfo!.sizeBytes ?? 0;

        _status = DownloadStatus.connecting;
        _emitProgress(DownloadStatus.connecting);

        final client = clientFactory != null ? clientFactory!() : http.Client();
        _activeClient = client;

        final request = http.Request('GET', Uri.parse(_activeInfo!.downloadUrl));
        request.headers['User-Agent'] = 'ZohalConnect/${_activeInfo!.version}';
        request.headers['Accept'] = '*/*';

        if (offset > 0) {
          request.headers['Range'] = 'bytes=$offset-';
        }

        final http.StreamedResponse streamedResponse;
        try {
          streamedResponse = await client.send(request);
        } catch (e) {
          if (_isPaused || _isCancelled) return;
          rethrow;
        }

        final statusCode = streamedResponse.statusCode;

        // HTTP 416: Range Not Satisfiable
        if (statusCode == 416) {
          if (_totalBytes > 0 && offset >= _totalBytes) {
            await _finalizeDownload();
            return;
          } else {
            await partFile.delete();
            offset = 0;
            _receivedBytes = 0;
            continue;
          }
        }

        if (statusCode != 200 && statusCode != 206) {
          throw HttpException(
            'HTTP error $statusCode: ${streamedResponse.reasonPhrase}',
          );
        }

        final bool isPartial = statusCode == 206;

        if (isPartial) {
          final contentRange = streamedResponse.headers['content-range'] ?? '';
          final match =
              RegExp(r'bytes\s+\d+-\d+/(\d+)').firstMatch(contentRange);
          if (match != null) {
            _totalBytes = int.parse(match.group(1)!);
          } else if (streamedResponse.contentLength != null) {
            _totalBytes = offset + streamedResponse.contentLength!;
          }
          _activeSink = partFile.openWrite(mode: FileMode.writeOnlyAppend);
        } else {
          // HTTP 200: Server restarted from byte 0 or ignored Range
          offset = 0;
          _receivedBytes = 0;
          _totalBytes =
              streamedResponse.contentLength ?? _activeInfo!.sizeBytes ?? 0;
          _activeSink = partFile.openWrite(mode: FileMode.write);
        }

        _status = DownloadStatus.downloading;
        _emitProgress(DownloadStatus.downloading);

        final chunkCompleter = Completer<void>();
        _activeChunkCompleter = chunkCompleter;

        _streamSubscription = streamedResponse.stream.listen(
          (chunk) {
            if (_isPaused || _isCancelled) return;
            _activeSink?.add(chunk);
            _receivedBytes += chunk.length;
            _recordSpeedSample(_receivedBytes);
            _emitProgress(DownloadStatus.downloading);
          },
          onError: (Object err, StackTrace st) {
            if (!chunkCompleter.isCompleted) {
              chunkCompleter.completeError(err, st);
            }
          },
          onDone: () {
            if (!chunkCompleter.isCompleted) {
              chunkCompleter.complete();
            }
          },
          cancelOnError: true,
        );

        await chunkCompleter.future;

        if (_isPaused || _isCancelled) return;

        await _activeSink?.flush();
        await _activeSink?.close();
        _activeSink = null;

        await _finalizeDownload();
        return;
      } catch (e) {
        if (_isPaused || _isCancelled) return;

        _tearDownCurrentStream();

        _retryCount++;
        if (_retryCount > maxRetries) {
          _status = DownloadStatus.failed;
          _emitProgress(
            DownloadStatus.failed,
            errorMessage: 'Download failed after $maxRetries retries: $e',
          );
          if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
            _activeCompleter!.completeError(
              DownloadException('Download failed after $maxRetries retries', e),
            );
          }
          return;
        }

        _status = DownloadStatus.retrying;
        _emitProgress(DownloadStatus.retrying);

        final backoffDelayMs = 1000 * (1 << (_retryCount - 1));
        await Future<void>.delayed(Duration(milliseconds: backoffDelayMs));
      }
    }
  }

  Future<void> _finalizeDownload() async {
    _status = DownloadStatus.verifying;
    _emitProgress(DownloadStatus.verifying);

    // 1. Check SHA256 integrity if hash is present
    if (_expectedSha256 != null && _expectedSha256!.isNotEmpty) {
      try {
        final actualHash = await computeFileSha256(partFile);
        if (actualHash.toLowerCase() != _expectedSha256!.toLowerCase()) {
          if (await partFile.exists()) {
            await partFile.delete();
          }
          _status = DownloadStatus.failed;
          final error = ChecksumMismatchException(
            expected: _expectedSha256!,
            actual: actualHash,
          );
          _emitProgress(
            DownloadStatus.failed,
            errorMessage: error.toString(),
          );
          if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
            _activeCompleter!.completeError(error);
          }
          return;
        }
      } catch (e) {
        if (e is ChecksumMismatchException) rethrow;
        if (await partFile.exists()) {
          await partFile.delete();
        }
        _status = DownloadStatus.failed;
        _emitProgress(
          DownloadStatus.failed,
          errorMessage: 'Integrity check error: $e',
        );
        if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
          _activeCompleter!.completeError(
            DownloadException('Integrity verification failed', e),
          );
        }
        return;
      }
    }

    // 2. Custom integrity verifier hook if configured
    if (integrityVerifier != null) {
      final isValid = await integrityVerifier!(partFile);
      if (!isValid) {
        if (await partFile.exists()) {
          await partFile.delete();
        }
        _status = DownloadStatus.failed;
        const msg = 'File integrity verification hook failed';
        _emitProgress(DownloadStatus.failed, errorMessage: msg);
        if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
          _activeCompleter!.completeError(DownloadException(msg));
        }
        return;
      }
    }

    // 3. Atomically replace target file
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    final finalFile = await partFile.rename(targetFile.path);

    _status = DownloadStatus.readyToInstall;
    _emitProgress(DownloadStatus.readyToInstall);

    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(finalFile);
    }
  }

  void _recordSpeedSample(int currentBytes) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _speedSamples.add(_ByteSample(nowMs, currentBytes));

    final cutoff = nowMs - _windowDurationMs;
    while (_speedSamples.length > 2 && _speedSamples[1].timestampMs < cutoff) {
      _speedSamples.removeAt(0);
    }
  }

  double _calculateSpeedBytesPerSec() {
    if (_speedSamples.length < 2) return 0.0;
    final oldest = _speedSamples.first;
    final newest = _speedSamples.last;
    final deltaMs = newest.timestampMs - oldest.timestampMs;
    if (deltaMs < _minDurationMs) return 0.0;
    final deltaBytes = newest.bytes - oldest.bytes;
    if (deltaBytes <= 0) return 0.0;
    return (deltaBytes / deltaMs) * 1000.0;
  }

  Duration? _calculateEta(double speedBytesPerSec, int remainingBytes) {
    if (speedBytesPerSec <= 0 || remainingBytes <= 0) return null;
    final seconds = (remainingBytes / speedBytesPerSec).ceil();
    if (seconds <= 0 || seconds > 604800) return null;
    return Duration(seconds: seconds);
  }

  void _emitProgress(DownloadStatus status, {String? errorMessage}) {
    final speed = (status == DownloadStatus.downloading)
        ? _calculateSpeedBytesPerSec()
        : 0.0;
    final remainingBytes =
        (_totalBytes > _receivedBytes) ? _totalBytes - _receivedBytes : 0;
    final eta = (status == DownloadStatus.downloading)
        ? _calculateEta(speed, remainingBytes)
        : null;

    final progressFraction = _totalBytes > 0
        ? (_receivedBytes / _totalBytes).clamp(0.0, 1.0)
        : 0.0;

    final progress = DownloadProgress(
      bytesReceived: _receivedBytes,
      totalBytes: _totalBytes,
      progressFraction: progressFraction,
      speedBytesPerSec: speed,
      estimatedTimeRemaining: eta,
      status: status,
      retryAttempt: _retryCount,
      maxRetries: maxRetries,
      errorMessage: errorMessage,
    );

    _currentProgress = progress;
    _progressStreamController.add(progress);
    _progressCallback?.call(progress);
  }
}

// =============================================================================
// Backward Compatibility Wrapper
// =============================================================================

Future<File> downloadUpdate(
  UpdateInfo info, {
  void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
}) async {
  final downloader = ResumableDownloader(info: info);
  return downloader.start(
    onProgress: (p) {
      onProgress?.call(p.progressFraction, p.receivedBytes, p.totalBytes);
    },
  );
}

// =============================================================================
// Linux Daemon & Tunnel Teardown Before Restart
// =============================================================================

Future<void> _teardownLinuxEngineBeforeRestart() async {
  final socketCandidates = [
    '/run/zohal/engine.sock',
    '${Directory.systemTemp.path}/zohal/engine.sock',
    if (Platform.environment['XDG_RUNTIME_DIR'] != null)
      '${Platform.environment['XDG_RUNTIME_DIR']}/zohal/user_engine.sock',
    if (Platform.environment['HOME'] != null)
      '${Platform.environment['HOME']}/.local/share/zohal/user_engine.sock',
    '${Directory.systemTemp.path}/zohal_user/user_engine.sock',
  ];

  for (final path in socketCandidates) {
    try {
      final file = File(path);
      if (await file.exists()) {
        final socket = await Socket.connect(
          InternetAddress(path, type: InternetAddressType.unix),
          0,
          timeout: const Duration(milliseconds: 250),
        );
        socket.writeln(
          jsonEncode({'t': 'set_desired', 'up': false, 'epoch': 999999}),
        );
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        socket.destroy();
      }
    } catch (_) {}
  }

  try {
    await Process.run('pkill', ['-f', 'zohald user']);
  } catch (_) {}
}

// =============================================================================
// Platform Installation
// =============================================================================

Future<void> installUpdate(File file) async {
  if (Platform.isLinux) {
    // 1. Ensure executable permission
    await Process.run('chmod', ['+x', file.path]);

    // 2. Perform pre-restart tunnel & engine teardown
    await _teardownLinuxEngineBeforeRestart();

    // 3. If running inside an existing AppImage, atomically replace it
    final currentAppImage = Platform.environment['APPIMAGE'];
    if (currentAppImage != null && currentAppImage.isNotEmpty) {
      try {
        final currentFile = File(currentAppImage);
        if (await currentFile.exists()) {
          final tempTarget = '$currentAppImage.new';
          await file.copy(tempTarget);
          await Process.run('chmod', ['+x', tempTarget]);
          final renameResult =
              await Process.run('mv', ['-f', tempTarget, currentAppImage]);
          if (renameResult.exitCode == 0) {
            SingleInstance.cleanup();
            try {
              await trayManager.destroy();
            } catch (_) {}
            await Process.start(
              currentAppImage,
              [],
              mode: ProcessStartMode.detached,
            );
            exit(0);
          }
        }
      } catch (e) {
        ZohalLogger().warn('Could not replace current AppImage: $e');
      }
    }

    // 4. Fallback: launch the newly downloaded AppImage directly
    SingleInstance.cleanup();
    try {
      await trayManager.destroy();
    } catch (_) {}
    await Process.start(file.path, [], mode: ProcessStartMode.detached);
    exit(0);
  } else if (Platform.isAndroid) {
    await VpnChannel().installApk(file.path);
  } else if (Platform.isWindows) {
    SingleInstance.cleanup();
    try {
      await trayManager.destroy();
    } catch (_) {}
    await Process.start(file.path, ['/SILENT'],
        mode: ProcessStartMode.detached);
    exit(0);
  }
}

// =============================================================================
// Version Comparison
// =============================================================================

bool isNewerVersion(String remote, String current) {
  try {
    final remoteClean = remote.split('+').first.split('-').first;
    final currentClean = current.split('+').first.split('-').first;

    final remoteParts = remoteClean.split('.').map(int.parse).toList();
    final currentParts = currentClean.split('.').map(int.parse).toList();

    final maxLen = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;

    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
  } catch (_) {
    return remote.compareTo(current) > 0;
  }
  return false;
}
