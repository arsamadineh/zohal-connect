// core/tray_service.dart
// Desktop system tray and window manager integration for Zohal Connect.
// Manages AppImage / Linux / Windows system tray icon, menu actions, and minimize-to-tray.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app.dart';
import '../design/motion.dart';
import '../features/about/update_dialog.dart';
import '../features/logs/logs_screen.dart';
import '../features/settings/settings_screen.dart';
import 'bridge.dart';
import 'engine_state.dart';
import 'logger.dart';
import 'settings.dart';
import 'single_instance.dart';
import 'updater.dart';

final trayServiceProvider = Provider<DesktopTrayService>((ref) {
  final service = DesktopTrayService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class DesktopTrayService with TrayListener, WindowListener {
  final Ref _ref;
  bool _initialized = false;
  ProviderSubscription<EngineState>? _stateSub;
  ProviderSubscription<ZohalSettings>? _settingsSub;

  DesktopTrayService(this._ref);

  Future<void> init() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return;
    }
    if (_initialized) return;
    _initialized = true;

    try {
      // Ensure previous tray icon is destroyed first to prevent duplicate icons
      try {
        await trayManager.destroy();
      } catch (_) {}

      trayManager.addListener(this);
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);

      String iconPath = 'assets/images/tray_icon.png';
      if (Platform.isLinux) {
        try {
          ByteData byteData;
          try {
            byteData = await rootBundle.load('assets/images/tray_icon.png');
          } catch (_) {
            byteData = await rootBundle.load('assets/images/logo.png');
          }
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

      _settingsSub = _ref.listen<ZohalSettings>(
        zohalSettingsProvider,
        (previous, next) {
          if (previous != next) {
            _updateContextMenu(_ref.read(engineStateProvider));
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
          engineState.phase == ConnectionPhase.preparing ||
          engineState.phase == ConnectionPhase.reconnecting;

      final statusLabel = isConnected
          ? 'وضعیت: متصل'
          : (isConnecting ? 'وضعیت: در حال اتصال...' : 'وضعیت: قطع');

      final toggleLabel = isConnected
          ? 'قطع اتصال'
          : (isConnecting ? 'لغو اتصال' : 'اتصال سریع');

      final settings = _ref.read(zohalSettingsProvider);
      final currentMode = settings.connectionMode;

      final menu = Menu(
        items: [
          MenuItem(
            key: 'status_label',
            label: statusLabel,
            disabled: true,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'toggle_connect',
            label: toggleLabel,
            disabled: false,
          ),
          MenuItem(
            key: 'show_window',
            label: 'نمایش پنجره اصلی',
          ),
          MenuItem(
            key: 'hide_window',
            label: 'مخفی کردن پنجره',
          ),
          MenuItem.separator(),
          MenuItem.submenu(
            key: 'mode_submenu',
            label: 'حالت اتصال',
            submenu: Menu(
              items: [
                MenuItem.checkbox(
                  key: 'mode_auto',
                  label: 'خودکار (هوشمند)',
                  checked: currentMode == ConnectionMode.auto,
                ),
                MenuItem.checkbox(
                  key: 'mode_masque3',
                  label: 'مسک ۳ (MASQUE HTTP/3)',
                  checked: currentMode == ConnectionMode.masque3,
                ),
                MenuItem.checkbox(
                  key: 'mode_masque2',
                  label: 'مسک ۲ (MASQUE HTTP/2)',
                  checked: currentMode == ConnectionMode.masque2,
                ),
                MenuItem.checkbox(
                  key: 'mode_wireguard',
                  label: 'وایرگارد (WireGuard)',
                  checked: currentMode == ConnectionMode.wireguard,
                ),
                MenuItem.checkbox(
                  key: 'mode_gool',
                  label: 'گول (Gool)',
                  checked: currentMode == ConnectionMode.gool,
                ),
              ],
            ),
          ),
          MenuItem.submenu(
            key: 'options_submenu',
            label: 'گزینه‌های سریع',
            submenu: Menu(
              items: [
                MenuItem.checkbox(
                  key: 'toggle_kill_switch',
                  label: 'سوئیچ قطع اضطراری',
                  checked: settings.killSwitch,
                ),
                MenuItem.checkbox(
                  key: 'toggle_smart_domestic',
                  label: 'هدایت ترافیک داخلی',
                  checked: settings.smartDomesticDirect,
                ),
                MenuItem.checkbox(
                  key: 'toggle_lan_direct',
                  label: 'هدایت شبکه محلی',
                  checked: settings.lanDirect,
                ),
                MenuItem.checkbox(
                  key: 'toggle_fragment',
                  label: 'تکه‌تکه‌سازی پکت‌ها',
                  checked: settings.fragment,
                ),
              ],
            ),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'open_settings',
            label: 'تنظیمات',
          ),
          MenuItem(
            key: 'open_logs',
            label: 'گزارش‌ها',
          ),
          MenuItem(
            key: 'check_update',
            label: 'بررسی به‌روزرسانی',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'خروج کامل',
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
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await _bringToFront();
        break;
      case 'hide_window':
        try {
          await windowManager.hide();
        } catch (_) {}
        break;
      case 'toggle_connect':
        final state = _ref.read(engineStateProvider);
        final settings = _ref.read(zohalSettingsProvider);
        final isConnected = state.phase == ConnectionPhase.connected;
        _ref
            .read(engineStateProvider.notifier)
            .setDesired(!isConnected, settings: settings);
        break;
      case 'mode_auto':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(connectionMode: ConnectionMode.auto),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'mode_masque3':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(connectionMode: ConnectionMode.masque3),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'mode_masque2':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(connectionMode: ConnectionMode.masque2),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'mode_wireguard':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(connectionMode: ConnectionMode.wireguard),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'mode_gool':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(connectionMode: ConnectionMode.gool),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'toggle_kill_switch':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(killSwitch: !settings.killSwitch),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'toggle_smart_domestic':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(
                  smartDomesticDirect: !settings.smartDomesticDirect),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'toggle_lan_direct':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(lanDirect: !settings.lanDirect),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'toggle_fragment':
        final settings = _ref.read(zohalSettingsProvider);
        await _ref.read(zohalSettingsProvider.notifier).updateSettings(
              settings.copyWith(fragment: !settings.fragment),
            );
        await _updateContextMenu(_ref.read(engineStateProvider));
        break;
      case 'open_settings':
        await _bringToFront();
        rootNavigatorKey.currentState?.push(
          ZohalMotion.createPageRoute<void>(const SettingsScreen()),
        );
        break;
      case 'open_logs':
        await _bringToFront();
        rootNavigatorKey.currentState?.push(
          ZohalMotion.createPageRoute<void>(const LogsScreen()),
        );
        break;
      case 'check_update':
        await _bringToFront();
        try {
          final update = await fetchLatestUpdate(force: true);
          if (update != null && rootNavigatorKey.currentContext != null) {
            await UpdateDialog.show(rootNavigatorKey.currentContext!, update);
          }
        } catch (_) {}
        break;
      case 'exit_app':
        await _exitApplication();
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
        await _exitApplication();
      }
    } catch (_) {
      await _exitApplication();
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

  Future<void> _exitApplication() async {
    try {
      _ref.read(engineStateProvider.notifier).setDesired(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } catch (_) {}
    try {
      await trayManager.destroy();
    } catch (_) {}
    try {
      await windowManager.destroy();
    } catch (_) {}
    SingleInstance.cleanup();
    exit(0);
  }

  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _stateSub?.close();
    _settingsSub?.close();
  }
}
