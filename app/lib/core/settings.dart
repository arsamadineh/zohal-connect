// core/settings.dart
// Settings model and validation for Zohal Connect according to ZOHAL_SPEC Section 9.1.

enum ConnectionMode { auto, masque3, masque2, wireguard, gool }

enum IpVersion { auto, v4, v6, dual }

enum ScanProfile { auto, turbo, balanced, thorough, verified, ironclad }

enum NoiseProfile { auto, off, light, balanced, aggressive, firewall, gfw }

enum RuleKind { domain, domainExact, keyword, regex, ipCidr, port }

class RoutingRule {
  final RuleKind kind;
  final String value;

  const RoutingRule({required this.kind, required this.value});

  Map<String, dynamic> toJson() => {
        'kind': ZohalSettings.ruleKindToString(kind),
        'value': value,
      };

  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    RuleKind parseKind(String? val) {
      switch (val?.toLowerCase()) {
        case 'domainexact':
        case 'full':
          return RuleKind.domainExact;
        case 'keyword':
          return RuleKind.keyword;
        case 'regex':
        case 'regexp':
          return RuleKind.regex;
        case 'ipcidr':
        case 'cidr':
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

  Map<String, dynamic> toJson() => {
        'mode': ZohalSettings.appSplitModeToString(mode),
        'packages': packages,
      };

  factory AppSplitConfig.fromJson(Map<String, dynamic> json) {
    AppSplitMode parseMode(String? val) {
      switch (val?.toLowerCase()) {
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
      packages: (json['packages'] as List<dynamic>?)
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
    this.scanProfile = ScanProfile.turbo,
    this.noiseProfile = NoiseProfile.auto,
    this.scope = 'Tun',
    this.killSwitch = true,
    this.autoConnectOnLaunch = true,
    this.restoreLastState = true,
    this.autoConnectOnBoot = false,
    this.startWithSystem = false,
    this.minimizeToTray = false,
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
    this.diagnosticLog = true,
  });

  static String modeToString(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.auto:
        return 'Auto';
      case ConnectionMode.masque3:
        return 'Masque3';
      case ConnectionMode.masque2:
        return 'Masque2';
      case ConnectionMode.wireguard:
        return 'WireGuard';
      case ConnectionMode.gool:
        return 'Gool';
    }
  }

  static String ipVersionToString(IpVersion version) {
    switch (version) {
      case IpVersion.auto:
        return 'Auto';
      case IpVersion.v4:
        return 'V4';
      case IpVersion.v6:
        return 'V6';
      case IpVersion.dual:
        return 'Dual';
    }
  }

  static String scanProfileToString(ScanProfile p) {
    switch (p) {
      case ScanProfile.auto:
        return 'Auto';
      case ScanProfile.turbo:
        return 'Turbo';
      case ScanProfile.balanced:
        return 'Balanced';
      case ScanProfile.thorough:
        return 'Thorough';
      case ScanProfile.verified:
        return 'Verified';
      case ScanProfile.ironclad:
        return 'Ironclad';
    }
  }

  static String noiseProfileToString(NoiseProfile p) {
    switch (p) {
      case NoiseProfile.auto:
        return 'Auto';
      case NoiseProfile.off:
        return 'Off';
      case NoiseProfile.light:
        return 'Light';
      case NoiseProfile.balanced:
        return 'Balanced';
      case NoiseProfile.aggressive:
        return 'Aggressive';
      case NoiseProfile.firewall:
        return 'Firewall';
      case NoiseProfile.gfw:
        return 'Gfw';
    }
  }

  static String appSplitModeToString(AppSplitMode m) {
    switch (m) {
      case AppSplitMode.all:
        return 'All';
      case AppSplitMode.only:
        return 'Only';
      case AppSplitMode.except:
        return 'Except';
    }
  }

  static String ruleKindToString(RuleKind k) {
    switch (k) {
      case RuleKind.domain:
        return 'Domain';
      case RuleKind.domainExact:
        return 'Full';
      case RuleKind.keyword:
        return 'Keyword';
      case RuleKind.regex:
        return 'Regexp';
      case RuleKind.ipCidr:
        return 'Cidr';
      case RuleKind.port:
        return 'Port';
    }
  }

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
        'connection_mode': modeToString(connectionMode),
        'ip_version': ipVersionToString(ipVersion),
        'scan_profile': scanProfileToString(scanProfile),
        'noize_profile': noiseProfileToString(noiseProfile),
        'scope': scope,
        'kill_switch': killSwitch,
        'auto_connect_on_launch': autoConnectOnLaunch,
        'restore_last_state': restoreLastState,
        'auto_connect_on_boot': autoConnectOnBoot,
        'start_with_system': startWithSystem,
        'minimize_to_tray': minimizeToTray,
        'routing': {
          'smart_domestic_direct': smartDomesticDirect,
          'lan_direct': lanDirect,
          'direct_rules': directRules.map((e) => e.toJson()).toList(),
          'block_rules': blockRules.map((e) => e.toJson()).toList(),
          'app_split': appSplit.toJson(),
        },
        'dns': {
          'servers': dnsServers,
        },
        'dns_servers': dnsServers,
        'advanced': {
          'fragment': fragment,
          'ech': ech,
        },
        'diagnostic_log': diagnosticLog,
        // Dotted keys preserved for backward compatibility
        'routing.smart_domestic_direct': smartDomesticDirect,
        'routing.lan_direct': lanDirect,
        'routing.direct_rules': directRules.map((e) => e.toJson()).toList(),
        'routing.block_rules': blockRules.map((e) => e.toJson()).toList(),
        'routing.app_split': appSplit.toJson(),
        'dns.servers': dnsServers,
        'advanced.fragment': fragment,
        'advanced.ech': ech,
      };

  factory ZohalSettings.fromJson(Map<String, dynamic> json) {
    final data = json['settings'] is Map<String, dynamic>
        ? json['settings'] as Map<String, dynamic>
        : json;

    ConnectionMode parseMode(String? val) {
      switch (val?.toLowerCase()) {
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

    IpVersion parseIpVersion(String? val) {
      switch (val?.toLowerCase()) {
        case 'v4':
        case 'ipv4':
          return IpVersion.v4;
        case 'v6':
        case 'ipv6':
          return IpVersion.v6;
        case 'dual':
          return IpVersion.dual;
        default:
          return IpVersion.auto;
      }
    }

    ScanProfile parseScanProfile(String? val) {
      switch (val?.toLowerCase()) {
        case 'turbo':
          return ScanProfile.turbo;
        case 'balanced':
          return ScanProfile.balanced;
        case 'thorough':
          return ScanProfile.thorough;
        case 'verified':
          return ScanProfile.verified;
        case 'ironclad':
          return ScanProfile.ironclad;
        default:
          return ScanProfile.auto;
      }
    }

    NoiseProfile parseNoiseProfile(String? val) {
      switch (val?.toLowerCase()) {
        case 'off':
          return NoiseProfile.off;
        case 'light':
          return NoiseProfile.light;
        case 'balanced':
          return NoiseProfile.balanced;
        case 'aggressive':
          return NoiseProfile.aggressive;
        case 'firewall':
          return NoiseProfile.firewall;
        case 'gfw':
          return NoiseProfile.gfw;
        default:
          return NoiseProfile.auto;
      }
    }

    final routingData = data['routing'] is Map<String, dynamic>
        ? data['routing'] as Map<String, dynamic>
        : null;

    final dnsData = data['dns'] is Map<String, dynamic>
        ? data['dns'] as Map<String, dynamic>
        : null;

    final advancedData = data['advanced'] is Map<String, dynamic>
        ? data['advanced'] as Map<String, dynamic>
        : null;

    List<String> parseDns() {
      if (dnsData != null && dnsData['servers'] is List) {
        return (dnsData['servers'] as List).map((e) => e.toString()).toList();
      }
      if (data['dns.servers'] is List) {
        return (data['dns.servers'] as List).map((e) => e.toString()).toList();
      }
      if (data['dns_servers'] is List) {
        return (data['dns_servers'] as List).map((e) => e.toString()).toList();
      }
      return const ['1.1.1.1', '1.0.0.1'];
    }

    List<RoutingRule> parseDirectRules() {
      final list = (routingData?['direct_rules'] ??
          data['routing.direct_rules']) as List<dynamic>?;
      return list
              ?.map((e) => RoutingRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
    }

    List<RoutingRule> parseBlockRules() {
      final list = (routingData?['block_rules'] ?? data['routing.block_rules'])
          as List<dynamic>?;
      return list
              ?.map((e) => RoutingRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
    }

    AppSplitConfig parseAppSplit() {
      final raw = routingData?['app_split'] ?? data['routing.app_split'];
      if (raw is Map<String, dynamic>) {
        return AppSplitConfig.fromJson(raw);
      }
      return const AppSplitConfig();
    }

    return ZohalSettings(
      connectionMode: parseMode(data['connection_mode'] as String?),
      ipVersion: parseIpVersion(data['ip_version'] as String?),
      scanProfile: parseScanProfile(data['scan_profile'] as String?),
      noiseProfile: parseNoiseProfile(
          data['noize_profile'] as String? ?? data['noise_profile'] as String?),
      scope: data['scope'] as String? ?? 'Tun',
      killSwitch: data['kill_switch'] as bool? ?? true,
      autoConnectOnLaunch: data['auto_connect_on_launch'] as bool? ?? true,
      restoreLastState: data['restore_last_state'] as bool? ?? true,
      autoConnectOnBoot: data['auto_connect_on_boot'] as bool? ?? false,
      startWithSystem: data['start_with_system'] as bool? ?? false,
      minimizeToTray: data['minimize_to_tray'] as bool? ?? false,
      smartDomesticDirect: routingData?['smart_domestic_direct'] as bool? ??
          data['routing.smart_domestic_direct'] as bool? ??
          true,
      lanDirect: routingData?['lan_direct'] as bool? ??
          data['routing.lan_direct'] as bool? ??
          true,
      directRules: parseDirectRules(),
      blockRules: parseBlockRules(),
      appSplit: parseAppSplit(),
      dnsServers: parseDns(),
      fragment: advancedData?['fragment'] as bool? ??
          data['advanced.fragment'] as bool? ??
          false,
      ech: advancedData?['ech'] as bool? ??
          data['advanced.ech'] as bool? ??
          false,
      diagnosticLog: data['diagnostic_log'] as bool? ?? true,
    );
  }
}
