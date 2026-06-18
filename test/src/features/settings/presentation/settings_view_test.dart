import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/settings_view.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

@GenerateMocks([
  ClusterListController,
  ActiveConnectionController,
  SettingsService,
])
import 'settings_view_test.mocks.dart';

void main() {
  late MockClusterListController mockClusterListController;
  late MockActiveConnectionController mockActiveConnectionController;
  late MockSettingsService mockSettingsService;

  final testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    schemaRegistryUrl: 'http://localhost:8081',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'general_default_output_dir': '/tmp',
      'scripting_max_run_history': 50,
      'consumer_max_concurrent_queries': 10,
    });

    mockClusterListController = MockClusterListController();
    mockActiveConnectionController = MockActiveConnectionController();
    mockSettingsService = MockSettingsService();

    final getIt = GetIt.instance;
    getIt.reset();
    getIt.registerSingleton<ClusterListController>(mockClusterListController);
    getIt.registerSingleton<ActiveConnectionController>(
      mockActiveConnectionController,
    );
    getIt.registerSingleton<SettingsService>(mockSettingsService);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const SettingsView(),
    );
  }

  group('SettingsView', () {
    testWidgets('renders general settings', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Default Script Output Directory'), findsOneWidget);
      expect(find.text('/tmp'), findsOneWidget);
      expect(find.text('Max Script Runs to keep'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Maximum Concurrent Lag Queries'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('allows changing maximum concurrent queries setting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Maximum Concurrent Lag Queries',
      );
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, '15');
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('consumer_max_concurrent_queries'), 15);
    });

    testWidgets('renders configuration buttons', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Configuration'), findsOneWidget);
      expect(find.text('Export Configuration'), findsOneWidget);
      expect(find.text('Import Configuration'), findsOneWidget);
    });

    testWidgets('renders cluster list', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Cluster Configuration'), findsOneWidget);
      expect(find.text('test-cluster'), findsOneWidget);
      expect(find.text('localhost:9092'), findsOneWidget);
    });

    testWidgets('calls export configuration', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      when(mockSettingsService.exportConfiguration()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export Configuration'));
      await tester.pump();

      verify(mockSettingsService.exportConfiguration()).called(1);
    });
    testWidgets('shows add cluster dialog on tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Cluster'));
      await tester.pumpAndSettle();

      expect(find.text('Add Cluster'), findsNWidgets(2));
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Cluster'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete test-cluster?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(mockClusterListController.deleteCluster(0)).called(1);
    });
  });
}
