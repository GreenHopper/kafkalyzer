import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_list_item.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class MockSchemaController extends ChangeNotifier implements SchemaController {
  @override
  List<String>? getSchemas(ClusterProfile cluster) => null;

  @override
  bool isLoading(ClusterProfile cluster) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSchemaControllerWithSchema extends ChangeNotifier
    implements SchemaController {
  @override
  List<String>? getSchemas(ClusterProfile cluster) => ['test-topic-value'];

  @override
  bool isLoading(ClusterProfile cluster) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testTopic = TopicMetadata(
    name: 'test-topic',
    partitionCount: 3,
    replicationFactor: 1,
    cleanupPolicy: 'delete',
    retentionMs: '86400000',
  );

  const testProfile = ClusterProfile(
    name: 'local-cluster',
    bootstrapServers: 'localhost:9092',
  );

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<SchemaController>(() => MockSchemaController());
  });

  Widget createWidgetUnderTest({
    required TopicMetadata topic,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    VoidCallback? onOpenInNewTab,
    ClusterProfile? clusterProfile,
    String? highlightQuery,
    double? width,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: width != null
            ? SizedBox(
                width: width,
                child: TopicListItem(
                  topic: topic,
                  isSelected: isSelected,
                  onTap: onTap,
                  onDoubleTap: onDoubleTap,
                  onOpenInNewTab: onOpenInNewTab,
                  clusterProfile: clusterProfile,
                  highlightQuery: highlightQuery,
                ),
              )
            : TopicListItem(
                topic: topic,
                isSelected: isSelected,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                onOpenInNewTab: onOpenInNewTab,
                clusterProfile: clusterProfile,
                highlightQuery: highlightQuery,
              ),
      ),
    );
  }

  testWidgets(
    'renders topic name without inline badges and includes full topic in tooltip',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(topic: testTopic, clusterProfile: testProfile),
      );

      // Topic name rendered
      expect(find.text('test-topic'), findsOneWidget);
      // Micro-badge for partitions should NOT be on the card face
      expect(find.text('3P'), findsNothing);
      expect(find.text('3 Partitions'), findsNothing);
      expect(find.text('RF: 1'), findsNothing);

      // Check Tooltip presence and content (line 1: topic name, line 2: metadata)
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(
        tooltip.message,
        'test-topic\nPartitions: 3 • RF: 1 • Retention: 1.0 days • Cleanup: delete',
      );
    },
  );

  testWidgets(
    'renders hierarchical segmented topic name without inline badges',
    (WidgetTester tester) async {
      const hierarchicalTopic = TopicMetadata(
        name: 'com.company.orders.incoming',
        partitionCount: 12,
        replicationFactor: 3,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          topic: hierarchicalTopic,
          clusterProfile: testProfile,
        ),
      );

      // Both prefix and leaf are in the Text.rich widget
      final textFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText() == 'com.company.orders.incoming',
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      final rootSpan = textWidget.textSpan as TextSpan;
      expect(rootSpan.children?.length, 2);

      final prefixSpan = rootSpan.children![0] as TextSpan;
      expect(prefixSpan.text, 'com.company.orders.');
      expect(prefixSpan.style?.fontWeight, FontWeight.normal);

      final leafSpan = rootSpan.children![1] as TextSpan;
      expect(leafSpan.text, 'incoming');
      expect(leafSpan.style?.fontWeight, FontWeight.bold);

      // Partition badge should NOT be on card face
      expect(find.text('12P'), findsNothing);
    },
  );

  testWidgets('displays Avro schema in tooltip when schema is detected', (
    WidgetTester tester,
  ) async {
    final schemaController = MockSchemaControllerWithSchema();
    await getIt.reset();
    getIt.registerLazySingleton<SchemaController>(() => schemaController);

    await tester.pumpWidget(
      createWidgetUnderTest(topic: testTopic, clusterProfile: testProfile),
    );

    // Badges NOT on card face
    expect(find.text('Avro'), findsNothing);
    expect(find.text('3P'), findsNothing);

    // Tooltip includes Schema: Avro
    final tooltipFinder = find.byType(Tooltip);
    final tooltip = tester.widget<Tooltip>(tooltipFinder);
    expect(tooltip.message?.contains('Schema: Avro'), isTrue);
  });

  testWidgets('triggers onTap callback on single tap', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      createWidgetUnderTest(
        topic: testTopic,
        clusterProfile: testProfile,
        onTap: () => tapped = true,
      ),
    );

    await tester.tap(find.text('test-topic'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('triggers onDoubleTap callback on double tap', (
    WidgetTester tester,
  ) async {
    bool doubleTapped = false;
    await tester.pumpWidget(
      createWidgetUnderTest(
        topic: testTopic,
        clusterProfile: testProfile,
        onDoubleTap: () => doubleTapped = true,
      ),
    );

    await tester.tap(find.text('test-topic'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('test-topic'));
    await tester.pumpAndSettle();

    expect(doubleTapped, isTrue);
  });

  testWidgets('triggers onOpenInNewTab when clicking the trailing button', (
    WidgetTester tester,
  ) async {
    bool openedInNewTab = false;
    await tester.pumpWidget(
      createWidgetUnderTest(
        topic: testTopic,
        clusterProfile: testProfile,
        onOpenInNewTab: () => openedInNewTab = true,
      ),
    );

    final newTabButton = find.byIcon(Icons.add_to_photos_outlined);
    expect(newTabButton, findsOneWidget);

    await tester.tap(newTabButton);
    await tester.pumpAndSettle();

    expect(openedInNewTab, isTrue);
  });

  testWidgets(
    'applies middle ellipsis when topic name is constrained in narrow width',
    (WidgetTester tester) async {
      const longTopic = TopicMetadata(
        name: 'dataops.cdc.db2.jdbc.LKW_TRANSPORT_ORDER_HEADER',
        partitionCount: 12,
        replicationFactor: 3,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          topic: longTopic,
          clusterProfile: testProfile,
          width: 260,
        ),
      );

      final textFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.textSpan?.toPlainText().contains('…') ?? false),
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      final renderedString = textWidget.textSpan!.toPlainText();
      expect(renderedString.contains('…'), isTrue);
      expect(renderedString.startsWith('dat'), isTrue);
      expect(renderedString.endsWith('HEADER'), isTrue);
    },
  );

  testWidgets('highlights search filter matches within the topic name', (
    WidgetTester tester,
  ) async {
    const topic = TopicMetadata(
      name: 'kaenup.lopoco.temp.migrationPreSelection',
      partitionCount: 1,
      replicationFactor: 1,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        topic: topic,
        clusterProfile: testProfile,
        highlightQuery: 'migration',
      ),
    );

    final textFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.textSpan?.toPlainText() ==
              'kaenup.lopoco.temp.migrationPreSelection'),
    );
    expect(textFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(textFinder);
    final rootSpan = textWidget.textSpan as TextSpan;

    final matchSpan =
        rootSpan.children?.firstWhere(
              (span) => span is TextSpan && span.text == 'migration',
            )
            as TextSpan?;

    expect(matchSpan, isNotNull);
    expect(matchSpan!.style?.backgroundColor, isNotNull);
  });
}
