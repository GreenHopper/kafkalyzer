import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

@GenerateMocks([
  ClusterListController,
  ActiveConnectionController,
  TopicController,
  SchemaController,
])
import 'explorer_view_test.mocks.dart';

void main() {
  late MockClusterListController mockClusterListController;
  late MockActiveConnectionController mockActiveConnectionController;
  late MockTopicController mockTopicController;
  late MockSchemaController mockSchemaController;

  final testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    schemaRegistryUrl: 'http://localhost:8081',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
  );

  setUp(() {
    mockClusterListController = MockClusterListController();
    mockActiveConnectionController = MockActiveConnectionController();
    // Use FixedMockTopicController to handle missing hasCachedTopics stub in generated mocks
    mockTopicController = FixedMockTopicController();
    mockSchemaController = MockSchemaController();

    final getIt = GetIt.instance;
    getIt.reset();
    getIt.registerSingleton<ClusterListController>(mockClusterListController);
    getIt.registerSingleton<ActiveConnectionController>(
      mockActiveConnectionController,
    );
    getIt.registerSingleton<TopicController>(mockTopicController);
    getIt.registerSingleton<SchemaController>(mockSchemaController);

    // Stub ChangeNotifier methods to prevent watch_it hangs
    when(mockActiveConnectionController.addListener(any)).thenReturn(null);
    when(mockActiveConnectionController.removeListener(any)).thenReturn(null);
    when(mockActiveConnectionController.hasListeners).thenReturn(false);

    when(mockClusterListController.addListener(any)).thenReturn(null);
    when(mockClusterListController.removeListener(any)).thenReturn(null);
    when(mockClusterListController.hasListeners).thenReturn(false);

    when(mockTopicController.addListener(any)).thenReturn(null);
    when(mockTopicController.removeListener(any)).thenReturn(null);
    when(mockTopicController.hasListeners).thenReturn(false);

    when(mockSchemaController.addListener(any)).thenReturn(null);
    when(mockSchemaController.removeListener(any)).thenReturn(null);
    when(mockSchemaController.hasListeners).thenReturn(false);
    when(mockSchemaController.getSchemas(any)).thenReturn([]);
    when(mockSchemaController.isLoading(any)).thenReturn(false);
    when(mockTopicController.hasCachedTopics(any)).thenReturn(false);
    when(mockTopicController.isLoading(any)).thenReturn(false);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const Scaffold(body: ExplorerView()),
    );
  }

  group('ExplorerView', () {
    testWidgets('renders list of clusters', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Use pump instead of pumpAndSettle to avoid hangs

      expect(find.text('CLUSTERS'), findsOneWidget); // Sidebar header
      expect(find.text('test-cluster'), findsOneWidget);
      expect(
        find.text('Select a cluster to view topics'),
        findsOneWidget,
      ); // Empty state
    });

    testWidgets('shows topics when cluster is active', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.topics).thenReturn([
        const TopicMetadata(
          name: 'test-topic',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ]);
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.getTopics(testProfile)).thenReturn([
        const TopicMetadata(
          name: 'test-topic',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ]);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('test-topic'), findsOneWidget);
    });

    testWidgets('selects cluster on tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.tap(find.text('test-cluster'));
      await tester.pump();

      verify(mockActiveConnectionController.connect(testProfile)).called(1);
      verify(mockSchemaController.fetchSchemas(testProfile)).called(1);
    });

    testWidgets('filtering updates topics', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockActiveConnectionController.topics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'filter');
      await tester.pump();

      verify(
        mockActiveConnectionController.updateTopicFilter('filter'),
      ).called(1);
    });

    testWidgets('toggle internal topics', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockActiveConnectionController.topics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
      await tester.tap(switches.first);
      await tester.pump();

      verify(
        mockActiveConnectionController.toggleShowInternalTopics(true),
      ).called(1);
    });
  });
}

class FixedMockTopicController extends MockTopicController {
  @override
  bool hasCachedTopics(ClusterProfile? cluster) {
    return super.noSuchMethod(
          Invocation.method(#hasCachedTopics, [cluster]),
          returnValue: false,
          returnValueForMissingStub: false,
        )
        as bool;
  }
}
