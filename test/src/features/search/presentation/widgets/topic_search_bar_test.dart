import 'dart:async';

import 'package:flutter/services.dart';
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
    'TopicSearchBar renders compact default row with inline scope/type menu and More filters button',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify scan mode label is shown
      expect(find.text('Latest Messages'), findsOneWidget);

      // Verify fetch-time filter placeholder, inline scope/type summary, and More filters button
      expect(
        find.text('Filter while fetching (key & value)...'),
        findsOneWidget,
      );
      expect(find.text('Both · Contains'), findsOneWidget);
      expect(find.text('More filters'), findsOneWidget);

      // Verify lower right start action button is not rendered
      expect(find.byKey(const Key('search_bar_start_button')), findsNothing);
    },
  );

  testWidgets(
    'TopicSearchBar opens More filters overlay popover without pushing down sibling widgets and closes on Escape or outside click',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                TopicSearchBar(
                  scanMode: TopicScanMode.latestN,
                  onScanModeChanged: (_) {},
                  quickFilterController: quickFilterController,
                  fieldController: fieldController,
                  filterType: FilterType.contains,
                  onFilterTypeChanged: (_) {},
                  searchScope: SearchScope.both,
                  onSearchScopeChanged: (_) {},
                  limitResults: true,
                  onLimitResultsChanged: (_) {},
                  maxResultsController: maxResultsController,
                  partitionController: partitionController,
                  fastTraceEnabled: false,
                  onFastTraceEnabledChanged: (_) {},
                  startStrategy: MultiSearchStartStrategy.latest,
                  onStartStrategyChanged: (_) {},
                  startOffsetController: startOffsetController,
                  startTimestampController: startTimestampController,
                  endStrategy: MultiSearchEndStrategy.latest,
                  onEndStrategyChanged: (_) {},
                  endOffsetController: endOffsetController,
                  endTimestampController: endTimestampController,
                  onStart: () {},
                ),
                const Expanded(
                  child: SizedBox(
                    key: Key('results_area_below_search_bar'),
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resultsFinder = find.byKey(
        const Key('results_area_below_search_bar'),
      );
      final initialResultsTop = tester.getTopLeft(resultsFinder).dy;

      // Popover is closed initially
      expect(find.text('Partition (Opt.)'), findsNothing);

      // Tap More filters toggle
      await tester.tap(find.byKey(const Key('more_filters_button')));
      await tester.pumpAndSettle();

      // Popover options are visible and results area did not move down
      expect(find.text('Partition (Opt.)'), findsOneWidget);
      expect(find.text('Fast Trace (Hash Key)'), findsOneWidget);
      expect(tester.getTopLeft(resultsFinder).dy, equals(initialResultsTop));

      // Press Escape to close popover
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Partition (Opt.)'), findsNothing);
    },
  );

  testWidgets(
    'inline scope/type menu updates scope, match type, and fetch filter placeholder',
    (tester) async {
      SearchScope currentScope = SearchScope.both;
      FilterType currentType = FilterType.contains;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestWidget(
              searchScope: currentScope,
              onSearchScopeChanged: (s) => setState(() => currentScope = s),
              filterType: currentType,
              onFilterTypeChanged: (t) => setState(() => currentType = t),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Both · Contains'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fetch_filter_scope_type_menu')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Key').last);
      await tester.pumpAndSettle();

      expect(currentScope, SearchScope.key);
      expect(find.text('Key · Contains'), findsOneWidget);
      expect(find.text('Filter while fetching (key only)...'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fetch_filter_scope_type_menu')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exact').last);
      await tester.pumpAndSettle();

      expect(currentType, FilterType.exact);
      expect(find.text('Key · Exact'), findsOneWidget);
    },
  );

  testWidgets(
    'TopicSearchBar renders active filter count badge and chips when collapsed and non-default filters exist',
    (tester) async {
      partitionController.text = '3';
      fieldController.text = 'order.id';
      await tester.pumpWidget(buildTestWidget(filterType: FilterType.exact));
      await tester.pumpAndSettle();

      // Button shows active count for popover filters (Field + Partition = 2)
      expect(find.text('More filters (2)'), findsOneWidget);
      // Should show filter chips
      expect(find.text('Partition: 3'), findsOneWidget);
      expect(find.text('Field: order.id'), findsOneWidget);
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
      expect(find.text('More filters (1)'), findsOneWidget);
    },
  );

  testWidgets(
    'Time Range mode shows start and end in one compact row with preset menus and blocks scan when end is before start',
    (tester) async {
      var started = false;
      startTimestampController.text = '2000';
      endTimestampController.text = '1000';

      await tester.pumpWidget(
        buildTestWidget(
          scanMode: TopicScanMode.timeRange,
          onStart: () => started = true,
        ),
      );
      await tester.pumpAndSettle();

      // No inline preset ChoiceChips are shown in compact time range row
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byIcon(Icons.timer_outlined), findsNWidgets(2));
      expect(
        find.text('End time must not be before start time.'),
        findsOneWidget,
      );

      final searchField = find.widgetWithIcon(TextField, Icons.search);
      await tester.tap(searchField);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(started, isFalse);
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
    expect(
      find.text('Beim Abrufen filtern (Schlüssel & Wert)...'),
      findsOneWidget,
    );
    expect(find.text('Beides · Enthält'), findsOneWidget);
    expect(find.text('Weitere Filter'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Partition (opt.)'), findsOneWidget);
    expect(find.text('Feld (Opt.)'), findsOneWidget);
  });
}
