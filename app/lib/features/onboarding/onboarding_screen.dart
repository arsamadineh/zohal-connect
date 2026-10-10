// features/onboarding/onboarding_screen.dart
// 4-step onboarding flow for Zohal Connect according to ZOHAL_SPEC Section 13.7.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge.dart';
import '../../core/engine_state.dart';
import '../../core/settings.dart';
import '../../design/components/connect_control.dart';
import '../../design/components/sharp_button.dart';
import '../../design/components/sharp_row.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';
import '../connect/main_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      ZohalMotion.createPageRoute<void>(const MainScreen()),
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

    final engineState = ref.watch(engineStateProvider);
    final settings = ref.watch(zohalSettingsProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ZohalTokens.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Step Indicator Header
                  Row(
                    children: List.generate(4, (index) {
                      final active = index <= _currentStep;
                      return Expanded(
                        child: Container(
                          height: 2.0,
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          color: active ? accent : hairline,
                        ),
                      );
                    }),
                  ),
                  const Spacer(),

                  // Step 0: معرفی (Intro)
                  if (_currentStep == 0) ...[
                    IgnorePointer(
                      child: ConnectControl(
                        phase: ConnectionPhase.idle,
                        stage: ConnectionStage.none,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    Text(
                      StringsFa.appName,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 26.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      StringsFa.onboardingIntro,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 15.0,
                        height: 1.6,
                        color: textSecondary,
                      ),
                    ),
                    const Spacer(),
                    SharpButton(
                      label: StringsFa.continueAction,
                      width: double.infinity,
                      onPressed: _nextStep,
                    ),
                  ],

                  // Step 1: دسترسیها (Permissions / Service)
                  if (_currentStep == 1) ...[
                    Text(
                      StringsFa.onboardingPermissionsTitle,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    if (Platform.isAndroid) ...[
                      SharpRow(
                        title: StringsFa.onboardingVpnPermission,
                        trailing: Icon(
                          Icons.check_sharp,
                          size: 20.0,
                          color: accent,
                        ),
                      ),
                      SharpRow(
                        title: StringsFa.onboardingNotificationPermission,
                        trailing: Icon(
                          Icons.check_sharp,
                          size: 20.0,
                          color: accent,
                        ),
                      ),
                      SharpRow(
                        title: StringsFa.onboardingBatteryPermission,
                        trailing: Icon(
                          Icons.check_sharp,
                          size: 20.0,
                          color: accent,
                        ),
                      ),
                    ] else ...[
                      SharpRow(
                        title: StringsFa.onboardingServiceRunning,
                        trailing: Icon(
                          Icons.check_sharp,
                          size: 20.0,
                          color: accent,
                        ),
                      ),
                    ],
                    const Spacer(),
                    SharpButton(
                      label: StringsFa.continueAction,
                      width: double.infinity,
                      onPressed: _nextStep,
                    ),
                  ],

                  // Step 2: روش اتصال (Mode Choice)
                  if (_currentStep == 2) ...[
                    Text(
                      StringsFa.connectionMethod,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      StringsFa.onboardingModeRecommend,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 14.0,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SharpRow(
                      title: StringsFa.modeAutoTitle,
                      subtitle: StringsFa.modeAutoDesc,
                      trailing: Container(
                        width: 16.0,
                        height: 16.0,
                        color: settings.connectionMode == ConnectionMode.auto
                            ? accent
                            : hairline,
                      ),
                      onTap: () {
                        ref.read(zohalSettingsProvider.notifier).updateSettings(
                              settings.copyWith(
                                connectionMode: ConnectionMode.auto,
                              ),
                            );
                      },
                    ),
                    SharpRow(
                      title: StringsFa.modeMasque3Title,
                      subtitle: StringsFa.modeMasque3Desc,
                      trailing: Container(
                        width: 16.0,
                        height: 16.0,
                        color: settings.connectionMode == ConnectionMode.masque3
                            ? accent
                            : hairline,
                      ),
                      onTap: () {
                        ref.read(zohalSettingsProvider.notifier).updateSettings(
                              settings.copyWith(
                                connectionMode: ConnectionMode.masque3,
                              ),
                            );
                      },
                    ),
                    SharpRow(
                      title: StringsFa.modeMasque2Title,
                      subtitle: StringsFa.modeMasque2Desc,
                      trailing: Container(
                        width: 16.0,
                        height: 16.0,
                        color: settings.connectionMode == ConnectionMode.masque2
                            ? accent
                            : hairline,
                      ),
                      onTap: () {
                        ref.read(zohalSettingsProvider.notifier).updateSettings(
                              settings.copyWith(
                                connectionMode: ConnectionMode.masque2,
                              ),
                            );
                      },
                    ),
                    const Spacer(),
                    SharpButton(
                      label: StringsFa.continueAction,
                      width: double.infinity,
                      onPressed: () {
                        _nextStep();
                        // Trigger initial registration & probe
                        ref.read(engineStateProvider.notifier).setDesired(true);
                      },
                    ),
                  ],

                  // Step 3: اولین اتصال (First Connect)
                  if (_currentStep == 3) ...[
                    ConnectControl(
                      phase: engineState.phase,
                      stage: engineState.stage,
                      onTap: () {},
                    ),
                    const SizedBox(height: 24.0),
                    Text(
                      engineState.phase == ConnectionPhase.connected
                          ? StringsFa.onboardingFirstConnectReady
                          : StringsFa.onboardingFirstConnectTesting,
                      style: TextStyle(
                        fontFamily: ZohalTokens.fontFamily,
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (engineState.phase == ConnectionPhase.connected) ...[
                      SharpButton(
                        label: StringsFa.continueAction,
                        width: double.infinity,
                        onPressed: _finishOnboarding,
                      ),
                    ] else if (engineState.phase == ConnectionPhase.failed) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SharpButton(
                              label: StringsFa.skip,
                              isOutlined: true,
                              onPressed: _finishOnboarding,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: SharpButton(
                              label: StringsFa.retry,
                              onPressed: () {
                                ref
                                    .read(engineStateProvider.notifier)
                                    .setDesired(true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SharpButton(
                        label: StringsFa.skip,
                        isOutlined: true,
                        width: double.infinity,
                        onPressed: _finishOnboarding,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
