import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/main_layout.dart';
import 'package:kafkalyzer/src/theme_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:logger/logger.dart';

class FakeActiveConnectionController extends ChangeNotifier
    implements ActiveConnectionController {
  @override
  ClusterProfile? get activeProfile => null;
  @override
  bool get isConnecting => false;
  @override
  List<TopicMetadata> get topics => [];
  @override
  List<OpenTopicRecord> get openTopics => [];
  @override
  OpenTopicRecord? get activeTopic => null;
  @override
  String? get error => null;
  @override
  String get topicFilter => "";
  @override
  bool get showInternalTopics => false;
  @override
  bool get showStreamTopics => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClusterListController extends ChangeNotifier
    implements ClusterListController {
  @override
  List<ClusterProfile> get clusters => [];
  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTopicController extends ChangeNotifier implements TopicController {
  @override
  bool isLoading(ClusterProfile profile) => false;
  @override
  bool hasCachedTopics(ClusterProfile profile) => false;
  @override
  List<TopicMetadata>? getTopics(ClusterProfile profile) => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSchemaController extends ChangeNotifier implements SchemaController {
  @override
  bool isLoading(ClusterProfile profile) => false;
  List<String> get schemas => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMultiSearchController extends ChangeNotifier
    implements MultiSearchController {
  @override
  String? get outputDirectory => null;
  @override
  List<SearchTarget> get targets => [];
  bool get isSearching => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScriptController extends ChangeNotifier implements ScriptController {
  @override
  List<Script> get scripts => [];
  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScriptRunner extends ChangeNotifier implements ScriptRunner {
  @override
  bool get isRunning => false;
  @override
  Map<String, StepStatus> get stepStatuses => {};
  @override
  Map<String, StepStatus> get topicStatuses => {};
  @override
  Map<String, String> get stepErrorMessages => {};
  @override
  Future<List<ScriptRun>> getPastRuns(Script script) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsService implements SettingsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClusterService implements ClusterService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeKafkaMetadataService implements KafkaMetadataService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSchemaRegistryService implements SchemaRegistryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMessageExportService implements MessageExportService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScriptRepository implements ScriptRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_mode', false);

    await getIt.reset();
    getIt.registerSingleton<Logger>(Logger());
    getIt.registerSingleton<ThemeController>(ThemeController());
    getIt.registerSingleton<ActiveConnectionController>(
      FakeActiveConnectionController(),
    );
    getIt.registerSingleton<ClusterListController>(FakeClusterListController());
    getIt.registerSingleton<TopicController>(FakeTopicController());
    getIt.registerSingleton<SchemaController>(FakeSchemaController());
    getIt.registerSingleton<MultiSearchController>(FakeMultiSearchController());
    getIt.registerSingleton<ScriptController>(FakeScriptController());
    getIt.registerSingleton<ScriptRunner>(FakeScriptRunner());
    getIt.registerSingleton<SettingsService>(FakeSettingsService());
    getIt.registerSingleton<ClusterService>(FakeClusterService());
    getIt.registerSingleton<KafkaMetadataService>(FakeKafkaMetadataService());
    getIt.registerSingleton<SchemaRegistryService>(FakeSchemaRegistryService());
    getIt.registerSingleton<MessageExportService>(FakeMessageExportService());
    getIt.registerSingleton<ScriptRepository>(FakeScriptRepository());

    final keyNavigator = GlobalKey<NavigatorState>();
    final keyMessenger = GlobalKey<ScaffoldMessengerState>();
    getIt.registerSingleton<GlobalKey<NavigatorState>>(keyNavigator);
    getIt.registerSingleton<GlobalKey<ScaffoldMessengerState>>(keyMessenger);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: [Locale('en')],
      home: MainLayout(),
    );
  }

  testWidgets('renders MainLayout with navigation rail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify navigation rail exists
    expect(find.byType(NavigationRail), findsOneWidget);

    // Verify ExplorerView is loaded by default
    expect(find.text('Select a cluster to view topics'), findsOneWidget);

    // Tap on settings rail item (Settings is the 5th destination, index 4)
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Settings view should show Settings sections
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('toggles dark mode / light mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final themeController = getIt<ThemeController>();
    expect(themeController.isDarkMode, isFalse);

    // Find the toggle button
    final themeButtonFinder = find.byTooltip('Switch to Dark Mode');
    expect(themeButtonFinder, findsOneWidget);

    await tester.tap(themeButtonFinder);
    await tester.pumpAndSettle();

    expect(themeController.isDarkMode, isTrue);
  });
}
