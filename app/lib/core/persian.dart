// core/persian.dart
// Persian typography, numerals, duration, and isolate helpers for Zohal Connect.

class Persian {
  Persian._();

  static const String ltrIsolateStart = '\u2066';
  static const String ltrIsolateEnd = '\u2069';

  static const Map<String, String> _digitMap = {
    '0': '۰',
    '1': '۱',
    '2': '۲',
    '3': '۳',
    '4': '۴',
    '5': '۵',
    '6': '۶',
    '7': '۷',
    '8': '۸',
    '9': '۹',
  };

  /// Converts ASCII digits in any string to Persian digits (۰-۹).
  static String toPersianDigits(String input) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(_digitMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Formats an integer with Persian digits and optional thousands separator («٬»).
  static String formatNumber(num number, {bool useGrouping = false}) {
    if (number is int && !useGrouping) {
      return toPersianDigits(number.toString());
    }

    final parts = number.toString().split('.');
    String integerPart = parts[0];
    if (useGrouping) {
      final buffer = StringBuffer();
      final len = integerPart.length;
      for (int i = 0; i < len; i++) {
        if (i > 0 && (len - i) % 3 == 0) {
          buffer.write('٬');
        }
        buffer.write(_digitMap[integerPart[i]] ?? integerPart[i]);
      }
      integerPart = buffer.toString();
    } else {
      integerPart = toPersianDigits(integerPart);
    }

    if (parts.length > 1) {
      final decimalPart = toPersianDigits(parts[1]);
      return '$integerPart٫$decimalPart';
    }
    return integerPart;
  }

  /// Formats a duration in seconds into HH:MM:SS with Persian digits.
  /// Example: 125 seconds -> ۰۰:۰۲:۰۵
  static String formatDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String hStr = hours < 10 ? '0$hours' : hours.toString();
    final String mStr = minutes < 10 ? '0$minutes' : minutes.toString();
    final String sStr = seconds < 10 ? '0$seconds' : seconds.toString();

    final String timeStr = '$hStr:$mStr:$sStr';
    return toPersianDigits(timeStr);
  }

  /// Formats bytes into human-readable Persian string (کیلوبایت، مگابایت، گیگابایت).
  static String formatBytes(int bytes) {
    if (bytes < 0) bytes = 0;
    const double kb = 1024;
    const double mb = 1024 * 1024;
    const double gb = 1024 * 1024 * 1024;

    if (bytes >= gb) {
      final double val = bytes / gb;
      return '${formatDecimal(val, 1)} گیگابایت';
    } else if (bytes >= mb) {
      final double val = bytes / mb;
      return '${formatDecimal(val, 1)} مگابایت';
    } else {
      final double val = bytes / kb;
      return '${formatDecimal(val, 1)} کیلوبایت';
    }
  }

  /// Formats byte transfer rates into Persian string (کیلوبیت/ث، مگابیت/ث).
  /// Rate is in bytes per second; converts to bits/sec.
  static String formatRate(int bytesPerSecond) {
    if (bytesPerSecond < 0) bytesPerSecond = 0;
    final double bitsPerSec = bytesPerSecond * 8.0;
    const double kbps = 1000.0;
    const double mbps = 1000.0 * 1000.0;
    const double gbps = 1000.0 * 1000.0 * 1000.0;

    if (bitsPerSec >= gbps) {
      final double val = bitsPerSec / gbps;
      return '${formatDecimal(val, 1)} گیگابیت/ث';
    } else if (bitsPerSec >= mbps) {
      final double val = bitsPerSec / mbps;
      return '${formatDecimal(val, 1)} مگابیت/ث';
    } else {
      final double val = bitsPerSec / kbps;
      return '${formatDecimal(val, 1)} کیلوبیت/ث';
    }
  }

  /// Formats a float with specific decimal places using Persian digits and Persian decimal separator «٫».
  static String formatDecimal(double value, int fractionDigits) {
    final String fixed = value.toStringAsFixed(fractionDigits);
    final parts = fixed.split('.');
    final String intPart = toPersianDigits(parts[0]);
    if (parts.length > 1) {
      final String fracPart = toPersianDigits(parts[1]);
      return '$intPart٫$fracPart';
    }
    return intPart;
  }

  /// Wraps a technical Latin string (IP address, protocol, port) in an LTR isolate.
  static String ltrIsolate(String text) {
    return '$ltrIsolateStart$text$ltrIsolateEnd';
  }

  /// Formats IPv4 address with Persian digits inside an LTR isolate.
  static String formatIpv4(String ip) {
    final persianIp = toPersianDigits(ip);
    return ltrIsolate(persianIp);
  }

  /// Formats IPv6 address, preserving Latin characters inside an LTR isolate.
  static String formatIpv6(String ip) {
    return ltrIsolate(ip);
  }

  /// Formats a percentage value with Persian digits and «٪».
  static String formatPercent(num value) {
    return '${formatNumber(value)}٪';
  }
}
