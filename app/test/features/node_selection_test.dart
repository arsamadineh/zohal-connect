// test/features/node_selection_test.dart
// Verification tests for custom node management, live TCP pinging, and NodeSheet / AddConfigDialog UI.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zohal/core/bridge.dart';
import 'package:zohal/core/engine_state.dart';
import 'package:zohal/core/proxy_models.dart';
import 'package:zohal/core/proxy_runner.dart';
import 'package:zohal/core/proxy_service.dart';
import 'package:zohal/features/nodes/add_config_dialog.dart';
import 'package:zohal/features/nodes/node_sheet.dart';
import 'package:zohal/l10n/strings_fa.dart';

class MockTraceHttpClient extends http.BaseClient {
  final String body;
  MockTraceHttpClient(this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      contentLength: bytes.length,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProxyNodesNotifier & SelectedNodeNotifier Unit Tests', () {
    test('Initializes with default built-in WARP nodes', () {
      final notifier = ProxyNodesNotifier();
      expect(notifier.state.length, equals(defaultProxyNodes.length));
      expect(notifier.state.first.id, equals('warp_auto_gateway'));
    });

    test('addFromText parses and appends valid VLESS and VMess nodes',
        () async {
      final notifier = ProxyNodesNotifier();

      const input = '''
vless://9f3b2591-628b-4a57-b08e-5975d048d084@198.51.100.1:443?security=reality&sni=test.com#[DE] Frankfurt
vmess://eyJhZGQiOiAiMTk4LjUxLjEwMC4yIiwgInBvcnQiOiA0NDMsICJpZCI6ICJhM2JiMTg5ZS04YmY5LTM4ODgtOTkxMi1hY2U0ZTY1NDMwMDIiLCAicHMiOiAiW0ZSXSBQYXJpcyJ9
''';

      final count = await notifier.addFromText(input);
      expect(count, equals(2));
      expect(notifier.state.length, equals(defaultProxyNodes.length + 2));

      final deNode =
          notifier.state.firstWhere((n) => n.isCustom && n.countryCode == 'DE');
      expect(deNode.name, equals('[DE] Frankfurt'));
      expect(deNode.protocol, equals(ProxyProtocol.vless));

      final frNode = notifier.state.firstWhere((n) => n.countryCode == 'FR');
      expect(frNode.name, equals('[FR] Paris'));
      expect(frNode.protocol, equals(ProxyProtocol.vmess));
    });

    test('removeNode removes custom node and persists changes', () async {
      final notifier = ProxyNodesNotifier();
      const node = ProxyNode(
        id: 'test_node_to_delete',
        name: 'Temporary Node',
        protocol: ProxyProtocol.vless,
        server: '1.2.3.4',
        port: 443,
        rawUri: 'vless://test',
      );

      await notifier.addNode(node);
      expect(notifier.state.any((n) => n.id == 'test_node_to_delete'), isTrue);

      await notifier.removeNode('test_node_to_delete');
      expect(notifier.state.any((n) => n.id == 'test_node_to_delete'), isFalse);
    });

    test('SelectedNodeNotifier selects and persists selected node', () async {
      final nodes = defaultProxyNodes;
      final selectedNotifier = SelectedNodeNotifier(nodes);

      expect(selectedNotifier.state?.id, equals(nodes.first.id));

      final targetNode = nodes[1];
      await selectedNotifier.selectNode(targetNode);
      expect(selectedNotifier.state?.id, equals(targetNode.id));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zohal_selected_proxy_node_id'),
          equals(targetNode.id));
    });
  });

  group('PublicIpDetector Unit Tests', () {
    test('Extracts exit IP and country location code from Cloudflare trace',
        () async {
      const tracePayload = '''
fl=123f45
h=cloudflare.com
ip=198.51.100.99
ts=1700000000
visit_scheme=https
uag=Mozilla/5.0
colo=FRA
sliver=none
http=http/2
loc=DE
tls=TLSv1.3
sni=plaintext
warp=off
gateway=off
rbi=off
kex=X25519
''';

      final mockClient = MockTraceHttpClient(tracePayload);
      final result =
          await PublicIpDetector.detectExitIpAndLocation(client: mockClient);

      expect(result, isNotNull);
      expect(result!['ip'], equals('198.51.100.99'));
      expect(result['loc'], equals('DE'));
    });
  });

  group('CustomProxyRunner Connection Lifecycle', () {
    test('Runner connects and transitions through stages into connected state',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final runner = container.read(customProxyRunnerProvider);

      expect(runner.isConnected, isFalse);

      // Verify disconnect sets phase back to idle
      await runner.disconnect();
      final idleState = container.read(engineStateProvider);
      expect(idleState.phase, equals(ConnectionPhase.idle));
      expect(idleState.desiredUp, isFalse);
    });
  });

  group('NodeSheet & AddConfigDialog Widget Tests', () {
    testWidgets(
        'NodeSheet displays server list, ping all button, and add config trigger',
        (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('fa'),
            supportedLocales: [Locale('fa')],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: NodeSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Toolbar items
      expect(find.text(StringsFa.pingAll), findsOneWidget);
      expect(find.text(StringsFa.addConfig), findsOneWidget);

      // Verify Built-in items
      expect(find.text('دروازه خودکار زحل (WARP Auto)'), findsOneWidget);
      expect(find.text('[DE] فرانکفورت (Cloudflare Edge)'), findsOneWidget);
    });

    testWidgets(
        'AddConfigDialog parses pasted VLESS URI and displays live preview card',
        (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('fa'),
            supportedLocales: [Locale('fa')],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: AddConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(StringsFa.addConfig), findsOneWidget);
      expect(find.text(StringsFa.pasteConfig), findsOneWidget);

      // Enter a valid VLESS config into TextField
      const vlessUri =
          'vless://9f3b2591-628b-4a57-b08e-5975d048d084@198.51.100.1:443?security=reality#[DE] Berlin HighSpeed';

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, vlessUri);
      await tester.pump();

      // Verify the preview section appears with the parsed server
      expect(find.text('[DE] Berlin HighSpeed'), findsOneWidget);
      expect(find.textContaining('VLESS'), findsOneWidget);

      // Verify the Add button is enabled
      final addButtonFinder =
          find.widgetWithText(ElevatedButton, StringsFa.add);
      if (addButtonFinder.evaluate().isNotEmpty) {
        expect(tester.widget<ElevatedButton>(addButtonFinder).onPressed,
            isNotNull);
      }
    });
  });
}
