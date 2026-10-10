// main.dart
// Application entrypoint for Zohal Connect.
// Desktop window sizing and immediate runApp per ZOHAL_SPEC Section 13.1 & 15.2.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window configuration (fallback silently if unavailable)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(400.0, 680.0),
        minimumSize: Size(360.0, 600.0),
        maximumSize: Size(480.0, 900.0),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'Zohal',
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // Degrade gracefully if running in headless or non-desktop environment
    }
  }

  runApp(const ProviderScope(child: ZohalApp()));
}
