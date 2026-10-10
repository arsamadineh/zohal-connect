// core/vpn_channel.dart
// Android VPN control channel for Zohal Connect.
// The Dart engine bridge cannot reach a Unix socket on Android: the engine
// lives in the `:vpn` process. All control goes through this MethodChannel
// to MainActivity/ZohalVpnService, and state comes back on the EventChannel.
// On other platforms every call is a silent no-op.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class VpnNativeState {
  final String phase;
  final String stage;
  final String? error;
  final String? exitIp;
  final String? exitLoc;
  final int? sinceUnix;
  final int? rxBps;
  final int? txBps;
  final int? rxTotal;
  final int? txTotal;

  const VpnNativeState({
    required this.phase,
    this.stage = 'none',
    this.error,
    this.exitIp,
    this.exitLoc,
    this.sinceUnix,
    this.rxBps,
    this.txBps,
    this.rxTotal,
    this.txTotal,
  });

  factory VpnNativeState.fromMap(Map<dynamic, dynamic> map) {
    return VpnNativeState(
      phase: map['phase'] as String? ?? 'idle',
      stage: map['stage'] as String? ?? 'none',
      error: map['error'] as String?,
      exitIp: map['exitIp'] as String?,
      exitLoc: map['exitLoc'] as String?,
      sinceUnix: (map['sinceUnix'] as num?)?.toInt(),
      rxBps: (map['rxBps'] as num?)?.toInt(),
      txBps: (map['txBps'] as num?)?.toInt(),
      rxTotal: (map['rxTotal'] as num?)?.toInt(),
      txTotal: (map['txTotal'] as num?)?.toInt(),
    );
  }
}

class VpnChannel {
  static const MethodChannel _methods = MethodChannel(
    'app.zohal.connect/vpn',
  );
  static const EventChannel _events = EventChannel(
    'app.zohal.connect/vpn_state',
  );

  static bool get isSupported => Platform.isAndroid;

  Stream<VpnNativeState>? _stateStream;

  Stream<VpnNativeState> get stateStream {
    _stateStream ??= _events.receiveBroadcastStream().map((event) {
      if (event is Map) return VpnNativeState.fromMap(event);
      return const VpnNativeState(phase: 'idle');
    });
    return _stateStream!;
  }

  Future<bool> prepare() async {
    if (!isSupported) return false;
    try {
      final granted = await _methods.invokeMethod<bool>('prepareVpn');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> start(Map<String, dynamic> config) async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('startVpn', config);
  }

  Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _methods.invokeMethod<void>('stopVpn');
    } on PlatformException {
      // Service already gone; treated as stopped.
    }
  }

  Future<String> currentState() async {
    if (!isSupported) return 'idle';
    try {
      final state = await _methods.invokeMethod<String>('vpnState');
      return state ?? 'idle';
    } on PlatformException {
      return 'idle';
    }
  }
}
