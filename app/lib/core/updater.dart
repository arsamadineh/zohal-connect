// core/updater.dart
// Automatic update checker for Zohal Connect desktop/AppImage distributions.
// Queries GitHub Releases API directly with zero telemetry and zero tracking pings (R11).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'logger.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
  });
}

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  // Only check updates on desktop platforms
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
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
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = json['tag_name'] as String? ?? '';
    final remoteVersion = tagName.replaceAll(RegExp(r'^[vV]'), '').trim();

    if (remoteVersion.isEmpty) return null;

    if (_isNewerVersion(remoteVersion, currentVersion)) {
      final assets = json['assets'] as List<dynamic>? ?? [];
      String downloadUrl = json['html_url'] as String? ??
          'https://github.com/arsamadineh/zohal-connect/releases';

      // Pick matching platform artifact if available
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final url = asset['browser_download_url'] as String?;
          if (url != null) {
            if (Platform.isLinux && name.endsWith('.appimage')) {
              downloadUrl = url;
              break;
            } else if (Platform.isWindows && name.endsWith('.exe')) {
              downloadUrl = url;
              break;
            }
          }
        }
      }

      final body = json['body'] as String?;
      return UpdateInfo(
        version: remoteVersion,
        downloadUrl: downloadUrl,
        releaseNotes: body,
      );
    }
  } catch (e) {
    ZohalLogger().debug('Update check failed (safe fallback): $e');
  } finally {
    client.close();
  }

  return null;
});

bool _isNewerVersion(String remote, String current) {
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
    // String comparison fallback if semantic parse fails
    return remote.compareTo(current) > 0;
  }
  return false;
}
