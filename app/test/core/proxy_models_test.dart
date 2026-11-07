// test/core/proxy_models_test.dart
// Comprehensive unit tests for ProxyNode parsing, country inference, and protocols.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/core/proxy_models.dart';

void main() {
  group('ProxyNode URI Parsers', () {
    test('Parses standard VLESS URI with Reality & SNI', () {
      const uri =
          'vless://9f3b2591-628b-4a57-b08e-5975d048d084@198.51.100.1:443?'
          'security=reality&type=grpc&serviceName=grpc-tun&sni=yahoo.com&fp=chrome&pbk=publicKey123#%F0%9F%87%A9%F0%9F%87%AA%20Frankfurt%20Reality';

      final node = ProxyNode.parse(uri);
      expect(node, isNotNull);
      expect(node!.protocol, equals(ProxyProtocol.vless));
      expect(node.server, equals('198.51.100.1'));
      expect(node.port, equals(443));
      expect(node.name, contains('Frankfurt Reality'));
      expect(node.countryCode, equals('DE'));
      expect(node.metadata['security'], equals('reality'));
      expect(node.metadata['type'], equals('grpc'));
      expect(node.metadata['sni'], equals('yahoo.com'));
      expect(node.metadata['pbk'], equals('publicKey123'));
      expect(node.isCustom, isTrue);
    });

    test('Parses VMess standard JSON base64 URI', () {
      final vmessJson = {
        'v': '2',
        'ps': '[FI] Helsinki Fast VMess',
        'add': 'fi.fastnode.org',
        'port': '443',
        'id': 'a3bb189e-8bf9-3888-9912-ace4e6543002',
        'aid': '0',
        'net': 'ws',
        'type': 'none',
        'host': 'fi.fastnode.org',
        'path': '/stream',
        'tls': 'tls',
        'sni': 'fi.fastnode.org',
      };
      final base64Payload = base64Url.encode(utf8.encode(jsonEncode(vmessJson)));
      final uri = 'vmess://$base64Payload';

      final node = ProxyNode.parse(uri);
      expect(node, isNotNull);
      expect(node!.protocol, equals(ProxyProtocol.vmess));
      expect(node.server, equals('fi.fastnode.org'));
      expect(node.port, equals(443));
      expect(node.name, equals('[FI] Helsinki Fast VMess'));
      expect(node.countryCode, equals('FI'));
      expect(node.metadata['net'], equals('ws'));
      expect(node.metadata['tls'], equals('tls'));
      expect(node.metadata['path'], equals('/stream'));
    });

    test('Parses Shadowsocks URI with user info base64', () {
      // chacha20-ietf-poly1305:SecretPassword123
      final userInfo = base64.encode(utf8.encode('chacha20-ietf-poly1305:SecretPassword123'));
      final uri = 'ss://$userInfo@ams.edge.nl:8388#%F0%9F%87%B3%F0%9F%87%B1%20Amsterdam%20SS';

      final node = ProxyNode.parse(uri);
      expect(node, isNotNull);
      expect(node!.protocol, equals(ProxyProtocol.shadowsocks));
      expect(node.server, equals('ams.edge.nl'));
      expect(node.port, equals(8388));
      expect(node.countryCode, equals('NL'));
      expect(node.metadata['method'], equals('chacha20-ietf-poly1305'));
      expect(node.metadata['password'], equals('SecretPassword123'));
    });

    test('Parses Trojan URI with query parameters', () {
      const uri = 'trojan://superPassword@192.0.2.55:443?sni=cdn.example.com&type=tcp#%5BFR%5D%20Paris%20Trojan';
      final node = ProxyNode.parse(uri);
      expect(node, isNotNull);
      expect(node!.protocol, equals(ProxyProtocol.trojan));
      expect(node.server, equals('192.0.2.55'));
      expect(node.port, equals(443));
      expect(node.name, equals('[FR] Paris Trojan'));
      expect(node.countryCode, equals('FR'));
      expect(node.metadata['password'], equals('superPassword'));
      expect(node.metadata['sni'], equals('cdn.example.com'));
    });

    test('Parses WARP URI', () {
      const uri = 'warp://auto?endpoint=162.159.193.10:2408#Cloudflare%20WARP';
      final node = ProxyNode.parse(uri);
      expect(node, isNotNull);
      expect(node!.protocol, equals(ProxyProtocol.warp));
      expect(node.server, equals('auto'));
      expect(node.port, equals(2408));
      expect(node.metadata['endpoint'], equals('162.159.193.10:2408'));
    });

    test('Returns null for malformed or unsupported URIs', () {
      expect(ProxyNode.parse(''), isNull);
      expect(ProxyNode.parse('http://example.com'), isNull);
      expect(ProxyNode.parse('vless://malformed-no-port-or-host'), isNull);
      expect(ProxyNode.parse('vmess://invalidBase64!!##'), isNull);
      expect(ProxyNode.parse('unknownprotocol://server:443'), isNull);
    });

    test('Parses multi-line text input into distinct nodes, filtering blanks and invalids', () {
      const input = '''
# Comments should be ignored
vless://uuid@server1.de:443?type=tcp#[DE] Berlin

invalid_link_line_here

vmess://eyJhZGQiOiAic2VydmVyMi5mcCIsICJwb3J0IjogNDQzLCAiaWQiOiAidXVpZDIiLCAicHMiOiAiW0ZSXSBQYXJpcyJ9

   
trojan://pass@server3.nl:443#[NL] Amsterdam
''';

      final nodes = ProxyNode.parseList(input);
      expect(nodes.length, equals(3));
      expect(nodes[0].countryCode, equals('DE'));
      expect(nodes[1].countryCode, equals('FR'));
      expect(nodes[2].countryCode, equals('NL'));
    });
  });

  group('Country Code Inference', () {
    test('Infers from ISO bracket notation [US], (GB)', () {
      expect(ProxyNode.inferCountryCode('[US] Chicago Node', '1.1.1.1'), equals('US'));
      expect(ProxyNode.inferCountryCode('(GB) London Core', '1.1.1.1'), equals('GB'));
      expect(ProxyNode.inferCountryCode('SG - Singapore #1', '1.1.1.1'), equals('SG'));
    });

    test('Infers from Unicode emoji flag', () {
      expect(ProxyNode.inferCountryCode('🇩🇪 Frankfurt #1', '1.1.1.1'), equals('DE'));
      expect(ProxyNode.inferCountryCode('🇫🇮 Helsinki Fast', '1.1.1.1'), equals('FI'));
      expect(ProxyNode.inferCountryCode('🇳🇱 Amsterdam Core', '1.1.1.1'), equals('NL'));
      expect(ProxyNode.inferCountryCode('🇺🇸 Ashburn VIP', '1.1.1.1'), equals('US'));
    });

    test('Infers from Persian and English keywords', () {
      expect(ProxyNode.inferCountryCode('سرور اختصاصی آلمان', '1.1.1.1'), equals('DE'));
      expect(ProxyNode.inferCountryCode('تونل فرانسه با پینگ کم', '1.1.1.1'), equals('FR'));
      expect(ProxyNode.inferCountryCode('London Fast Proxy', '1.1.1.1'), equals('GB'));
      expect(ProxyNode.inferCountryCode('Tokyo Edge Cluster', '1.1.1.1'), equals('JP'));
      expect(ProxyNode.inferCountryCode('Helsinki Dedicated', '1.1.1.1'), equals('FI'));
    });

    test('Infers from host domain suffix when remark has no country', () {
      expect(ProxyNode.inferCountryCode('Custom VPS', 'edge-fra.de'), equals('DE'));
      expect(ProxyNode.inferCountryCode('Custom VPS', 'proxy.finland.fi'), equals('FI'));
      expect(ProxyNode.inferCountryCode('Custom VPS', 'node.london.uk'), equals('GB'));
    });

    test('Defaults to UN (United Nations/World) when undetectable', () {
      expect(ProxyNode.inferCountryCode('My Node', '192.168.1.1'), equals('UN'));
    });
  });

  group('ProxyNode JSON Serialization', () {
    test('Round-trip serialization to/from JSON matches exactly', () {
      const node = ProxyNode(
        id: 'node_123',
        name: 'Frankfurt VIP',
        protocol: ProxyProtocol.vless,
        server: '198.51.100.5',
        port: 8443,
        rawUri: 'vless://uuid@198.51.100.5:8443#Frankfurt%20VIP',
        countryCode: 'DE',
        latencyMs: 85,
        metadata: {'security': 'reality', 'sni': 'apple.com'},
      );

      final json = node.toJson();
      final restored = ProxyNode.fromJson(json);

      expect(restored.id, equals(node.id));
      expect(restored.name, equals(node.name));
      expect(restored.protocol, equals(node.protocol));
      expect(restored.server, equals(node.server));
      expect(restored.port, equals(node.port));
      expect(restored.countryCode, equals(node.countryCode));
      expect(restored.latencyMs, equals(85));
      expect(restored.metadata['sni'], equals('apple.com'));
    });
  });
}
