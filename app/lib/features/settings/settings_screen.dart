// features/settings/settings_screen.dart
// Settings screen for Zohal Connect according to ZOHAL_SPEC Section 13.4.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge.dart';
import '../../design/components/sharp_button.dart';
import '../../design/components/sharp_row.dart';
import '../../design/components/sharp_switch.dart';
import '../../design/components/sharp_toast.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';
import '../about/about_screen.dart';
import '../logs/logs_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showResetIdentityDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(StringsFa.dialogResetIdentityTitle),
        content: const Text(StringsFa.dialogResetIdentityBody),
        actions: [
          SharpButton(
            label: StringsFa.dialogResetIdentityCancel,
            isOutlined: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8.0),
          SharpButton(
            label: StringsFa.dialogResetIdentityConfirm,
            isDestructive: true,
            onPressed: () {
              ref.read(bridgeClientProvider).resetIdentity();
              Navigator.of(ctx).pop();
              SharpToast.show(context, StringsFa.toastSaved);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? ZohalTokens.darkHairline : ZohalTokens.lightHairline;
    final textPrimary =
        isDark ? ZohalTokens.darkTextPrimary : ZohalTokens.lightTextPrimary;
    final textSecondary =
        isDark ? ZohalTokens.darkTextSecondary : ZohalTokens.lightTextSecondary;

    final settings = ref.watch(zohalSettingsProvider);
    final notifier = ref.read(zohalSettingsProvider.notifier);

    Widget buildSectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 20.0,
          bottom: 8.0,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: ZohalTokens.fontFamily,
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          StringsFa.settings,
          style: TextStyle(
            fontFamily: ZohalTokens.fontFamily,
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: hairline, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            // 1. Connection Group
            buildSectionHeader(StringsFa.settingsGroupConnection),
            SharpRow(
              title: StringsFa.settingsAutoLaunch,
              trailing: SharpSwitch(
                value: settings.autoConnectOnLaunch,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(autoConnectOnLaunch: val),
                  );
                },
              ),
            ),
            SharpRow(
              title: StringsFa.settingsRestoreState,
              trailing: SharpSwitch(
                value: settings.restoreLastState,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(restoreLastState: val),
                  );
                },
              ),
            ),
            SharpRow(
              title: StringsFa.settingsAutoBoot,
              trailing: SharpSwitch(
                value: settings.autoConnectOnBoot,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(autoConnectOnBoot: val),
                  );
                },
              ),
            ),
            SharpRow(
              title: StringsFa.killSwitch,
              subtitle: StringsFa.settingsKillSwitchDesc,
              trailing: SharpSwitch(
                value: settings.killSwitch,
                onChanged: (val) {
                  notifier.updateSettings(settings.copyWith(killSwitch: val));
                },
              ),
            ),

            // 2. System Group
            buildSectionHeader(StringsFa.settingsGroupSystem),
            if (!Platform.isAndroid && !Platform.isIOS) ...[
              SharpRow(
                title: StringsFa.settingsStartWithSystem,
                trailing: SharpSwitch(
                  value: settings.startWithSystem,
                  onChanged: (val) {
                    notifier.updateSettings(
                      settings.copyWith(startWithSystem: val),
                    );
                  },
                ),
              ),
              SharpRow(
                title: StringsFa.settingsMinimizeToTray,
                trailing: SharpSwitch(
                  value: settings.minimizeToTray,
                  onChanged: (val) {
                    notifier.updateSettings(
                      settings.copyWith(minimizeToTray: val),
                    );
                  },
                ),
              ),
            ],

            // 3. Network Group
            buildSectionHeader(StringsFa.settingsGroupNetwork),
            SharpRow(
              title: StringsFa.settingsDnsServers,
              subtitle: settings.dnsServers.take(2).join(', '),
              trailing: Icon(
                Icons.arrow_back_ios_new_sharp,
                size: 12.0,
                color: textSecondary,
              ),
              onTap: () {
                // Show info
              },
            ),

            // 4. Advanced Group
            buildSectionHeader(StringsFa.settingsGroupAdvanced),
            SharpRow(
              title: StringsFa.settingsDiagnosticLog,
              trailing: SharpSwitch(
                value: settings.diagnosticLog,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(diagnosticLog: val),
                  );
                },
              ),
            ),
            SharpRow(
              title: StringsFa.logs,
              trailing: Icon(
                Icons.arrow_back_ios_new_sharp,
                size: 12.0,
                color: textSecondary,
              ),
              onTap: () {
                Navigator.of(context).push(
                    ZohalMotion.createPageRoute<void>(const LogsScreen()));
              },
            ),
            SharpRow(
              title: StringsFa.settingsResetIdentity,
              trailing: Icon(
                Icons.warning_amber_sharp,
                size: 18.0,
                color: textSecondary,
              ),
              onTap: () => _showResetIdentityDialog(context, ref),
            ),

            // 5. About
            buildSectionHeader(StringsFa.about),
            SharpRow(
              title: StringsFa.about,
              trailing: Icon(
                Icons.arrow_back_ios_new_sharp,
                size: 12.0,
                color: textSecondary,
              ),
              onTap: () {
                Navigator.of(context).push(
                    ZohalMotion.createPageRoute<void>(const AboutScreen()));
              },
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}
