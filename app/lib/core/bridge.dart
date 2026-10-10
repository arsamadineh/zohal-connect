// core/bridge.dart
// Typed IPC connection and Riverpod providers for Zohal Connect according to ZOHAL_SPEC Section 6.4.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine_state.dart';
import 'logger.dart';
import 'settings.dart';

// Riverpod Providers
final engineStateProvider =
    StateNotifierProvider<EngineStateNotifier, EngineState>((ref) {
      final bridge = ref.watch(bridgeClientProvider);
      return EngineStateNotifier(bridge);
    });

final engineStatsProvider =
    StateNotifierProvider<EngineStatsNotifier, EngineStats>((ref) {
      final bridge = ref.watch(bridgeClientProvider);
      return EngineStatsNotifier(bridge);
    });

final zohalSettingsProvider =
    StateNotifierProvider<ZohalSettingsNotifier, ZohalSettings>((ref) {
      final bridge = ref.watch(bridgeClientProvider);
      return ZohalSettingsNotifier(bridge);
    });

final systemAccentProvider = StateProvider<Color?>((ref) => null);

final bridgeClientProvider = Provider<ZohalBridgeClient>((ref) {
  final client = ZohalBridgeClient();
  ref.onDispose(() => client.dispose());
  return client;
});

class EngineStateNotifier extends StateNotifier<EngineState> {
  final ZohalBridgeClient bridge;
  StreamSubscription<EngineState>? _sub;

  EngineStateNotifier(this.bridge) : super(const EngineState()) {
    _sub = bridge.stateStream.listen((newState) {
      state = newState;
    });
  }

  void setDesired(bool up) {
    bridge.setDesired(up);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class EngineStatsNotifier extends StateNotifier<EngineStats> {
  final ZohalBridgeClient bridge;
  StreamSubscription<EngineStats>? _sub;

  EngineStatsNotifier(this.bridge) : super(const EngineStats()) {
    _sub = bridge.statsStream.listen((newStats) {
      state = newStats;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class ZohalSettingsNotifier extends StateNotifier<ZohalSettings> {
  final ZohalBridgeClient bridge;
  StreamSubscription<ZohalSettings>? _sub;

  ZohalSettingsNotifier(this.bridge) : super(const ZohalSettings()) {
    _sub = bridge.settingsStream.listen((newSettings) {
      state = newSettings;
    });
  }

  Future<void> updateSettings(ZohalSettings settings) async {
    state = settings;
    await bridge.patchSettings(settings);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class ZohalBridgeClient {
  Socket? _socket;
  final StreamController<EngineState> _stateController =
      StreamController<EngineState>.broadcast();
  final StreamController<EngineStats> _statsController =
      StreamController<EngineStats>.broadcast();
  final StreamController<ZohalSettings> _settingsController =
      StreamController<ZohalSettings>.broadcast();

  Stream<EngineState> get stateStream => _stateController.stream;
  Stream<EngineStats> get statsStream => _statsController.stream;
  Stream<ZohalSettings> get settingsStream => _settingsController.stream;

  bool _connected = false;
  int _epoch = 0;
  Timer? _reconnectTimer;

  ZohalBridgeClient() {
    _initConnection();
  }

  Future<void> _initConnection() async {
    if (Platform.isLinux || Platform.isMacOS) {
      // Connect to Unix domain socket
      const socketPath = '/run/zohal/engine.sock';
      try {
        final address = InternetAddress(
          socketPath,
          type: InternetAddressType.unix,
        );
        _socket = await Socket.connect(address, 0);
        _onSocketConnected();
      } catch (e) {
        ZohalLogger().debug('Engine socket not reachable at $socketPath: $e');
        _scheduleReconnect();
      }
    } else {
      // Other platforms fallback or abstract / named pipe
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _initConnection();
    });
  }

  void _onSocketConnected() {
    _connected = true;
    ZohalLogger().info('Connected to Zohal Engine IPC');

    // Send handshake: {"t":"hello","proto":1,"client":"0.1.0"}
    final handshake = jsonEncode({'t': 'hello', 'proto': 1, 'client': '0.1.0'});
    _socket?.writeln(handshake);

    // Subscribe to stats
    final sub = jsonEncode({'t': 'subscribe', 'stats': true});
    _socket?.writeln(sub);

    // Read lines
    _socket
        ?.transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onError: (e) {
            ZohalLogger().warn('IPC socket error: $e');
            _disconnect();
          },
          onDone: () {
            ZohalLogger().warn('IPC socket closed by engine');
            _disconnect();
          },
        );
  }

  void _handleLine(String line) {
    if (line.isEmpty) return;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['t'] as String?;
      switch (type) {
        case 'state':
          _stateController.add(EngineState.fromJson(json));
          break;
        case 'stats':
          _statsController.add(EngineStats.fromJson(json));
          break;
        case 'settings':
          _settingsController.add(ZohalSettings.fromJson(json));
          break;
        case 'log':
          final msg = json['msg'] as String? ?? '';
          final code = json['code'] as String?;
          ZohalLogger().info(msg);
          break;
      }
    } catch (e) {
      ZohalLogger().warn('Failed to parse IPC message: $e');
    }
  }

  void setDesired(bool up) {
    _epoch++;
    final cmd = jsonEncode({'t': 'set_desired', 'up': up, 'epoch': _epoch});
    _send(cmd);
  }

  Future<void> patchSettings(ZohalSettings settings) async {
    final cmd = jsonEncode({
      't': 'patch_settings',
      'settings': settings.toJson(),
    });
    _send(cmd);
  }

  void probeNow() {
    _send(jsonEncode({'t': 'probe_now'}));
  }

  void resetIdentity() {
    _send(jsonEncode({'t': 'reset_identity'}));
  }

  void exportDiagnostics() {
    _send(jsonEncode({'t': 'export_diagnostics'}));
  }

  void _send(String payload) {
    if (_connected && _socket != null) {
      _socket?.writeln(payload);
    }
  }

  void _disconnect() {
    _connected = false;
    _socket?.destroy();
    _socket = null;
    _scheduleReconnect();
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _stateController.close();
    _statsController.close();
    _settingsController.close();
  }
}
