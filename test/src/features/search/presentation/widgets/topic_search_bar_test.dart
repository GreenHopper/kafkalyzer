import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:mockito/mockito.dart';

import '../../../../rust/api/rust_mocks.mocks.dart';

void main() {
  // Stands in for the Rust regex engine used by the scan: a term with an
  // unbalanced group is uncompilable there, so it must be refused here too.
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  void stubPatternEngine() {
    reset(mockApi);
    when(
      mockApi.crateApiJsonPathValidateFilterPatterns(terms: anyNamed('terms')),
    ).thenAnswer((invocation) async {
      final terms = invocation.namedArguments[#terms] as List<String>;
      return [
        for (final term in terms)
          if (term.split('(').length != term.split(')').length) term,
      ];
    });
  }

  late TextEditingController quickFilterController;
  late TextEditingController fieldController;
  late TextEditingController maxResultsController;
  late TextEditingController partitionController;
  late TextEditingController startOffsetController;
  late TextEditingController startTimestampController;
  late TextEditingController endOffsetController;
  late TextEditingController endTimestampController;

  setUp(() {
    quickFilterController = TextEditingController();
    fieldController = TextEditingController();
    maxResultsController = TextEditingController(text: "200");
    partitionController = TextEditingController();
    startOffsetController = TextEditingController();
    startTimestampController = TextEditingController();
    endOffsetController = TextEditingController();
    endTimestampController = TextEditingController();
  });

  tearDown(() {
    quickFilterController.dispose();
    fieldController.dispose();
    maxResultsController.dispose();
    partitionController.dispose();
    startOffsetController.dispose();
    startTimestampController.dispose();
    endOffsetController.dispose();
    endTimestampController.dispose();
  });

  Widget buildTestWidget({
    TopicScanMode scanMode = TopicScanMode.latestN,
    ValueChanged<TopicScanMode>? onScanModeChanged,
    FilterType filterType = FilterType.contains,
    ValueChanged<FilterType>? onFilterTypeChanged,
    SearchScope searchScope = SearchScope.both,
    ValueChanged<SearchScope>? onSearchScopeChanged,
    bool limitResults = true,
    ValueChanged<bool>? onLimitResultsChanged,
    bool fastTraceEnabled = false,
    ValueChanged<bool>? onFastTraceEnabledChanged,
    int? partitionCount,
    MultiSearchStartStrategy startStrategy = MultiSearchStartStrategy.latest,
    MultiSearchEndStrategy endStrategy = MultiSearchEndStrategy.latest,
    VoidCallback? onStart,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: TopicSearchBar(
          scanMode: scanMode,
          onScanModeChanged: onScanModeChanged ?? (_) {},
          quickFilterController: quickFilterController,
          fieldController: fieldController,
          filterType: filterType,
          onFilterTypeChanged: onFilterTypeChanged ?? (_) {},
          searchScope: searchScope,
          onSearchScopeChanged: onSearchScopeChanged ?? (_) {},
          limitResults: limitResults,
          onLimitResultsChanged: onLimitResultsChanged ?? (_) {},
          maxResultsController: maxResultsController,
          partitionController: partitionController,
          fastTraceEnabled: fastTraceEnabled,
          onFastTraceEnabledChanged: onFastTraceEnabledChanged ?? (_) {},
          partitionCount: partitionCount,
          startStrategy: startStrategy,
          onStartStrategyChanged: (_) {},
          startOffsetController: startOffsetController,
          startTimestampController: startTimestampController,
          endStrategy: endStrategy,
          onEndStrategyChanged: (_) {},
          endOffsetController: endOffsetController,
          endTimestampController: endTimestampController,
          onStart: onStart ?? () {},
        ),
      ),
    );
  }

  testWidgets(
    'TopicSearchBar renders compact default row with advanced toggle as trailing element',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify scan mode label is shown
      expect(find.text('Latest Messages'), findsOneWidget);

      // Verify limit and filter placeholder
      expect(find.text('Filter on fetch (key or value)...'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);

      // Verify lower right start action button is not rendered
      expect(find.byKey(const Key('search_bar_start_button')), findsNothing);
    },
  );

  testWidgets('TopicSearchBar toggles progressive disclosure advanced panel', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Advanced panel is collapsed initially
    expect(find.text('Partition (Opt.)'), findsNothing);

    // Tap advanced toggle
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    // Now advanced options should be visible
    expect(find.text('Partition (Opt.)'), findsOneWidget);
    expect(find.text('Fast Trace (Hash Key)'), findsOneWidget);
    expect(find.text('Exact'), findsOneWidget);
  });

  testWidgets(
    'TopicSearchBar renders active filter chips when collapsed and non-default filters exist',
    (tester) async {
      partitionController.text = '3';
      await tester.pumpWidget(buildTestWidget(filterType: FilterType.exact));
      await tester.pumpAndSettle();

      // Should show filter chips
      expect(find.text('Partition: 3'), findsOneWidget);
      expect(find.text('Type: exact'), findsOneWidget);

      // Deleting partition chip clears controller
      final cancelIcon = find.descendant(
        of: find.widgetWithText(InputChip, 'Partition: 3'),
        matching: find.byIcon(Icons.clear),
      );
      expect(cancelIcon, findsOneWidget);
      await tester.tap(cancelIcon);
      await tester.pumpAndSettle();
      expect(partitionController.text, isEmpty);
    },
  );

  testWidgets(
    'uncompilable regex names the term and blocks the scan on keyboard submit',
    (tester) async {
      stubPatternEngine();
      var started = false;

      await tester.pumpWidget(
        buildTestWidget(
          filterType: FilterType.regex,
          onStart: () => started = true,
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.widgetWithIcon(TextField, Icons.search);
      await tester.enterText(searchField, 'amount(');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Invalid regular expression: amount('), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(started, isFalse);

      final chip = tester.widget<InputChip>(
        find.byKey(const Key('filter_type_chip')),
      );
      expect((chip.avatar as Icon?)?.icon, Icons.error);
    },
  );

  testWidgets(
    'compilable regex starts the scan without an error on keyboard submit',
    (tester) async {
      stubPatternEngine();
      var started = false;

      await tester.pumpWidget(
        buildTestWidget(
          filterType: FilterType.regex,
          onStart: () => started = true,
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.widgetWithIcon(TextField, Icons.search);
      await tester.enterText(searchField, 'amount.*');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_filter_pattern_error')), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(started, isTrue);
    },
  );

  group('Fast Trace partition preview', () {
    testWidgets(
      'shows partition, count, assumption, caveat tooltip, and chip when collapsed',
      (tester) async {
        stubPatternEngine();
        when(
          mockApi.crateApiKafkaUtilsPredictDefaultPartition(
            key: 'order-4711',
            partitionCount: 12,
          ),
        ).thenAnswer((_) async => 3);

        quickFilterController.text = 'order-4711';
        await tester.pumpWidget(
          buildTestWidget(fastTraceEnabled: true, partitionCount: 12),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Chip shows predicted partition when collapsed
        expect(find.text('Fast Trace → P3'), findsOneWidget);

        // Expand advanced panel
        await tester.tap(find.byIcon(Icons.tune));
        await tester.pumpAndSettle();

        expect(find.text('Partition 3 of 12'), findsOneWidget);
        expect(
          find.text(
            'Assumes Java default partitioner (murmur2), UTF-8 text key',
          ),
          findsOneWidget,
        );
        final infoIcon = find.bySemanticsLabel(
          'Fast Trace partitioning assumptions',
        );
        expect(infoIcon, findsOneWidget);
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: infoIcon, matching: find.byType(Tooltip)),
        );
        expect(tooltip.message, contains('librdkafka'));
        expect(tooltip.message, contains('Avro'));
      },
    );

    testWidgets(
      'shows partition count unknown for 0 and null without calling bridge',
      (tester) async {
        stubPatternEngine();
        quickFilterController.text = 'order-4711';

        for (final count in [0, null]) {
          await tester.pumpWidget(
            buildTestWidget(fastTraceEnabled: true, partitionCount: count),
          );
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();

          // Expand advanced panel if needed
          if (find.text('Partition count unknown').evaluate().isEmpty) {
            await tester.tap(find.byIcon(Icons.tune));
            await tester.pumpAndSettle();
          }
          expect(find.text('Partition count unknown'), findsOneWidget);
        }

        verifyNever(
          mockApi.crateApiKafkaUtilsPredictDefaultPartition(
            key: anyNamed('key'),
            partitionCount: anyNamed('partitionCount'),
          ),
        );
      },
    );

    testWidgets('shows enter-key hint and no number when key is empty', (
      tester,
    ) async {
      stubPatternEngine();
      await tester.pumpWidget(
        buildTestWidget(fastTraceEnabled: true, partitionCount: 12),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a key to preview target partition'),
        findsOneWidget,
      );
      verifyNever(
        mockApi.crateApiKafkaUtilsPredictDefaultPartition(
          key: anyNamed('key'),
          partitionCount: anyNamed('partitionCount'),
        ),
      );
    });

    testWidgets(
      'uses first term and shows first-term note for comma-separated terms',
      (tester) async {
        stubPatternEngine();
        when(
          mockApi.crateApiKafkaUtilsPredictDefaultPartition(
            key: 'a',
            partitionCount: 12,
          ),
        ).thenAnswer((_) async => 5);

        quickFilterController.text = ' a , b ';
        await tester.pumpWidget(
          buildTestWidget(fastTraceEnabled: true, partitionCount: 12),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.tune));
        await tester.pumpAndSettle();

        expect(find.text('Partition 5 of 12'), findsOneWidget);
        expect(
          find.text('Only the first term selects the scanned partition'),
          findsOneWidget,
        );
        verify(
          mockApi.crateApiKafkaUtilsPredictDefaultPartition(
            key: 'a',
            partitionCount: 12,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'drops stale bridge answer when key changes before previous completes',
      (tester) async {
        stubPatternEngine();
        final firstCompleter = Completer<int?>();
        final secondCompleter = Completer<int?>();
        when(
          mockApi.crateApiKafkaUtilsPredictDefaultPartition(
            key: 'old',
            partitionCount: 12,
          ),
        ).thenAnswer((_) => firstCompleter.future);
        when(
          mockApi.crateApiKafkaUtilsPredictDefaultPartition(
            key: 'new',
            partitionCount: 12,
          ),
        ).thenAnswer((_) => secondCompleter.future);

        await tester.pumpWidget(
          buildTestWidget(fastTraceEnabled: true, partitionCount: 12),
        );
        await tester.pumpAndSettle();

        final searchField = find.widgetWithIcon(TextField, Icons.search);
        await tester.enterText(searchField, 'old');
        await tester.pump(const Duration(milliseconds: 350));

        await tester.enterText(searchField, 'new');
        await tester.pump(const Duration(milliseconds: 350));

        secondCompleter.complete(7);
        await tester.pumpAndSettle();
        expect(find.text('Fast Trace → P7'), findsOneWidget);

        firstCompleter.complete(2);
        await tester.pumpAndSettle();
        expect(find.text('Fast Trace → P7'), findsOneWidget);
        expect(find.text('Fast Trace → P2'), findsNothing);
      },
    );

    testWidgets('shows partition count unknown when bridge throws', (
      tester,
    ) async {
      stubPatternEngine();
      when(
        mockApi.crateApiKafkaUtilsPredictDefaultPartition(
          key: 'order-4711',
          partitionCount: 12,
        ),
      ).thenThrow(Exception('bridge failure'));

      quickFilterController.text = 'order-4711';
      await tester.pumpWidget(
        buildTestWidget(fastTraceEnabled: true, partitionCount: 12),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Fast Trace'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Partition count unknown'), findsOneWidget);
    });
  });

  testWidgets('renders German labels when locale is de', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        scanMode: TopicScanMode.timeRange,
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Startzeit'), findsOneWidget);
    expect(find.text('Endzeit'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Partition (opt.)'), findsOneWidget);
    expect(find.text('Feld (Opt.)'), findsOneWidget);
    expect(find.text('Typ:'), findsOneWidget);
    expect(find.text('Bereich:'), findsOneWidget);
  });
}
