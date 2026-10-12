// core/tray_service.dart
// Desktop system tray and window manager integration for Zohal Connect.
// Manages AppImage / Linux / Windows system tray icon, menu actions, and minimize-to-tray.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'bridge.dart';
import 'engine_state.dart';
import 'logger.dart';

final trayServiceProvider = Provider<DesktopTrayService>((ref) {
  final service = DesktopTrayService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class DesktopTrayService with TrayListener, WindowListener {
  final Ref _ref;
  bool _initialized = false;
  ProviderSubscription<EngineState>? _stateSub;

  DesktopTrayService(this._ref);

  Future<void> init() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return;
    }
    if (_initialized) return;
    _initialized = true;

    try {
      trayManager.addListener(this);
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);

      String iconPath = 'assets/images/logo.png';
      if (Platform.isLinux) {
        try {
          final byteData = await rootBundle.load('assets/images/logo.png');
          final iconFile =
              File('${Directory.systemTemp.path}/zohal_tray_icon.png');
          await iconFile.writeAsBytes(
            byteData.buffer.asUint8List(),
            flush: true,
          );
          iconPath = iconFile.path;
        } catch (e) {
          ZohalLogger().debug('Tray icon extraction fallback: $e');
        }
      }

      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('زحل');

      await _updateContextMenu(_ref.read(engineStateProvider));

      _stateSub = _ref.listen<EngineState>(
        engineStateProvider,
        (previous, next) {
          if (previous?.phase != next.phase) {
            _updateContextMenu(next);
          }
        },
      );
    } catch (e) {
      ZohalLogger().warn('Desktop tray initialization failed: $e');
    }
  }

  Future<void> _updateContextMenu(EngineState engineState) async {
    try {
      final isConnected = engineState.phase == ConnectionPhase.connected;
      final isConnecting = engineState.phase == ConnectionPhase.connecting ||
          engineState.phase == ConnectionPhase.preparing;

      final toggleLabel = isConnected
          ? 'قطع اتصال'
          : (isConnecting ? 'در حال اتصال...' : 'اتصال');

      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'نمایش زحل',
          ),
          MenuItem(
            key: 'toggle_connect',
            label: toggleLabel,
            disabled: isConnecting,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'خروج',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      ZohalLogger().debug('Tray menu update failed: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    _bringToFront();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        _bringToFront();
        break;
      case 'toggle_connect':
        final state = _ref.read(engineStateProvider);
        final settings = _ref.read(zohalSettingsProvider);
        final isConnected = state.phase == ConnectionPhase.connected;
        _ref
            .read(engineStateProvider.notifier)
            .setDesired(!isConnected, settings: settings);
        break;
      case 'exit_app':
        _exitApplication();
        break;
    }
  }

  @override
  void onWindowClose() async {
    try {
      final settings = _ref.read(zohalSettingsProvider);
      if (settings.minimizeToTray) {
        await windowManager.hide();
      } else {
        _exitApplication();
      }
    } catch (_) {
      _exitApplication();
    }
  }

  Future<void> _bringToFront() async {
    try {
      final isVisible = await windowManager.isVisible();
      if (!isVisible) {
        await windowManager.show();
      }
      await windowManager.focus();
    } catch (e) {
      ZohalLogger().debug('Failed to bring window to front: $e');
    }
  }

  void _exitApplication() async {
    try {
      await trayManager.destroy();
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _stateSub?.close();
  }
}
