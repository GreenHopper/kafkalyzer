import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/command_palette_dialog.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/ui/shortcuts/shortcut_overview_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/main_layout.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';
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
  ClusterProfile? get connectingProfile => null;
  @override
  bool get isConnecting => false;
  @override
  List<TopicMetadata> get topics => [];
  @override
  List<OpenTopicRecord> get openTopics => [];
  @override
  OpenTopicRecord? get activeTopic => null;
  @override
  ConnectionError? get error => null;
  @override
  String get topicFilter => "";
  @override
  bool get showInternalTopics => false;
  @override
  bool get showStreamTopics => false;
  @override
  List<String> get unrestoredTopics => const [];

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
  StoreStatus get storeStatus => const StoreStatus.ok();

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
  StoreStatus get storeStatus => const StoreStatus.ok();

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

    getIt.registerSingleton<Logger>(Logger());
    final appearance = AppearanceSettings();
    await appearance.load(prefs);
    getIt.registerSingleton<AppearanceSettings>(appearance);
    getIt.registerSingleton<MainNavigationController>(
      MainNavigationController(),
    );
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
    getIt.registerSingleton<RecentTopicsService>(RecentTopicsService());
    getIt.registerSingleton<UpdateService>(
      UpdateService(logger: Logger(level: Level.off)),
    );

    final keyNavigator = GlobalKey<NavigatorState>();
    final keyMessenger = GlobalKey<ScaffoldMessengerState>();
    getIt.registerSingleton<GlobalKey<NavigatorState>>(keyNavigator);
    getIt.registerSingleton<GlobalKey<ScaffoldMessengerState>>(keyMessenger);
  });

  tearDown(() async {
    if (getIt.isRegistered<UpdateService>()) {
      getIt<UpdateService>().dispose();
    }
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

    // Multi-Search is no longer a standalone rail destination
    expect(find.text('Multi-Search'), findsNothing);

    // Verify ExplorerView is loaded by default with onboarding state
    expect(find.byType(ExplorerOnboardingView), findsOneWidget);

    // Tap on settings rail item (Settings is the 4th destination, index 3)
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

    final appearance = getIt<AppearanceSettings>();
    expect(appearance.themeMode, ThemeMode.light);

    // Find the toggle button
    final themeButtonFinder = find.byTooltip('Switch to Dark Mode');
    expect(themeButtonFinder, findsOneWidget);

    await tester.tap(themeButtonFinder);
    await tester.pumpAndSettle();

    expect(appearance.themeMode, ThemeMode.dark);
  });

  testWidgets(
    'toggles from System mode to explicit Dark mode when light is shown',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appearance = getIt<AppearanceSettings>();
      await appearance.setThemeMode(ThemeMode.system);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final themeButtonFinder = find.byTooltip('Switch to Dark Mode');
      expect(themeButtonFinder, findsOneWidget);

      await tester.tap(themeButtonFinder);
      await tester.pumpAndSettle();

      expect(appearance.themeMode, ThemeMode.dark);
    },
  );

  testWidgets(
    'hosts TlsTransitionDialog sequentially for queued decisions, handling keep/disable/dismiss',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const p1 = ClusterProfile(
        name: 'Cluster One',
        bootstrapServers: 'b1:9093',
        securityProtocol: 'SSL',
        tlsVerification: TlsVerification.unreviewed,
      );
      const p2 = ClusterProfile(
        name: 'Cluster Two',
        bootstrapServers: 'b2:9093',
        securityProtocol: 'SSL',
        tlsVerification: TlsVerification.unreviewed,
      );

      final tlsController = TlsTransitionController(
        probeFn: (p) async => TlsProbeResult(
          outcome: TlsProbeOutcome.certificateRejected,
          message: 'cert error ${p.name}',
        ),
      );
      getIt.registerSingleton<TlsTransitionController>(tlsController);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Queue two decisions via resolveBeforeConnect
      final f1 = tlsController.resolveBeforeConnect(p1);
      final f2 = tlsController.resolveBeforeConnect(p2);
      await tester.pumpAndSettle();

      // First dialog is shown for Cluster One
      expect(find.text('TLS certificate verification failed'), findsOneWidget);
      expect(find.textContaining('Cluster One'), findsOneWidget);

      // Tap "Keep verification on"
      await tester.tap(find.text('Keep verification on'));
      await tester.pumpAndSettle();

      final r1 = await f1;
      expect(r1.profile.tlsVerification, TlsVerification.enabled);
      expect(r1.blockedByCertificateRejection, isTrue);

      // Second dialog is now shown for Cluster Two
      expect(find.text('TLS certificate verification failed'), findsOneWidget);
      expect(find.textContaining('Cluster Two'), findsOneWidget);

      // Tap "Disable verification (insecure)"
      await tester.tap(find.text('Disable verification (insecure)'));
      await tester.pumpAndSettle();

      final r2 = await f2;
      expect(r2.profile.tlsVerification, TlsVerification.disabled);
      expect(r2.blockedByCertificateRejection, isFalse);

      // Dismissal leaves profile unreviewed
      const p3 = ClusterProfile(
        name: 'Cluster Three',
        bootstrapServers: 'b3:9093',
        securityProtocol: 'SSL',
        tlsVerification: TlsVerification.unreviewed,
      );
      final f3 = tlsController.resolveBeforeConnect(p3);
      await tester.pumpAndSettle();
      expect(find.textContaining('Cluster Three'), findsOneWidget);

      // Dismiss dialog by tapping barrier outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      final r3 = await f3;
      expect(r3.profile.tlsVerification, TlsVerification.unreviewed);
      expect(r3.blockedByCertificateRejection, isTrue);
    },
  );

  testWidgets(
    'shows error SnackBar on ErrorReporter notice, opens ErrorDetailsDialog, and copies redacted details',
    (tester) async {
      final reporter = ErrorReporter();
      addTearDown(reporter.dispose);
      GetIt.I.registerSingleton<ErrorReporter>(reporter);

      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MainLayout(),
        ),
      );
      await tester.pumpAndSettle();

      reporter.reportUncaught(
        StateError('Unhandled failure sasl.password=secret_val'),
        StackTrace.current,
      );
      await tester.pumpAndSettle();

      expect(find.text('An unexpected error occurred.'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Error Details'), findsOneWidget);
      expect(find.textContaining('sasl.password=***'), findsOneWidget);
      expect(find.textContaining('secret_val'), findsNothing);

      await tester.tap(find.text('Copy details'));
      await tester.pumpAndSettle();

      expect(copiedText, contains('sasl.password=***'));
      expect(copiedText, isNot(contains('secret_val')));
      expect(find.text('Error details copied to clipboard'), findsOneWidget);
    },
  );

  testWidgets('F1 opens ShortcutOverviewDialog once and Escape closes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MainLayout(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.byType(ShortcutOverviewDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.byType(ShortcutOverviewDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ShortcutOverviewDialog), findsNothing);
  });

  testWidgets(
    '? outside TextField opens ShortcutOverviewDialog, inside does not',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Column(
            children: [
              Material(child: TextField(controller: controller)),
              const Expanded(child: MainLayout()),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Outside TextField: ? opens overview
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.slash,
          logicalKey: LogicalKeyboardKey.question,
          character: '?',
          timeStamp: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShortcutOverviewDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ShortcutOverviewDialog), findsNothing);

      // Inside TextField: ? is typed, overview does not open
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '?');
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.slash,
          logicalKey: LogicalKeyboardKey.question,
          character: '?',
          timeStamp: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '?');
      expect(find.byType(ShortcutOverviewDialog), findsNothing);
    },
  );

  testWidgets('MainNavigationController.select(settings) shows SettingsView', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    getIt<MainNavigationController>().select(MainDestination.settings);
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 3);
  });

  testWidgets(
    'Ctrl+K opens CommandPaletteDialog from any destination and not over dialogs or twice',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      getIt<MainNavigationController>().select(MainDestination.settings);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPaletteDialog), findsOneWidget);

      // Second Ctrl+K does not open a second palette.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPaletteDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPaletteDialog), findsNothing);

      // Open ShortcutOverviewDialog first; Ctrl+K must not open over it.
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.byType(ShortcutOverviewDialog), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPaletteDialog), findsNothing);
    },
  );

  testWidgets(
    'macOS keeps Ctrl+K in focused TextField while Meta+K opens CommandPaletteDialog',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Column(
            children: [
              Material(child: TextField(controller: controller)),
              const Expanded(child: MainLayout()),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      // Ctrl+K on macOS in a focused TextField does not open palette.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPaletteDialog), findsNothing);

      // Meta+K on macOS opens palette even in a focused TextField.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPaletteDialog), findsOneWidget);
    },
  );

  testWidgets('shows update SnackBar for manual AvailableUpdate', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    GetIt.instance<UpdateService>().availableUpdateNotifier.value =
        const AvailableUpdate(version: '1.5.0', canAutoApply: false);
    await tester.pumpAndSettle();

    expect(
      find.text('A new version of Kafkalyzer (v1.5.0) is available.'),
      findsOneWidget,
    );
    expect(find.text('Update'), findsOneWidget);
  });
}
