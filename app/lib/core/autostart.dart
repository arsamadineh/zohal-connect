// core/autostart.dart
// Manages desktop system autostart configuration for Zohal Connect.
// On Linux, writes or removes ~/.config/autostart/zohal.desktop.
// On other platforms, handles platform-specific autostart or gracefully no-ops.

import 'dart:io';

import 'logger.dart';

class AutostartManager {
  static Future<void> sync(bool enabled) async {
    if (Platform.isLinux) {
      await _syncLinux(enabled);
    }
  }

  static Future<void> _syncLinux(bool enabled) async {
    try {
      final home = Platform.environment['HOME'];
      final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
      final configDirPath = (xdgConfig != null && xdgConfig.isNotEmpty)
          ? xdgConfig
          : (home != null && home.isNotEmpty ? '$home/.config' : null);

      if (configDirPath == null) {
        ZohalLogger().debug('Cannot determine user config dir for autostart');
        return;
      }

      final autostartDir = Directory('$configDirPath/autostart');
      final desktopFile = File('${autostartDir.path}/zohal.desktop');

      if (enabled) {
        if (!await autostartDir.exists()) {
          await autostartDir.create(recursive: true);
        }
        final execPath =
            Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;
        final content = '''[Desktop Entry]
Type=Application
Name=Zohal Connect
Exec="$execPath"
Icon=zohal
Terminal=false
Categories=Network;Utility;
''';
        await desktopFile.writeAsString(content);
        ZohalLogger()
            .info('Autostart desktop file written: ${desktopFile.path}');
      } else {
        if (await desktopFile.exists()) {
          await desktopFile.delete();
          ZohalLogger()
              .info('Autostart desktop file removed: ${desktopFile.path}');
        }
      }
    } catch (e) {
      ZohalLogger().warn('Failed to sync Linux autostart: $e');
    }
  }

  static Future<bool> isLinuxAutostartEnabled() async {
    if (!Platform.isLinux) return false;
    try {
      final home = Platform.environment['HOME'];
      final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
      final configDirPath = (xdgConfig != null && xdgConfig.isNotEmpty)
          ? xdgConfig
          : (home != null && home.isNotEmpty ? '$home/.config' : null);
      if (configDirPath == null) return false;
      final desktopFile = File('$configDirPath/autostart/zohal.desktop');
      return await desktopFile.exists();
    } catch (_) {
      return false;
    }
  }
}
