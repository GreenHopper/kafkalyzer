import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

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
    mockTopicController = MockTopicController();
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

    when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(false);
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
    await tester.pump();

    expect(find.text('CLUSTERS'), findsOneWidget);
    expect(find.text('test-cluster'), findsOneWidget);
    expect(find.text('Select a cluster to view topics'), findsOneWidget);
  });
}
