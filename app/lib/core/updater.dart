// core/updater.dart
// Automatic and manual update checker and installer for Zohal Connect distributions.
// Queries GitHub Releases API directly with zero telemetry and zero tracking pings (R11).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tray_manager/tray_manager.dart';

import 'logger.dart';
import 'single_instance.dart';
import 'vpn_channel.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String filename;
  final int? sizeBytes;
  final String? releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.filename,
    this.sizeBytes,
    this.releaseNotes,
  });
}

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  return fetchLatestUpdate();
});

Future<UpdateInfo?> fetchLatestUpdate({bool force = false}) async {
  if (!Platform.isLinux &&
      !Platform.isWindows &&
      !Platform.isMacOS &&
      !Platform.isAndroid) {
    return null;
  }

  final client = http.Client();
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
            } else if (Platform.isAndroid && name.endsWith('.apk')) {
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

      final body = json['body'] as String?;
      return UpdateInfo(
        version: remoteVersion,
        downloadUrl: downloadUrl,
        filename: filename,
        sizeBytes: sizeBytes,
        releaseNotes: body,
      );
    }
  } catch (e) {
    ZohalLogger().debug('Update check failed (safe fallback): $e');
  } finally {
    client.close();
  }

  return null;
}

Future<File> downloadUpdate(
  UpdateInfo info, {
  void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
}) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(info.downloadUrl));
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('HTTP error ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? info.sizeBytes ?? 0;
    final tempDir = Directory('${Directory.systemTemp.path}/zohal_update');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    final targetFile = File('${tempDir.path}/${info.filename}');
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final sink = targetFile.openWrite();
    int receivedBytes = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (onProgress != null && totalBytes > 0) {
        onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
      }
    }

    await sink.flush();
    await sink.close();
    return targetFile;
  } finally {
    client.close();
  }
}

Future<void> installUpdate(File file) async {
  if (Platform.isLinux) {
    // 1. Ensure executable permission
    await Process.run('chmod', ['+x', file.path]);

    // 2. If running inside an existing AppImage, atomically replace it
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

    // 3. Fallback: launch the newly downloaded AppImage directly
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
