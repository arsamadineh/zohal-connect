// core/proxy_models.dart
// Production-grade data model and URI parser for VLESS, VMess, Shadowsocks, Trojan, and WARP configs.
// Complies with ZOHAL_SPEC: clean data types, zero telemetry, robust parsing with zero crashes.

import 'dart:convert';

enum ProxyProtocol {
  warp,
  vless,
  vmess,
  shadowsocks,
  trojan,
}

class ProxyNode {
  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String server;
  final int port;
  final String rawUri;
  final String countryCode;
  final int? latencyMs;
  final bool isTesting;
  final Map<String, dynamic> metadata;

  const ProxyNode({
    required this.id,
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    required this.rawUri,
    this.countryCode = 'UN',
    this.latencyMs,
    this.isTesting = false,
    this.metadata = const {},
  });

  bool get isCustom => protocol != ProxyProtocol.warp;

  /// Convenience forwarding helper to [ProxyParser.parseSingle].
  static ProxyNode? parse(String uri) => ProxyParser.parseSingle(uri);

  /// Convenience forwarding helper to [ProxyParser.parseAll].
  static List<ProxyNode> parseList(String input) => ProxyParser.parseAll(input);

  ProxyNode copyWith({
    String? id,
    String? name,
    ProxyProtocol? protocol,
    String? server,
    int? port,
    String? rawUri,
    String? countryCode,
    int? Function()? latencyMs,
    bool? isTesting,
    Map<String, dynamic>? metadata,
  }) {
    return ProxyNode(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      server: server ?? this.server,
      port: port ?? this.port,
      rawUri: rawUri ?? this.rawUri,
      countryCode: countryCode ?? this.countryCode,
      latencyMs: latencyMs != null ? latencyMs() : this.latencyMs,
      isTesting: isTesting ?? this.isTesting,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'server': server,
        'port': port,
        'rawUri': rawUri,
        'countryCode': countryCode,
        'latencyMs': latencyMs,
        'metadata': metadata,
      };

  factory ProxyNode.fromJson(Map<String, dynamic> json) {
    ProxyProtocol parseProtocol(String? val) {
      switch (val?.toLowerCase()) {
        case 'vless':
          return ProxyProtocol.vless;
        case 'vmess':
          return ProxyProtocol.vmess;
        case 'shadowsocks':
        case 'ss':
          return ProxyProtocol.shadowsocks;
        case 'trojan':
          return ProxyProtocol.trojan;
        default:
          return ProxyProtocol.warp;
      }
    }

    return ProxyNode(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'سرور',
      protocol: parseProtocol(json['protocol'] as String?),
      server: json['server'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 443,
      rawUri: json['rawUri'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? 'UN',
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// Extracts standard 2-letter ISO country code from remark, host, or emojis.
  static String inferCountryCode(String text, String server) {
    final cleanText = text.trim();

    // 1. Check bracketed ISO code: e.g. [DE], (NL), DE - Server
    final bracketMatch =
        RegExp(r'[\[\(\s]([A-Za-z]{2})[\]\)\s\-]').firstMatch(cleanText);
    if (bracketMatch != null) {
      final code = bracketMatch.group(1)!.toUpperCase();
      if (_knownCountryCodes.contains(code)) return code;
    }

    // 2. Check Unicode flag emoji (e.g. 🇩🇪, 🇺🇸, 🇫🇮) via 32-bit runes
    final runes = cleanText.runes.toList();
    for (int i = 0; i < runes.length - 1; i++) {
      final r1 = runes[i];
      final r2 = runes[i + 1];
      if (r1 >= 0x1F1E6 && r1 <= 0x1F1FF && r2 >= 0x1F1E6 && r2 <= 0x1F1FF) {
        final c1 = String.fromCharCode(r1 - 0x1F1E6 + 65);
        final c2 = String.fromCharCode(r2 - 0x1F1E6 + 65);
        final code = '$c1$c2'.toUpperCase();
        if (_knownCountryCodes.contains(code)) return code;
      }
    }

    // 3. Keyword matching (English and Persian)
    final lower = cleanText.toLowerCase();
    for (final entry in _countryKeywords.entries) {
      for (final kw in entry.value) {
        if (kw.length <= 2) {
          // Strict word boundary check for 2-letter codes to prevent false positives
          // e.g. "us" in "custom", "de" in "node"
          final regex = RegExp('(^|[^a-zA-Z0-9])$kw([^a-zA-Z0-9]|\$)',
              caseSensitive: false);
          if (regex.hasMatch(lower)) {
            return entry.key;
          }
        } else {
          if (lower.contains(kw)) {
            return entry.key;
          }
        }
      }
    }

    // 4. Server TLD match (e.g. server.de, edge.nl, london.uk)
    final serverLower = server.toLowerCase();
    if (serverLower.endsWith('.uk')) return 'GB';
    for (final code in _knownCountryCodes) {
      if (serverLower.endsWith('.${code.toLowerCase()}')) {
        return code;
      }
    }

    return 'UN';
  }

  static const Set<String> _knownCountryCodes = {
    'DE',
    'US',
    'NL',
    'FR',
    'TR',
    'GB',
    'FI',
    'CA',
    'SG',
    'JP',
    'SE',
    'CH',
    'AE',
    'RU',
    'PL',
    'IT',
    'ES',
    'IR',
    'AT',
    'AU',
    'BE',
    'BR',
    'DK',
    'HK',
    'IN',
    'KR',
    'NO',
    'RO',
    'UA',
    'UN'
  };

  static const Map<String, List<String>> _countryKeywords = {
    'DE': [
      'germany',
      'frankfurt',
      'berlin',
      'آلمان',
      'فرانکفورت',
      'برلین',
      'de'
    ],
    'US': [
      'united states',
      'usa',
      'america',
      'new york',
      'los angeles',
      'آمریکا',
      'us'
    ],
    'NL': ['netherlands', 'holland', 'amsterdam', 'هلند', 'آمستردام', 'nl'],
    'FR': ['france', 'paris', 'فرانسه', 'پاریس', 'fr'],
    'TR': ['turkey', 'istanbul', 'ترکیه', 'استانبول', 'tr'],
    'GB': [
      'united kingdom',
      'britain',
      'london',
      'england',
      'انگلیس',
      'لندن',
      'بریتانیا',
      'uk',
      'gb'
    ],
    'FI': ['finland', 'helsinki', 'فنلاند', 'هلسینکی', 'fi'],
    'CA': ['canada', 'toronto', 'کانادا', 'تورنتو', 'ca'],
    'SG': ['singapore', 'سنگاپور', 'sg'],
    'JP': ['japan', 'tokyo', 'ژاپن', 'توکیو', 'jp'],
    'SE': ['sweden', 'stockholm', 'سوئد', 'استکهلم', 'se'],
    'CH': ['switzerland', 'zurich', 'سوئیس', 'زوریخ', 'ch'],
    'AE': ['uae', 'dubai', 'امارات', 'دبی', 'ae'],
    'RU': ['russia', 'moscow', 'روسیه', 'مسکو', 'ru'],
    'PL': ['poland', 'warsaw', 'لهستان', 'ورشو', 'pl'],
    'IT': ['italy', 'milan', 'rome', 'ایتالیا', 'میلان', 'رم', 'it'],
    'ES': ['spain', 'madrid', 'اسپانیا', 'مادرید', 'es'],
    'IR': ['iran', 'tehran', 'ایران', 'تهران', 'ir'],
  };
}

class ProxyParser {
  ProxyParser._();

  /// Parses a raw configuration string (single URI, multi-line list, or subscription text).
  static List<ProxyNode> parseAll(String input) {
    final nodes = <ProxyNode>[];
    final lines = input.split(RegExp(r'[\r\n]+'));

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }

      final node = parseSingle(line);
      if (node != null) {
        nodes.add(node);
      }
    }

    return nodes;
  }

  /// Parses a single URI string into a ProxyNode.
  static ProxyNode? parseSingle(String uriString) {
    final trimmed = uriString.trim();
    if (trimmed.isEmpty) return null;

    try {
      if (trimmed.startsWith('vless://')) {
        return _parseVless(trimmed);
      } else if (trimmed.startsWith('vmess://')) {
        return _parseVmess(trimmed);
      } else if (trimmed.startsWith('ss://')) {
        return _parseShadowsocks(trimmed);
      } else if (trimmed.startsWith('trojan://')) {
        return _parseTrojan(trimmed);
      } else if (trimmed.startsWith('warp://')) {
        return _parseWarp(trimmed);
      }
    } catch (_) {}

    return null;
  }

  static ProxyNode? _parseVless(String uriStr) {
    final uri = Uri.parse(uriStr);
    final uuid = uri.userInfo;
    final server = uri.host;
    final port = uri.port > 0 ? uri.port : 443;
    final query = uri.queryParameters;
    final remark = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : 'VLESS $server:$port';

    if (server.isEmpty || uuid.isEmpty) return null;

    final countryCode = ProxyNode.inferCountryCode(remark, server);

    return ProxyNode(
      id: 'vless_${server}_${port}_${uuid.substring(0, uuid.length > 8 ? 8 : uuid.length)}',
      name: remark,
      protocol: ProxyProtocol.vless,
      server: server,
      port: port,
      rawUri: uriStr,
      countryCode: countryCode,
      metadata: {
        'uuid': uuid,
        'security': query['security'] ?? 'none',
        'sni': query['sni'] ?? query['peer'] ?? '',
        'type': query['type'] ?? 'tcp',
        'path': query['path'] ?? '',
        'flow': query['flow'] ?? '',
        'pbk': query['pbk'] ?? '', // Reality public key
        'sid': query['sid'] ?? '', // Reality short id
        'fp': query['fp'] ?? 'chrome',
      },
    );
  }

  static ProxyNode? _parseVmess(String uriStr) {
    final b64Content = uriStr.substring('vmess://'.length).trim();
    String jsonStr;
    try {
      jsonStr = utf8.decode(base64.decode(base64.normalize(b64Content)));
    } catch (_) {
      try {
        jsonStr =
            utf8.decode(base64Url.decode(base64Url.normalize(b64Content)));
      } catch (_) {
        return null;
      }
    }

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final server = (json['add'] as String? ?? '').trim();
    final rawPort = json['port'];
    final port = rawPort is int
        ? rawPort
        : int.tryParse(rawPort?.toString() ?? '443') ?? 443;
    final uuid = (json['id'] as String? ?? '').trim();
    final remark = (json['ps'] as String? ?? 'VMess $server:$port').trim();

    if (server.isEmpty || uuid.isEmpty) return null;

    final countryCode = ProxyNode.inferCountryCode(remark, server);

    return ProxyNode(
      id: 'vmess_${server}_${port}_${uuid.substring(0, uuid.length > 8 ? 8 : uuid.length)}',
      name: remark,
      protocol: ProxyProtocol.vmess,
      server: server,
      port: port,
      rawUri: uriStr,
      countryCode: countryCode,
      metadata: {
        'uuid': uuid,
        'aid': json['aid'] ?? 0,
        'net': json['net'] ?? 'tcp',
        'type': json['type'] ?? 'none',
        'host': json['host'] ?? '',
        'path': json['path'] ?? '',
        'tls': json['tls'] ?? '',
        'sni': json['sni'] ?? '',
        'scy': json['scy'] ?? 'auto',
      },
    );
  }

  static ProxyNode? _parseShadowsocks(String uriStr) {
    final uri = Uri.parse(uriStr);
    final remark = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : 'Shadowsocks ${uri.host}:${uri.port}';

    final server = uri.host;
    final port = uri.port > 0 ? uri.port : 8388;
    String method = '';
    String password = '';

    if (uri.userInfo.isNotEmpty) {
      if (uri.userInfo.contains(':')) {
        final parts = uri.userInfo.split(':');
        method = parts[0];
        password = parts.sublist(1).join(':');
      } else {
        try {
          final decoded =
              utf8.decode(base64.decode(base64.normalize(uri.userInfo)));
          final parts = decoded.split(':');
          if (parts.length >= 2) {
            method = parts[0];
            password = parts.sublist(1).join(':');
          }
        } catch (_) {}
      }
    }

    if (server.isEmpty) return null;
    final countryCode = ProxyNode.inferCountryCode(remark, server);

    return ProxyNode(
      id: 'ss_${server}_$port',
      name: remark,
      protocol: ProxyProtocol.shadowsocks,
      server: server,
      port: port,
      rawUri: uriStr,
      countryCode: countryCode,
      metadata: {
        'method': method,
        'password': password,
      },
    );
  }

  static ProxyNode? _parseTrojan(String uriStr) {
    final uri = Uri.parse(uriStr);
    final server = uri.host;
    final port = uri.port > 0 ? uri.port : 443;
    final password = uri.userInfo;
    final query = uri.queryParameters;
    final remark = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : 'Trojan $server:$port';

    if (server.isEmpty || password.isEmpty) return null;
    final countryCode = ProxyNode.inferCountryCode(remark, server);

    return ProxyNode(
      id: 'trojan_${server}_$port',
      name: remark,
      protocol: ProxyProtocol.trojan,
      server: server,
      port: port,
      rawUri: uriStr,
      countryCode: countryCode,
      metadata: {
        'password': password,
        'sni': query['sni'] ?? server,
        'type': query['type'] ?? 'tcp',
      },
    );
  }

  static ProxyNode? _parseWarp(String uriStr) {
    final uri = Uri.parse(uriStr);
    final server =
        uri.host.isNotEmpty ? uri.host : 'engage.cloudflareclient.com';
    final port = uri.port > 0 ? uri.port : 2408;
    final remark = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : 'Cloudflare WARP';

    return ProxyNode(
      id: 'warp_${server}_$port',
      name: remark,
      protocol: ProxyProtocol.warp,
      server: server,
      port: port,
      rawUri: uriStr,
      countryCode: 'US',
      metadata: Map.from(uri.queryParameters),
    );
  }
}
