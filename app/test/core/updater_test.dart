// test/core/updater_test.dart
// Unit tests for update checker version comparison and autostart logic.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/core/autostart.dart';
import 'package:zohal/core/updater.dart';

void main() {
  group('Updater Semantic Versioning', () {
    test('identifies newer major, minor, and patch versions', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('0.2.0', '0.1.9'), isTrue);
    });

    test('rejects older or identical versions', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('0.9.9', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(isNewerVersion('1.1.0', '1.2.0'), isFalse);
    });

    test('handles build metadata and pre-release tags', () {
      expect(isNewerVersion('1.0.1+5', '1.0.0+4'), isTrue);
      expect(isNewerVersion('1.0.0-rc1', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.1-beta', '1.0.0'), isTrue);
    });

    test('handles different component lengths gracefully', () {
      expect(isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
    });
  });

  group('DNS IP Validation', () {
    test('validates standard IPv4 addresses', () {
      expect(InternetAddress.tryParse('1.1.1.1'), isNotNull);
      expect(InternetAddress.tryParse('8.8.8.8'), isNotNull);
      expect(InternetAddress.tryParse('178.22.122.100'), isNotNull);
      expect(InternetAddress.tryParse('10.202.10.10'), isNotNull);
      expect(InternetAddress.tryParse('256.0.0.1'), isNull);
      expect(InternetAddress.tryParse('1.1.1'), isNull);
      expect(InternetAddress.tryParse('invalid'), isNull);
    });

    test('validates standard IPv6 addresses', () {
      expect(InternetAddress.tryParse('2606:4700:4700::1111'), isNotNull);
      expect(InternetAddress.tryParse('2001:4860:4860::8888'), isNotNull);
      expect(InternetAddress.tryParse('::1'), isNotNull);
      expect(InternetAddress.tryParse('2606:4700:gggg::1111'), isNull);
    });
  });

  group('Autostart Manager', () {
    test('isLinuxAutostartEnabled returns boolean without crashing', () async {
      final enabled = await AutostartManager.isLinuxAutostartEnabled();
      expect(enabled, isA<bool>());
    });

    test('sync false succeeds without throwing', () async {
      await expectLater(AutostartManager.sync(false), completes);
    });
  });
}
