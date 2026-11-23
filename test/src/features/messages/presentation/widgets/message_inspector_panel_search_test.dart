import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/features/messages/presentation/widgets/message_inspector_panel.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const message = KafkaMessage(
    topic: 'test-topic',
    partition: 0,
    offset: 42,
    key: 'k',
    payload: 'alpha beta alpha gamma',
    timestamp: 1700000000000,
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: SizedBox(width: 900, height: 600, child: child)),
    );
  }

  testWidgets(
    'shows running state without No matches, then done and capped counts',
    (tester) async {
      final completer = Completer<({Int32List offsets, bool capped})>();
      await tester.pumpWidget(
        wrap(
          MessageInspectorPanel(
            message: message,
            dockPosition: InspectorDockPosition.bottom,
            onToggleDockPosition: () {},
            onClose: () {},
            findPayloadMatches: (_, _) => completer.future,
            onJumpToOriginalMessage: (topic, partition, offset) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open in-inspector search bar via search icon button.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump();
      await tester.pump();

      expect(find.text('No matches'), findsNothing);
      expect(find.bySemanticsLabel('Searching...'), findsOneWidget);

      completer.complete((offsets: Int32List.fromList([0, 11]), capped: false));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2 matches'), findsOneWidget);

      // Capped state
      await tester.pumpWidget(
        wrap(
          MessageInspectorPanel(
            message: message,
            dockPosition: InspectorDockPosition.bottom,
            onToggleDockPosition: () {},
            onClose: () {},
            findPayloadMatches: (_, _) async =>
                (offsets: Int32List.fromList([0, 11, 16]), capped: true),
            onJumpToOriginalMessage: (topic, partition, offset) {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      expect(find.text('1 / 3+'), findsOneWidget);
    },
  );

  testWidgets('shows Search failed instead of No matches when search throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MessageInspectorPanel(
          message: message,
          dockPosition: InspectorDockPosition.bottom,
          onToggleDockPosition: () {},
          onClose: () {},
          findPayloadMatches: (_, _) async => throw Exception('boom'),
          onJumpToOriginalMessage: (topic, partition, offset) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();

    expect(find.text('Search failed'), findsOneWidget);
    expect(find.text('No matches'), findsNothing);
  });
}
