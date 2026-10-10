// features/routing/routing_screen.dart
// Smart and custom routing configuration screen for Zohal Connect per ZOHAL_SPEC Section 13.3.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge.dart';
import '../../core/persian.dart';
import '../../core/settings.dart';
import '../../design/components/sharp_button.dart';
import '../../design/components/sharp_row.dart';
import '../../design/components/sharp_sheet.dart';
import '../../design/components/sharp_switch.dart';
import '../../design/components/sharp_toast.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';

class RoutingScreen extends ConsumerStatefulWidget {
  const RoutingScreen({super.key});

  @override
  ConsumerState<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends ConsumerState<RoutingScreen> {
  void _toggleSmartDomestic(bool value) {
    final settings = ref.read(zohalSettingsProvider);
    ref
        .read(zohalSettingsProvider.notifier)
        .updateSettings(settings.copyWith(smartDomesticDirect: value));
  }

  void _toggleLanDirect(bool value) {
    final settings = ref.read(zohalSettingsProvider);
    ref
        .read(zohalSettingsProvider.notifier)
        .updateSettings(settings.copyWith(lanDirect: value));
  }

  void _removeRule(bool isDirect, int index) {
    final settings = ref.read(zohalSettingsProvider);
    if (isDirect) {
      final list = List<RoutingRule>.from(settings.directRules);
      list.removeAt(index);
      ref
          .read(zohalSettingsProvider.notifier)
          .updateSettings(settings.copyWith(directRules: list));
    } else {
      final list = List<RoutingRule>.from(settings.blockRules);
      list.removeAt(index);
      ref
          .read(zohalSettingsProvider.notifier)
          .updateSettings(settings.copyWith(blockRules: list));
    }
  }

  void _showAddRuleDialog(bool isDirect) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark
        ? ZohalTokens.darkTextPrimary
        : ZohalTokens.lightTextPrimary;

    RuleKind selectedKind = RuleKind.domain;
    final textController = TextEditingController();
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                '${StringsFa.routingAddRule} (${isDirect ? StringsFa.routingDirectSection : StringsFa.routingBlockSection})',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    StringsFa.routingRuleType,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  DropdownButtonFormField<RuleKind>(
                    value: selectedKind,
                    items: [
                      DropdownMenuItem(
                        value: RuleKind.domain,
                        child: Text(StringsFa.ruleTypeDomain),
                      ),
                      DropdownMenuItem(
                        value: RuleKind.domainExact,
                        child: Text(StringsFa.ruleTypeDomainExact),
                      ),
                      DropdownMenuItem(
                        value: RuleKind.keyword,
                        child: Text(StringsFa.ruleTypeKeyword),
                      ),
                      DropdownMenuItem(
                        value: RuleKind.ipCidr,
                        child: Text(StringsFa.ruleTypeIpCidr),
                      ),
                      DropdownMenuItem(
                        value: RuleKind.port,
                        child: Text(StringsFa.ruleTypePort),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedKind = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    StringsFa.routingRuleValue,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      errorText: errorText,
                      hintText: selectedKind == RuleKind.ipCidr
                          ? '10.0.0.0/8'
                          : selectedKind == RuleKind.port
                          ? '8080'
                          : 'example.com',
                    ),
                  ),
                ],
              ),
              actions: [
                SharpButton(
                  label: StringsFa.cancel,
                  isOutlined: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                const SizedBox(width: 8.0),
                SharpButton(
                  label: StringsFa.add,
                  onPressed: () {
                    final val = textController.text.trim();
                    if (val.isEmpty) {
                      setDialogState(
                        () => errorText = 'مقدار نمیتواند خالی باشد',
                      );
                      return;
                    }
                    if (val.length > 255) {
                      setDialogState(
                        () => errorText = 'طول قانون بیش از ۲۵۵ نویسه است',
                      );
                      return;
                    }

                    final newRule = RoutingRule(kind: selectedKind, value: val);
                    final settings = ref.read(zohalSettingsProvider);
                    if (isDirect) {
                      final list = List<RoutingRule>.from(settings.directRules)
                        ..add(newRule);
                      ref
                          .read(zohalSettingsProvider.notifier)
                          .updateSettings(settings.copyWith(directRules: list));
                    } else {
                      final list = List<RoutingRule>.from(settings.blockRules)
                        ..add(newRule);
                      ref
                          .read(zohalSettingsProvider.notifier)
                          .updateSettings(settings.copyWith(blockRules: list));
                    }
                    Navigator.of(ctx).pop();
                    SharpToast.show(context, StringsFa.toastSaved);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getRuleKindLabel(RuleKind kind) {
    switch (kind) {
      case RuleKind.domain:
        return StringsFa.ruleTypeDomain;
      case RuleKind.domainExact:
        return StringsFa.ruleTypeDomainExact;
      case RuleKind.keyword:
        return StringsFa.ruleTypeKeyword;
      case RuleKind.regex:
        return StringsFa.ruleTypeRegex;
      case RuleKind.ipCidr:
        return StringsFa.ruleTypeIpCidr;
      case RuleKind.port:
        return StringsFa.ruleTypePort;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark
        ? ZohalTokens.darkHairline
        : ZohalTokens.lightHairline;
    final textPrimary = isDark
        ? ZohalTokens.darkTextPrimary
        : ZohalTokens.lightTextPrimary;
    final textSecondary = isDark
        ? ZohalTokens.darkTextSecondary
        : ZohalTokens.lightTextSecondary;

    final settings = ref.watch(zohalSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          StringsFa.routing,
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
            // Smart Domestic Direct Toggle
            SharpRow(
              title: StringsFa.routingSmartTitle,
              subtitle: StringsFa.routingSmartDesc,
              trailing: SharpSwitch(
                value: settings.smartDomesticDirect,
                onChanged: _toggleSmartDomestic,
              ),
            ),

            // LAN Direct Toggle
            SharpRow(
              title: StringsFa.routingLanTitle,
              subtitle: StringsFa.routingLanDesc,
              trailing: SharpSwitch(
                value: settings.lanDirect,
                onChanged: _toggleLanDirect,
              ),
            ),

            const SizedBox(height: 16.0),

            // Direct Rules Section Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Text(
                    StringsFa.routingDirectSection,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const Spacer(),
                  SharpButton(
                    label: StringsFa.routingAddRule,
                    isOutlined: true,
                    height: 36.0,
                    onPressed: () => _showAddRuleDialog(true),
                  ),
                ],
              ),
            ),
            Container(height: 1.0, color: hairline),

            // Direct Rules List
            if (settings.directRules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Text(
                  'هیچ قانون مستقیمی تعریف نشده است.',
                  style: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 13.0,
                    color: textSecondary,
                  ),
                ),
              )
            else
              ...List.generate(settings.directRules.length, (index) {
                final rule = settings.directRules[index];
                return SharpRow(
                  title: Persian.ltrIsolate(rule.value),
                  subtitle: _getRuleKindLabel(rule.kind),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_sharp, size: 20.0),
                    tooltip: StringsFa.remove,
                    onPressed: () => _removeRule(true, index),
                  ),
                );
              }),

            const SizedBox(height: 24.0),

            // Block Rules Section Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Text(
                    StringsFa.routingBlockSection,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const Spacer(),
                  SharpButton(
                    label: StringsFa.routingAddRule,
                    isOutlined: true,
                    height: 36.0,
                    onPressed: () => _showAddRuleDialog(false),
                  ),
                ],
              ),
            ),
            Container(height: 1.0, color: hairline),

            // Block Rules List
            if (settings.blockRules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Text(
                  'هیچ قانون مسدودی تعریف نشده است.',
                  style: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 13.0,
                    color: textSecondary,
                  ),
                ),
              )
            else
              ...List.generate(settings.blockRules.length, (index) {
                final rule = settings.blockRules[index];
                return SharpRow(
                  title: Persian.ltrIsolate(rule.value),
                  subtitle: _getRuleKindLabel(rule.kind),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_sharp, size: 20.0),
                    tooltip: StringsFa.remove,
                    onPressed: () => _removeRule(false, index),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
