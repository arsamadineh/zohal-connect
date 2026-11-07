// core/proxy_service.dart
// Node management, TCP handshake ping testing, and exit IP detection for Zohal Connect.
// Strict ZOHAL_SPEC: zero telemetry, resilient state management, full Persian numbers.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';
import 'proxy_models.dart';

const String _prefCustomNodes = 'zohal_custom_proxy_nodes';
const String _prefSelectedNodeId = 'zohal_selected_proxy_node_id';

/// Default built-in Cloudflare WARP and Edge gateways
final List<ProxyNode> defaultProxyNodes = [
  const ProxyNode(
    id: 'warp_auto_gateway',
    name: 'دروازه خودکار زحل (WARP Auto)',
    protocol: ProxyProtocol.warp,
    server: 'engage.cloudflareclient.com',
    port: 2408,
    rawUri: 'warp://engage.cloudflareclient.com:2408#دروازه خودکار زحل',
    countryCode: 'UN',
  ),
  const ProxyNode(
    id: 'warp_frankfurt_de',
    name: '[DE] فرانکفورت (Cloudflare Edge)',
    protocol: ProxyProtocol.warp,
    server: '162.159.192.1',
    port: 2408,
    rawUri: 'warp://162.159.192.1:2408#[DE] فرانکفورت',
    countryCode: 'DE',
  ),
  const ProxyNode(
    id: 'warp_amsterdam_nl',
    name: '[NL] آمستردام (Cloudflare Edge)',
    protocol: ProxyProtocol.warp,
    server: '162.159.193.1',
    port: 2408,
    rawUri: 'warp://162.159.193.1:2408#[NL] آمستردام',
    countryCode: 'NL',
  ),
  const ProxyNode(
    id: 'warp_helsinki_fi',
    name: '[FI] هلسینکی (Cloudflare Edge)',
    protocol: ProxyProtocol.warp,
    server: '162.159.195.1',
    port: 2408,
    rawUri: 'warp://162.159.195.1:2408#[FI] هلسینکی',
    countryCode: 'FI',
  ),
];

// Riverpod Providers
final proxyNodesProvider =
    StateNotifierProvider<ProxyNodesNotifier, List<ProxyNode>>((ref) {
  return ProxyNodesNotifier();
});

final selectedNodeProvider =
    StateNotifierProvider<SelectedNodeNotifier, ProxyNode?>((ref) {
  final nodes = ref.watch(proxyNodesProvider);
  return SelectedNodeNotifier(nodes);
});

class ProxyNodesNotifier extends StateNotifier<List<ProxyNode>> {
  ProxyNodesNotifier() : super(defaultProxyNodes) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_prefCustomNodes);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as List<dynamic>;
        final customNodes = decoded
            .map((item) => ProxyNode.fromJson(item as Map<String, dynamic>))
            .where((n) => n.id.isNotEmpty && n.server.isNotEmpty)
            .toList();

        state = [...defaultProxyNodes, ...customNodes];
      }
    } catch (e) {
      ZohalLogger().debug('Failed to load custom proxy nodes: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customNodes = state.where((n) => n.isCustom).toList();
      final rawJson = jsonEncode(customNodes.map((n) => n.toJson()).toList());
      await prefs.setString(_prefCustomNodes, rawJson);
    } catch (e) {
      ZohalLogger().debug('Failed to save custom proxy nodes: $e');
    }
  }

  Future<int> addFromText(String text) async {
    final parsed = ProxyParser.parseAll(text);
    if (parsed.isEmpty) return 0;

    final existingIds = state.map((n) => n.id).toSet();
    final toAdd = parsed.where((n) => !existingIds.contains(n.id)).toList();

    if (toAdd.isNotEmpty) {
      state = [...state, ...toAdd];
      await _saveToStorage();
    }
    return toAdd.length;
  }

  Future<void> addNode(ProxyNode node) async {
    state = [...state.where((n) => n.id != node.id), node];
    await _saveToStorage();
  }

  Future<void> removeNode(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _saveToStorage();
  }

  Future<int?> pingNode(String id) async {
    final index = state.indexWhere((n) => n.id == id);
    if (index == -1) return null;

    final node = state[index];
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(isTesting: true) else state[i]
    ];

    final latency = await measureTcpPing(node.server, node.port);

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(
            latencyMs: () => latency,
            isTesting: false,
          )
        else
          state[i]
    ];

    return latency;
  }

  Future<void> pingAllNodes() async {
    state = [for (final n in state) n.copyWith(isTesting: true)];

    // Concurrently ping with max 6 workers
    final queue = List<ProxyNode>.from(state);
    const workerCount = 6;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final node = queue.removeLast();
        final latency = await measureTcpPing(node.server, node.port);
        state = [
          for (final n in state)
            if (n.id == node.id)
              n.copyWith(
                latencyMs: () => latency,
                isTesting: false,
              )
            else
              n
        ];
      }
    }

    await Future.wait(
      List.generate(
        workerCount.clamp(1, state.length),
        (_) => worker(),
      ),
    );
  }

  static Future<int?> measureTcpPing(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1; // Unreachable / Timeout
    }
  }
}

class SelectedNodeNotifier extends StateNotifier<ProxyNode?> {
  final List<ProxyNode> availableNodes;

  SelectedNodeNotifier(this.availableNodes)
      : super(availableNodes.isNotEmpty ? availableNodes.first : null) {
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString(_prefSelectedNodeId);
      if (selectedId != null) {
        final match = availableNodes.firstWhere(
          (n) => n.id == selectedId,
          orElse: () => availableNodes.first,
        );
        state = match;
        return;
      }
    } catch (_) {}

    if (availableNodes.isNotEmpty) {
      state = availableNodes.first;
    }
  }

  Future<void> selectNode(ProxyNode node) async {
    state = node;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSelectedNodeId, node.id);
    } catch (_) {}
  }
}

/// Discovers verified public exit IP and ISO country code using external CDN traces.
class PublicIpDetector {
  PublicIpDetector._();

  static Future<Map<String, String>?> detectExitIpAndLocation({
    Duration timeout = const Duration(seconds: 4),
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      // 1. Try Cloudflare trace (provides both IPv4/v6 and 2-letter country code)
      final traceUri = Uri.parse('https://cloudflare.com/cdn-cgi/trace');
      final res = await httpClient.get(traceUri).timeout(timeout);

      if (res.statusCode == 200) {
        String? ip;
        String? loc;
        for (final line in res.body.split('\n')) {
          if (line.startsWith('ip=')) {
            ip = line.substring(3).trim();
          } else if (line.startsWith('loc=')) {
            loc = line.substring(4).trim().toUpperCase();
          }
        }
        if (ip != null && ip.isNotEmpty) {
          return {
            'ip': ip,
            'loc': loc ?? 'UN',
          };
        }
      }
    } catch (_) {
      // 2. Fallback to ipify JSON API
      try {
        final ipifyUri = Uri.parse('https://api.ipify.org?format=json');
        final res2 = await httpClient.get(ipifyUri).timeout(timeout);
        if (res2.statusCode == 200) {
          final json = jsonDecode(res2.body) as Map<String, dynamic>;
          final ip = json['ip'] as String?;
          if (ip != null && ip.isNotEmpty) {
            return {
              'ip': ip,
              'loc': 'UN',
            };
          }
        }
      } catch (_) {}
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
    return null;
  }
}
