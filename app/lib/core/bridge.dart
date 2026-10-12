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
  StreamSubscription<Map<String, dynamic>>? _vpnLogSub;
  bool _spawnAttempted = false;
  final List<String> _pendingMessages = [];

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

    channel.statsStream.listen((stats) {
      _statsController.add(EngineStats.fromJson(stats));
    });
    _vpnLogSub = channel.logsStream.listen((log) {
      ZohalLogger().fromNative(
        level: log['level']?.toString() ?? 'info',
        message: log['message']?.toString() ?? '',
        code: log['code']?.toString(),
        timestampSeconds: (log['ts'] as num?)?.toInt(),
      );
    });

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
          const EngineState(phase: ConnectionPhase.failed, errorCode: 'E220'),
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
  static final List<String> _systemSocketPaths = [
    '/run/zohal/engine.sock',
    '${Directory.systemTemp.path}/zohal/engine.sock',
  ];

  static String _userSocketPath() {
    final xdg = Platform.environment['XDG_RUNTIME_DIR'];
    if (xdg != null && xdg.isNotEmpty) {
      return '$xdg/zohal/user_engine.sock';
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/.local/share/zohal/user_engine.sock';
    }
    return '${Directory.systemTemp.path}/zohal_user/user_engine.sock';
  }

  Future<String?> _stageAppImageBinary(String srcBin) async {
    try {
      final stageDir = Directory('/tmp/zohal_stage');
      if (!await stageDir.exists()) {
        await stageDir.create(recursive: true);
        await Process.run('chmod', ['755', stageDir.path]);
      }
      final targetBin = '${stageDir.path}/zohald';
      final srcFile = File(srcBin);
      if (await srcFile.exists()) {
        await srcFile.copy(targetBin);
        await Process.run('chmod', ['755', targetBin]);
        final aetherSrc = '${srcFile.parent.path}/aether';
        if (await File(aetherSrc).exists()) {
          final aetherTarget = '${stageDir.path}/aether';
          await File(aetherSrc).copy(aetherTarget);
          await Process.run('chmod', ['755', aetherTarget]);
        }
        return targetBin;
      }
    } catch (e) {
      if (File('/tmp/zohal_stage/zohald').existsSync()) {
        return '/tmp/zohal_stage/zohald';
      }
      ZohalLogger().warn('Staging binary outside FUSE mount failed: $e');
    }
    return null;
  }

  List<String> _zohaldCandidates() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final appdir =
        Platform.environment['ZOHAL_APPDIR'] ?? Platform.environment['APPDIR'];
    return [
      if (appdir != null) '$appdir/usr/bin/zohald',
      '$exeDir/zohald',
      '$exeDir/../lib/zohal/zohald',
      '/usr/lib/zohal/zohald',
      '/usr/bin/zohald',
      '/opt/zohal/zohald',
    ];
  }

  Future<void> _initConnection() async {
    if (!(Platform.isLinux || Platform.isMacOS)) {
      _scheduleReconnect();
      return;
    }
    // 1. System service sockets.
    for (final sysPath in _systemSocketPaths) {
      if (await _tryConnect(sysPath)) return;
    }
    // 2. Per-user engine socket (AppImage/tarball without the service).
    if (await _tryConnect(_userSocketPath())) return;

    // 3. Spawn engine: ask for root for TUN, or fallback to user proxy.
    if (!_spawnAttempted) {
      _spawnAttempted = true;
      if (await _spawnEngine()) {
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          for (final sysPath in _systemSocketPaths) {
            if (await _tryConnect(sysPath)) return;
          }
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

  Future<bool> _spawnEngine() async {
    final candidates = _zohaldCandidates();
    String? binPath;
    for (final c in candidates) {
      if (File(c).existsSync()) {
        binPath = c;
        break;
      }
    }
    if (binPath == null) {
      ZohalLogger().warn('No bundled zohald binary found');
      return false;
    }

    // Attempt root privilege via pkexec on Linux for kernel TUN mode.
    // If running from AppImage (inside FUSE mount), stage binaries to /tmp/zohal_stage
    // so pkexec/root has direct access outside FUSE restrictions.
    final appdir =
        Platform.environment['ZOHAL_APPDIR'] ?? Platform.environment['APPDIR'];
    if (Platform.isLinux) {
      String runBin = binPath;
      if (File('/usr/lib/zohal/zohald').existsSync()) {
        runBin = '/usr/lib/zohal/zohald';
      } else if (appdir != null) {
        final staged = await _stageAppImageBinary(binPath);
        if (staged != null) runBin = staged;
      }

      try {
        final whichPkexec = await Process.run('which', ['pkexec']);
        if (whichPkexec.exitCode == 0) {
          ZohalLogger().info(
            'Requesting root privileges via pkexec for TUN engine',
          );
          await Process.start(
              'pkexec',
              [
                'env',
                '-i',
                'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin',
                runBin,
                'service',
              ],
              mode: ProcessStartMode.detached);
          for (var i = 0; i < 15; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            for (final sysPath in _systemSocketPaths) {
              if (await _tryConnect(sysPath)) {
                ZohalLogger().info('Connected to root TUN engine at $sysPath');
                return true;
              }
            }
          }
        }
      } catch (e) {
        ZohalLogger().debug('pkexec attempt skipped or failed: $e');
      }
    }

    // Fallback: spawn unprivileged user proxy engine (100% works without root)
    ZohalLogger().info('Falling back to user proxy engine: $binPath user');
    try {
      await Process.start(
        binPath,
        ['user'],
        mode: ProcessStartMode.detached,
        runInShell: false,
        environment: {
          ...Platform.environment,
          if (appdir != null) 'ZOHAL_APPDIR': appdir,
          if (appdir != null) 'APPDIR': appdir,
        },
      );
      return true;
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

    // Request current state immediately so UI reflects engine's real state
    final getState = jsonEncode({'t': 'get_state'});
    _socket?.writeln(getState);

    // Flush any pending commands buffered while disconnected
    while (_pendingMessages.isNotEmpty) {
      final msg = _pendingMessages.removeAt(0);
      _socket?.writeln(msg);
    }

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
          final level =
              json['level']?.toString() ?? (code == null ? 'info' : 'warn');
          ZohalLogger().fromNative(
            level: level,
            message: msg,
            code: code,
            timestampSeconds: (json['ts'] as num?)?.toInt(),
          );
          break;
        case 'hello':
          // Server handshake reply — ignore
          break;
        case 'pong':
          // Server pong — ignore
          break;
        case 'notice':
          // Server notice
          break;
        case 'error':
          ZohalLogger().warn('IPC server error: ${json["msg"]}');
          break;
        case 'diagnostics':
          // Diagnostic export — log receipt
          ZohalLogger().info('Diagnostic data received');
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
    } else {
      _pendingMessages.add(payload);
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
    _vpnLogSub?.cancel();
    _socket?.destroy();
    _stateController.close();
    _statsController.close();
    _settingsController.close();
  }
}
