// test/features/connect_control_test.dart
// Component tests for ConnectControl.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/engine_state.dart';
import '../../lib/design/components/connect_control.dart';
import '../../lib/l10n/strings_fa.dart';

void main() {
  testWidgets('ConnectControl displays idle state with correct semantics', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConnectControl(
              phase: ConnectionPhase.idle,
              stage: ConnectionStage.none,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    // Verify semantics
    expect(find.bySemanticsLabel(StringsFa.stateIdle), findsOneWidget);

    // Tap the control
    await tester.tap(find.byType(ConnectControl));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('ConnectControl reflects connected phase semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConnectControl(
              phase: ConnectionPhase.connected,
              stage: ConnectionStage.none,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(StringsFa.stateConnected), findsOneWidget);
  });

  testWidgets('ConnectControl reflects connecting stage semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConnectControl(
              phase: ConnectionPhase.connecting,
              stage: ConnectionStage.findGateway,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(StringsFa.stateConnecting), findsOneWidget);
  });
}
