import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/models/topic_search_preset.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/search_stream_configuration.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/saved_searches_service.dart';

void main() {
  final getIt = GetIt.instance;
  late SavedSearchesService savedSearchesService;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    savedSearchesService = SavedSearchesService();
    getIt.registerSingleton<SavedSearchesService>(savedSearchesService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders preset bar and populates inputs when preset selected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pre-populate a saved preset
    final preset = TopicSearchPreset(
      id: 'p-1',
      name: 'High Watermark Errors',
      clusterName: 'local-cluster',
      topicName: 'test-topic',
      scanMode: TopicScanMode.liveTail,
      filterType: FilterType.regex,
      searchScope: SearchScope.value,
      filterTerm: 'ERROR.*',
      maxResults: '999',
      limitResults: true,
      partition: '3',
      createdAt: DateTime.now(),
    );
    await savedSearchesService.savePreset(preset);

    TopicScanMode currentScanMode = TopicScanMode.latestN;
    FilterType currentFilterType = FilterType.contains;
    SearchScope currentSearchScope = SearchScope.both;
    bool currentLimitResults = true;
    final maxResultsController = TextEditingController(text: '200');
    final partitionController = TextEditingController();
    final startOffsetController = TextEditingController();
    final startTimestampController = TextEditingController();
    final endOffsetController = TextEditingController();
    final endTimestampController = TextEditingController();
    final filterTermController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SearchStreamConfiguration(
              clusterName: 'local-cluster',
              topicName: 'test-topic',
              scanMode: currentScanMode,
              onScanModeChanged: (m) => currentScanMode = m,
              filterType: currentFilterType,
              onFilterTypeChanged: (f) => currentFilterType = f,
              searchScope: currentSearchScope,
              onSearchScopeChanged: (s) => currentSearchScope = s,
              filterTermController: filterTermController,
              fastTraceEnabled: false,
              onFastTraceChanged: (_) {},
              limitResults: currentLimitResults,
              onLimitResultsChanged: (l) => currentLimitResults = l,
              maxResultsController: maxResultsController,
              partitionController: partitionController,
              startStrategy: MultiSearchStartStrategy.latest,
              onStartStrategyChanged: (_) {},
              startOffsetController: startOffsetController,
              startTimestampController: startTimestampController,
              endStrategy: MultiSearchEndStrategy.latest,
              onEndStrategyChanged: (_) {},
              endOffsetController: endOffsetController,
              endTimestampController: endTimestampController,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify presets dropdown is shown with "Default"
    expect(find.text('Search Presets'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);

    // Open dropdown and select the preset
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();

    expect(find.text('High Watermark Errors'), findsOneWidget);
    await tester.tap(find.text('High Watermark Errors').last);
    await tester.pumpAndSettle();

    // Verify inputs were populated
    expect(currentScanMode, TopicScanMode.liveTail);
    expect(currentFilterType, FilterType.regex);
    expect(currentSearchScope, SearchScope.value);
    expect(filterTermController.text, 'ERROR.*');
    expect(maxResultsController.text, '999');
    expect(partitionController.text, '3');

    // Test deleting the preset
    final deleteFinder = find.byIcon(Icons.delete_outline);
    expect(deleteFinder, findsOneWidget);
    await tester.tap(deleteFinder);
    await tester.pumpAndSettle();

    final remaining = await savedSearchesService.getPresets(
      clusterName: 'local-cluster',
      topicName: 'test-topic',
    );
    expect(remaining, isEmpty);
  });
}
