// core/settings.dart
// Settings model and validation for Zohal Connect according to ZOHAL_SPEC Section 9.1.

enum ConnectionMode { auto, masque3, masque2, wireguard, gool }

enum IpVersion { auto, v4, v6, dual }

enum ScanProfile { auto, turbo, balanced, thorough, stealth, ironclad }

enum NoiseProfile { auto, off, light, balanced, aggressive, firewall, gfw }

enum RuleKind { domain, domainExact, keyword, regex, ipCidr, port }

class RoutingRule {
  final RuleKind kind;
  final String value;

  const RoutingRule({required this.kind, required this.value});

  Map<String, dynamic> toJson() => {'kind': kind.name, 'value': value};

  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    RuleKind parseKind(String? val) {
      switch (val) {
        case 'domainExact':
          return RuleKind.domainExact;
        case 'keyword':
          return RuleKind.keyword;
        case 'regex':
          return RuleKind.regex;
        case 'ipCidr':
          return RuleKind.ipCidr;
        case 'port':
          return RuleKind.port;
        default:
          return RuleKind.domain;
      }
    }

    return RoutingRule(
      kind: parseKind(json['kind'] as String?),
      value: json['value'] as String? ?? '',
    );
  }
}

enum AppSplitMode { all, only, except }

class AppSplitConfig {
  final AppSplitMode mode;
  final List<String> packages;

  const AppSplitConfig({
    this.mode = AppSplitMode.all,
    this.packages = const [],
  });

  Map<String, dynamic> toJson() => {'mode': mode.name, 'packages': packages};

  factory AppSplitConfig.fromJson(Map<String, dynamic> json) {
    AppSplitMode parseMode(String? val) {
      switch (val) {
        case 'only':
          return AppSplitMode.only;
        case 'except':
          return AppSplitMode.except;
        default:
          return AppSplitMode.all;
      }
    }

    return AppSplitConfig(
      mode: parseMode(json['mode'] as String?),
      packages:
          (json['packages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class ZohalSettings {
  final ConnectionMode connectionMode;
  final IpVersion ipVersion;
  final ScanProfile scanProfile;
  final NoiseProfile noiseProfile;
  final String scope; // 'Tun' or 'SystemProxy'
  final bool killSwitch;
  final bool autoConnectOnLaunch;
  final bool restoreLastState;
  final bool autoConnectOnBoot;
  final bool startWithSystem;
  final bool minimizeToTray;
  final bool smartDomesticDirect;
  final bool lanDirect;
  final List<RoutingRule> directRules;
  final List<RoutingRule> blockRules;
  final AppSplitConfig appSplit;
  final List<String> dnsServers;
  final bool fragment;
  final bool ech;
  final bool diagnosticLog;

  const ZohalSettings({
    this.connectionMode = ConnectionMode.auto,
    this.ipVersion = IpVersion.auto,
    this.scanProfile = ScanProfile.auto,
    this.noiseProfile = NoiseProfile.auto,
    this.scope = 'Tun',
    this.killSwitch = true,
    this.autoConnectOnLaunch = true,
    this.restoreLastState = true,
    this.autoConnectOnBoot = false,
    this.startWithSystem = false,
    this.minimizeToTray = true,
    this.smartDomesticDirect = true,
    this.lanDirect = true,
    this.directRules = const [],
    this.blockRules = const [],
    this.appSplit = const AppSplitConfig(),
    this.dnsServers = const [
      '1.1.1.1',
      '1.0.0.1',
      '2606:4700:4700::1111',
      '2606:4700:4700::1001',
    ],
    this.fragment = false,
    this.ech = false,
    this.diagnosticLog = false,
  });

  ZohalSettings copyWith({
    ConnectionMode? connectionMode,
    IpVersion? ipVersion,
    ScanProfile? scanProfile,
    NoiseProfile? noiseProfile,
    String? scope,
    bool? killSwitch,
    bool? autoConnectOnLaunch,
    bool? restoreLastState,
    bool? autoConnectOnBoot,
    bool? startWithSystem,
    bool? minimizeToTray,
    bool? smartDomesticDirect,
    bool? lanDirect,
    List<RoutingRule>? directRules,
    List<RoutingRule>? blockRules,
    AppSplitConfig? appSplit,
    List<String>? dnsServers,
    bool? fragment,
    bool? ech,
    bool? diagnosticLog,
  }) {
    return ZohalSettings(
      connectionMode: connectionMode ?? this.connectionMode,
      ipVersion: ipVersion ?? this.ipVersion,
      scanProfile: scanProfile ?? this.scanProfile,
      noiseProfile: noiseProfile ?? this.noiseProfile,
      scope: scope ?? this.scope,
      killSwitch: killSwitch ?? this.killSwitch,
      autoConnectOnLaunch: autoConnectOnLaunch ?? this.autoConnectOnLaunch,
      restoreLastState: restoreLastState ?? this.restoreLastState,
      autoConnectOnBoot: autoConnectOnBoot ?? this.autoConnectOnBoot,
      startWithSystem: startWithSystem ?? this.startWithSystem,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      smartDomesticDirect: smartDomesticDirect ?? this.smartDomesticDirect,
      lanDirect: lanDirect ?? this.lanDirect,
      directRules: directRules ?? this.directRules,
      blockRules: blockRules ?? this.blockRules,
      appSplit: appSplit ?? this.appSplit,
      dnsServers: dnsServers ?? this.dnsServers,
      fragment: fragment ?? this.fragment,
      ech: ech ?? this.ech,
      diagnosticLog: diagnosticLog ?? this.diagnosticLog,
    );
  }

  Map<String, dynamic> toJson() => {
    'connection_mode': connectionMode.name,
    'ip_version': ipVersion.name,
    'scan_profile': scanProfile.name,
    'noize_profile': noiseProfile.name,
    'scope': scope,
    'kill_switch': killSwitch,
    'auto_connect_on_launch': autoConnectOnLaunch,
    'restore_last_state': restoreLastState,
    'auto_connect_on_boot': autoConnectOnBoot,
    'start_with_system': startWithSystem,
    'minimize_to_tray': minimizeToTray,
    'routing.smart_domestic_direct': smartDomesticDirect,
    'routing.lan_direct': lanDirect,
    'routing.direct_rules': directRules.map((e) => e.toJson()).toList(),
    'routing.block_rules': blockRules.map((e) => e.toJson()).toList(),
    'routing.app_split': appSplit.toJson(),
    'dns.servers': dnsServers,
    'advanced.fragment': fragment,
    'advanced.ech': ech,
    'diagnostic_log': diagnosticLog,
  };

  factory ZohalSettings.fromJson(Map<String, dynamic> json) {
    ConnectionMode parseMode(String? val) {
      switch (val) {
        case 'masque3':
          return ConnectionMode.masque3;
        case 'masque2':
          return ConnectionMode.masque2;
        case 'wireguard':
          return ConnectionMode.wireguard;
        case 'gool':
          return ConnectionMode.gool;
        default:
          return ConnectionMode.auto;
      }
    }

    return ZohalSettings(
      connectionMode: parseMode(json['connection_mode'] as String?),
      scope: json['scope'] as String? ?? 'Tun',
      killSwitch: json['kill_switch'] as bool? ?? true,
      autoConnectOnLaunch: json['auto_connect_on_launch'] as bool? ?? true,
      restoreLastState: json['restore_last_state'] as bool? ?? true,
      autoConnectOnBoot: json['auto_connect_on_boot'] as bool? ?? false,
      startWithSystem: json['start_with_system'] as bool? ?? false,
      minimizeToTray: json['minimize_to_tray'] as bool? ?? true,
      smartDomesticDirect:
          json['routing.smart_domestic_direct'] as bool? ?? true,
      lanDirect: json['routing.lan_direct'] as bool? ?? true,
      directRules:
          (json['routing.direct_rules'] as List<dynamic>?)
              ?.map((e) => RoutingRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      blockRules:
          (json['routing.block_rules'] as List<dynamic>?)
              ?.map((e) => RoutingRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      appSplit: json['routing.app_split'] != null
          ? AppSplitConfig.fromJson(
              json['routing.app_split'] as Map<String, dynamic>,
            )
          : const AppSplitConfig(),
      dnsServers:
          (json['dns.servers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['1.1.1.1', '1.0.0.1'],
      fragment: json['advanced.fragment'] as bool? ?? false,
      ech: json['advanced.ech'] as bool? ?? false,
      diagnosticLog: json['diagnostic_log'] as bool? ?? false,
    );
  }
}
