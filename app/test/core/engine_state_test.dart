// test/core/engine_state_test.dart
// Tests for EngineState, EngineStats, and ZohalSettings JSON deserialization.

import 'package:flutter_test/flutter_test.dart';
import 'package:zohal/core/engine_state.dart';
import 'package:zohal/core/settings.dart';

void main() {
  group('EngineState JSON parsing', () {
    test('parses flat engine state json correctly', () {
      final json = {
        'phase': 'Connected',
        'stage': 'VerifyPath',
        'desired': 'up',
        'epoch': 5,
        'transport': 'Masque2',
        'rung': 1,
        'exit_loc': 'de',
        'exit_ip': '1.2.3.4',
        'since_unix': 1700000000,
      };

      final state = EngineState.fromJson(json);
      expect(state.phase, ConnectionPhase.connected);
      expect(state.stage, ConnectionStage.verifyPath);
      expect(state.desiredUp, isTrue);
      expect(state.epoch, 5);
      expect(state.transport, TransportKind.masque2);
      expect(state.rung, 1);
      expect(state.exitLoc, 'de');
      expect(state.exitIp, '1.2.3.4');
      expect(state.sinceUnix, 1700000000);
    });

    test('parses wrapped IPC server message format (t: state, state: {...})',
        () {
      final json = {
        't': 'state',
        'state': {
          'phase': 'Connecting',
          'stage': 'FindGateway',
          'desired': {'intent': 'Up', 'epoch': 8},
          'transport': 'Masque3',
          'rung': 2,
          'attempt': 1,
          'exit_loc': 'nl',
        },
      };

      final state = EngineState.fromJson(json);
      expect(state.phase, ConnectionPhase.connecting);
      expect(state.stage, ConnectionStage.findGateway);
      expect(state.desiredUp, isTrue);
      expect(state.epoch, 8);
      expect(state.transport, TransportKind.masque3);
      expect(state.rung, 2);
      expect(state.exitLoc, 'nl');
    });

    test('parses desired intent Down', () {
      final json = {
        't': 'state',
        'state': {
          'phase': 'Idle',
          'stage': 'None',
          'desired': {'intent': 'Down', 'epoch': 9},
        },
      };

      final state = EngineState.fromJson(json);
      expect(state.phase, ConnectionPhase.idle);
      expect(state.stage, ConnectionStage.none);
      expect(state.desiredUp, isFalse);
      expect(state.epoch, 9);
    });
  });

  group('EngineStats JSON parsing', () {
    test('parses wrapped and unwrapped traffic stats', () {
      final flat = {
        'rx_bps': 1024,
        'tx_bps': 512,
        'rx_total': 2048,
        'tx_total': 1024,
      };
      final stats1 = EngineStats.fromJson(flat);
      expect(stats1.rxBps, 1024);
      expect(stats1.txBps, 512);

      final wrapped = {
        't': 'stats',
        'stats': {
          'rx_bps': 4096,
          'tx_bps': 2048,
          'rx_total': 8192,
          'tx_total': 4096,
        },
      };
      final stats2 = EngineStats.fromJson(wrapped);
      expect(stats2.rxBps, 4096);
      expect(stats2.txBps, 2048);
    });
  });

  group('ZohalSettings JSON parsing', () {
    test('parses wrapped settings server message', () {
      final json = {
        't': 'settings',
        'settings': {
          'connection_mode': 'masque2',
          'scope': 'SystemProxy',
          'kill_switch': false,
          'minimize_to_tray': true,
        },
      };

      final settings = ZohalSettings.fromJson(json);
      expect(settings.connectionMode, ConnectionMode.masque2);
      expect(settings.scope, 'SystemProxy');
      expect(settings.killSwitch, isFalse);
      expect(settings.minimizeToTray, isTrue);
    });

    test('parses PascalCase connection modes serialized by Rust daemon', () {
      final rustModes = {
        'Masque3': ConnectionMode.masque3,
        'Masque2': ConnectionMode.masque2,
        'WireGuard': ConnectionMode.wireguard,
        'Gool': ConnectionMode.gool,
        'Auto': ConnectionMode.auto,
      };

      for (final entry in rustModes.entries) {
        final json = {
          'settings': {
            'connection_mode': entry.key,
          },
        };
        final parsed = ZohalSettings.fromJson(json);
        expect(
          parsed.connectionMode,
          entry.value,
          reason: 'Failed to parse Rust mode: ${entry.key}',
        );
      }
    });

    test('parses case-insensitive phase, stage, and transport from any source',
        () {
      final state1 = EngineState.fromJson({
        'phase': 'connected',
        'stage': 'buildtunnel',
        'transport': 'wireguard',
      });
      expect(state1.phase, ConnectionPhase.connected);
      expect(state1.stage, ConnectionStage.buildTunnel);
      expect(state1.transport, TransportKind.wireguard);

      final state2 = EngineState.fromJson({
        'phase': 'PREPARING',
        'stage': 'FINDGATEWAY',
        'transport': 'MASQUE3',
      });
      expect(state2.phase, ConnectionPhase.preparing);
      expect(state2.stage, ConnectionStage.findGateway);
      expect(state2.transport, TransportKind.masque3);
    });

    test('serializes and deserializes IpVersion and DNS servers roundtrip', () {
      const s = ZohalSettings(
        connectionMode: ConnectionMode.wireguard,
        ipVersion: IpVersion.v6,
        dnsServers: ['1.1.1.1', '2606:4700:4700::1111'],
        smartDomesticDirect: false,
        lanDirect: false,
        fragment: true,
        killSwitch: true,
      );

      final json = s.toJson();
      expect(json['connection_mode'], 'WireGuard');
      expect(json['ip_version'], 'V6');
      expect(json['dns_servers'], ['1.1.1.1', '2606:4700:4700::1111']);
      expect(json['routing.smart_domestic_direct'], false);
      expect(json['routing.lan_direct'], false);
      expect(json['advanced.fragment'], true);

      final decoded = ZohalSettings.fromJson(json);
      expect(decoded.connectionMode, ConnectionMode.wireguard);
      expect(decoded.ipVersion, IpVersion.v6);
      expect(decoded.dnsServers, ['1.1.1.1', '2606:4700:4700::1111']);
      expect(decoded.smartDomesticDirect, false);
      expect(decoded.lanDirect, false);
      expect(decoded.fragment, true);
      expect(decoded.killSwitch, true);
    });
  });
}
