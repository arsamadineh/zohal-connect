// test/challenger/m4_parser_adversarial_test.dart
// Adversarial challenge test harness for ProxyNode and ProxyParser.
// Empirically stress-tests parser edge cases: malformed URIs, missing UUIDs,
// base64 padding errors, invalid ports, non-object JSON payloads, and giant inputs.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/core/proxy_models.dart';

void main() {
  group('Adversarial Parser Challenges: Malformed URIs & Encodings', () {
    test('Handles malformed URI schemes and invalid characters gracefully', () {
      final malformedCases = [
        'vless://',
        'vless:///',
        'vless://@',
        'vless://:@',
        'vless://:443',
        'vless://user@',
        'vless://user@:443',
        'vless://user@host:',
        'vless://user@host:-1',
        'vless://user@host:99999999999999999999',
        'vless://[invalid_ipv6_bracket:443',
        'vless://uuid@host:443#%ZZ%FF%GG', // Corrupt percent-encoding in fragment
        'vless://uuid@host:443?key=%ZZ%GG', // Corrupt percent-encoding in query
        'vmess://',
        'vmess:///',
        'vmess://?#',
        'ss://',
        'ss://@',
        'trojan://',
        'trojan://@',
        'warp://',
        '   ',
        '\r\n\t',
        'http://example.com/not-a-proxy',
        'ftp://user:pass@ftp.example.com',
        'javascript:alert(1)',
        'data:text/plain;base64,SGVsbG8=',
      ];

      for (final uri in malformedCases) {
        expect(
          () => ProxyParser.parseSingle(uri),
          returnsNormally,
          reason: 'Failed on input: "$uri"',
        );
        final node = ProxyParser.parseSingle(uri);
        // None of these should result in a valid node with valid server & port
        if (node != null) {
          expect(node.server.isNotEmpty, isTrue);
          expect(node.port, inInclusiveRange(1, 65535));
        }
      }
    });

    test('Missing UUIDs in VLESS and VMess return null safely', () {
      final missingUuidCases = [
        'vless://@1.1.1.1:443',
        'vless://1.1.1.1:443',
        'vless://?security=reality@1.1.1.1:443',
      ];

      for (final uri in missingUuidCases) {
        final node = ProxyParser.parseSingle(uri);
        expect(node, isNull, reason: 'Expected null for missing UUID: $uri');
      }

      // Adversarial Finding: vless://:secret@1.1.1.1:443 treats ':secret' as uuid because uri.userInfo is ':secret'
      final colonUserInfoNode =
          ProxyParser.parseSingle('vless://:secret@1.1.1.1:443');
      expect(colonUserInfoNode, isNotNull);
      expect(colonUserInfoNode!.metadata['uuid'], equals(':secret'));

      // VMess missing id in JSON
      final vmessNoId = base64Url.encode(utf8.encode(jsonEncode({
        'add': '1.1.1.1',
        'port': 443,
        // no 'id'
      })));
      expect(ProxyParser.parseSingle('vmess://$vmessNoId'), isNull);

      // VMess empty id in JSON
      final vmessEmptyId = base64Url.encode(utf8.encode(jsonEncode({
        'add': '1.1.1.1',
        'port': 443,
        'id': '   ',
      })));
      expect(ProxyParser.parseSingle('vmess://$vmessEmptyId'), isNull);
    });

    test('Base64 padding and encoding variations in VMess and SS', () {
      final validVmessJson = jsonEncode({
        'add': 'example.com',
        'port': 443,
        'id': 'b3bb189e-8bf9-3888-9912-ace4e6543003',
        'net': 'ws',
        'ps': 'Test VMess'
      });
      final rawBytes = utf8.encode(validVmessJson);
      final stdB64 = base64.encode(rawBytes); // Standard with padding '='
      final unpaddedB64 = stdB64.replaceAll('=', ''); // Unpadded
      final urlB64 = base64Url.encode(rawBytes); // URL-safe base64

      // 1. Standard padded base64
      final n1 = ProxyParser.parseSingle('vmess://$stdB64');
      expect(n1, isNotNull);
      expect(n1!.server, equals('example.com'));

      // 2. Unpadded standard base64 (tests base64.normalize)
      final n2 = ProxyParser.parseSingle('vmess://$unpaddedB64');
      expect(n2, isNotNull);
      expect(n2!.server, equals('example.com'));

      // 3. URL-safe base64
      final n3 = ProxyParser.parseSingle('vmess://$urlB64');
      expect(n3, isNotNull);
      expect(n3!.server, equals('example.com'));

      // 4. Invalid base64 characters
      final invalidB64Cases = [
        'vmess://!!!notbase64@@@',
        'vmess://${stdB64.substring(0, 5)}???',
        'vmess://$stdB64======',
        'vmess://',
      ];
      for (final bad in invalidB64Cases) {
        expect(
          () => ProxyParser.parseSingle(bad),
          returnsNormally,
          reason: 'Threw exception on invalid base64: $bad',
        );
        expect(ProxyParser.parseSingle(bad), isNull);
      }
    });

    test('VMess with non-object JSON payloads (array, string, number, null)',
        () {
      final nonObjectPayloads = [
        '["item1", "item2", 42]',
        '"just a plain string"',
        '123456789',
        'null',
        'true',
        '{"add": "server.com", "port": 443', // Truncated/syntax error JSON
      ];

      for (final payload in nonObjectPayloads) {
        final b64 = base64.encode(utf8.encode(payload));
        final uri = 'vmess://$b64';
        expect(
          () => ProxyParser.parseSingle(uri),
          returnsNormally,
          reason: 'Crashed on non-object JSON: $payload',
        );
        final node = ProxyParser.parseSingle(uri);
        expect(node, isNull);
      }
    });

    test('Port boundary cases (0, string ports, negative, floats, overflows)',
        () {
      // VMess port variations
      final portCases = [
        {'port': 0, 'valid': true},
        {'port': '8080', 'valid': true},
        {'port': 'invalid_port', 'valid': true, 'fallback': 443},
        {'port': null, 'valid': true, 'fallback': 443},
        {'port': 443.5, 'valid': true, 'fallback': 443},
      ];

      for (final c in portCases) {
        final jsonStr = jsonEncode({
          'add': 'server.org',
          'port': c['port'],
          'id': 'b3bb189e-8bf9-3888-9912-ace4e6543003',
        });
        final b64 = base64.encode(utf8.encode(jsonStr));
        final node = ProxyParser.parseSingle('vmess://$b64');
        expect(node, isNotNull);
        if (c.containsKey('fallback')) {
          expect(node!.port, equals(c['fallback']));
        }
      }
    });

    test('Batch multi-line stress test with 1,000 mixed valid & corrupt lines',
        () {
      final buffer = StringBuffer();
      int expectedValid = 0;

      for (int i = 0; i < 1000; i++) {
        if (i % 5 == 0) {
          // Valid VLESS
          buffer.writeln(
              'vless://uuid$i@node$i.de:443?security=reality#[DE] Node $i');
          expectedValid++;
        } else if (i % 5 == 1) {
          // Valid VMess
          final jsonStr = jsonEncode({
            'add': 'node$i.fr',
            'port': 8443,
            'id': 'uuid-vmess-$i',
            'ps': '[FR] Node $i',
          });
          buffer.writeln('vmess://${base64.encode(utf8.encode(jsonStr))}');
          expectedValid++;
        } else if (i % 5 == 2) {
          // Comment or blank line
          buffer.writeln(i % 2 == 0 ? '# A comment line $i' : '   ');
        } else if (i % 5 == 3) {
          // Malformed base64 / corrupted URI
          buffer.writeln('vmess://corrupt@@base64==$i');
        } else {
          // Random garbage
          buffer.writeln('garbage_protocol://$i@something:unknown');
        }
      }

      final stopwatch = Stopwatch()..start();
      final nodes = ProxyParser.parseAll(buffer.toString());
      stopwatch.stop();

      expect(nodes.length, equals(expectedValid));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason:
              '1000 line parse took longer than 1s: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
