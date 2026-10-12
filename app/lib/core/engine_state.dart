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
    final state = json['state'] is Map<String, dynamic>
        ? json['state'] as Map<String, dynamic>
        : json;

    ConnectionPhase parsePhase(String? val) {
      switch (val?.toLowerCase()) {
        case 'preparing':
          return ConnectionPhase.preparing;
        case 'connecting':
          return ConnectionPhase.connecting;
        case 'connected':
          return ConnectionPhase.connected;
        case 'reconnecting':
          return ConnectionPhase.reconnecting;
        case 'disconnecting':
          return ConnectionPhase.disconnecting;
        case 'failed':
          return ConnectionPhase.failed;
        default:
          return ConnectionPhase.idle;
      }
    }

    ConnectionStage parseStage(String? val) {
      switch (val?.toLowerCase()) {
        case 'prepare':
          return ConnectionStage.prepare;
        case 'findgateway':
          return ConnectionStage.findGateway;
        case 'buildtunnel':
          return ConnectionStage.buildTunnel;
        case 'verifypath':
          return ConnectionStage.verifyPath;
        default:
          return ConnectionStage.none;
      }
    }

    TransportKind parseTransport(String? val) {
      switch (val?.toLowerCase()) {
        case 'masque3':
          return TransportKind.masque3;
        case 'masque2':
          return TransportKind.masque2;
        case 'wireguard':
          return TransportKind.wireguard;
        case 'goolmasque':
          return TransportKind.goolMasque;
        case 'goolclassic':
          return TransportKind.goolClassic;
        default:
          return TransportKind.none;
      }
    }

    final desired = state['desired'];
    final bool desiredUp = desired == 'up' ||
        desired == true ||
        (desired is Map &&
            (desired['intent'] == 'Up' || desired['intent'] == 'up'));

    final int epoch = (state['epoch'] as num?)?.toInt() ??
        (desired is Map ? (desired['epoch'] as num?)?.toInt() ?? 0 : 0);

    return EngineState(
      phase: parsePhase(state['phase'] as String?),
      stage: parseStage(state['stage'] as String?),
      desiredUp: desiredUp,
      epoch: epoch,
      transport: parseTransport(state['transport'] as String?),
      rung: (state['rung'] as num?)?.toInt() ?? 0,
      attempt: (state['attempt'] as num?)?.toInt() ?? 0,
      gateway: state['gateway'] as String?,
      exitIp: state['exit_ip'] as String?,
      exitLoc: state['exit_loc'] as String?,
      colo: state['colo'] as String?,
      sinceUnix: (state['since_unix'] as num?)?.toInt(),
      errorCode: state['error'] as String?,
      failStreak: (state['fail_streak'] as num?)?.toInt() ?? 0,
      scope: state['scope'] == 'SystemProxy'
          ? ConnectionScope.systemProxy
          : ConnectionScope.tun,
      killSwitchEngaged: state['kill_switch_engaged'] as bool? ?? true,
    );
  }

  EngineState copyWith({
    ConnectionPhase? phase,
    ConnectionStage? stage,
    bool? desiredUp,
    int? epoch,
    TransportKind? transport,
    int? rung,
    int? attempt,
    String? Function()? gateway,
    String? Function()? exitIp,
    String? Function()? exitLoc,
    String? Function()? colo,
    int? Function()? sinceUnix,
    String? Function()? errorCode,
    int? failStreak,
    ConnectionScope? scope,
    bool? killSwitchEngaged,
  }) {
    return EngineState(
      phase: phase ?? this.phase,
      stage: stage ?? this.stage,
      desiredUp: desiredUp ?? this.desiredUp,
      epoch: epoch ?? this.epoch,
      transport: transport ?? this.transport,
      rung: rung ?? this.rung,
      attempt: attempt ?? this.attempt,
      gateway: gateway != null ? gateway() : this.gateway,
      exitIp: exitIp != null ? exitIp() : this.exitIp,
      exitLoc: exitLoc != null ? exitLoc() : this.exitLoc,
      colo: colo != null ? colo() : this.colo,
      sinceUnix: sinceUnix != null ? sinceUnix() : this.sinceUnix,
      errorCode: errorCode != null ? errorCode() : this.errorCode,
      failStreak: failStreak ?? this.failStreak,
      scope: scope ?? this.scope,
      killSwitchEngaged: killSwitchEngaged ?? this.killSwitchEngaged,
    );
  }

  static ConnectionPhase _vpnPhase(String val) {
    switch (val) {
      case 'preparing':
        return ConnectionPhase.preparing;
      case 'connecting':
        return ConnectionPhase.connecting;
      case 'connected':
        return ConnectionPhase.connected;
      case 'reconnecting':
        return ConnectionPhase.reconnecting;
      case 'disconnecting':
        return ConnectionPhase.disconnecting;
      case 'failed':
        return ConnectionPhase.failed;
      default:
        return ConnectionPhase.idle;
    }
  }

  static ConnectionStage _vpnStage(String val) {
    switch (val) {
      case 'prepare':
        return ConnectionStage.prepare;
      case 'findGateway':
        return ConnectionStage.findGateway;
      case 'buildTunnel':
        return ConnectionStage.buildTunnel;
      case 'verifyPath':
        return ConnectionStage.verifyPath;
      default:
        return ConnectionStage.none;
    }
  }

  factory EngineState.fromVpnMap(Map<String, dynamic> map) {
    return EngineState(
      phase: _vpnPhase(map['phase'] as String? ?? 'idle'),
      stage: _vpnStage(map['stage'] as String? ?? 'none'),
      desiredUp: map['phase'] != 'idle' && map['phase'] != 'failed',
      epoch: (map['epoch'] as num?)?.toInt() ?? 0,
      exitIp: map['exitIp'] as String?,
      exitLoc: map['exitLoc'] as String?,
      sinceUnix: (map['sinceUnix'] as num?)?.toInt(),
      errorCode: map['error'] as String?,
      scope: ConnectionScope.tun,
      killSwitchEngaged: true,
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
    final stats = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : json;
    return EngineStats(
      rxBps: ((stats['rx_bps'] ?? stats['rxBps']) as num?)?.toInt() ?? 0,
      txBps: ((stats['tx_bps'] ?? stats['txBps']) as num?)?.toInt() ?? 0,
      rxTotal:
          ((stats['rx_total'] ?? stats['rxTotal'] ?? stats['rx_bytes']) as num?)
                  ?.toInt() ??
              0,
      txTotal:
          ((stats['tx_total'] ?? stats['txTotal'] ?? stats['tx_bytes']) as num?)
                  ?.toInt() ??
              0,
    );
  }
}
