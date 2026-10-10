// core/logger.dart
// In-app log ring buffer (2000 events) for Zohal Connect according to ZOHAL_SPEC Section 9.6.

import 'dart:async';
import 'dart:collection';

import 'persian.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String? code;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    this.code,
    required this.message,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return Persian.toPersianDigits('$h:$m:$s');
  }

  String get levelLabel {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String toExportString() {
    final codeStr = code != null ? ' [$code]' : '';
    return '${timestamp.toIso8601String()} [$levelLabel]$codeStr $message';
  }
}

class ZohalLogger {
  static final ZohalLogger _instance = ZohalLogger._internal();
  factory ZohalLogger() => _instance;
  ZohalLogger._internal();

  static const int maxEntries = 2000;
  final DoubleLinkedQueue<LogEntry> _queue = DoubleLinkedQueue<LogEntry>();
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast(sync: true);

  Stream<LogEntry> get stream => _controller.stream;

  void log(LogLevel level, String message, {String? code}) {
    logAt(DateTime.now(), level, message, code: code);
  }

  void logAt(
    DateTime timestamp,
    LogLevel level,
    String message, {
    String? code,
  }) {
    if (_queue.length >= maxEntries) {
      _queue.removeFirst();
    }
    final entry = LogEntry(
      timestamp: timestamp,
      level: level,
      code: code,
      message: message,
    );
    _queue.addLast(entry);
    _controller.add(entry);
  }

  void fromNative({
    required String level,
    required String message,
    String? code,
    int? timestampSeconds,
  }) {
    final parsedLevel = switch (level.toLowerCase()) {
      'error' || 'err' || 'fatal' => LogLevel.error,
      'warn' || 'warning' => LogLevel.warn,
      'debug' || 'trace' => LogLevel.debug,
      _ => LogLevel.info,
    };
    logAt(
      timestampSeconds == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000),
      parsedLevel,
      message,
      code: code,
    );
  }

  void info(String message) => log(LogLevel.info, message);
  void warn(String message) => log(LogLevel.warn, message);
  void error(String message, {String? code}) =>
      log(LogLevel.error, message, code: code);
  void debug(String message) => log(LogLevel.debug, message);

  List<LogEntry> getEntries({LogLevel? minLevel}) {
    if (minLevel == null) {
      return _queue.toList();
    }
    return _queue.where((e) => e.level.index >= minLevel.index).toList();
  }

  void clear() {
    _queue.clear();
  }

  String exportAll() {
    final buffer = StringBuffer();
    for (final entry in _queue) {
      buffer.writeln(entry.toExportString());
    }
    return buffer.toString();
  }

  void dispose() {
    _controller.close();
  }
}
