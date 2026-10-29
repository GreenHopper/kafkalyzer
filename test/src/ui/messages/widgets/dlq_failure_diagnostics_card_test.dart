import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/dlq_failure_diagnostics_card.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
  );

  final testDlqMessage = KafkaMessage(
    topic: 'orders-dlq',
    partition: 1,
    offset: 200,
    timestamp: 1695888000000,
    key: 'order-1',
    payload: '{"item": "book"}',
  );

  const testMetadata = DlqFailureMetadata(
    originalTopic: 'orders',
    originalPartition: 0,
    originalOffset: 42,
    exceptionMessage: 'NullPointerException at service',
    exceptionClass: 'java.lang.NullPointerException',
    exceptionStacktrace:
        'at com.example.OrderService.process(OrderService.java:10)',
  );

  Widget createWidget({void Function(String, int, int)? onJump}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DlqFailureDiagnosticsCard(
          metadata: testMetadata,
          message: testDlqMessage,
          profile: testProfile,
          onJumpToOriginalMessage: onJump,
        ),
      ),
    );
  }

  group('DlqFailureDiagnosticsCard', () {
    testWidgets(
      'renders diagnostics title, coordinates, and exception details',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.text('Failure Diagnostics (DLQ)'), findsOneWidget);
        expect(
          find.textContaining('Origin: orders [P: 0, O: 42]'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'java.lang.NullPointerException: NullPointerException at service',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('triggers onJumpToOriginalMessage when jump button tapped', (
      tester,
    ) async {
      String? jumpedTopic;
      int? jumpedPartition;
      int? jumpedOffset;

      await tester.pumpWidget(
        createWidget(
          onJump: (t, p, o) {
            jumpedTopic = t;
            jumpedPartition = p;
            jumpedOffset = o;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dlq_jump_original_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dlq_jump_original_button')));

      expect(jumpedTopic, equals('orders'));
      expect(jumpedPartition, equals(0));
      expect(jumpedOffset, equals(42));
    });

    testWidgets('copies kcat replay command to clipboard', (tester) async {
      final List<MethodCall> log = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            methodCall,
          ) async {
            log.add(methodCall);
            return null;
          });

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dlq_copy_kcat_button')));
      await tester.pumpAndSettle();

      expect(log.any((call) => call.method == 'Clipboard.setData'), isTrue);
    });

    testWidgets('toggles stacktrace visibility', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('OrderService.java:10'), findsNothing);

      await tester.tap(find.byKey(const Key('dlq_toggle_stacktrace_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('OrderService.java:10'), findsOneWidget);
    });
  });
}
