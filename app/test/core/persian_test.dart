// test/core/persian_test.dart
// Unit tests for Persian formatting and typography helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/core/persian.dart';
import 'package:zohal/l10n/strings_fa.dart';

void main() {
  group('Persian Digit Conversion', () {
    test('converts all ASCII digits to Persian digits', () {
      expect(Persian.toPersianDigits('0123456789'), '۰۱۲۳۴۵۶۷۸۹');
      expect(Persian.toPersianDigits('198.18.0.1'), '۱۹۸.۱۸.۰.۱');
    });

    test('preserves non-digits', () {
      expect(Persian.toPersianDigits('Hello 123!'), 'Hello ۱۲۳!');
      expect(Persian.toPersianDigits('زحل ۲۰۲۶'), 'زحل ۲۰۲۶');
    });
  });

  group('Persian Number Formatting', () {
    test('formats integers with thousands separators', () {
      expect(Persian.formatNumber(1000, useGrouping: true), '۱٬۰۰۰');
      expect(Persian.formatNumber(1234567, useGrouping: true), '۱٬۲۳۴٬۵۶۷');
    });

    test('formats decimals with Persian comma', () {
      expect(Persian.formatDecimal(12.5, 1), '۱۲٫۵');
      expect(Persian.formatDecimal(0.75, 2), '۰٫۷۵');
    });
  });

  group('Persian Duration Formatting', () {
    test('formats zero duration as ۰۰:۰۰:۰۰', () {
      expect(Persian.formatDuration(0), '۰۰:۰۰:۰۰');
    });

    test('formats seconds and minutes', () {
      expect(Persian.formatDuration(65), '۰۰:۰۱:۰۵');
      expect(Persian.formatDuration(3600), '۰۱:۰۰:۰۰');
      expect(Persian.formatDuration(3665), '۰۱:۰۱:۰۵');
    });
  });

  group('Persian Rate and Byte Formatting', () {
    test('formats bytes appropriately', () {
      expect(Persian.formatBytes(500), '۰٫۵ کیلوبایت');
      expect(Persian.formatBytes(1024 * 1024), '۱٫۰ مگابایت');
      expect(Persian.formatBytes(1024 * 1024 * 1024 * 2), '۲٫۰ گیگابایت');
    });

    test('formats transfer rates', () {
      expect(Persian.formatRate(125000), '۱٫۰ مگابیت/ث');
      expect(Persian.formatRate(12500), '۱۰۰٫۰ کیلوبیت/ث');
    });
  });

  group('LTR Isolate Formatting', () {
    test('wraps text in unicode isolates', () {
      final wrapped = Persian.ltrIsolate('1.1.1.1');
      expect(wrapped.startsWith('\u2066'), isTrue);
      expect(wrapped.endsWith('\u2069'), isTrue);
      expect(wrapped.contains('1.1.1.1'), isTrue);
    });
  });

  group('Digit Lint in Persian UI Strings', () {
    test('UI strings do not contain ASCII digits', () {
      final testStrings = [
        StringsFa.appName,
        StringsFa.appFullName,
        StringsFa.connect,
        StringsFa.disconnect,
        StringsFa.stateIdle,
        StringsFa.stateConnecting,
        StringsFa.stateConnected,
        StringsFa.hintTouch,
        StringsFa.hintClick,
        StringsFa.hintCancelConfirm,
        StringsFa.routingSmartTitle,
        StringsFa.routingSmartDesc,
        StringsFa.toastCopied,
        StringsFa.toastSaved,
        StringsFa.onboardingIntro,
      ];

      final asciiDigitRegex = RegExp(r'[0-9]');
      for (final str in testStrings) {
        expect(
          asciiDigitRegex.hasMatch(str),
          isFalse,
          reason: 'String "$str" contains forbidden ASCII digit',
        );
      }
    });
  });
}
