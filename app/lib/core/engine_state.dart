// core/engine_state.dart
// Typed representation of the Zohal Engine state and stats according to ZOHAL_SPEC Section 6.5.

enum ConnectionPhase {
  idle,
  preparing,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  failed,
}

enum ConnectionStage { none, prepare, findGateway, buildTunnel, verifyPath }

enum TransportKind {
  none,
  masque3,
  masque2,
  wireguard,
  goolMasque,
  goolClassic,
}

enum ConnectionScope { tun, systemProxy }

class EngineState {
  final ConnectionPhase phase;
  final ConnectionStage stage;
  final bool desiredUp;
  final int epoch;
  final TransportKind transport;
  final int rung;
  final int attempt;
  final String? gateway;
  final String? exitIp;
  final String? exitLoc;
  final String? colo;
  final int? sinceUnix;
  final String? errorCode;
  final int failStreak;
  final ConnectionScope scope;
  final bool killSwitchEngaged;

  const EngineState({
    this.phase = ConnectionPhase.idle,
    this.stage = ConnectionStage.none,
    this.desiredUp = false,
    this.epoch = 0,
    this.transport = TransportKind.none,
    this.rung = 0,
    this.attempt = 0,
    this.gateway,
    this.exitIp,
    this.exitLoc,
    this.colo,
    this.sinceUnix,
    this.errorCode,
    this.failStreak = 0,
    this.scope = ConnectionScope.tun,
    this.killSwitchEngaged = true,
  });

  factory EngineState.fromJson(Map<String, dynamic> json) {
    ConnectionPhase parsePhase(String? val) {
      switch (val) {
        case 'Preparing':
          return ConnectionPhase.preparing;
        case 'Connecting':
          return ConnectionPhase.connecting;
        case 'Connected':
          return ConnectionPhase.connected;
        case 'Reconnecting':
          return ConnectionPhase.reconnecting;
        case 'Disconnecting':
          return ConnectionPhase.disconnecting;
        case 'Failed':
          return ConnectionPhase.failed;
        default:
          return ConnectionPhase.idle;
      }
    }

    ConnectionStage parseStage(String? val) {
      switch (val) {
        case 'Prepare':
          return ConnectionStage.prepare;
        case 'FindGateway':
          return ConnectionStage.findGateway;
        case 'BuildTunnel':
          return ConnectionStage.buildTunnel;
        case 'VerifyPath':
          return ConnectionStage.verifyPath;
        default:
          return ConnectionStage.none;
      }
    }

    TransportKind parseTransport(String? val) {
      switch (val) {
        case 'Masque3':
          return TransportKind.masque3;
        case 'Masque2':
          return TransportKind.masque2;
        case 'WireGuard':
          return TransportKind.wireguard;
        case 'GoolMasque':
          return TransportKind.goolMasque;
        case 'GoolClassic':
          return TransportKind.goolClassic;
        default:
          return TransportKind.none;
      }
    }

    return EngineState(
      phase: parsePhase(json['phase'] as String?),
      stage: parseStage(json['stage'] as String?),
      desiredUp: json['desired'] == 'up' || json['desired'] == true,
      epoch: (json['epoch'] as num?)?.toInt() ?? 0,
      transport: parseTransport(json['transport'] as String?),
      rung: (json['rung'] as num?)?.toInt() ?? 0,
      attempt: (json['attempt'] as num?)?.toInt() ?? 0,
      gateway: json['gateway'] as String?,
      exitIp: json['exit_ip'] as String?,
      exitLoc: json['exit_loc'] as String?,
      colo: json['colo'] as String?,
      sinceUnix: (json['since_unix'] as num?)?.toInt(),
      errorCode: json['error'] as String?,
      failStreak: (json['fail_streak'] as num?)?.toInt() ?? 0,
      scope: json['scope'] == 'SystemProxy'
          ? ConnectionScope.systemProxy
          : ConnectionScope.tun,
      killSwitchEngaged: json['kill_switch_engaged'] as bool? ?? true,
    );
  }
}

class EngineStats {
  final int rxBps;
  final int txBps;
  final int rxTotal;
  final int txTotal;

  const EngineStats({
    this.rxBps = 0,
    this.txBps = 0,
    this.rxTotal = 0,
    this.txTotal = 0,
  });

  factory EngineStats.fromJson(Map<String, dynamic> json) {
    return EngineStats(
      rxBps: (json['rx_bps'] as num?)?.toInt() ?? 0,
      txBps: (json['tx_bps'] as num?)?.toInt() ?? 0,
      rxTotal: (json['rx_total'] as num?)?.toInt() ?? 0,
      txTotal: (json['tx_total'] as num?)?.toInt() ?? 0,
    );
  }
}
