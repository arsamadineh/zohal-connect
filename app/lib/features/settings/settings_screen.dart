// features/settings/settings_screen.dart
// Settings screen for Zohal Connect according to ZOHAL_SPEC Section 13.4.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autostart.dart';
import '../../core/bridge.dart';
import '../../core/persian.dart';
import '../../core/settings.dart';
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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

  void _showIpVersionDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(zohalSettingsProvider);
    final notifier = ref.read(zohalSettingsProvider.notifier);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(StringsFa.settingsIpVersion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in [
              (IpVersion.auto, StringsFa.ipVersionAuto),
              (IpVersion.v4, StringsFa.ipVersionV4),
              (IpVersion.v6, StringsFa.ipVersionV6),
              (IpVersion.dual, StringsFa.ipVersionDual),
            ])
              InkWell(
                onTap: () {
                  notifier
                      .updateSettings(settings.copyWith(ipVersion: entry.$1));
                  Navigator.of(ctx).pop();
                  SharpToast.show(context, StringsFa.toastSaved);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.$2,
                          style: const TextStyle(
                            fontFamily: ZohalTokens.fontFamily,
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                      if (settings.ipVersion == entry.$1)
                        const Icon(
                          Icons.check_sharp,
                          size: 18.0,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _ipVersionLabel(IpVersion version) {
    switch (version) {
      case IpVersion.auto:
        return StringsFa.ipVersionAuto;
      case IpVersion.v4:
        return StringsFa.ipVersionV4;
      case IpVersion.v6:
        return StringsFa.ipVersionV6;
      case IpVersion.dual:
        return StringsFa.ipVersionDual;
    }
  }

  void _showDnsDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(zohalSettingsProvider);
    final notifier = ref.read(zohalSettingsProvider.notifier);

    showDialog<void>(
      context: context,
      builder: (ctx) => _DnsDialog(
        initialServers: settings.dnsServers,
        onSave: (newServers) {
          notifier.updateSettings(settings.copyWith(dnsServers: newServers));
          SharpToast.show(context, StringsFa.toastSaved);
        },
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
                    AutostartManager.sync(val);
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
              subtitle: settings.dnsServers
                  .take(2)
                  .map(Persian.ltrIsolate)
                  .join(', '),
              trailing: Icon(
                Icons.arrow_back_ios_new_sharp,
                size: 12.0,
                color: textSecondary,
              ),
              onTap: () => _showDnsDialog(context, ref),
            ),
            SharpRow(
              title: StringsFa.settingsIpVersion,
              subtitle: _ipVersionLabel(settings.ipVersion),
              trailing: Icon(
                Icons.arrow_back_ios_new_sharp,
                size: 12.0,
                color: textSecondary,
              ),
              onTap: () => _showIpVersionDialog(context, ref),
            ),
            SharpRow(
              title: StringsFa.routingSmartTitle,
              subtitle: StringsFa.routingSmartDesc,
              trailing: SharpSwitch(
                value: settings.smartDomesticDirect,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(smartDomesticDirect: val),
                  );
                },
              ),
            ),
            SharpRow(
              title: StringsFa.routingLanTitle,
              subtitle: StringsFa.routingLanDesc,
              trailing: SharpSwitch(
                value: settings.lanDirect,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(lanDirect: val),
                  );
                },
              ),
            ),

            // 4. Advanced Group
            buildSectionHeader(StringsFa.settingsGroupAdvanced),
            SharpRow(
              title: StringsFa.settingsFragment,
              trailing: SharpSwitch(
                value: settings.fragment,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(fragment: val),
                  );
                },
              ),
            ),
            SharpRow(
              title: StringsFa.settingsEch,
              trailing: SharpSwitch(
                value: settings.ech,
                onChanged: (val) {
                  notifier.updateSettings(
                    settings.copyWith(ech: val),
                  );
                },
              ),
            ),
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

class _DnsDialog extends StatefulWidget {
  final List<String> initialServers;
  final ValueChanged<List<String>> onSave;

  const _DnsDialog({
    required this.initialServers,
    required this.onSave,
  });

  @override
  State<_DnsDialog> createState() => _DnsDialogState();
}

class _DnsDialogState extends State<_DnsDialog> {
  late List<String> _servers;
  final TextEditingController _inputController = TextEditingController();
  String? _errorMessage;

  static const Map<String, List<String>> _presets = {
    StringsFa.dnsPresetCloudflare: ['1.1.1.1', '1.0.0.1'],
    StringsFa.dnsPresetGoogle: ['8.8.8.8', '8.8.4.4'],
    StringsFa.dnsPresetQuad9: ['9.9.9.9'],
    StringsFa.dnsPresetShecan: ['178.22.122.100', '185.51.200.2'],
    StringsFa.dnsPresetElectro: ['78.157.42.100', '78.157.42.101'],
    StringsFa.dnsPresetRadar: ['10.202.10.10', '10.202.10.11'],
  };

  @override
  void initState() {
    super.initState();
    _servers = List<String>.from(widget.initialServers);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _addServer() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final address = InternetAddress.tryParse(text);
    if (address == null) {
      setState(() => _errorMessage = StringsFa.dnsInvalidIp);
      return;
    }

    if (_servers.contains(text)) {
      setState(() => _errorMessage = StringsFa.dnsDuplicateIp);
      return;
    }

    setState(() {
      _servers.add(text);
      _inputController.clear();
      _errorMessage = null;
    });
  }

  void _removeServer(int index) {
    if (_servers.length <= 1) {
      setState(() => _errorMessage = StringsFa.dnsAtLeastOne);
      return;
    }
    setState(() {
      _servers.removeAt(index);
      _errorMessage = null;
    });
  }

  void _applyPreset(List<String> servers) {
    setState(() {
      _servers = List<String>.from(servers);
      _errorMessage = null;
    });
  }

  void _resetDefaults() {
    setState(() {
      _servers = const [
        '1.1.1.1',
        '1.0.0.1',
        '2606:4700:4700::1111',
        '2606:4700:4700::1001',
      ];
      _errorMessage = null;
    });
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

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: theme.scaffoldBackgroundColor,
      title: Text(
        StringsFa.dnsDialogTitle,
        style: TextStyle(
          fontFamily: ZohalTokens.fontFamily,
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      content: SizedBox(
        width: 440.0,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Presets Header
              Text(
                StringsFa.dnsPresets,
                style: TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: [
                  for (final entry in _presets.entries)
                    InkWell(
                      onTap: () => _applyPreset(entry.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: hairline),
                        ),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontFamily: ZohalTokens.fontFamily,
                            fontSize: 12.0,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Active DNS servers list
              Text(
                StringsFa.settingsDnsServers,
                style: TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8.0),
              Container(
                constraints: const BoxConstraints(maxHeight: 180.0),
                decoration: BoxDecoration(
                  border: Border.all(color: hairline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _servers.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1.0, color: hairline),
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Persian.ltrIsolate(server),
                              style: TextStyle(
                                fontFamily: ZohalTokens.fontFamily,
                                fontSize: 13.0,
                                color: textPrimary,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_sharp, size: 16.0),
                            color: textSecondary,
                            tooltip: StringsFa.dialogResetIdentityCancel,
                            onPressed: _servers.length > 1
                                ? () => _removeServer(index)
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16.0),

              // Custom Input
              Text(
                StringsFa.dnsCustomInput,
                style: TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: StringsFa.dnsInputHint,
                        hintTextDirection: TextDirection.rtl,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 10.0,
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: hairline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _addServer(),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  SharpButton(
                    label: StringsFa.dnsAdd,
                    onPressed: _addServer,
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8.0),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 12.0,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SharpButton(
          label: StringsFa.dnsResetDefaults,
          isOutlined: true,
          onPressed: _resetDefaults,
        ),
        const SizedBox(width: 8.0),
        SharpButton(
          label: StringsFa.dialogCancelConnectCancel,
          isOutlined: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8.0),
        SharpButton(
          label: StringsFa.toastSaved,
          onPressed: () {
            if (_servers.isEmpty) {
              setState(() => _errorMessage = StringsFa.dnsAtLeastOne);
              return;
            }
            widget.onSave(_servers);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
