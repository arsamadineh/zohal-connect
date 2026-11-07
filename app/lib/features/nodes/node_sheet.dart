// features/nodes/node_sheet.dart
// Node selection and live ping latency testing sheet for Zohal Connect.
// Strict sharp design language, country flags, real TCP ping test, zero emojis.

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge.dart';
import '../../core/engine_state.dart';
import '../../core/persian.dart';
import '../../core/proxy_models.dart';
import '../../core/proxy_runner.dart';
import '../../core/proxy_service.dart';
import '../../design/components/sharp_button.dart';
import '../../design/components/sharp_sheet.dart';
import '../../design/components/sharp_toast.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';
import 'add_config_dialog.dart';

class NodeSheet extends ConsumerWidget {
  const NodeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return SharpSheet.show<void>(
      context: context,
      title: StringsFa.configsTitle,
      child: const NodeSheet(),
    );
  }

  Color _getLatencyColor(int? latencyMs, Color textSecondary) {
    if (latencyMs == null) return textSecondary;
    if (latencyMs < 0) return const Color(0xFFE53935); // Red
    if (latencyMs < 150) return const Color(0xFF43A047); // Green
    if (latencyMs < 300) return const Color(0xFFFB8C00); // Orange
    return const Color(0xFFE53935);
  }

  String _formatLatency(int? latencyMs) {
    if (latencyMs == null) return StringsFa.untested;
    if (latencyMs < 0) return 'قطع';
    return '${Persian.formatNumber(latencyMs)} ${StringsFa.ms}';
  }

  void _handleNodeSelect(
    BuildContext context,
    WidgetRef ref,
    ProxyNode node,
  ) {
    ref.read(selectedNodeProvider.notifier).selectNode(node);
    Navigator.of(context).pop();

    final engineState = ref.read(engineStateProvider);
    if (engineState.phase == ConnectionPhase.connected ||
        engineState.phase == ConnectionPhase.connecting) {
      SharpToast.show(context, 'سرور فعال تغییر کرد؛ در حال اتصال...');
      final runner = ref.read(customProxyRunnerProvider);
      if (node.isCustom) {
        runner.connect(node);
      } else {
        final bridge = ref.read(bridgeClientProvider);
        bridge.setDesired(true, mode: {'Auto': null});
      }
    } else {
      SharpToast.show(context, StringsFa.toastSaved);
    }
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
    final accent = theme.colorScheme.primary;

    final nodes = ref.watch(proxyNodesProvider);
    final selectedNode = ref.watch(selectedNodeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar: Ping All & Add Config
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(proxyNodesProvider.notifier).pingAllNodes();
                },
                icon: const Icon(Icons.speed_sharp, size: 16.0),
                label: const Text(
                  StringsFa.pingAll,
                  style: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 12.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  side: BorderSide(color: hairline),
                ),
              ),
              const Spacer(),
              SharpButton(
                label: StringsFa.addConfig,
                height: 36.0,
                onPressed: () {
                  AddConfigDialog.show(context);
                },
              ),
            ],
          ),
        ),
        Container(height: 1.0, color: hairline),

        // Scrollable Node Cards List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380.0),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: nodes.length,
            separatorBuilder: (context, index) =>
                Container(height: 1.0, color: hairline),
            itemBuilder: (context, index) {
              final node = nodes[index];
              final isSelected = selectedNode?.id == node.id;
              final latencyColor =
                  _getLatencyColor(node.latencyMs, textSecondary);

              return InkWell(
                onTap: () => _handleNodeSelect(context, ref, node),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      // Square Radio Marker (16x16 dp)
                      Container(
                        width: 16.0,
                        height: 16.0,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? accent : hairline,
                            width: 1.5,
                          ),
                          color: isSelected ? accent : Colors.transparent,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      const SizedBox(width: 12.0),

                      // Country Flag
                      if (node.countryCode != 'UN')
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: hairline, width: 1.0),
                          ),
                          child: CountryFlag.fromCountryCode(
                            node.countryCode,
                            height: 14.0,
                            width: 22.0,
                            borderRadius: 0,
                          ),
                        )
                      else
                        Icon(Icons.public_sharp,
                            size: 18.0, color: textSecondary),
                      const SizedBox(width: 10.0),

                      // Node Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Protocol Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                    vertical: 1.0,
                                  ),
                                  color: accent.withValues(alpha: 0.12),
                                  child: Text(
                                    Persian.ltrIsolate(
                                      node.protocol.name.toUpperCase(),
                                    ),
                                    style: TextStyle(
                                      fontFamily: ZohalTokens.fontFamily,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Expanded(
                                  child: Text(
                                    node.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: ZohalTokens.fontFamily,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3.0),
                            Text(
                              Persian.ltrIsolate('${node.server}:${node.port}'),
                              style: TextStyle(
                                fontFamily: ZohalTokens.fontFamily,
                                fontSize: 12.0,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Live Latency Pill
                      const SizedBox(width: 8.0),
                      if (node.isTesting)
                        SizedBox(
                          width: 14.0,
                          height: 14.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: latencyColor.withValues(alpha: 0.1),
                            border: Border.all(
                              color: latencyColor.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            _formatLatency(node.latencyMs),
                            style: TextStyle(
                              fontFamily: ZohalTokens.fontFamily,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w500,
                              color: latencyColor,
                            ),
                          ),
                        ),

                      // Single Ping Icon Button
                      IconButton(
                        icon: const Icon(Icons.refresh_sharp, size: 16.0),
                        tooltip: 'تست پینگ',
                        onPressed: () {
                          ref
                              .read(proxyNodesProvider.notifier)
                              .pingNode(node.id);
                        },
                      ),

                      // Delete Button (only for custom imported nodes)
                      if (node.isCustom)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_sharp,
                            size: 16.0,
                          ),
                          tooltip: StringsFa.deleteServer,
                          onPressed: () {
                            ref
                                .read(proxyNodesProvider.notifier)
                                .removeNode(node.id);
                            SharpToast.show(context, 'سرور حذف شد');
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
