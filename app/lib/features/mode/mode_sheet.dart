// features/mode/mode_sheet.dart
// Connection mode sheet for Zohal Connect according to ZOHAL_SPEC Section 13.2.
// Five options with square radio markers and expandable advanced options.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge.dart';
import '../../core/engine_state.dart';
import '../../core/settings.dart';
import '../../design/components/sharp_switch.dart';
import '../../design/components/sharp_toast.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';

class ModeSheet extends ConsumerStatefulWidget {
  const ModeSheet({super.key});

  @override
  ConsumerState<ModeSheet> createState() => _ModeSheetState();
}

class _ModeSheetState extends ConsumerState<ModeSheet> {
  bool _showAdvanced = false;

  void _selectMode(ConnectionMode mode) {
    final settings = ref.read(zohalSettingsProvider);
    final engineState = ref.read(engineStateProvider);

    if (settings.connectionMode == mode) return;

    ref
        .read(zohalSettingsProvider.notifier)
        .updateSettings(settings.copyWith(connectionMode: mode));

    Navigator.of(context).pop();

    if (engineState.phase == ConnectionPhase.connected) {
      SharpToast.show(context, StringsFa.toastModeChanged);
      ref.read(engineStateProvider.notifier).setDesired(false);
      Future.delayed(const Duration(milliseconds: 350), () {
        ref.read(engineStateProvider.notifier).setDesired(true);
      });
    }
  }

  Widget _buildRadioRow({
    required String title,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accent,
    required Color hairline,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square Radio Marker (16x16 dp)
            Container(
              width: 16.0,
              height: 16.0,
              margin: const EdgeInsets.only(top: 4.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? accent : hairline,
                  width: 1.5,
                ),
                color: isSelected ? accent : Colors.transparent,
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    desc,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final accent = theme.colorScheme.primary;

    final settings = ref.watch(zohalSettingsProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRadioRow(
            title: StringsFa.modeAutoTitle,
            desc: StringsFa.modeAutoDesc,
            isSelected: settings.connectionMode == ConnectionMode.auto,
            onTap: () => _selectMode(ConnectionMode.auto),
            accent: accent,
            hairline: hairline,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Container(height: 1.0, color: hairline),
          _buildRadioRow(
            title: StringsFa.modeMasque3Title,
            desc: StringsFa.modeMasque3Desc,
            isSelected: settings.connectionMode == ConnectionMode.masque3,
            onTap: () => _selectMode(ConnectionMode.masque3),
            accent: accent,
            hairline: hairline,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Container(height: 1.0, color: hairline),
          _buildRadioRow(
            title: StringsFa.modeMasque2Title,
            desc: StringsFa.modeMasque2Desc,
            isSelected: settings.connectionMode == ConnectionMode.masque2,
            onTap: () => _selectMode(ConnectionMode.masque2),
            accent: accent,
            hairline: hairline,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Container(height: 1.0, color: hairline),
          _buildRadioRow(
            title: StringsFa.modeWireguardTitle,
            desc: StringsFa.modeWireguardDesc,
            isSelected: settings.connectionMode == ConnectionMode.wireguard,
            onTap: () => _selectMode(ConnectionMode.wireguard),
            accent: accent,
            hairline: hairline,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Container(height: 1.0, color: hairline),
          _buildRadioRow(
            title: StringsFa.modeGoolTitle,
            desc: StringsFa.modeGoolDesc,
            isSelected: settings.connectionMode == ConnectionMode.gool,
            onTap: () => _selectMode(ConnectionMode.gool),
            accent: accent,
            hairline: hairline,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Container(height: 1.0, color: hairline),

          // Advanced Options Toggle
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 14.0,
              ),
              child: Row(
                children: [
                  Text(
                    StringsFa.settingsAdvancedSection,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up_sharp
                        : Icons.keyboard_arrow_down_sharp,
                    size: 20.0,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_showAdvanced) ...[
            Container(height: 1.0, color: hairline),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Text(
                    StringsFa.settingsFragment,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 14.0,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  SharpSwitch(
                    value: settings.fragment,
                    onChanged: (val) {
                      ref
                          .read(zohalSettingsProvider.notifier)
                          .updateSettings(settings.copyWith(fragment: val));
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Text(
                    StringsFa.settingsEch,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 14.0,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  SharpSwitch(
                    value: settings.ech,
                    onChanged: (val) {
                      ref
                          .read(zohalSettingsProvider.notifier)
                          .updateSettings(settings.copyWith(ech: val));
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }
}
