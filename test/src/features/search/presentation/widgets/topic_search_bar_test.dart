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
    MultiSearchStartStrategy startStrategy = MultiSearchStartStrategy.latest,
    MultiSearchEndStrategy endStrategy = MultiSearchEndStrategy.latest,
    VoidCallback? onStart,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
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
}
