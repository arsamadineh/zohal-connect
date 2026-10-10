// core/bridge.dart
// Typed IPC connection and Riverpod providers for Zohal Connect according to ZOHAL_SPEC Section 6.4.
//
// Desktop: Unix socket to zohald (`/run/zohal/engine.sock` from the system
// service, or the per-user `zohald user` socket; the bundled engine is
// auto-spawned so AppImage/tarball installs work without a service).
// Android: the engine lives in the `:vpn` process, controlled through
// VpnChannel (MethodChannel/EventChannel to ZohalVpnService).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'engine_state.dart';
import 'logger.dart';
import 'settings.dart';
import 'vpn_channel.dart';

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
  EngineState _lastEngineState = const EngineState();
  Timer? _convergeTimer;

  EngineStateNotifier(this.bridge) : super(const EngineState()) {
    _sub = bridge.stateStream.listen((newState) {
      _lastEngineState = newState;
      _convergeTimer?.cancel();
      state = newState;
    });
  }

  void setDesired(bool up, {ZohalSettings? settings}) {
    // Optimistic UI (spec 12.6): the control reacts within one frame while
    // the engine confirms asynchronously. If the engine disagrees for more
    // than 2 s, the engine's last real state wins back.
    final optimistic = _lastEngineState.copyWith(
      phase: up ? ConnectionPhase.preparing : ConnectionPhase.disconnecting,
      stage: up ? ConnectionStage.prepare : ConnectionStage.none,
      desiredUp: up,
      errorCode: () => null,
    );
    state = optimistic;
    _convergeTimer?.cancel();
    _convergeTimer = Timer(const Duration(seconds: 15), () {
      state = _lastEngineState;
    });
    bridge.setDesired(up, settings: settings);
  }

  @override
  void dispose() {
    _convergeTimer?.cancel();
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
    bridge.pushSettings(state);
    _sub = bridge.settingsStream.listen((newSettings) {
      state = newSettings;
    });
  }

  Future<void> updateSettings(ZohalSettings settings) async {
    state = settings;
    bridge.pushSettings(settings);
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
  ZohalSettings _lastSettings = const ZohalSettings();
  StreamSubscription<VpnNativeState>? _vpnSub;
  bool _spawnAttempted = false;

  ZohalBridgeClient() {
    if (VpnChannel.isSupported) {
      _initAndroid();
    } else {
      _initConnection();
    }
  }

  void pushSettings(ZohalSettings settings) {
    _lastSettings = settings;
  }

  // ---- Android path: engine in :vpn process via platform channel ----
  void _initAndroid() {
    final channel = VpnChannel();
    _vpnSub = channel.stateStream.listen(
      (native) {
        _connected = true;
        _stateController.add(
          EngineState.fromVpnMap({
            'phase': native.phase,
            'stage': native.stage,
            'error': native.error,
            'exitIp': native.exitIp,
            'exitLoc': native.exitLoc,
            'sinceUnix': native.sinceUnix,
            'epoch': _epoch,
          }),
        );
      },
      onError: (Object e) {
        ZohalLogger().warn('VPN state channel error: $e');
        _connected = false;
      },
    );
    // Publish the current native state once so the UI never starts blank.
    channel.currentState().then((phase) {
      _stateController.add(
        EngineState.fromVpnMap({'phase': phase, 'epoch': _epoch}),
      );
    }).catchError((Object e) {
      ZohalLogger().debug('VPN current state unavailable: $e');
    });
  }

  Future<void> _androidSetDesired(bool up) async {
    final channel = VpnChannel();
    if (up) {
      final granted = await channel.prepare();
      if (!granted) {
        _stateController.add(
          const EngineState(
            phase: ConnectionPhase.failed,
            errorCode: 'E220',
          ),
        );
        return;
      }
      await channel.start({
        'mode': _lastSettings.connectionMode.name,
        'dns': _lastSettings.dnsServers,
        'fragment': _lastSettings.fragment,
        'ech': _lastSettings.ech,
        'splitMode': _lastSettings.appSplit.mode.name,
        'splitPackages': _lastSettings.appSplit.packages,
      });
    } else {
      await channel.stop();
    }
  }

  // ---- Desktop path: Unix socket to zohald ----
  static const String _systemSocketPath = '/run/zohal/engine.sock';

  static String _userSocketPath() {
    return '${Directory.systemTemp.path}/zohal_user/user_engine.sock';
  }

  List<String> _zohaldCandidates() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return [
      '/usr/lib/zohal/zohald',
      '$exeDir/zohald',
      '$exeDir/../lib/zohal/zohald',
      '/opt/zohal/zohald',
    ];
  }

  Future<void> _initConnection() async {
    if (!(Platform.isLinux || Platform.isMacOS)) {
      _scheduleReconnect();
      return;
    }
    // 1. System service socket.
    if (await _tryConnect(_systemSocketPath)) return;
    // 2. Per-user engine socket (AppImage/tarball without the service).
    if (await _tryConnect(_userSocketPath())) return;
    // 3. Spawn the bundled user-scope engine once, then connect to it.
    if (!_spawnAttempted) {
      _spawnAttempted = true;
      if (await _spawnUserEngine()) {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (await _tryConnect(_userSocketPath())) return;
        }
      }
    }
    ZohalLogger().debug('Engine socket not reachable; will retry');
    _scheduleReconnect();
  }

  Future<bool> _tryConnect(String socketPath) async {
    try {
      final file = File(socketPath);
      if (!await file.exists()) return false;
      final address = InternetAddress(
        socketPath,
        type: InternetAddressType.unix,
      );
      _socket = await Socket.connect(address, 0);
      _onSocketConnected();
      return true;
    } catch (e) {
      ZohalLogger().debug('Engine socket not reachable at $socketPath: $e');
      return false;
    }
  }

  Future<bool> _spawnUserEngine() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final logPath = '${supportDir.path}/zohald-user.log';
      for (final candidate in _zohaldCandidates()) {
        final bin = File(candidate);
        if (!await bin.exists()) continue;
        ZohalLogger().info('Spawning user engine: $candidate');
        final logFile = await File(logPath).open(mode: FileMode.write);
        await Process.start(
          candidate,
          ['user'],
          mode: ProcessStartMode.detached,
          runInShell: false,
        );
        await logFile.close();
        return true;
      }
      ZohalLogger().warn('No bundled zohald binary found for user scope');
    } catch (e) {
      ZohalLogger().warn('Failed to spawn user engine: $e');
    }
    return false;
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
        ?.cast<List<int>>()
        .transform<String>(utf8.decoder)
        .transform<String>(const LineSplitter())
        .listen(
      _handleLine,
      onError: (Object e) {
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
          if (code != null) {
            ZohalLogger().info('[$code] $msg');
          } else {
            ZohalLogger().info(msg);
          }
          break;
      }
    } catch (e) {
      ZohalLogger().warn('Failed to parse IPC message: $e');
    }
  }

  Future<bool> ensureVpnPermission() async {
    if (!VpnChannel.isSupported) return true;
    return VpnChannel().prepare();
  }

  void setDesired(bool up, {ZohalSettings? settings}) {
    if (settings != null) _lastSettings = settings;
    _epoch++;
    if (VpnChannel.isSupported) {
      _androidSetDesired(up);
      return;
    }
    final cmd = jsonEncode({'t': 'set_desired', 'up': up, 'epoch': _epoch});
    _send(cmd);
  }

  Future<void> patchSettings(ZohalSettings settings) async {
    _lastSettings = settings;
    if (VpnChannel.isSupported) return;
    final cmd = jsonEncode({
      't': 'patch_settings',
      'settings': settings.toJson(),
    });
    _send(cmd);
  }

  void probeNow() {
    if (VpnChannel.isSupported) return;
    _send(jsonEncode({'t': 'probe_now'}));
  }

  void resetIdentity() {
    if (VpnChannel.isSupported) return;
    _send(jsonEncode({'t': 'reset_identity'}));
  }

  void exportDiagnostics() {
    if (VpnChannel.isSupported) return;
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
    _vpnSub?.cancel();
    _socket?.destroy();
    _stateController.close();
    _statsController.close();
    _settingsController.close();
  }
}
