import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/topic_partition_table.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart' as consumer;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../rust/api/rust_mocks.mocks.dart';

Future<void> awaitIsolates(WidgetTester tester) async {
  await tester.pump();
  int attempts = 0;
  while (tester.any(find.byType(CircularProgressIndicator)) && attempts < 50) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    attempts++;
  }
  await tester.pumpAndSettle();
}

void main() {
  late MockKafkalyzerRustLibApi mockApi;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    mockApi = MockKafkalyzerRustLibApi();
    KafkalyzerRustLib.initMock(api: mockApi);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  setUp(() {
    reset(mockApi);
  });

  const testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
  );

  Widget createWidgetUnderTest({
    required List<TopicPartitionLag> partitionLags,
    Map<String, int>? partitionDeltas,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return TopicPartitionTable(
              profile: testProfile,
              partitionLags: partitionLags,
              partitionDeltas: partitionDeltas,
              l10n: l10n,
            );
          },
        ),
      ),
    );
  }

  group('TopicPartitionTable', () {
    testWidgets(
      'displays message details dialog when offset was adjusted to watermark',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final stream = Stream<consumer.KafkaMessage>.fromIterable([
          const consumer.KafkaMessage(
            topic: '',
            partition: -1,
            offset: -1,
            payload: '__PROGRESS__:0:100',
            timestamp: 0,
          ),
          const consumer.KafkaMessage(
            topic: 'test-topic',
            partition: 1,
            offset: 286229286, // Adjusted from low watermark
            key: 'test-key',
            payload: '{"event":"test"}',
            timestamp: 1700000000,
          ),
          const consumer.KafkaMessage(
            topic: 'test-topic',
            partition: -1,
            offset: -1,
            payload: '__EOF__',
            timestamp: 0,
          ),
        ]);

        when(
          mockApi.crateApiKafkaConsumerConsumeWithFilter(
            profile: anyNamed('profile'),
            topic: anyNamed('topic'),
            filterType: anyNamed('filterType'),
            searchScope: anyNamed('searchScope'),
            runForever: anyNamed('runForever'),
            startOffset: anyNamed('startOffset'),
            startTimestamp: anyNamed('startTimestamp'),
            startPartition: anyNamed('startPartition'),
            fastTraceKey: anyNamed('fastTraceKey'),
            endOffset: anyNamed('endOffset'),
            endTimestamp: anyNamed('endTimestamp'),
            maxResults: anyNamed('maxResults'),
            filterTerms: anyNamed('filterTerms'),
            filterField: anyNamed('filterField'),
            startFromTail: anyNamed('startFromTail'),
          ),
        ).thenAnswer((_) => stream);

        await tester.pumpWidget(
          createWidgetUnderTest(
            partitionLags: const [
              TopicPartitionLag(
                topic: 'test-topic',
                partition: 1,
                logEndOffset: 286229616,
                currentOffset: 286228569, // Below low watermark
                lag: 1047,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap view message icon
        final viewBtn = find.byIcon(Icons.visibility_outlined);
        expect(viewBtn, findsOneWidget);
        await tester.tap(viewBtn);
        await tester.pump();
        await awaitIsolates(tester);

        // Verify MessageDetailsDialog is opened with the message
        expect(find.byType(MessageDetailsDialog), findsOneWidget);
        expect(find.text('286229286'), findsWidgets);
      },
    );

    testWidgets('shows info snackbar when no message is found for offset', (
      tester,
    ) async {
      final stream = Stream<consumer.KafkaMessage>.fromIterable([
        const consumer.KafkaMessage(
          topic: 'test-topic',
          partition: -1,
          offset: -1,
          payload: '__EOF__',
          timestamp: 0,
        ),
      ]);

      when(
        mockApi.crateApiKafkaConsumerConsumeWithFilter(
          profile: anyNamed('profile'),
          topic: anyNamed('topic'),
          filterType: anyNamed('filterType'),
          searchScope: anyNamed('searchScope'),
          runForever: anyNamed('runForever'),
          startOffset: anyNamed('startOffset'),
          startTimestamp: anyNamed('startTimestamp'),
          startPartition: anyNamed('startPartition'),
          fastTraceKey: anyNamed('fastTraceKey'),
          endOffset: anyNamed('endOffset'),
          endTimestamp: anyNamed('endTimestamp'),
          maxResults: anyNamed('maxResults'),
          filterTerms: anyNamed('filterTerms'),
          filterField: anyNamed('filterField'),
          startFromTail: anyNamed('startFromTail'),
        ),
      ).thenAnswer((_) => stream);

      await tester.pumpWidget(
        createWidgetUnderTest(
          partitionLags: const [
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 1,
              logEndOffset: 100,
              currentOffset: 100,
              lag: 0,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final viewBtn = find.byIcon(Icons.visibility_outlined);
      await tester.tap(viewBtn);
      await tester.pump();
      await awaitIsolates(tester);

      expect(find.byType(MessageDetailsDialog), findsNothing);
      expect(
        find.textContaining('No message found at or after offset 100'),
        findsOneWidget,
      );
    });

    testWidgets('shows error snackbar when stream throws an error', (
      tester,
    ) async {
      when(
        mockApi.crateApiKafkaConsumerConsumeWithFilter(
          profile: anyNamed('profile'),
          topic: anyNamed('topic'),
          filterType: anyNamed('filterType'),
          searchScope: anyNamed('searchScope'),
          runForever: anyNamed('runForever'),
          startOffset: anyNamed('startOffset'),
          startTimestamp: anyNamed('startTimestamp'),
          startPartition: anyNamed('startPartition'),
          fastTraceKey: anyNamed('fastTraceKey'),
          endOffset: anyNamed('endOffset'),
          endTimestamp: anyNamed('endTimestamp'),
          maxResults: anyNamed('maxResults'),
          filterTerms: anyNamed('filterTerms'),
          filterField: anyNamed('filterField'),
          startFromTail: anyNamed('startFromTail'),
        ),
      ).thenAnswer(
        (_) => Stream<consumer.KafkaMessage>.error(
          Exception('Kafka connection lost'),
        ),
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          partitionLags: const [
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 1,
              logEndOffset: 100,
              currentOffset: 50,
              lag: 50,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final viewBtn = find.byIcon(Icons.visibility_outlined);
      await tester.tap(viewBtn);
      await tester.pump();
      await awaitIsolates(tester);

      expect(find.byType(MessageDetailsDialog), findsNothing);
      expect(find.textContaining('Kafka connection lost'), findsOneWidget);
    });

    testWidgets('action button is disabled when committed offset is -1', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          partitionLags: const [
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 0,
              logEndOffset: 100,
              currentOffset: -1,
              lag: 100,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });
  });
}
