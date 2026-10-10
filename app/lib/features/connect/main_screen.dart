// features/connect/main_screen.dart
// Main screen of Zohal Connect according to ZOHAL_SPEC Section 13.1.
// Strict layout: 360x640 fit, no scrolling, centered Saturn connect control, stats row, bottom group.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge.dart';
import '../../core/engine_state.dart';
import '../../core/persian.dart';
import '../../core/settings.dart';
import '../../design/components/connect_control.dart';
import '../../design/components/sharp_row.dart';
import '../../design/components/sharp_sheet.dart';
import '../../design/components/sharp_toast.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';
import '../mode/mode_sheet.dart';
import '../routing/routing_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  Timer? _ticker;
  int _connectedSeconds = 0;
  bool _cancelConfirmationArmed = false;
  Timer? _cancelArmTimer;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final engineState = ref.read(engineStateProvider);
      if (engineState.phase == ConnectionPhase.connected &&
          engineState.sinceUnix != null) {
        final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        setState(() {
          _connectedSeconds = nowUnix - engineState.sinceUnix!;
          if (_connectedSeconds < 0) _connectedSeconds = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cancelArmTimer?.cancel();
    super.dispose();
  }

  void _handleConnectTap(EngineState state) {
    final settings = ref.read(zohalSettingsProvider);
    if (state.phase == ConnectionPhase.idle ||
        state.phase == ConnectionPhase.failed) {
      ref
          .read(engineStateProvider.notifier)
          .setDesired(true, settings: settings);
    } else if (state.phase == ConnectionPhase.connecting ||
        state.phase == ConnectionPhase.preparing ||
        state.phase == ConnectionPhase.reconnecting) {
      if (_cancelConfirmationArmed) {
        // Second tap cancels
        _cancelArmTimer?.cancel();
        setState(() => _cancelConfirmationArmed = false);
        ref
            .read(engineStateProvider.notifier)
            .setDesired(false, settings: settings);
      } else {
        // First tap arms cancel confirmation for 3s
        setState(() => _cancelConfirmationArmed = true);
        _cancelArmTimer?.cancel();
        _cancelArmTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _cancelConfirmationArmed = false);
          }
        });
      }
    } else if (state.phase == ConnectionPhase.connected) {
      ref
          .read(engineStateProvider.notifier)
          .setDesired(false, settings: settings);
    } else if (state.phase == ConnectionPhase.disconnecting) {
      ref
          .read(engineStateProvider.notifier)
          .setDesired(true, settings: settings);
    }
  }

  String _getStateTitle(ConnectionPhase phase) {
    switch (phase) {
      case ConnectionPhase.idle:
        return StringsFa.stateIdle;
      case ConnectionPhase.preparing:
        return StringsFa.statePreparing;
      case ConnectionPhase.connecting:
        return StringsFa.stateConnecting;
      case ConnectionPhase.connected:
        return StringsFa.stateConnected;
      case ConnectionPhase.reconnecting:
        return StringsFa.stateReconnecting;
      case ConnectionPhase.disconnecting:
        return StringsFa.stateDisconnecting;
      case ConnectionPhase.failed:
        return StringsFa.stateFailed;
    }
  }

  String _getStateSubLabel(EngineState state) {
    if (_cancelConfirmationArmed) {
      return StringsFa.hintCancelConfirm;
    }

    switch (state.phase) {
      case ConnectionPhase.idle:
        return (Platform.isAndroid || Platform.isIOS)
            ? StringsFa.hintTouch
            : StringsFa.hintClick;
      case ConnectionPhase.preparing:
      case ConnectionPhase.connecting:
      case ConnectionPhase.reconnecting:
        switch (state.stage) {
          case ConnectionStage.prepare:
            return StringsFa.stagePrepare;
          case ConnectionStage.findGateway:
            return StringsFa.stageFindGateway;
          case ConnectionStage.buildTunnel:
            return StringsFa.stageBuildTunnel;
          case ConnectionStage.verifyPath:
            return StringsFa.stageVerifyPath;
          case ConnectionStage.none:
            return StringsFa.stateConnecting;
        }
      case ConnectionPhase.connected:
        return Persian.formatDuration(_connectedSeconds);
      case ConnectionPhase.disconnecting:
        return StringsFa.stateDisconnecting;
      case ConnectionPhase.failed:
        if (state.errorCode != null) {
          return StringsFa.getErrorTitle(state.errorCode!);
        }
        return StringsFa.stateFailed;
    }
  }

  String _getMethodLabel(ZohalSettings settings, EngineState state) {
    if (settings.connectionMode == ConnectionMode.auto) {
      if (state.phase == ConnectionPhase.connected &&
          state.transport != TransportKind.none) {
        final transportName = state.transport.name;
        return '${StringsFa.modeAutoTitle} (${Persian.ltrIsolate(transportName)})';
      }
      return StringsFa.modeAutoTitle;
    }

    switch (settings.connectionMode) {
      case ConnectionMode.masque3:
        return StringsFa.modeMasque3Title;
      case ConnectionMode.masque2:
        return StringsFa.modeMasque2Title;
      case ConnectionMode.wireguard:
        return StringsFa.modeWireguardTitle;
      case ConnectionMode.gool:
        return StringsFa.modeGoolTitle;
      case ConnectionMode.auto:
        return StringsFa.modeAutoTitle;
    }
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

    final engineState = ref.watch(engineStateProvider);
    final engineStats = ref.watch(engineStatsProvider);
    final settings = ref.watch(zohalSettingsProvider);

    final isConnected = engineState.phase == ConnectionPhase.connected;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ZohalTokens.contentMaxWidth,
            ),
            child: Column(
              children: [
                // 1. Header (56 dp)
                Container(
                  height: 56.0,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      // Wordmark with 14 dp square mark
                      ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 22.0,
                          height: 22.0,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Text(
                        StringsFa.appName,
                        style: TextStyle(
                          fontFamily: ZohalTokens.fontFamily,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings_sharp, size: 22.0),
                        tooltip: StringsFa.settings,
                        onPressed: () {
                          Navigator.of(context).push(
                            ZohalMotion.createPageRoute<void>(
                              const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(height: 1.0, color: hairline),

                // 2. Body Area (Connect Control + Labels)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Centered Connect Control
                      ConnectControl(
                        phase: engineState.phase,
                        stage: engineState.stage,
                        cancelConfirmationArmed: _cancelConfirmationArmed,
                        onTap: () => _handleConnectTap(engineState),
                      ),
                      const SizedBox(height: 20.0),

                      // State Title
                      Text(
                        _getStateTitle(engineState.phase),
                        style: TextStyle(
                          fontFamily: ZohalTokens.fontFamily,
                          fontSize: 22.0,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6.0),

                      // Sub-label / Timer / Hint
                      Text(
                        _getStateSubLabel(engineState),
                        style: TextStyle(
                          fontFamily: ZohalTokens.fontFamily,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // 5. Stats Row (when connected)
                      if (isConnected)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    StringsFa.download,
                                    style: TextStyle(
                                      fontFamily: ZohalTokens.fontFamily,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w400,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    Persian.formatRate(engineStats.rxBps),
                                    style: TextStyle(
                                      fontFamily: ZohalTokens.fontFamily,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1.0,
                                height: 28.0,
                                color: hairline,
                              ),
                              Column(
                                children: [
                                  Text(
                                    StringsFa.upload,
                                    style: TextStyle(
                                      fontFamily: ZohalTokens.fontFamily,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w400,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    Persian.formatRate(engineStats.txBps),
                                    style: TextStyle(
                                      fontFamily: ZohalTokens.fontFamily,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 6. Bottom Group (Anchored 56 dp rows)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: hairline, width: 1.0),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mode Selector Row
                      SharpRow(
                        title: StringsFa.connectionMethod,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getMethodLabel(settings, engineState),
                              style: TextStyle(
                                fontFamily: ZohalTokens.fontFamily,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            Icon(
                              Icons.arrow_back_ios_new_sharp,
                              size: 12.0,
                              color: textSecondary,
                            ),
                          ],
                        ),
                        onTap: () {
                          SharpSheet.show<void>(
                            context: context,
                            title: StringsFa.connectionMethod,
                            child: const ModeSheet(),
                          );
                        },
                      ),

                      // Routing Selector Row
                      SharpRow(
                        title: StringsFa.routing,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              settings.smartDomesticDirect
                                  ? StringsFa.smart
                                  : StringsFa.custom,
                              style: TextStyle(
                                fontFamily: ZohalTokens.fontFamily,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            Icon(
                              Icons.arrow_back_ios_new_sharp,
                              size: 12.0,
                              color: textSecondary,
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            ZohalMotion.createPageRoute<void>(
                              const RoutingScreen(),
                            ),
                          );
                        },
                      ),

                      // Exit Address Row (only when connected)
                      if (isConnected && engineState.exitIp != null)
                        SharpRow(
                          title: StringsFa.exitAddress,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Persian.formatIpv4(engineState.exitIp!),
                                style: TextStyle(
                                  fontFamily: ZohalTokens.fontFamily,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              IconButton(
                                icon: const Icon(
                                  Icons.content_copy_sharp,
                                  size: 16.0,
                                ),
                                tooltip: StringsFa.copy,
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: engineState.exitIp!),
                                  );
                                  SharpToast.show(
                                    context,
                                    StringsFa.toastCopied,
                                  );
                                },
                              ),
                            ],
                          ),
                          showDivider: false,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
