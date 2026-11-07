// core/proxy_runner.dart
// Connection execution manager for custom VLESS and VMess nodes.
// Bridges directly to zohald IPC with real SOCKS5 TUN routing and clean teardown.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bridge.dart';
import 'engine_state.dart';
import 'proxy_models.dart';

final customProxyRunnerProvider = Provider<CustomProxyRunner>((ref) {
  return CustomProxyRunner(ref);
});

class CustomProxyRunner {
  final Ref ref;

  CustomProxyRunner(this.ref);

  bool get isConnected {
    final state = ref.read(engineStateProvider);
    return state.phase == ConnectionPhase.connected;
  }

  Future<void> connect(ProxyNode node) async {
    final notifier = ref.read(engineStateProvider.notifier);

    // Map ProxyNode to CustomNodeConfig JSON
    final customConfig = <String, dynamic>{
      'protocol': node.protocol.name,
      'server': node.server,
      'port': node.port,
      'uuid': node.metadata['uuid'] ?? '',
      if (node.metadata['security'] != null)
        'security': node.metadata['security'],
      if (node.metadata['sni'] != null) 'sni': node.metadata['sni'],
      if (node.metadata['type'] != null || node.metadata['net'] != null)
        'transport': node.metadata['type'] ?? node.metadata['net'],
      if (node.metadata['path'] != null) 'path': node.metadata['path'],
      if (node.metadata['fp'] != null) 'fingerprint': node.metadata['fp'],
      if (node.metadata['pbk'] != null) 'public_key': node.metadata['pbk'],
      if (node.metadata['sid'] != null) 'short_id': node.metadata['sid'],
      if (node.metadata['flow'] != null) 'flow': node.metadata['flow'],
    };

    final modeJson = <String, dynamic>{
      'Custom': customConfig,
    };

    // Forward desired state and mode to daemon
    notifier.setDesired(true, mode: modeJson);
  }

  Future<void> disconnect() async {
    final notifier = ref.read(engineStateProvider.notifier);
    notifier.setDesired(false);
    notifier.setCustomProxyState(
      const EngineState(
        phase: ConnectionPhase.idle,
        stage: ConnectionStage.none,
        desiredUp: false,
      ),
    );
  }
}
