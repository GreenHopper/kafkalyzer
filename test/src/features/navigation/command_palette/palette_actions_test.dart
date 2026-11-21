import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/consumer/application/consumer_group_directory.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/command_palette_dialog.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

class _SpyActiveConnectionController extends ChangeNotifier
    implements ActiveConnectionController {
  ClusterProfile? _activeProfile;
  final List<ClusterProfile> connectCalls = [];
  final List<String> openTopicCalls = [];
  final List<OpenTopicRecord> _openTopics = [];

  @override
  ClusterProfile? get activeProfile => _activeProfile;

  @override
  List<OpenTopicRecord> get openTopics => _openTopics;

  @override
  Future<void> connect(ClusterProfile profile) async {
    connectCalls.add(profile);
    _activeProfile = profile;
    notifyListeners();
  }

  @override
  OpenTopicRecord? openTopic({
    required TopicMetadata topic,
    ClusterProfile? profile,
    bool forceNew = false,
    bool selectTab = true,
  }) {
    openTopicCalls.add('${topic.name}:$forceNew');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClusterListController extends ChangeNotifier
    implements ClusterListController {
  _FakeClusterListController(this._clusters);
  final List<ClusterProfile> _clusters;

  @override
  List<ClusterProfile> get clusters => _clusters;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTopicController extends ChangeNotifier implements TopicController {
  _FakeTopicController(this._topics);
  final List<TopicMetadata> _topics;

  @override
  List<TopicMetadata>? getTopics(ClusterProfile profile) => _topics;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScriptController extends ChangeNotifier implements ScriptController {
  @override
  List<Script> get scripts => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;
  const prod = ClusterProfile(
    name: 'prod',
    bootstrapServers: 'b:9092',
    tlsVerification: TlsVerification.enabled,
  );
  const staging = ClusterProfile(
    name: 'staging',
    bootstrapServers: 's:9092',
    tlsVerification: TlsVerification.enabled,
  );

  late _SpyActiveConnectionController spyActive;
  late MainNavigationController nav;

  setUp(() async {
    spyActive = _SpyActiveConnectionController();
    nav = MainNavigationController();
    getIt.registerSingleton<MainNavigationController>(nav);
    getIt.registerSingleton<ActiveConnectionController>(spyActive);
    getIt.registerSingleton<ClusterListController>(
      _FakeClusterListController(const [prod, staging]),
    );
    getIt.registerSingleton<TopicController>(
      _FakeTopicController(const [
        TopicMetadata(name: 'orders', partitionCount: 3, replicationFactor: 1),
      ]),
    );
    getIt.registerSingleton<ConsumerGroupDirectory>(ConsumerGroupDirectory());
    getIt.registerSingleton<ScriptController>(_FakeScriptController());
  });

  tearDown(() async {});

  Widget buildHost() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CommandPaletteDialog.show(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'cluster entry connects once, active profile does not reconnect, topic uses forceNew=false',
    (tester) async {
      nav.select(MainDestination.settings);
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      // 1. Run inactive cluster 'prod'
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'prod');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(spyActive.connectCalls, [prod]);
      expect(nav.destination, MainDestination.explorer);

      // 2. Run active cluster 'prod' again -> no second connect
      nav.select(MainDestination.settings);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'prod');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(spyActive.connectCalls.length, 1);
      expect(nav.destination, MainDestination.explorer);

      // 3. Run topic 'orders' -> openTopic(forceNew: false)
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'orders');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(spyActive.openTopicCalls, ['orders:false']);
      expect(nav.destination, MainDestination.explorer);
    },
  );
}
