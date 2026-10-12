// core/single_instance.dart
// Single-instance enforcement for desktop platforms (Linux, Windows, macOS).
// Uses OS file lock and loopback socket signaling to ensure only one instance runs.

import 'dart:io';

import 'package:flutter/foundation.dart';

class SingleInstance {
  static RandomAccessFile? _lockRaf;
  static ServerSocket? _serverSocket;
  static VoidCallback? onFocusRequested;

  /// Ensures that only a single instance of Zohal Connect is running on desktop.
  /// If another instance exists, notifies the running instance to focus its window,
  /// displays a user notification, and returns false.
  static Future<bool> ensureSingleInstance({VoidCallback? onFocus}) async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return true;
    }

    onFocusRequested = onFocus;
    final lockFile = File('${Directory.systemTemp.path}/zohal_instance.lock');

    try {
      // Use append mode so we do NOT truncate the file before acquiring the lock!
      final raf = lockFile.openSync(mode: FileMode.append);
      raf.lockSync(FileLock.exclusive);
      _lockRaf = raf;

      // Primary instance: bind loopback socket for inter-process focus communication
      _serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = _serverSocket!.port;

      raf.setPositionSync(0);
      raf.truncateSync(0);
      raf.writeStringSync('$port\n$pid\n');
      raf.flushSync();

      _serverSocket!.listen((socket) {
        socket.listen((data) {
          final msg = String.fromCharCodes(data).trim();
          if (msg == 'FOCUS') {
            onFocusRequested?.call();
          }
        });
      });

      return true;
    } on FileSystemException {
      // Another instance is running and holds the lock.
      // Signal existing instance to focus its window.
      try {
        if (lockFile.existsSync()) {
          final content = lockFile.readAsStringSync().trim().split('\n');
          if (content.isNotEmpty) {
            final port = int.tryParse(content[0]);
            if (port != null && port > 0) {
              final socket = await Socket.connect(
                InternetAddress.loopbackIPv4,
                port,
                timeout: const Duration(milliseconds: 800),
              );
              socket.writeln('FOCUS');
              await socket.flush();
              await socket.close();
            }
          }
        }
      } catch (_) {}

      // Inform user via native notification
      if (Platform.isLinux) {
        try {
          await Process.run('notify-send', [
            '-a',
            'Zohal',
            'زحل',
            'یک فرآیند دیگر از برنامه زحل از قبل در حال اجرا است.',
          ]);
        } catch (_) {}
      } else if (Platform.isWindows) {
        try {
          await Process.run('powershell', [
            '-WindowStyle',
            'Hidden',
            '-Command',
            '[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms"); '
                '[System.Windows.Forms.MessageBox]::Show("یک فرآیند دیگر از برنامه زحل از قبل در حال اجرا است.", "زحل")',
          ]);
        } catch (_) {}
      }

      stderr.writeln('یک فرآیند دیگر از برنامه زحل از قبل در حال اجرا است.');
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Releases resources, file locks, and sockets upon application shutdown.
  static void cleanup() {
    try {
      _serverSocket?.close();
    } catch (_) {}
    try {
      _lockRaf?.unlockSync();
      _lockRaf?.closeSync();
    } catch (_) {}
  }
}
